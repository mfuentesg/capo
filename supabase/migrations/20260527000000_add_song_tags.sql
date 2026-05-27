-- song_tags: reusable tag definitions, scoped to a user or team
CREATE TABLE song_tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL CHECK (length(trim(name)) > 0),
  color TEXT,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  team_id UUID REFERENCES teams(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT song_tags_owner_check CHECK (
    (user_id IS NOT NULL AND team_id IS NULL) OR
    (user_id IS NULL AND team_id IS NOT NULL)
  )
);

-- Prevent duplicate tag names (case-insensitive) within the same owner scope
CREATE UNIQUE INDEX song_tags_name_user_unique
  ON song_tags (lower(trim(name)), user_id) WHERE user_id IS NOT NULL;
CREATE UNIQUE INDEX song_tags_name_team_unique
  ON song_tags (lower(trim(name)), team_id) WHERE team_id IS NOT NULL;

CREATE INDEX idx_song_tags_user_id ON song_tags (user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_song_tags_team_id ON song_tags (team_id) WHERE team_id IS NOT NULL;

-- song_tag_assignments: many-to-many junction between songs and tags
CREATE TABLE song_tag_assignments (
  song_id UUID NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
  tag_id  UUID NOT NULL REFERENCES song_tags(id) ON DELETE CASCADE,
  PRIMARY KEY (song_id, tag_id)
);

CREATE INDEX idx_song_tag_assignments_tag_id ON song_tag_assignments (tag_id);

-- RLS for song_tags
ALTER TABLE song_tags ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage their own personal tags"
  ON song_tags FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Team members manage team tags"
  ON song_tags FOR ALL
  USING (
    team_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM team_members tm
      WHERE tm.team_id = song_tags.team_id AND tm.user_id = auth.uid()
    )
  )
  WITH CHECK (
    team_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM team_members tm
      WHERE tm.team_id = song_tags.team_id AND tm.user_id = auth.uid()
    )
  );

-- RLS for song_tag_assignments
ALTER TABLE song_tag_assignments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage tag assignments for accessible songs"
  ON song_tag_assignments FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM songs s
      WHERE s.id = song_tag_assignments.song_id
        AND (
          s.user_id = auth.uid() OR
          EXISTS (
            SELECT 1 FROM team_members tm
            WHERE tm.team_id = s.team_id AND tm.user_id = auth.uid()
          )
        )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM songs s
      WHERE s.id = song_tag_assignments.song_id
        AND (
          s.user_id = auth.uid() OR
          EXISTS (
            SELECT 1 FROM team_members tm
            WHERE tm.team_id = s.team_id AND tm.user_id = auth.uid()
          )
        )
    )
  );
