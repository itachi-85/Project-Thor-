-- Project Thor: private per-user cloud document storage.
-- Apply in Supabase SQL editor or migrations. Never put service-role keys in GitHub Pages.
create table if not exists public.thor_documents (
  owner_id uuid not null references auth.users(id) on delete cascade,
  document_id text not null,
  content jsonb not null default '{}'::jsonb,
  revision bigint not null default 1,
  updated_at timestamptz not null default now(),
  primary key (owner_id, document_id),
  constraint thor_document_id_length check (char_length(document_id) between 1 and 128),
  constraint thor_document_size check (pg_column_size(content) < 1048576)
);
alter table public.thor_documents enable row level security;
revoke all on public.thor_documents from anon;
grant select, insert, update, delete on public.thor_documents to authenticated;
drop policy if exists "thor_owner_read" on public.thor_documents;
create policy "thor_owner_read" on public.thor_documents
  for select to authenticated using ((select auth.uid()) = owner_id);
drop policy if exists "thor_owner_insert" on public.thor_documents;
create policy "thor_owner_insert" on public.thor_documents
  for insert to authenticated with check ((select auth.uid()) = owner_id);
drop policy if exists "thor_owner_update" on public.thor_documents;
create policy "thor_owner_update" on public.thor_documents
  for update to authenticated using ((select auth.uid()) = owner_id)
  with check ((select auth.uid()) = owner_id);
drop policy if exists "thor_owner_delete" on public.thor_documents;
create policy "thor_owner_delete" on public.thor_documents
  for delete to authenticated using ((select auth.uid()) = owner_id);

-- Do not use last-write-wins for entire workout histories.
-- Use per-day document keys like days/2026-10-29 with per-set IDs and revision checks.
-- Storage synchronization code must load the full remote history and merge without losing
-- unique set IDs before committing. Offline writes should remain queued for retry.
