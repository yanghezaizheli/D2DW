-- D2DW サンプルseed（動作確認用） 実データは import_d2dw.py が生成します
begin;
alter table visits add column if not exists source text not null default 'app';
alter table blocks add column if not exists type text;

insert into blocks (id,code,name,area,type,lat,lng) values ('2af4fb83-e61c-5592-ba1b-9758619782ed','8-C','長住2-3','01長住2','LDR',33.55157,130.39948) on conflict (id) do nothing;
insert into blocks (id,code,name,area,type,lat,lng) values ('2c120bde-4c9e-5416-94a2-ca56bfbe3fb5','4-C','長住2-9','01長住2','LDR',33.54872,130.39951) on conflict (id) do nothing;

insert into places (id,block_id,kind,parent_id,label,display_name,status,map_x,map_y) values ('31e0efed-af33-50d8-80c3-618611b7d5bc','2af4fb83-e61c-5592-ba1b-9758619782ed','戸建て',null,'3','藤崎','訪問可能',120,360) on conflict (id) do nothing;
insert into visits (id,place_id,outcome,visited_at,source) values ('f6287afc-305e-53ed-951b-e33de9a2a641','31e0efed-af33-50d8-80c3-618611b7d5bc','会えた','2026-06-13','migration') on conflict (id) do nothing;
insert into places (id,block_id,kind,parent_id,label,display_name,status,map_x,map_y) values ('4dc88a17-45a8-52bf-8251-5abe9a1278a9','2af4fb83-e61c-5592-ba1b-9758619782ed','戸建て',null,'6','エグチ','訪問可能',230,330) on conflict (id) do nothing;
insert into visits (id,place_id,outcome,visited_at,source) values ('1a42ad95-2b22-5128-960f-3badf8bc2d2f','4dc88a17-45a8-52bf-8251-5abe9a1278a9','不在','2026-06-13','migration') on conflict (id) do nothing;
insert into places (id,block_id,kind,parent_id,label,display_name,status,map_x,map_y) values ('02a4b011-8da6-5d35-9147-312cb0d39c0c','2af4fb83-e61c-5592-ba1b-9758619782ed','戸建て',null,'7','権藤','訪問可能',340,380) on conflict (id) do nothing;
insert into visits (id,place_id,outcome,visited_at,source) values ('1a91d6ca-17e6-5267-bf2a-fe18601d6cc6','02a4b011-8da6-5d35-9147-312cb0d39c0c','会えた','2026-06-13','migration') on conflict (id) do nothing;
insert into places (id,block_id,kind,parent_id,label,display_name,status,map_x,map_y) values ('2c56fae3-3add-5a00-a9d8-e618aae05120','2af4fb83-e61c-5592-ba1b-9758619782ed','戸建て',null,'8','成田','訪問可能',470,300) on conflict (id) do nothing;
insert into visits (id,place_id,outcome,visited_at,source) values ('b3bbdbba-ff1c-5540-93ff-d9127ffdc855','2c56fae3-3add-5a00-a9d8-e618aae05120','不在','2026-06-10','migration') on conflict (id) do nothing;
insert into visits (id,place_id,outcome,visited_at,source) values ('fc3705af-011d-55e4-80ab-ee596a5bf60d','2c56fae3-3add-5a00-a9d8-e618aae05120','不在','2026-06-13','migration') on conflict (id) do nothing;
insert into places (id,block_id,kind,parent_id,label,display_name,status,map_x,map_y) values ('57299f05-5d92-5b1a-a1c0-79af9b6a2e08','2af4fb83-e61c-5592-ba1b-9758619782ed','戸建て',null,'32','西木','訪問可能',560,360) on conflict (id) do nothing;
insert into visits (id,place_id,outcome,visited_at,source) values ('1830d78c-ad7a-5870-8d49-0dd5f3b2cbec','57299f05-5d92-5b1a-a1c0-79af9b6a2e08','会えた','2026-06-13','migration') on conflict (id) do nothing;
insert into places (id,block_id,kind,parent_id,label,display_name,status,map_x,map_y) values ('c5372a49-53c6-52aa-b115-9ad80f612073','2af4fb83-e61c-5592-ba1b-9758619782ed','戸建て',null,'27','古田','訪問拒否',null,null) on conflict (id) do nothing;
insert into visits (id,place_id,outcome,visited_at,source) values ('a0e101fa-a562-551b-b095-d2ba6b8b0b71','c5372a49-53c6-52aa-b115-9ad80f612073','不在','2026-06-13','migration') on conflict (id) do nothing;
insert into places (id,block_id,kind,parent_id,label,display_name,status,map_x,map_y) values ('6d66a501-0cab-5c76-b47d-880cae3bfcbb','2af4fb83-e61c-5592-ba1b-9758619782ed','集合住宅',null,null,'D-room長住北A','訪問可能',300,170) on conflict (id) do nothing;
insert into places (id,block_id,kind,parent_id,label,display_name,status,map_x,map_y) values ('2062b976-3565-5b39-9fdb-830c76903555','2af4fb83-e61c-5592-ba1b-9758619782ed','号室','6d66a501-0cab-5c76-b47d-880cae3bfcbb','101','D-room長住北A 101','訪問可能',null,null) on conflict (id) do nothing;
insert into visits (id,place_id,outcome,visited_at,source) values ('a6c78481-dbd7-505f-8bb6-eaf84156f00a','2062b976-3565-5b39-9fdb-830c76903555','会えた','2026-06-13','migration') on conflict (id) do nothing;
insert into places (id,block_id,kind,parent_id,label,display_name,status,map_x,map_y) values ('9430b78a-4c2c-5ca8-9402-fdabb5073158','2af4fb83-e61c-5592-ba1b-9758619782ed','号室','6d66a501-0cab-5c76-b47d-880cae3bfcbb','102','D-room長住北A 102','訪問可能',null,null) on conflict (id) do nothing;
insert into places (id,block_id,kind,parent_id,label,display_name,status,map_x,map_y) values ('31bba221-1ba8-57f9-896e-c40d6c940251','2af4fb83-e61c-5592-ba1b-9758619782ed','号室','6d66a501-0cab-5c76-b47d-880cae3bfcbb','201','D-room長住北A 201','訪問可能',null,null) on conflict (id) do nothing;
insert into visits (id,place_id,outcome,visited_at,source) values ('0ec9ba8c-8d1c-5a7a-a697-a5919d101b24','31bba221-1ba8-57f9-896e-c40d6c940251','不在','2026-06-13','migration') on conflict (id) do nothing;
insert into places (id,block_id,kind,parent_id,label,display_name,status,map_x,map_y) values ('ecc79fbe-f803-5b5f-92c1-564a12439ce1','2af4fb83-e61c-5592-ba1b-9758619782ed','号室','6d66a501-0cab-5c76-b47d-880cae3bfcbb','301','D-room長住北A 301','訪問可能',null,null) on conflict (id) do nothing;
insert into visits (id,place_id,outcome,visited_at,source) values ('20a2f440-206f-503c-8018-5f0c58c08cba','ecc79fbe-f803-5b5f-92c1-564a12439ce1','不在','2026-05-30','migration') on conflict (id) do nothing;
insert into visits (id,place_id,outcome,visited_at,source) values ('200410bb-b759-5e89-bbeb-4b58acdfc738','ecc79fbe-f803-5b5f-92c1-564a12439ce1','不在','2026-06-13','migration') on conflict (id) do nothing;
insert into places (id,block_id,kind,parent_id,label,display_name,status,map_x,map_y) values ('744167fe-6eef-5aaa-8c50-ecd94a2dd5c7','2af4fb83-e61c-5592-ba1b-9758619782ed','号室','6d66a501-0cab-5c76-b47d-880cae3bfcbb','302','D-room長住北A 302','訪問可能',null,null) on conflict (id) do nothing;
insert into places (id,block_id,kind,parent_id,label,display_name,status,map_x,map_y) values ('63fea974-c5d9-5c14-9f37-305c9abc3b17','2c120bde-4c9e-5416-94a2-ca56bfbe3fb5','戸建て',null,'1','福本','訪問可能',150,320) on conflict (id) do nothing;
insert into places (id,block_id,kind,parent_id,label,display_name,status,map_x,map_y) values ('e3c34d9f-a2bb-5ead-aa69-eb9b061835d4','2c120bde-4c9e-5416-94a2-ca56bfbe3fb5','戸建て',null,'3','篠隈','訪問可能',300,300) on conflict (id) do nothing;
insert into places (id,block_id,kind,parent_id,label,display_name,status,map_x,map_y) values ('c2f2360f-fc61-5a85-8d71-942f47e6bb5b','2c120bde-4c9e-5416-94a2-ca56bfbe3fb5','戸建て',null,'4','田野','訪問可能',450,350) on conflict (id) do nothing;
insert into visits (id,place_id,outcome,visited_at,source) values ('7cfc6273-43a2-51ca-bb14-b946989d2f65','c2f2360f-fc61-5a85-8d71-942f47e6bb5b','投函','2026-06-09','migration') on conflict (id) do nothing;
insert into places (id,block_id,kind,parent_id,label,display_name,status,map_x,map_y) values ('34126b86-c431-5f43-a784-e5ca17693de2','2c120bde-4c9e-5416-94a2-ca56bfbe3fb5','戸建て',null,'10','堺','訪問可能',560,300) on conflict (id) do nothing;
insert into visits (id,place_id,outcome,visited_at,source) values ('a60a6ef6-61bc-51c1-9b05-ede15f5f598b','34126b86-c431-5f43-a784-e5ca17693de2','会えた','2026-06-09','migration') on conflict (id) do nothing;
commit;