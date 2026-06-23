-- ============================================================
-- D2DW 戸別訪問記録 PWA : Supabase スキーマ (v0.1)
-- 実行先: Supabase の SQL Editor にそのまま貼り付け
-- 設計書 §4 のデータモデルに対応
-- ============================================================

-- 0) 拡張（UUID生成）。Supabaseでは通常有効ですが念のため。
create extension if not exists pgcrypto;

-- ============================================================
-- 1) 列挙型（種別・記録結果）
--    UIの表記に合わせ日本語の値を使用
-- ============================================================
do $$ begin
  create type place_kind as enum ('戸建て','集合住宅','号室');
exception when duplicate_object then null; end $$;

do $$ begin
  create type visit_outcome as enum ('会えた','不在','投函');
exception when duplicate_object then null; end $$;

-- ============================================================
-- 2) 利用者（auth.users と紐づけ）
--    Supabase Auth でログインしたユーザーのプロフィール
-- ============================================================
create table if not exists members (
  id          uuid primary key references auth.users(id) on delete cascade,
  name        text not null,
  role        text not null default 'member',   -- 'member' | 'admin'
  created_at  timestamptz not null default now()
);

-- ============================================================
-- 3) 区域（blocks）
-- ============================================================
create table if not exists blocks (
  id             uuid primary key default gen_random_uuid(),
  code           text,                 -- 区域番号（例: 8-B）
  name           text not null,        -- 例: 01長住2
  area           text,                 -- エリア
  lat            double precision,     -- 広域マップ用の代表座標
  lng            double precision,
  wide_map_url   text,                 -- 広域地図PDFのURL
  detail_map_url text,                 -- 詳細地図PDFのURL
  created_at     timestamptz not null default now()
);

-- ============================================================
-- 4) 戸・建物・号室（places）— 自己参照で集合住宅→号室を表現
-- ============================================================
create table if not exists places (
  id           uuid primary key default gen_random_uuid(),
  block_id     uuid not null references blocks(id) on delete cascade,
  kind         place_kind not null,
  parent_id    uuid references places(id) on delete cascade,  -- 号室→集合住宅
  label        text,                  -- 号
  display_name text,                  -- 表記・建物名
  address      text,
  map_x        double precision,      -- 詳細地図上のタップ座標（任意・第2段階）
  map_y        double precision,
  status       text not null default '訪問可能',
  note         text,
  sort_order   int default 0,
  created_at   timestamptz not null default now()
);

-- ============================================================
-- 5) 訪問ログ（visits）— 1タップ＝1行。すべての表示はここから集計
-- ============================================================
create table if not exists visits (
  id          uuid primary key default gen_random_uuid(),
  place_id    uuid not null references places(id) on delete cascade,
  member_id   uuid references members(id) on delete set null,
  outcome     visit_outcome not null,
  visited_at  timestamptz not null default now(),
  note        text,
  created_at  timestamptz not null default now()
);

-- ============================================================
-- 6) 区域担当（assignments）— 任意。誰がどの区域を担当するか
-- ============================================================
create table if not exists assignments (
  member_id uuid not null references members(id) on delete cascade,
  block_id  uuid not null references blocks(id) on delete cascade,
  primary key (member_id, block_id)
);

-- ============================================================
-- 7) インデックス
-- ============================================================
create index if not exists idx_places_block   on places(block_id);
create index if not exists idx_places_parent  on places(parent_id);
create index if not exists idx_visits_place    on visits(place_id);
create index if not exists idx_visits_visited  on visits(place_id, visited_at desc);

-- ============================================================
-- 7.5) タイプ別の再訪間隔（visit_rules）＋ type 列
--    「今訪問してよいか(is_due)」を前回結果×タイプの間隔で自動判定する。
--    タイプ: LDR=戸建てエリア / ST-M・EV-M・AL-M=集合住宅系（暫定値・要確認）
-- ============================================================
alter table blocks add column if not exists type text;   -- 区域/エリアのタイプ
alter table places add column if not exists type text;   -- 建物個別のタイプ上書き（任意）

create table if not exists visit_rules (
  type        text primary key,
  absent_days int not null,   -- 不在のあと再訪可になるまでの日数
  flyer_days  int not null,   -- 投函のあと
  met_days    int not null    -- 会えたのあと
);
insert into visit_rules (type, absent_days, flyer_days, met_days) values
  ('LDR', 30, 30,  90),
  ('ST-M',90, 30, 180),
  ('EV-M',90, 30, 180),
  ('AL-M',90, 30, 180)
on conflict (type) do update set
  absent_days=excluded.absent_days, flyer_days=excluded.flyer_days, met_days=excluded.met_days;

-- visit_rules は設定値。ログイン済みなら誰でも参照可（security_invoker ビューから読むため）。
alter table visit_rules enable row level security;
drop policy if exists visit_rules_select on visit_rules;
create policy visit_rules_select on visit_rules for select to authenticated using (true);

-- ============================================================
-- 8) 集計ビュー（place_stats）
--    カード表示用: 前回訪問/前回面会/累計不在/件数/前回結果
--    ＋自動判定: next_visitable_at（次に訪問可になる日時）/ is_due（今訪問可か）
-- ============================================================
-- 注: 列の追加・並べ替えに備え drop してから作成（create or replace は列の挿入/改名が不可）
drop view if exists place_stats;
create view place_stats as
with agg as (
  select
    p.id          as place_id,
    p.block_id,
    p.kind,
    p.parent_id,
    p.label,
    p.display_name,
    p.address,
    p.map_x,
    p.map_y,
    p.status,
    p.note,
    -- 有効タイプ: 建物個別 > 区域 > 種別からの既定（戸建て=LDR / それ以外=EV-M）
    coalesce(p.type, b.type, case when p.kind = '戸建て' then 'LDR' else 'EV-M' end) as eff_type,
    max(v.visited_at)                                     as last_visit_at,
    max(v.visited_at) filter (where v.outcome = '会えた') as last_met_at,
    count(*)          filter (where v.outcome = '不在')   as absent_count,
    count(v.id)                                           as visit_count,
    (array_agg(v.outcome order by v.visited_at desc)
       filter (where v.id is not null))[1]                as last_outcome
  from places p
  join blocks b on b.id = p.block_id
  left join visits v on v.place_id = p.id
  group by p.id, b.type
)
select
  a.*,
  case a.last_outcome
    when '会えた' then a.last_visit_at + (r.met_days    || ' days')::interval
    when '不在'   then a.last_visit_at + (r.absent_days || ' days')::interval
    when '投函'   then a.last_visit_at + (r.flyer_days  || ' days')::interval
    else null
  end as next_visitable_at,
  (
    coalesce(a.status, '訪問可能') = '訪問可能'
    and (
      a.last_visit_at is null
      or now() >= a.last_visit_at + (
        case a.last_outcome
          when '会えた' then r.met_days
          when '不在'   then r.absent_days
          when '投函'   then r.flyer_days
          else 0
        end || ' days')::interval
    )
  ) as is_due
from agg a
left join visit_rules r on r.type = a.eff_type;

-- ============================================================
-- 9) RLS（行レベルセキュリティ）
--    方針: ログイン済みユーザーは全件を閲覧可（共有データのため）。
--    記録(visits)は本人として追加。区域/戸の編集は担当者か管理者のみ。
--    ※ 運用ルールに合わせて後で調整してください。
-- ============================================================
alter table members     enable row level security;
alter table blocks      enable row level security;
alter table places      enable row level security;
alter table visits      enable row level security;
alter table assignments enable row level security;

-- members: 自分の行を読める／更新できる。全員の名前は読める（担当表示用）。
drop policy if exists members_select_all on members;
create policy members_select_all on members for select to authenticated using (true);
drop policy if exists members_self_upsert on members;
create policy members_self_upsert on members for insert to authenticated with check (id = auth.uid());
drop policy if exists members_self_update on members;
create policy members_self_update on members for update to authenticated using (id = auth.uid());

-- blocks / places: 全員が閲覧可
drop policy if exists blocks_select on blocks;
create policy blocks_select on blocks for select to authenticated using (true);
drop policy if exists places_select on places;
create policy places_select on places for select to authenticated using (true);

-- blocks / places の編集: 管理者、または当該区域の担当者のみ
drop policy if exists places_write on places;
create policy places_write on places for all to authenticated
  using (
    exists (select 1 from members m where m.id = auth.uid() and m.role = 'admin')
    or exists (select 1 from assignments a where a.member_id = auth.uid() and a.block_id = places.block_id)
  )
  with check (
    exists (select 1 from members m where m.id = auth.uid() and m.role = 'admin')
    or exists (select 1 from assignments a where a.member_id = auth.uid() and a.block_id = places.block_id)
  );

drop policy if exists blocks_write on blocks;
create policy blocks_write on blocks for all to authenticated
  using (exists (select 1 from members m where m.id = auth.uid() and m.role = 'admin'))
  with check (exists (select 1 from members m where m.id = auth.uid() and m.role = 'admin'));

-- visits: 全員閲覧可。追加は本人として。修正/削除は本人または管理者。
drop policy if exists visits_select on visits;
create policy visits_select on visits for select to authenticated using (true);
drop policy if exists visits_insert on visits;
create policy visits_insert on visits for insert to authenticated
  with check (member_id = auth.uid());
drop policy if exists visits_update on visits;
create policy visits_update on visits for update to authenticated
  using (member_id = auth.uid()
         or exists (select 1 from members m where m.id = auth.uid() and m.role = 'admin'));
drop policy if exists visits_delete on visits;
create policy visits_delete on visits for delete to authenticated
  using (member_id = auth.uid()
         or exists (select 1 from members m where m.id = auth.uid() and m.role = 'admin'));

-- assignments: 閲覧は全員、編集は管理者
drop policy if exists assign_select on assignments;
create policy assign_select on assignments for select to authenticated using (true);
drop policy if exists assign_write on assignments;
create policy assign_write  on assignments for all to authenticated
  using (exists (select 1 from members m where m.id = auth.uid() and m.role = 'admin'))
  with check (exists (select 1 from members m where m.id = auth.uid() and m.role = 'admin'));

-- ============================================================
-- 10) リアルタイム配信（端末間同期）
--    visits と places を Realtime のパブリケーションに追加
-- ============================================================
do $$ begin
  alter publication supabase_realtime add table visits;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table places;
exception when duplicate_object then null; end $$;

-- ============================================================
-- 11) サインアップ時に members を自動作成（任意）
-- ============================================================
-- members 行はアプリ側(ログイン時の upsert)で作成します。
-- auth.users へのトリガーは「Database error creating new user」の原因になりやすいため使いません。
-- 既存のトリガーがあれば外します:
drop trigger if exists on_auth_user_created on auth.users;

-- ============================================================
-- 動作確認用クエリ（任意）:
--   select * from place_stats where block_id = '<区域id>';
-- ============================================================
