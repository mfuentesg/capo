-- 1. Atomic JSONB merge of several preference keys for the signed-in user.
--    A null value in the patch removes that key. Replaces client-side read-merge-write.
CREATE OR REPLACE FUNCTION merge_user_preferences(p_patch JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller UUID := auth.uid();
  result JSONB;
BEGIN
  IF caller IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;
  IF p_patch IS NULL OR jsonb_typeof(p_patch) <> 'object' THEN
    RAISE EXCEPTION 'Patch must be a JSON object' USING ERRCODE = '22023';
  END IF;

  UPDATE profiles
  SET preferences = (COALESCE(preferences, '{}'::jsonb) || p_patch)
        - COALESCE(
            ARRAY(SELECT key FROM jsonb_each(p_patch) WHERE value = 'null'::jsonb),
            ARRAY[]::text[]
          ),
      updated_at = now()
  WHERE id = caller
  RETURNING preferences INTO result;

  RETURN COALESCE(result, '{}'::jsonb);
END;
$$;

REVOKE ALL ON FUNCTION merge_user_preferences(JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION merge_user_preferences(JSONB) TO authenticated;

-- 2. Pending invitations for the signed-in user. The team_invitations SELECT policy only shows
--    rows to members of the inviting team, so an invitee (not a member yet) saw nothing.
CREATE OR REPLACE FUNCTION get_my_pending_invitations()
RETURNS TABLE (
  id UUID,
  team_id UUID,
  email VARCHAR,
  role team_role_enum,
  token VARCHAR,
  invited_by UUID,
  expires_at TIMESTAMPTZ,
  accepted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ,
  team_name TEXT,
  inviter_name TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller UUID := auth.uid();
  caller_email TEXT;
BEGIN
  IF caller IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;
  SELECT u.email INTO caller_email FROM auth.users u WHERE u.id = caller;

  RETURN QUERY
  SELECT ti.id, ti.team_id, ti.email, ti.role, ti.token, ti.invited_by, ti.expires_at,
         ti.accepted_at, ti.created_at, t.name::text,
         COALESCE(p.full_name, p.email, 'A team member')::text
  FROM team_invitations ti
  JOIN teams t ON t.id = ti.team_id
  LEFT JOIN profiles p ON p.id = ti.invited_by
  WHERE lower(ti.email) = lower(caller_email)
    AND ti.accepted_at IS NULL
    AND ti.expires_at > now()
  ORDER BY ti.created_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION get_my_pending_invitations() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_my_pending_invitations() TO authenticated;

-- 3. Decline: deletes only the caller's own open invitation (RLS DELETE is admin-only).
CREATE OR REPLACE FUNCTION decline_team_invitation(p_token TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller UUID := auth.uid();
  caller_email TEXT;
  removed INT;
BEGIN
  IF caller IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;
  SELECT u.email INTO caller_email FROM auth.users u WHERE u.id = caller;

  DELETE FROM team_invitations ti
  WHERE ti.token = p_token
    AND lower(ti.email) = lower(caller_email)
    AND ti.accepted_at IS NULL;
  GET DIAGNOSTICS removed = ROW_COUNT;
  RETURN removed > 0;
END;
$$;

REVOKE ALL ON FUNCTION decline_team_invitation(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION decline_team_invitation(TEXT) TO authenticated;

-- 4. Atomic resend: replaces an unaccepted invitation with a fresh token and expiry in one
--    transaction (clients used delete + invite, which lost the invitation if the second failed).
CREATE OR REPLACE FUNCTION resend_team_invitation(p_invitation_id UUID)
RETURNS team_invitations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller UUID := auth.uid();
  caller_role team_role_enum;
  old team_invitations;
  fresh team_invitations;
BEGIN
  IF caller IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO old FROM team_invitations WHERE id = p_invitation_id AND accepted_at IS NULL;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invitation not found' USING ERRCODE = 'P0002';
  END IF;

  caller_role := get_team_role(old.team_id, caller);
  IF caller_role IS NULL OR caller_role NOT IN ('owner', 'admin') THEN
    RAISE EXCEPTION 'Only owners and admins can invite members' USING ERRCODE = '42501';
  END IF;
  IF caller_role = 'admin' AND old.role IN ('owner', 'admin') THEN
    RAISE EXCEPTION 'Admins can only invite members as member or viewer' USING ERRCODE = '42501';
  END IF;

  DELETE FROM team_invitations WHERE id = old.id;

  INSERT INTO team_invitations (team_id, email, token, role, invited_by, expires_at)
  VALUES (
    old.team_id, old.email, encode(extensions.gen_random_bytes(16), 'hex'), old.role, caller,
    now() + INTERVAL '7 days'
  )
  RETURNING * INTO fresh;

  RETURN fresh;
END;
$$;

REVOKE ALL ON FUNCTION resend_team_invitation(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION resend_team_invitation(UUID) TO authenticated;
