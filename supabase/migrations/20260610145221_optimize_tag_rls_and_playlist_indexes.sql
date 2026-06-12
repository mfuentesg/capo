-- Performance: wrap auth.uid() in scalar subqueries in the song_tags /
-- song_tag_assignments RLS policies so it is evaluated once per statement
-- (InitPlan) instead of once per row (Supabase linter: auth_rls_initplan).
-- The other tables were already fixed in 20260528122801_optimize_rls_and_indexes.

-- song_tags ------------------------------------------------------------------

DROP POLICY IF EXISTS "Users manage their own personal tags" ON song_tags;
CREATE POLICY "Users manage their own personal tags"
  ON song_tags FOR ALL
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Team members manage team tags" ON song_tags;
CREATE POLICY "Team members manage team tags"
  ON song_tags FOR ALL
  USING (
    team_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM team_members tm
      WHERE tm.team_id = song_tags.team_id AND tm.user_id = (SELECT auth.uid())
    )
  )
  WITH CHECK (
    team_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM team_members tm
      WHERE tm.team_id = song_tags.team_id AND tm.user_id = (SELECT auth.uid())
    )
  );

-- song_tag_assignments -------------------------------------------------------

DROP POLICY IF EXISTS "Users manage tag assignments for accessible songs" ON song_tag_assignments;
CREATE POLICY "Users manage tag assignments for accessible songs"
  ON song_tag_assignments FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM songs s
      WHERE s.id = song_tag_assignments.song_id
        AND (
          s.user_id = (SELECT auth.uid()) OR
          EXISTS (
            SELECT 1 FROM team_members tm
            WHERE tm.team_id = s.team_id AND tm.user_id = (SELECT auth.uid())
          )
        )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM songs s
      WHERE s.id = song_tag_assignments.song_id
        AND (
          s.user_id = (SELECT auth.uid()) OR
          EXISTS (
            SELECT 1 FROM team_members tm
            WHERE tm.team_id = s.team_id AND tm.user_id = (SELECT auth.uid())
          )
        )
    )
  );

-- Indexes --------------------------------------------------------------------

-- Listing team playlists orders by created_at within a team filter; songs and
-- activity_log already have the equivalent composite indexes.
CREATE INDEX IF NOT EXISTS idx_playlists_team_created
  ON playlists (team_id, created_at DESC)
  WHERE team_id IS NOT NULL;
