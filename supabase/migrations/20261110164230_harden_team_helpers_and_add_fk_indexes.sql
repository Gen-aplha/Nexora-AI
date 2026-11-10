-- NEXORA AI audit hardening migration
-- Applied to project jtwzxboewbzyuhlrfwnf on 2026-11-10.

-- Restrict privileged helper functions to the roles that actually need them.
REVOKE ALL ON FUNCTION public.accept_team_invite(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.accept_team_invite(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.add_team_owner() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.bump_team_conversation_updated_at() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.is_team_admin(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_team_admin(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.is_team_member(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_team_member(uuid) TO authenticated;

-- Cover the foreign keys reported by the performance advisor.
CREATE INDEX IF NOT EXISTS team_conversations_created_by_idx ON public.team_conversations(created_by);
CREATE INDEX IF NOT EXISTS team_files_uploaded_by_idx ON public.team_files(uploaded_by);
CREATE INDEX IF NOT EXISTS team_invites_invited_by_idx ON public.team_invites(invited_by);
CREATE INDEX IF NOT EXISTS team_invites_workspace_id_idx ON public.team_invites(workspace_id);
CREATE INDEX IF NOT EXISTS team_messages_author_id_idx ON public.team_messages(author_id);
CREATE INDEX IF NOT EXISTS team_messages_workspace_id_idx ON public.team_messages(workspace_id);
CREATE INDEX IF NOT EXISTS team_workspaces_created_by_idx ON public.team_workspaces(created_by);

-- Evaluate auth.uid() once per statement rather than once per candidate row.
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
CREATE POLICY "Users can insert their own profile" ON public.profiles
  FOR INSERT TO authenticated
  WITH CHECK ((select auth.uid()) = id);
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
CREATE POLICY "Users can view their own profile" ON public.profiles
  FOR SELECT TO authenticated
  USING ((select auth.uid()) = id);
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile" ON public.profiles
  FOR UPDATE TO authenticated
  USING ((select auth.uid()) = id)
  WITH CHECK ((select auth.uid()) = id);

-- Merge the two DELETE policies into one equivalent policy.
DROP POLICY IF EXISTS team_members_admin_remove ON public.team_members;
DROP POLICY IF EXISTS team_members_leave ON public.team_members;
CREATE POLICY team_members_delete_authorized ON public.team_members
  FOR DELETE TO authenticated
  USING (
    role <> 'owner'
    AND (
      is_team_admin(workspace_id)
      OR user_id = (select auth.uid())
    )
  );
