-- ============================================================
-- D2DW : Googleログイン許可リスト（allowlist）
-- 目的: ログイン自体は誰でもGoogleで可能だが、許可メール以外は
--       データを一切閲覧・記録できないようにする（RLSで実遮断）。
-- 実行順: D2DW_supabase_schema.sql を適用した後に、このファイルを実行。
-- ============================================================

-- ------------------------------------------------------------
-- 1) 許可メール表
-- ------------------------------------------------------------
create table if not exists allowed_emails (
  email      text primary key,
  display_name text,
  role       text not null default 'member',
  note       text,
  created_at timestamptz not null default now()
);
alter table allowed_emails add column if not exists display_name text;
alter table allowed_emails add column if not exists role text not null default 'member';
alter table members add column if not exists email text;
create index if not exists idx_members_email_lower on members (lower(email));
alter table allowed_emails enable row level security;

-- 管理者だけが許可リストを編集できる（閲覧も管理者のみ）
drop policy if exists allowed_emails_admin on allowed_emails;
create policy allowed_emails_admin on allowed_emails for all to authenticated
  using      (exists (select 1 from members m where m.id = auth.uid() and m.role = 'admin'))
  with check (exists (select 1 from members m where m.id = auth.uid() and m.role = 'admin'));

-- ------------------------------------------------------------
-- 2) 許可判定関数（JWTのemailが許可リストにあるか）
--    security definer で allowed_emails を RLS に関係なく参照。
--    RLSポリシーからも、アプリからの rpc('is_allowed') からも使う。
-- ------------------------------------------------------------
create or replace function public.is_allowed()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from allowed_emails ae
    where lower(ae.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;
grant execute on function public.is_allowed() to authenticated;

-- 許可リストに登録された権限をログイン中ユーザーの members 行へ同期。
-- role は admin / moderator / member / viewer の4種類。
create or replace function public.sync_member_from_allowlist()
returns table(role text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text := lower(coalesce(auth.jwt() ->> 'email', ''));
  v_role text;
  v_name text;
begin
  select case lower(ae.role)
    when 'admin' then 'admin'
    when 'moderator' then 'moderator'
    when 'viewer' then 'viewer'
    else 'member'
  end
  into v_role
  from allowed_emails ae
  where lower(ae.email) = v_email;

  select coalesce(nullif(ae.display_name, ''), auth.jwt() ->> 'name', auth.jwt() ->> 'email', 'member')
  into v_name
  from allowed_emails ae
  where lower(ae.email) = v_email;

  if v_role is null then
    raise exception 'not allowed';
  end if;

  insert into members (id, name, email, role)
  values (auth.uid(), v_name, v_email, v_role)
  on conflict (id) do update
    set name = excluded.name,
        email = excluded.email,
        role = excluded.role;

  return query select v_role;
end;
$$;
grant execute on function public.sync_member_from_allowlist() to authenticated;

-- ------------------------------------------------------------
-- 3) ビューを security_invoker 化
--    place_stats は既定だと所有者権限で実行され base表のRLSを
--    すり抜ける。呼び出しユーザーのRLSを適用させる。
-- ------------------------------------------------------------
alter view place_stats set (security_invoker = true);

-- ------------------------------------------------------------
-- 4) 既存ポリシーを「許可ユーザーのみ」に置き換え
--    （schema.sql の using(true) を is_allowed() に差し替え）
-- ------------------------------------------------------------
-- members
drop policy if exists members_select_all on members;
create policy members_select_all on members for select to authenticated
  using (public.is_allowed());

drop policy if exists members_self_upsert on members;
create policy members_self_upsert on members for insert to authenticated
  with check (id = auth.uid() and role = 'member' and public.is_allowed());

drop policy if exists members_self_update on members;
drop policy if exists members_admin_update on members;
create policy members_admin_update on members for update to authenticated
  using (exists (select 1 from members m where m.id = auth.uid() and m.role = 'admin'))
  with check (exists (select 1 from members m where m.id = auth.uid() and m.role = 'admin'));

-- blocks / places / visits / assignments の閲覧
drop policy if exists blocks_select on blocks;
create policy blocks_select on blocks for select to authenticated
  using (public.is_allowed());

drop policy if exists places_select on places;
create policy places_select on places for select to authenticated
  using (public.is_allowed());

drop policy if exists visits_select on visits;
create policy visits_select on visits for select to authenticated
  using (public.is_allowed());

drop policy if exists assign_select on assignments;
create policy assign_select on assignments for select to authenticated
  using (public.is_allowed());

-- 記録の追加も許可ユーザーのみ
drop policy if exists visits_insert on visits;
create policy visits_insert on visits for insert to authenticated
  with check (
    member_id = auth.uid()
    and public.is_allowed()
    and exists (select 1 from members m where m.id = auth.uid() and m.role in ('admin','moderator','member'))
  );

-- 記録の修正/削除も許可ユーザーのみ。
-- 削除は本人の記録、または管理者なら全件削除できる。
drop policy if exists visits_update on visits;
create policy visits_update on visits for update to authenticated
  using (
    public.is_allowed()
    and (
      member_id = auth.uid()
      or exists (select 1 from members m where m.id = auth.uid() and m.role in ('admin','moderator'))
    )
  );

drop policy if exists visits_delete on visits;
create policy visits_delete on visits for delete to authenticated
  using (
    public.is_allowed()
    and (
      member_id = auth.uid()
      or exists (select 1 from members m where m.id = auth.uid() and m.role = 'admin')
    )
  );

-- ============================================================
-- 5) ★必須: 最初の利用者を許可リストへ（メールを実物に変えて実行）
--    空のままだと全員ログインできない点に注意。
-- ============================================================
insert into allowed_emails (email, display_name, role, note) values
  ('yanghezaizheli@gmail.com', '管理者', 'admin', '管理者(初期)')
on conflict (email) do update set role = 'admin';

-- 上記メールで一度ログインすると members 行も admin として同期される。
-- 既存DBで手動昇格する場合:
--   update members set role = 'admin'
--   where id = (select id from auth.users where email = 'yanghezaizheli@gmail.com');
-- 以降、許可リストの追加はアプリ管理者が管理画面から行う。

-- 追加例:
--   insert into allowed_emails (email, display_name, role, note) values ('member@example.com', '山田太郎', 'member', '〇〇区域') on conflict do nothing;
