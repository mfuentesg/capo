-- ensure_share_code is SECURITY DEFINER and was callable by anyone who knew a playlist id, so it
-- returned (and could create) the share code of playlists the caller cannot edit. Require the same
-- access as the playlists UPDATE policies: the owner, or a team member with the 'member'
-- permission. Server-side callers (service_role) are still allowed.
CREATE OR REPLACE FUNCTION ensure_share_code(playlist_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  generated_code TEXT;
  playlist_record playlists%ROWTYPE;
BEGIN
  SELECT * INTO playlist_record
  FROM playlists
  WHERE id = playlist_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Playlist not found';
  END IF;

  IF auth.role() IS DISTINCT FROM 'service_role'
    AND NOT COALESCE(
      playlist_record.user_id = auth.uid()
      OR (
        playlist_record.team_id IS NOT NULL
        AND has_team_permission(playlist_record.team_id, auth.uid(), 'member')
      ),
      false
    )
  THEN
    RAISE EXCEPTION 'Not allowed to share this playlist' USING ERRCODE = '42501';
  END IF;

  IF playlist_record.share_code IS NOT NULL THEN
    RETURN playlist_record.share_code;
  END IF;

  LOOP
    generated_code := encode(extensions.gen_random_bytes(9), 'base64');
    generated_code := translate(generated_code, '+/', '-_');
    generated_code := substring(generated_code from 1 for 12);

    EXIT WHEN NOT EXISTS (
      SELECT 1
      FROM playlists
      WHERE share_code = generated_code
    );
  END LOOP;

  UPDATE playlists
  SET share_code = generated_code
  WHERE id = playlist_id;

  RETURN generated_code;
END;
$$;
