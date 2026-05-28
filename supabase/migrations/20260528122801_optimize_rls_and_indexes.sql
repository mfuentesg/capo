-- ============================================================================
-- 1. Fix auth_rls_initplan: user_song_settings
--    Wrap auth.uid() in (select ...) to prevent per-row re-evaluation
-- ============================================================================
DROP POLICY IF EXISTS "Users manage their own song settings" ON user_song_settings;

CREATE POLICY "Users manage their own song settings"
  ON user_song_settings FOR ALL
  USING ((select auth.uid()) = user_id)
  WITH CHECK ((select auth.uid()) = user_id);

-- ============================================================================
-- 2. Fix multiple_permissive_policies: songs SELECT
--    Merge "Users can read own or team songs" + "Anyone can read songs in
--    public playlists" into one policy using OR
-- ============================================================================
DROP POLICY IF EXISTS "Users can read own or team songs" ON songs;
DROP POLICY IF EXISTS "Anyone can read songs in public playlists" ON songs;

CREATE POLICY "Users can read own, team, or public-playlist songs" ON songs FOR SELECT
  USING (
    -- Own songs
    user_id = (select auth.uid())
    -- OR team songs
    OR (
      team_id IS NOT NULL
      AND is_team_member(songs.team_id, (select auth.uid()))
    )
    -- OR song belongs to a public playlist (anon access for shared pages)
    OR EXISTS (
      SELECT 1
      FROM playlist_songs ps
      JOIN playlists p ON p.id = ps.playlist_id
      WHERE ps.song_id = songs.id
        AND p.is_public = true
    )
  );

-- ============================================================================
-- 3. Add missing FK index: user_song_settings.song_id
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_user_song_settings_song_id
  ON user_song_settings (song_id);

-- ============================================================================
-- 4. Drop genuinely unused indexes
--    Kept: songs_search_vector_idx (FTS), idx_songs_key, idx_teams_created_by,
--          idx_teams_is_public (all support active or anticipated query paths)
-- ============================================================================
DROP INDEX IF EXISTS public.idx_activity_log_created_at;
DROP INDEX IF EXISTS public.idx_activity_log_metadata;
DROP INDEX IF EXISTS public.idx_songs_created_by;
DROP INDEX IF EXISTS public.idx_playlists_created_by;
DROP INDEX IF EXISTS public.idx_team_invitations_invited_by;
DROP INDEX IF EXISTS public.idx_team_members_role;
