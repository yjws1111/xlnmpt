-- ============================================================
-- 心灵驿站 · Supabase 初始化脚本
-- 用法：Supabase 控制台 → SQL Editor → 粘贴本文件全部内容 → Run
-- ============================================================

-- 1) 建表（键设计：均为可去重的自然主键，无需序列）
create table if not exists public.profiles (
  id   text primary key,     -- 匿名ID
  nick text,
  emoji text,
  secret text,               -- 身份码密钥（防止他人冒用该ID；网页端校验）
  last bigint                -- 心跳时间(毫秒)，判断在线
);

create table if not exists public.msgs (
  mid     text primary key,  -- 消息唯一编号（幂等去重）
  scope   text,              -- lobby=广场 / dm=私聊
  pair    text,              -- 私聊用：两ID排序后 A~B
  sender  text,              -- 发送者匿名ID
  nick    text,
  emoji   text,
  kind    text,              -- text / image / video
  content text,              -- 文字内容
  src     text,              -- 图片/视频URL
  ts      bigint             -- 毫秒时间戳（增量游标）
);
create index if not exists idx_msgs_lobby on public.msgs (scope, ts);
create index if not exists idx_msgs_dm     on public.msgs (scope, pair, ts);

create table if not exists public.friend_reqs (
  to_id      text,
  from_id    text,
  from_nick  text,
  from_emoji text,
  ts         bigint,
  primary key (to_id, from_id)
);
create index if not exists idx_reqs_to on public.friend_reqs (to_id, ts desc);

create table if not exists public.friendships (
  a      text,
  b      text,
  a_nick text,
  a_emoji text,
  b_nick text,
  b_emoji text,
  ts     bigint,
  primary key (a, b)
);

-- 2) 权限：让 anon（网页的匿名密钥）能读能写这些表
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on public.profiles, public.msgs, public.friend_reqs, public.friendships to anon, authenticated;

-- 3) 行级安全：开放所有行（班级互信小圈子模型；如需严格私密请勿使用本方案）
alter table public.profiles     enable row level security;
alter table public.msgs         enable row level security;
alter table public.friend_reqs  enable row level security;
alter table public.friendships  enable row level security;

drop policy if exists "open_all_profiles"    on public.profiles;
drop policy if exists "open_all_msgs"        on public.msgs;
drop policy if exists "open_all_friend_reqs" on public.friend_reqs;
drop policy if exists "open_all_friendships" on public.friendships;

create policy "open_all_profiles"    on public.profiles    for all using (true) with check (true);
create policy "open_all_msgs"        on public.msgs        for all using (true) with check (true);
create policy "open_all_friend_reqs" on public.friend_reqs for all using (true) with check (true);
create policy "open_all_friendships" on public.friendships for all using (true) with check (true);

-- 4) 文件存储桶 media（图片/视频），公开读、匿名写
insert into storage.buckets (id, name, public)
values ('media', 'media', true)
on conflict (id) do nothing;

grant select, insert on storage.objects to anon, authenticated;

drop policy if exists "media_public_read" on storage.objects;
create policy "media_public_read" on storage.objects
  for select using (bucket_id = 'media');

drop policy if exists "media_anon_write" on storage.objects;
create policy "media_anon_write" on storage.objects
  for insert with check (bucket_id = 'media');

-- 兼容旧项目：如果之前跑过没有 secret 列的脚本，此行会补上（幂等，可反复执行）
alter table public.profiles add column if not exists secret text;

-- 完成。可在控制台 Table Editor 看到 4 张表、Storage 看到 media 桶。
