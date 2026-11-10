create table if not exists public.team_workspaces (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 80),
  description text not null default '' check (char_length(description) <= 500),
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create table if not exists public.team_members (
  workspace_id uuid not null references public.team_workspaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','admin','member')),
  joined_at timestamptz not null default now(),
  primary key (workspace_id,user_id)
);
create table if not exists public.team_invites (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.team_workspaces(id) on delete cascade,
  email text not null,
  token uuid not null unique default gen_random_uuid(),
  role text not null default 'member' check (role in ('admin','member')),
  invited_by uuid not null references auth.users(id) on delete cascade,
  expires_at timestamptz not null default (now() + interval '7 days'),
  accepted_at timestamptz,
  created_at timestamptz not null default now()
);
create table if not exists public.team_conversations (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.team_workspaces(id) on delete cascade,
  title text not null default 'Team conversation' check (char_length(title) between 1 and 120),
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.team_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.team_conversations(id) on delete cascade,
  workspace_id uuid not null references public.team_workspaces(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  author_email text not null,
  content text not null check (char_length(content) between 1 and 20000),
  created_at timestamptz not null default now()
);
create index if not exists team_members_user_idx on public.team_members(user_id);
create index if not exists team_invites_email_idx on public.team_invites(lower(email));
create index if not exists team_conversations_workspace_idx on public.team_conversations(workspace_id,updated_at desc);
create index if not exists team_messages_conversation_idx on public.team_messages(conversation_id,created_at);

create or replace function public.is_team_member(p_workspace_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.team_members m
    where m.workspace_id = p_workspace_id and m.user_id = (select auth.uid())
  );
$$;
create or replace function public.is_team_admin(p_workspace_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.team_members m
    where m.workspace_id = p_workspace_id
      and m.user_id = (select auth.uid())
      and m.role in ('owner','admin')
  );
$$;
revoke all on function public.is_team_member(uuid) from public;
revoke all on function public.is_team_admin(uuid) from public;
grant execute on function public.is_team_member(uuid) to authenticated;
grant execute on function public.is_team_admin(uuid) to authenticated;

create or replace function public.add_team_owner()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.team_members(workspace_id,user_id,role)
  values (new.id,new.created_by,'owner')
  on conflict (workspace_id,user_id) do nothing;
  return new;
end;
$$;
drop trigger if exists team_workspace_owner on public.team_workspaces;
create trigger team_workspace_owner after insert on public.team_workspaces
for each row execute function public.add_team_owner();

create or replace function public.accept_team_invite(p_token uuid)
returns uuid language plpgsql security definer set search_path = ''
as $$
declare
  v_invite public.team_invites%rowtype;
  v_email text;
begin
  if (select auth.uid()) is null then
    raise exception 'Sign in before accepting a team invitation';
  end if;
  v_email := lower(coalesce((select auth.jwt())->>'email',''));
  select * into v_invite from public.team_invites
  where token = p_token and accepted_at is null and expires_at > now()
    and lower(email) = v_email
  for update;
  if not found then
    raise exception 'Invitation is invalid, expired, or belongs to another email address';
  end if;
  insert into public.team_members(workspace_id,user_id,role)
  values (v_invite.workspace_id,(select auth.uid()),v_invite.role)
  on conflict (workspace_id,user_id) do nothing;
  update public.team_invites set accepted_at = now() where id = v_invite.id;
  return v_invite.workspace_id;
end;
$$;
revoke all on function public.accept_team_invite(uuid) from public;
grant execute on function public.accept_team_invite(uuid) to authenticated;

alter table public.team_workspaces enable row level security;
alter table public.team_members enable row level security;
alter table public.team_invites enable row level security;
alter table public.team_conversations enable row level security;
alter table public.team_messages enable row level security;

grant select,insert,update,delete on public.team_workspaces to authenticated;
grant select,delete on public.team_members to authenticated;
grant select,insert,delete on public.team_invites to authenticated;
grant select,insert,update,delete on public.team_conversations to authenticated;
grant select,insert,update,delete on public.team_messages to authenticated;

drop policy if exists team_workspaces_read on public.team_workspaces;
create policy team_workspaces_read on public.team_workspaces for select to authenticated using (public.is_team_member(id));
drop policy if exists team_workspaces_create on public.team_workspaces;
create policy team_workspaces_create on public.team_workspaces for insert to authenticated with check (created_by = (select auth.uid()));
drop policy if exists team_workspaces_update on public.team_workspaces;
create policy team_workspaces_update on public.team_workspaces for update to authenticated using (public.is_team_admin(id)) with check (public.is_team_admin(id));
drop policy if exists team_workspaces_delete on public.team_workspaces;
create policy team_workspaces_delete on public.team_workspaces for delete to authenticated using (created_by = (select auth.uid()));

drop policy if exists team_members_read on public.team_members;
create policy team_members_read on public.team_members for select to authenticated using (public.is_team_member(workspace_id));
drop policy if exists team_members_leave on public.team_members;
create policy team_members_leave on public.team_members for delete to authenticated using (user_id = (select auth.uid()) and role <> 'owner');
drop policy if exists team_members_admin_remove on public.team_members;
create policy team_members_admin_remove on public.team_members for delete to authenticated using (public.is_team_admin(workspace_id) and role <> 'owner');

drop policy if exists team_invites_admin_read on public.team_invites;
create policy team_invites_admin_read on public.team_invites for select to authenticated using (public.is_team_admin(workspace_id));
drop policy if exists team_invites_admin_create on public.team_invites;
create policy team_invites_admin_create on public.team_invites for insert to authenticated with check (public.is_team_admin(workspace_id) and invited_by = (select auth.uid()));
drop policy if exists team_invites_admin_delete on public.team_invites;
create policy team_invites_admin_delete on public.team_invites for delete to authenticated using (public.is_team_admin(workspace_id));

drop policy if exists team_conversations_member_read on public.team_conversations;
create policy team_conversations_member_read on public.team_conversations for select to authenticated using (public.is_team_member(workspace_id));
drop policy if exists team_conversations_member_create on public.team_conversations;
create policy team_conversations_member_create on public.team_conversations for insert to authenticated with check (public.is_team_member(workspace_id) and created_by = (select auth.uid()));
drop policy if exists team_conversations_member_update on public.team_conversations;
create policy team_conversations_member_update on public.team_conversations for update to authenticated using (public.is_team_member(workspace_id)) with check (public.is_team_member(workspace_id));
drop policy if exists team_conversations_member_delete on public.team_conversations;
create policy team_conversations_member_delete on public.team_conversations for delete to authenticated using (public.is_team_admin(workspace_id) or created_by = (select auth.uid()));

drop policy if exists team_messages_member_read on public.team_messages;
create policy team_messages_member_read on public.team_messages for select to authenticated using (public.is_team_member(workspace_id));
drop policy if exists team_messages_member_create on public.team_messages;
create policy team_messages_member_create on public.team_messages for insert to authenticated with check (public.is_team_member(workspace_id) and author_id = (select auth.uid()) and exists (select 1 from public.team_conversations c where c.id = conversation_id and c.workspace_id = team_messages.workspace_id));
drop policy if exists team_messages_author_update on public.team_messages;
create policy team_messages_author_update on public.team_messages for update to authenticated using (author_id = (select auth.uid()) and public.is_team_member(workspace_id)) with check (author_id = (select auth.uid()) and public.is_team_member(workspace_id));
drop policy if exists team_messages_author_delete on public.team_messages;
create policy team_messages_author_delete on public.team_messages for delete to authenticated using (author_id = (select auth.uid()) or public.is_team_admin(workspace_id));

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('nexora-team-files','nexora-team-files',false,12582912,
  array['application/pdf','text/plain','text/markdown','image/png','image/jpeg','image/webp','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'])
on conflict (id) do nothing;
drop policy if exists team_files_member_read on storage.objects;
create policy team_files_member_read on storage.objects for select to authenticated
using (bucket_id = 'nexora-team-files' and public.is_team_member(((storage.foldername(name))[1])::uuid));
drop policy if exists team_files_member_upload on storage.objects;
create policy team_files_member_upload on storage.objects for insert to authenticated
with check (bucket_id = 'nexora-team-files' and public.is_team_member(((storage.foldername(name))[1])::uuid) and (storage.foldername(name))[2] = (select auth.uid())::text);
drop policy if exists team_files_member_delete on storage.objects;
create policy team_files_member_delete on storage.objects for delete to authenticated
using (bucket_id = 'nexora-team-files' and public.is_team_member(((storage.foldername(name))[1])::uuid) and ((storage.foldername(name))[2] = (select auth.uid())::text or public.is_team_admin(((storage.foldername(name))[1])::uuid)));

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'team_messages') then
    alter publication supabase_realtime add table public.team_messages;
  end if;
end $$;
