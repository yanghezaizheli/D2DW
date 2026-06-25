-- ============================================================
-- D2DW: 区域単位 Realtime 同期パッチ
-- 目的:
--   index.html の `filter: 'block_id=eq.<区域ID>'` が効くように、
--   visits に block_id を持たせ、place_id から常に自動補完する。
--
-- 適用先:
--   Supabase SQL Editor で、既存スキーマ適用済みDBに実行。
--   D2DW_supabase_schema.sql をこれから新規適用する場合、このパッチは不要。
-- ============================================================

alter table visits add column if not exists block_id uuid references blocks(id) on delete cascade;

-- 既存データの backfill（place から区域を補完）
update visits v
set block_id = p.block_id
from places p
where p.id = v.place_id
  and v.block_id is distinct from p.block_id;

alter table visits alter column block_id set not null;

-- クライアントから誤った block_id が渡っても、place_id から必ず再計算する。
create or replace function public.set_visit_block_id() returns trigger
language plpgsql as $$
begin
  select block_id into new.block_id from places where id = new.place_id;

  if new.block_id is null then
    raise exception 'place_id does not belong to a block: %', new.place_id;
  end if;

  return new;
end; $$;

drop trigger if exists trg_set_visit_block_id on visits;
create trigger trg_set_visit_block_id before insert or update on visits
  for each row execute function public.set_visit_block_id();

create index if not exists idx_visits_block on visits(block_id);

-- DELETE/UPDATE の Realtime payload に old レコードの全列を含める。
alter table visits replica identity full;

do $$ begin
  alter publication supabase_realtime add table visits;
exception when duplicate_object then null; end $$;

-- ============================================================
-- 適用確認クエリ
-- ============================================================

-- 1) block_id が埋まっていない訪問ログがないこと。
select count(*) as visits_missing_block_id
from visits
where block_id is null;

-- 2) visits.block_id と places.block_id がずれていないこと。
select count(*) as visits_block_id_mismatch
from visits v
join places p on p.id = v.place_id
where v.block_id is distinct from p.block_id;

-- 3) Realtime publication に visits が含まれていること。
select schemaname, tablename
from pg_publication_tables
where pubname = 'supabase_realtime'
  and schemaname = 'public'
  and tablename = 'visits';

-- 4) トリガーが有効なこと。
select trigger_name, event_manipulation, action_timing
from information_schema.triggers
where event_object_schema = 'public'
  and event_object_table = 'visits'
  and trigger_name = 'trg_set_visit_block_id'
order by event_manipulation;
