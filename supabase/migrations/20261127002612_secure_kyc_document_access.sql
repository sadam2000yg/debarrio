update storage.buckets set public = false where id = 'kyc_docs';

drop policy if exists perfiles_select on public.perfiles;
create policy perfiles_select
on public.perfiles
for select
to authenticated
using ((select auth.uid()) = id);

drop policy if exists "Permitir lectura en buckets DBarrio" on storage.objects;
create policy "Permitir lectura en buckets DBarrio"
on storage.objects
for select
to public
using (bucket_id in ('negocios_assets', 'productos_assets'));
create policy kyc_docs_read_own
on storage.objects
for select
to authenticated
using (
  bucket_id = 'kyc_docs'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Permitir subida en buckets DBarrio" on storage.objects;
create policy "Permitir subida en buckets DBarrio"
on storage.objects
for insert
to anon, authenticated
with check (bucket_id in ('negocios_assets', 'productos_assets'));
create policy kyc_docs_insert_own
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'kyc_docs'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Permitir actualización en buckets DBarrio" on storage.objects;
create policy "Permitir actualización en buckets DBarrio"
on storage.objects
for update
to anon, authenticated
using (bucket_id in ('negocios_assets', 'productos_assets'))
with check (bucket_id in ('negocios_assets', 'productos_assets'));
create policy kyc_docs_update_own
on storage.objects
for update
to authenticated
using (
  bucket_id = 'kyc_docs'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'kyc_docs'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
