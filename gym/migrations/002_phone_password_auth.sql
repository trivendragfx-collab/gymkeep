-- GymKeep mobile-first member authentication
-- Authenticated phone accounts are linked to an existing member by the member's
-- registered 10-digit phone number. Owner and staff access remain email-invite based.
create or replace function public.bootstrap_gym_user()
returns jsonb
language plpgsql
security definer
set search_path=public,auth,extensions
as $$
declare
 v_email text;
 v_phone text;
 v_owner_email text;
 v_name text;
 v_role text;
 v_member uuid;
 v_display text;
 v_token text;
 v_phone_digits text;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 select lower(email), phone into v_email,v_phone from auth.users where id=auth.uid();
 select gym_name,lower(owner_email) into v_name,v_owner_email from public.gym_settings order by created_at limit 1;
 select role,member_id,display_name into v_role,v_member,v_display
 from public.gym_users where user_id=auth.uid() and status='active';
 if v_role is not null then
   return jsonb_build_object('ok',true,'role',v_role,'gym_name',v_name,'member_id',v_member,'display_name',v_display);
 end if;
 if v_email is not null and v_email=v_owner_email then
   insert into public.gym_users(user_id,role,display_name,status)
   values(auth.uid(),'owner',v_name,'active')
   on conflict(user_id) do update set role='owner',status='active';
   return jsonb_build_object('ok',true,'role','owner','gym_name',v_name);
 end if;
 if v_email is not null and exists(select 1 from public.gym_staff_invites where email=v_email and accepted_at is null) then
   insert into public.gym_users(user_id,role,display_name,status)
   values(auth.uid(),'staff','Front desk staff','active')
   on conflict(user_id) do update set role='staff',status='active';
   update public.gym_staff_invites set accepted_at=now() where email=v_email and accepted_at is null;
   return jsonb_build_object('ok',true,'role','staff','gym_name',v_name,'display_name','Front desk staff');
 end if;
 v_phone_digits:=right(regexp_replace(coalesce(v_phone,''),'\D','','g'),10);
 if length(v_phone_digits)=10 then
   select id,full_name into v_member,v_display
   from public.members
   where right(regexp_replace(phone,'\D','','g'),10)=v_phone_digits
   limit 1;
 end if;
 if v_member is null and v_email is not null then
   select id,full_name into v_member,v_display from public.members
   where lower(coalesce(email,''))=v_email limit 1;
 end if;
 if v_member is not null then
   insert into public.gym_users(user_id,role,member_id,display_name,status)
   values(auth.uid(),'member',v_member,v_display,'active')
   on conflict(user_id) do update set role='member',member_id=excluded.member_id,status='active';
   if not exists(select 1 from public.member_qr_tokens where member_id=v_member and revoked_at is null) then
     v_token:=encode(gen_random_bytes(32),'hex');
     insert into public.member_qr_tokens(member_id,token_hash)
     values(v_member,encode(digest(v_token,'sha256'),'hex'));
   end if;
   return jsonb_build_object('ok',true,'role','member','gym_name',v_name,'member_id',v_member,'display_name',v_display);
 end if;
 raise exception 'This mobile number or email is not registered with this gym. Ask the gym owner to add your member profile first.';
end;
$$;
revoke all on function public.bootstrap_gym_user() from public,anon;
grant execute on function public.bootstrap_gym_user() to authenticated;
notify pgrst, 'reload schema';