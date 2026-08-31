-- 本番は Supabase（Postgres + GoTrue + PostgREST）だが、ローカルの検証用に
-- 素の postgres:16 を使う。schema.sql は auth スキーマと auth.uid() / RLSロールに
-- 依存しているため、その最小限だけをここで用意して schema.sql を無修正で流せるようにする。
--
-- 目的は「スキーマ定義・制約・関数が正しいかをローカルで確かめること」であり、
-- 認証そのものを再現するものではない（ログインは本番同様 Supabase 側が担う）。

create extension if not exists "pgcrypto";

-- Supabase が持つロール。RLSポリシーの grant/revoke 先として必要。
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin bypassrls;
  end if;
end
$$;

grant usage on schema public to anon, authenticated, service_role;

-- GoTrue が管理するユーザーテーブルの最小代替。
create schema if not exists auth;
create table if not exists auth.users (
  id uuid primary key default gen_random_uuid(),
  email text unique,
  created_at timestamptz not null default now()
);
grant usage on schema auth to anon, authenticated, service_role;

-- RLSポリシーが参照する「今ログインしているユーザーID」。
-- Supabase では JWT から取り出すが、ここでは検証用にセッション変数から読む。
--   例) select set_config('request.jwt.claim.sub', '<uuid>', false);
create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;
