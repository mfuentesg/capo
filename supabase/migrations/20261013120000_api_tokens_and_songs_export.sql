-- api_tokens: personal, revocable tokens for read-only API access
CREATE TABLE api_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL CHECK (length(trim(name)) > 0),
  token_hash TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_used_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ
);

CREATE INDEX idx_api_tokens_user_id ON api_tokens (user_id);

ALTER TABLE api_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read own api tokens" ON api_tokens FOR SELECT
  USING (user_id = (SELECT auth.uid()));
CREATE POLICY "Users create own api tokens" ON api_tokens FOR INSERT
  WITH CHECK (user_id = (SELECT auth.uid()));
CREATE POLICY "Users revoke own api tokens" ON api_tokens FOR UPDATE
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

-- Read-only export of every song the token's user can see (own songs + team songs).
-- Mirrors the "Users can read own songs" / "Team members can read team songs" policies;
-- tags are limited to those the token's user can see (song_tags RLS: own personal tags + team tags).
CREATE OR REPLACE FUNCTION export_songs_for_token(
  p_token_hash TEXT,
  p_since TIMESTAMPTZ,
  p_after_updated TIMESTAMPTZ,
  p_after_id UUID,
  p_limit INT
)
RETURNS TABLE (
  id UUID, title TEXT, artist TEXT, key TEXT, bpm INT, lyrics TEXT,
  status TEXT, tags TEXT[], updated_at TIMESTAMPTZ, valid BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user UUID;
  v_limit INT := LEAST(GREATEST(COALESCE(p_limit, 200), 1), 500);
BEGIN
  UPDATE api_tokens t SET last_used_at = now()
   WHERE t.token_hash = p_token_hash AND t.revoked_at IS NULL
  RETURNING t.user_id INTO v_user;

  IF v_user IS NULL THEN
    RETURN QUERY SELECT NULL::UUID, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::INT,
      NULL::TEXT, NULL::TEXT, NULL::TEXT[], NULL::TIMESTAMPTZ, FALSE;
    RETURN;
  END IF;

  RETURN QUERY
  SELECT s.id, s.title::TEXT, s.artist::TEXT, s.key::TEXT, s.bpm, s.lyrics,
         s.status::TEXT,
         COALESCE(
           (SELECT array_agg(tg.name ORDER BY tg.name)
              FROM song_tag_assignments a JOIN song_tags tg ON tg.id = a.tag_id
             WHERE a.song_id = s.id
               AND (tg.user_id = v_user
                    OR (tg.team_id IS NOT NULL AND is_team_member(tg.team_id, v_user)))),
           ARRAY[]::TEXT[]),
         s.updated_at, TRUE
    FROM songs s
   WHERE (s.user_id = v_user
          OR (s.team_id IS NOT NULL AND is_team_member(s.team_id, v_user)))
     AND (p_since IS NULL OR s.updated_at >= p_since)
     AND (p_after_updated IS NULL
          OR (s.updated_at, s.id) > (p_after_updated, p_after_id))
   ORDER BY s.updated_at, s.id
   LIMIT v_limit;
END;
$$;

REVOKE ALL ON FUNCTION export_songs_for_token FROM PUBLIC;
GRANT EXECUTE ON FUNCTION export_songs_for_token TO anon, authenticated;
