-- ============================================================
-- D2DW: places に地図用の緯度経度を追加
--   集合住宅(オートロック/エレベーター/階段/メゾネット/タウンハウス)を
--   広域地図に個別ピン表示するため。住所からの初回ジオコーディング結果や
--   全体マップ上での手動配置をここに保存する。
--   実行先: Supabase SQL Editor
-- ============================================================

alter table places add column if not exists lat double precision;  -- 広域地図用の緯度
alter table places add column if not exists lng double precision;  -- 広域地図用の経度

-- place_stats ビューに lat/lng を露出（アプリが集計ビュー経由で参照するため）
-- 注: 列追加のため drop してから再作成（create or replace は列の挿入不可）
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
    p.lat,
    p.lng,
    p.status,
    p.note,
    p.sort_order,
    p.type as place_type,
    case
      when upper(coalesce(p.type, b.type, '')) like '%LDR%'  then 'LDR'
      when upper(coalesce(p.type, b.type, '')) like '%ST-M%' then 'ST-M'
      when upper(coalesce(p.type, b.type, '')) like '%EV-M%' then 'EV-M'
      when upper(coalesce(p.type, b.type, '')) like '%AL-M%' then 'AL-M'
      when p.kind = '戸建て' then 'LDR'
      else 'EV-M'
    end as base_type,
    coalesce(p.has_manager, upper(coalesce(p.type, b.type, '')) like '%MGR%') as has_manager,
    p.manager_hours,
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
  (a.base_type || case when a.has_manager then '-MGR' else '' end) as eff_type,
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
left join visit_rules r on r.type = (a.base_type || case when a.has_manager then '-MGR' else '' end);
