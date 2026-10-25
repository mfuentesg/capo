-- Realtime for the tables the clients already subscribe to or mirror locally but that were never
-- added to the publication, so tag, profile and invitation changes only showed up after a manual
-- refresh. Realtime still applies each table's RLS select policies to every event.
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['song_tags', 'song_tag_assignments', 'profiles', 'team_invitations'] LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    END IF;
  END LOOP;
END $$;
