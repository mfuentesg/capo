-- Harden add_song_to_playlist: the function is SECURITY DEFINER (bypasses RLS),
-- so it must verify the caller is allowed to modify the target playlist before
-- inserting. Mirrors the playlist_songs INSERT policies: playlist owner, or a
-- team member with at least 'member' role on the playlist's team.
CREATE OR REPLACE FUNCTION add_song_to_playlist(p_playlist_id uuid, p_song_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  next_position integer;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM playlists p
    WHERE p.id = p_playlist_id
      AND (
        p.user_id = auth.uid()
        OR (
          p.team_id IS NOT NULL
          AND has_team_permission(p.team_id, auth.uid(), 'member')
        )
      )
  ) THEN
    RAISE EXCEPTION 'Not authorized to modify this playlist'
      USING ERRCODE = '42501';
  END IF;

  SELECT COALESCE(MAX(position) + 1, 0)
  INTO next_position
  FROM playlist_songs
  WHERE playlist_id = p_playlist_id;

  INSERT INTO playlist_songs (playlist_id, song_id, position)
  VALUES (p_playlist_id, p_song_id, next_position)
  ON CONFLICT (playlist_id, song_id) DO NOTHING;
END;
$$;
