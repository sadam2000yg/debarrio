alter table public.perfiles
  add column if not exists avatar_path text;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'profile_avatars',
  'profile_avatars',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

grant usage on schema d_barrio_private to authenticated;

drop policy if exists profile_avatars_insert_own on storage.objects;
create policy profile_avatars_insert_own
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'profile_avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and coalesce(array_length(storage.foldername(name), 1), 0) = 1
  and exists (
    select 1
    from public.perfiles as perfil
    where perfil.id = (select auth.uid())
  )
);

drop policy if exists profile_avatars_delete_own on storage.objects;
create policy profile_avatars_delete_own
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'profile_avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and coalesce(array_length(storage.foldername(name), 1), 0) = 1
);

create or replace function d_barrio_private.actualizar_avatar_perfil(
  p_avatar_path text
)
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := (select auth.uid());
  v_previous_path text;
begin
  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Se requiere una sesión autenticada.';
  end if;

  if nullif(btrim(p_avatar_path), '') is null
    or (storage.foldername(p_avatar_path))[1] is distinct from v_user_id::text
    or coalesce(array_length(storage.foldername(p_avatar_path), 1), 0) <> 1
  then
    raise exception using
      errcode = '22023',
      message = 'La ruta de la foto de perfil no pertenece al usuario autenticado.';
  end if;

  if not exists (
    select 1
    from storage.objects as objeto
    where objeto.bucket_id = 'profile_avatars'
      and objeto.name = p_avatar_path
  ) then
    raise exception using
      errcode = '22023',
      message = 'La foto de perfil no existe en el almacenamiento.';
  end if;

  select perfil.avatar_path
  into v_previous_path
  from public.perfiles as perfil
  where perfil.id = v_user_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'No se encontró el perfil del usuario.';
  end if;

  update public.perfiles
  set avatar_path = p_avatar_path
  where id = v_user_id;

  return v_previous_path;
end;
$function$;

revoke all on function
  d_barrio_private.actualizar_avatar_perfil(text)
  from public, anon, authenticated;
grant execute on function
  d_barrio_private.actualizar_avatar_perfil(text)
  to authenticated;

create or replace function public.actualizar_avatar_perfil(
  p_avatar_path text
)
returns text
language sql
volatile
security invoker
set search_path = ''
as $function$
  select d_barrio_private.actualizar_avatar_perfil(p_avatar_path);
$function$;

revoke all on function public.actualizar_avatar_perfil(text)
  from public, anon, authenticated;
grant execute on function public.actualizar_avatar_perfil(text)
  to authenticated;

create or replace function
  d_barrio_private.obtener_resumen_compradores_pedidos_con_avatar(
    p_negocio_id uuid
  )
returns table (
  pedido_id uuid,
  comprador_nombre text,
  comprador_verificado boolean,
  comprador_avatar_path text
)
language sql
stable
security definer
set search_path = ''
as $function$
  select
    pedido.id,
    perfil.nombre,
    coalesce(perfil.kyc_verificado, false)
      or (
        nullif(btrim(perfil.ci_anverso_url), '') is not null
        and nullif(btrim(perfil.ci_reverso_url), '') is not null
      ),
    perfil.avatar_path
  from public.pedidos as pedido
  join public.negocios as negocio
    on negocio.id = pedido.negocio_id
  join public.perfiles as perfil
    on perfil.id = pedido.comprador_id
  where pedido.negocio_id = p_negocio_id
    and negocio.owner_id = (select auth.uid());
$function$;

revoke all on function
  d_barrio_private.obtener_resumen_compradores_pedidos_con_avatar(uuid)
  from public, anon, authenticated;
grant execute on function
  d_barrio_private.obtener_resumen_compradores_pedidos_con_avatar(uuid)
  to authenticated;

create or replace function public.obtener_resumen_compradores_pedidos_con_avatar(
  p_negocio_id uuid
)
returns table (
  pedido_id uuid,
  comprador_nombre text,
  comprador_verificado boolean,
  comprador_avatar_path text
)
language sql
stable
security invoker
set search_path = ''
as $function$
  select
    resumen.pedido_id,
    resumen.comprador_nombre,
    resumen.comprador_verificado,
    resumen.comprador_avatar_path
  from d_barrio_private.obtener_resumen_compradores_pedidos_con_avatar(
    p_negocio_id
  ) as resumen;
$function$;

revoke all on function
  public.obtener_resumen_compradores_pedidos_con_avatar(uuid)
  from public, anon, authenticated;
grant execute on function
  public.obtener_resumen_compradores_pedidos_con_avatar(uuid)
  to authenticated;

create or replace function
  d_barrio_private.listar_resenas_negocio_con_perfil(p_negocio_id uuid)
returns table (
  id uuid,
  pedido_id uuid,
  negocio_id uuid,
  comprador_id uuid,
  calificacion integer,
  comentario text,
  created_at timestamptz,
  comprador_nombre text,
  comprador_avatar_path text
)
language sql
stable
security definer
set search_path = ''
as $function$
  select
    resena.id::uuid,
    resena.pedido_id::uuid,
    resena.negocio_id::uuid,
    resena.comprador_id::uuid,
    resena.calificacion::integer,
    resena.comentario::text,
    resena.created_at::timestamptz,
    perfil.nombre::text,
    perfil.avatar_path
  from public.resenas as resena
  join public.perfiles as perfil
    on perfil.id = resena.comprador_id
  where resena.negocio_id = p_negocio_id
    and exists (
      select 1
      from public.perfiles as viewer
      where viewer.id = (select auth.uid())
    )
  order by resena.created_at desc;
$function$;

revoke all on function
  d_barrio_private.listar_resenas_negocio_con_perfil(uuid)
  from public, anon, authenticated;
grant execute on function
  d_barrio_private.listar_resenas_negocio_con_perfil(uuid)
  to authenticated;

create or replace function public.listar_resenas_negocio_con_perfil(
  p_negocio_id uuid
)
returns table (
  id uuid,
  pedido_id uuid,
  negocio_id uuid,
  comprador_id uuid,
  calificacion integer,
  comentario text,
  created_at timestamptz,
  comprador_nombre text,
  comprador_avatar_path text
)
language sql
stable
security invoker
set search_path = ''
as $function$
  select
    resena.id,
    resena.pedido_id,
    resena.negocio_id,
    resena.comprador_id,
    resena.calificacion,
    resena.comentario,
    resena.created_at,
    resena.comprador_nombre,
    resena.comprador_avatar_path
  from d_barrio_private.listar_resenas_negocio_con_perfil(p_negocio_id)
    as resena;
$function$;

revoke all on function
  public.listar_resenas_negocio_con_perfil(uuid)
  from public, anon, authenticated;
grant execute on function
  public.listar_resenas_negocio_con_perfil(uuid)
  to authenticated;