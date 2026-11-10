create table if not exists public.team_files (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.team_workspaces(id) on delete cascade,
 uploaded_by uuid not null references auth.users(id) on delete cascade,
 object_path text not null unique,
 file_name text not null check(char_length(file_name) between 1 and 255),
 mime_type text not null default 'application/octet-stream',
 size_bytes bigint not null check(size_bytes between 0 and 12582912),
 uploaded_at timestamptz not null default now()
);
create index if not exists team_files_workspace_idx on public.team_files(workspace_id,uploaded_at desc);
alter table public.team_files enable row level security;
grant select,insert,delete on public.team_files to authenticated;
drop policy if exists team_files_member_read_metadata on public.team_files;
create policy team_files_member_read_metadata on public.team_files for select to authenticated using(public.is_team_member(workspace_id));
drop policy if exists team_files_member_add_metadata on public.team_files;
create policy team_files_member_add_metadata on public.team_files for insert to authenticated with check(public.is_team_member(workspace_id) and uploaded_by=(select auth.uid()) and (storage.foldername(object_path))[1]=workspace_id::text and (storage.foldername(object_path))[2]=(select auth.uid())::text);
drop policy if exists team_files_member_delete_metadata on public.team_files;
create policy team_files_member_delete_metadata on public.team_files for delete to authenticated using(uploaded_by=(select auth.uid()) or public.is_team_admin(workspace_id));
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('nexora-team-files','nexora-team-files',false,12582912,array['application/pdf','text/plain','text/markdown','image/png','image/jpeg','image/webp','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'])
on conflict(id) do nothing;
drop policy if exists team_files_member_read on storage.objects;
create policy team_files_member_read on storage.objects for select to authenticated using(bucket_id='nexora-team-files' and public.is_team_member(((storage.foldername(name))[1])::uuid));
drop policy if exists team_files_member_upload on storage.objects;
create policy team_files_member_upload on storage.objects for insert to authenticated with check(bucket_id='nexora-team-files' and public.is_team_member(((storage.foldername(name))[1])::uuid) and (storage.foldername(name))[2]=(select auth.uid())::text);
drop policy if exists team_files_member_delete on storage.objects;
create policy team_files_member_delete on storage.objects for delete to authenticated using(bucket_id='nexora-team-files' and public.is_team_member(((storage.foldername(name))[1])::uuid) and ((storage.foldername(name))[2]=(select auth.uid())::text or public.is_team_admin(((storage.foldername(name))[1])::uuid)));