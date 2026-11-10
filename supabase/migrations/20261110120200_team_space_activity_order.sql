create or replace function public.bump_team_conversation_updated_at()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
 update public.team_conversations set updated_at=now() where id=new.conversation_id;
 return new;
end;
$$;
drop trigger if exists team_message_bump_conversation on public.team_messages;
create trigger team_message_bump_conversation after insert on public.team_messages
for each row execute function public.bump_team_conversation_updated_at();