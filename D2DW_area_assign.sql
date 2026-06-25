-- ============================================================
-- D2DW: blocks.area へエリア名を一括登録
--   区域名(blocks.name)に含まれるエリア名でマッチして area を設定する。
--   13エリア名は互いに部分文字列にならないため like 一致で安全。
--   実行先: Supabase SQL Editor
-- ============================================================

update blocks set area = case
  when name like '%長住%'   then '長住'
  when name like '%長丘%'   then '長丘'
  when name like '%皿山%'   then '皿山'
  when name like '%柳河内%' then '柳河内'
  when name like '%寺塚%'   then '寺塚'
  when name like '%大池%'   then '大池'
  when name like '%多賀%'   then '多賀'
  when name like '%野間%'   then '野間'
  when name like '%玉川町%' then '玉川町'
  when name like '%大楠%'   then '大楠'
  when name like '%高宮%'   then '高宮'
  when name like '%市崎%'   then '市崎'
  when name like '%平和%'   then '平和'
  else area
end;

-- 確認用: 割り当て結果の件数（エリアごと）
--   area が null の区域は名前にエリア名が含まれていない＝要手動確認
select coalesce(area,'(未分類)') as area, count(*) as blocks
from blocks group by area order by area;
