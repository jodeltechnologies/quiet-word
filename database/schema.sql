create extension if not exists pgcrypto with schema extensions;
create schema if not exists qw_private;
revoke all on schema qw_private from public,anon,authenticated;
grant usage on schema qw_private to authenticated;
create table qw_private.accounts(user_id uuid primary key references auth.users(id) on delete cascade,pin_hash text not null,failed integer not null default 0,blocked_until timestamptz,pin_version integer not null default 1);
create table qw_private.sessions(token_hash text primary key,user_id uuid not null references auth.users(id) on delete cascade,pin_version integer not null,expires timestamptz not null);
create index sessions_user on qw_private.sessions(user_id);
create table qw_private.records(user_id uuid not null references auth.users(id) on delete cascade,key text not null,value text not null,version integer not null default 1,updated_at timestamptz not null default now(),primary key(user_id,key));
alter table qw_private.accounts enable row level security;
alter table qw_private.sessions enable row level security;
alter table qw_private.records enable row level security;
revoke all on all tables in schema qw_private from public,anon,authenticated;
-- A deliberately privileged function in a non-exposed schema. It checks auth.uid()
-- for every action and requires a separate PIN session for every data operation.
create or replace function qw_private.call(p_action text,p_payload jsonb default '{}'::jsonb,p_token text default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); a qw_private.accounts%rowtype; tok text; op jsonb; changed integer; conflicts jsonb:='[]'::jsonb; rows jsonb; pin text:=p_payload->>'pin'; confirmed text:=p_payload->>'confirm'; action text:=p_action;
begin
 if uid is null then return jsonb_build_object('error','Sign in to your app account.','code',401);end if;
 select * into a from qw_private.accounts where user_id=uid for update;
 if action='status' then return jsonb_build_object('configured',a.user_id is not null);end if;
 if action='setup' then
  if a.user_id is not null then return jsonb_build_object('error','A PIN already exists. Unlock to change it.','code',409);end if;
  if pin is null or pin !~ '^[0-9]{4}$' or pin is distinct from confirmed then return jsonb_build_object('error','Enter and confirm exactly four digits.','code',400);end if;
  insert into qw_private.accounts(user_id,pin_hash) values(uid,extensions.crypt(pin,extensions.gen_salt('bf',10))) on conflict(user_id) do nothing;
  get diagnostics changed=row_count;if changed=0 then return jsonb_build_object('error','A PIN was just created. Please reload.','code',409);end if;
  select * into a from qw_private.accounts where user_id=uid;
 elsif action='unlock' then
  if a.user_id is null then return jsonb_build_object('error','Set your PIN first.','code',409);end if;
  if a.blocked_until>now() then return jsonb_build_object('error','Too many attempts. Wait five minutes.','code',429);end if;
  if a.blocked_until is not null then a.failed:=0;end if;
  if pin is null or pin !~ '^[0-9]{4}$' or extensions.crypt(pin,a.pin_hash)<>a.pin_hash then
   a.failed:=a.failed+1;
   update qw_private.accounts set failed=a.failed,blocked_until=case when a.failed>=5 then now()+interval '5 minutes' else null end where user_id=uid;
   return jsonb_build_object('error',case when a.failed>=5 then 'Too many attempts. Wait five minutes.' else 'Incorrect PIN. Please try again.' end,'code',case when a.failed>=5 then 429 else 403 end);
  end if;
  update qw_private.accounts set failed=0,blocked_until=null where user_id=uid;
 end if;
 if action in ('setup','unlock') then
  tok:=encode(extensions.gen_random_bytes(32),'hex');
  delete from qw_private.sessions where user_id=uid and expires<now();
  insert into qw_private.sessions values(encode(extensions.digest(tok,'sha256'),'hex'),uid,a.pin_version,now()+interval '30 minutes');
  return jsonb_build_object('ok',true,'token',tok);
 end if;
 if action='lock' then delete from qw_private.sessions where user_id=uid and token_hash=encode(extensions.digest(coalesce(p_token,''),'sha256'),'hex');return jsonb_build_object('ok',true);end if;
 if a.user_id is null or not exists(select 1 from qw_private.sessions where user_id=uid and token_hash=encode(extensions.digest(coalesce(p_token,''),'sha256'),'hex') and pin_version=a.pin_version and expires>now()) then return jsonb_build_object('error','Unlock with your PIN to continue.','code',423,'locked',true);end if;
 if action='pin' then
  if pin is null or pin !~ '^[0-9]{4}$' or pin is distinct from confirmed then return jsonb_build_object('error','Enter and confirm exactly four digits.','code',400);end if;
  update qw_private.accounts set pin_hash=extensions.crypt(pin,extensions.gen_salt('bf',10)),pin_version=pin_version+1,failed=0,blocked_until=null where user_id=uid;
  delete from qw_private.sessions where user_id=uid;
  tok:=encode(extensions.gen_random_bytes(32),'hex');
  insert into qw_private.sessions values(encode(extensions.digest(tok,'sha256'),'hex'),uid,a.pin_version+1,now()+interval '30 minutes');
  return jsonb_build_object('ok',true,'token',tok);
 end if;
 if action='save' then
  if jsonb_typeof(p_payload->'ops') is distinct from 'array' or jsonb_array_length(p_payload->'ops')>100 then return jsonb_build_object('error','Invalid changes.','code',400);end if;
  if (select count(*) from jsonb_array_elements(p_payload->'ops'))<>(select count(distinct e->>'key') from jsonb_array_elements(p_payload->'ops') e) then return jsonb_build_object('error','Duplicate changes.','code',400);end if;
  -- Validate every operation before writing any of them.
  for op in select value from jsonb_array_elements(p_payload->'ops') loop
   if (op->>'key') is null or op->>'key' !~ '^(note\.[0-9]{1,5}\.(q[0-2]|response)|done\.[0-9]{1,5}|current)$' or jsonb_typeof(op->'value') is distinct from 'string' or length(op->>'value')>15000 or coalesce(op->>'base','') !~ '^[0-9]{1,9}$' then return jsonb_build_object('error','Invalid change.','code',400);end if;
   if op->>'key' like 'done.%' and op->>'value' not in ('true','false') then return jsonb_build_object('error','Invalid progress.','code',400);end if;
   if op->>'key'='current' and op->>'value' !~ '^[0-9]{1,5}$' then return jsonb_build_object('error','Invalid study.','code',400);end if;
  end loop;
  for op in select value from jsonb_array_elements(p_payload->'ops') loop
   if (op->>'base')::integer=0 then
    insert into qw_private.records(user_id,key,value) values(uid,op->>'key',op->>'value') on conflict(user_id,key) do nothing;
   else
    update qw_private.records set value=op->>'value',version=version+1,updated_at=now() where user_id=uid and key=op->>'key' and version=(op->>'base')::integer;
   end if;
   get diagnostics changed=row_count;if changed=0 then conflicts:=conflicts||jsonb_build_array(op->>'key');end if;
  end loop;
 elsif action<>'records' then return jsonb_build_object('error','Unknown action.','code',400);
 end if;
 select coalesce(jsonb_agg(jsonb_build_object('key',key,'value',value,'version',version,'updated_at',updated_at)),'[]'::jsonb) into rows from qw_private.records where user_id=uid;
 return jsonb_build_object('records',rows,'conflicts',conflicts);
end $$;
revoke all on function qw_private.call(text,jsonb,text) from public,anon,authenticated;
grant execute on function qw_private.call(text,jsonb,text) to authenticated;
create or replace function public.quiet_word(p_action text,p_payload jsonb default '{}'::jsonb,p_token text default null) returns jsonb language sql security invoker set search_path='' as $$select qw_private.call(p_action,p_payload,p_token)$$;
revoke all on function public.quiet_word(text,jsonb,text) from public,anon;
grant execute on function public.quiet_word(text,jsonb,text) to authenticated;
