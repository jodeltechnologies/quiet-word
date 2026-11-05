-- PIN access without Supabase email accounts. A random 256-bit journal code
-- identifies the private journal. Every read/write also needs a PIN session.
create table qw_private.pin_journals(key_hash text primary key,pin_hash text not null,failed integer not null default 0,blocked_until timestamptz,pin_version integer not null default 1,created_at timestamptz not null default now());
create table qw_private.pin_sessions(token_hash text primary key,journal_hash text not null references qw_private.pin_journals(key_hash) on delete cascade,pin_version integer not null,expires timestamptz not null);
create index pin_sessions_journal on qw_private.pin_sessions(journal_hash);
create table qw_private.pin_records(journal_hash text not null references qw_private.pin_journals(key_hash) on delete cascade,key text not null,value text not null,version integer not null default 1,updated_at timestamptz not null default now(),primary key(journal_hash,key));
alter table qw_private.pin_journals enable row level security;
alter table qw_private.pin_sessions enable row level security;
alter table qw_private.pin_records enable row level security;
revoke all on qw_private.pin_journals,qw_private.pin_sessions,qw_private.pin_records from public,anon,authenticated;
-- This private implementation intentionally uses capability authentication:
-- a hashed 256-bit recovery code plus a hashed expiring PIN session, instead
-- of auth.uid(). Never return the stored hashes or unscoped journal records.
create or replace function qw_private.pin_call(p_action text,p_payload jsonb,p_key text,p_token text) returns jsonb language plpgsql security definer set search_path='' as $$
declare j qw_private.pin_journals%rowtype; kh text; tok text; pin text:=p_payload->>'pin'; confirmed text:=p_payload->>'confirm'; op jsonb; changed integer; conflicts jsonb:='[]'::jsonb; rows jsonb; total_size bigint;
begin
 if p_key is null or p_key !~ '^[0-9a-f]{64}$' then return jsonb_build_object('error','Connect this device using your private recovery code.','code',423,'locked',true);end if;
 kh:=encode(extensions.digest(p_key,'sha256'),'hex');
 select * into j from qw_private.pin_journals where key_hash=kh for update;
 if p_action='status' then return jsonb_build_object('configured',j.key_hash is not null);end if;
 if p_action='setup' then
  if j.key_hash is not null then return jsonb_build_object('error','A PIN already exists. Unlock your journal.','code',409);end if;
  if pin is null or pin !~ '^[0-9]{4}$' or pin is distinct from confirmed then return jsonb_build_object('error','Enter and confirm exactly four digits.','code',400);end if;
  perform pg_catalog.pg_advisory_xact_lock(87214033);
  if (select count(*) from qw_private.pin_journals)>=100 or (select count(*) from qw_private.pin_journals where created_at>now()-interval '1 hour')>=10 then return jsonb_build_object('error','New journal limit reached. Try again later or connect an existing journal.','code',429);end if;
  insert into qw_private.pin_journals(key_hash,pin_hash) values(kh,extensions.crypt(pin,extensions.gen_salt('bf',10))) on conflict do nothing;
  get diagnostics changed=row_count;if changed=0 then return jsonb_build_object('error','This journal was just created. Please unlock it.','code',409);end if;
  select * into j from qw_private.pin_journals where key_hash=kh;
 elsif p_action='unlock' then
  if j.key_hash is null then return jsonb_build_object('error','Recovery code not found. Check the code or create a new journal.','code',404);end if;
  if j.blocked_until>now() then return jsonb_build_object('error','Too many attempts. Wait five minutes.','code',429);end if;
  if j.blocked_until is not null then j.failed:=0;end if;
  if pin is null or pin !~ '^[0-9]{4}$' or extensions.crypt(pin,j.pin_hash)<>j.pin_hash then
   j.failed:=j.failed+1;
   update qw_private.pin_journals set failed=j.failed,blocked_until=case when j.failed>=5 then now()+interval '5 minutes' else null end where key_hash=kh;
   return jsonb_build_object('error',case when j.failed>=5 then 'Too many attempts. Wait five minutes.' else 'Incorrect PIN. Please try again.' end,'code',case when j.failed>=5 then 429 else 403 end);
  end if;
  update qw_private.pin_journals set failed=0,blocked_until=null where key_hash=kh;
 end if;
 if p_action in ('setup','unlock') then
  tok:=encode(extensions.gen_random_bytes(32),'hex');
  delete from qw_private.pin_sessions where journal_hash=kh and expires<now();
  insert into qw_private.pin_sessions values(encode(extensions.digest(tok,'sha256'),'hex'),kh,j.pin_version,now()+interval '30 minutes');
  return jsonb_build_object('ok',true,'token',tok);
 end if;
 if p_action='lock' then delete from qw_private.pin_sessions where journal_hash=kh and token_hash=encode(extensions.digest(coalesce(p_token,''),'sha256'),'hex');return jsonb_build_object('ok',true);end if;
 if j.key_hash is null or not exists(select 1 from qw_private.pin_sessions where journal_hash=kh and token_hash=encode(extensions.digest(coalesce(p_token,''),'sha256'),'hex') and pin_version=j.pin_version and expires>now()) then return jsonb_build_object('error','Unlock with your PIN to continue.','code',423,'locked',true);end if;
 if p_action='pin' then
  if pin is null or pin !~ '^[0-9]{4}$' or pin is distinct from confirmed then return jsonb_build_object('error','Enter and confirm exactly four digits.','code',400);end if;
  update qw_private.pin_journals set pin_hash=extensions.crypt(pin,extensions.gen_salt('bf',10)),pin_version=pin_version+1,failed=0,blocked_until=null where key_hash=kh;
  delete from qw_private.pin_sessions where journal_hash=kh;
  tok:=encode(extensions.gen_random_bytes(32),'hex');
  insert into qw_private.pin_sessions values(encode(extensions.digest(tok,'sha256'),'hex'),kh,j.pin_version+1,now()+interval '30 minutes');
  return jsonb_build_object('ok',true,'token',tok);
 end if;
 if p_action='save' then
  if jsonb_typeof(p_payload->'ops') is distinct from 'array' or jsonb_array_length(p_payload->'ops')>100 then return jsonb_build_object('error','Invalid changes.','code',400);end if;
  if (select count(*) from jsonb_array_elements(p_payload->'ops'))<>(select count(distinct e->>'key') from jsonb_array_elements(p_payload->'ops') e) then return jsonb_build_object('error','Duplicate changes.','code',400);end if;
  select coalesce(sum(length(value)),0) into total_size from qw_private.pin_records where journal_hash=kh;
  for op in select value from jsonb_array_elements(p_payload->'ops') loop
   if op->>'key' is null or op->>'key' !~ '^(note\.[0-9]{1,5}\.(q[0-2]|response)|done\.[0-9]{1,5}|current)$' or jsonb_typeof(op->'value') is distinct from 'string' or length(op->>'value')>15000 or coalesce(op->>'base','') !~ '^[0-9]{1,9}$' then return jsonb_build_object('error','Invalid change.','code',400);end if;
   if op->>'key'<>'current' and (split_part(op->>'key','.',2)::integer>99999 or split_part(op->>'key','.',2)<>((split_part(op->>'key','.',2))::integer)::text) then return jsonb_build_object('error','Invalid study.','code',400);end if;
   if op->>'key' like 'done.%' and op->>'value' not in ('true','false') then return jsonb_build_object('error','Invalid progress.','code',400);end if;
   if op->>'key'='current' then
    if op->>'value' !~ '^[0-9]{1,5}$' then return jsonb_build_object('error','Invalid study.','code',400);end if;
    if (op->>'value')::integer>99999 then return jsonb_build_object('error','Invalid study.','code',400);end if;
   end if;
   total_size:=total_size+greatest(0,length(op->>'value')-coalesce((select length(value) from qw_private.pin_records where journal_hash=kh and key=op->>'key'),0));
  end loop;
  if total_size>2000000 then return jsonb_build_object('error','Journal storage limit reached. Download a backup before reducing older notes.','code',413);end if;
  for op in select value from jsonb_array_elements(p_payload->'ops') loop
   if (op->>'base')::integer=0 then
    insert into qw_private.pin_records(journal_hash,key,value) values(kh,op->>'key',op->>'value') on conflict do nothing;
   else
    update qw_private.pin_records set value=op->>'value',version=version+1,updated_at=now() where journal_hash=kh and key=op->>'key' and version=(op->>'base')::integer;
   end if;
   get diagnostics changed=row_count;if changed=0 then conflicts:=conflicts||jsonb_build_array(op->>'key');end if;
  end loop;
 elsif p_action<>'records' then return jsonb_build_object('error','Unknown action.','code',400);
 end if;
 select coalesce(jsonb_agg(jsonb_build_object('key',key,'value',value,'version',version,'updated_at',updated_at)),'[]'::jsonb) into rows from qw_private.pin_records where journal_hash=kh;
 return jsonb_build_object('records',rows,'conflicts',conflicts);
end $$;
revoke all on function qw_private.pin_call(text,jsonb,text,text) from public,anon,authenticated;
grant usage on schema qw_private to anon;
grant execute on function qw_private.pin_call(text,jsonb,text,text) to anon,authenticated;
create or replace function public.quiet_time_pin(p_action text,p_payload jsonb default '{}'::jsonb,p_key text default null,p_token text default null) returns jsonb language sql security invoker set search_path='' as $$select qw_private.pin_call(p_action,p_payload,p_key,p_token)$$;
revoke all on function public.quiet_time_pin(text,jsonb,text,text) from public,anon,authenticated;
grant execute on function public.quiet_time_pin(text,jsonb,text,text) to anon,authenticated;
