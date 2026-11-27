create or replace function public.obtener_resumen_compradores_pedidos(
  p_negocio_id uuid
)
returns table (
  pedido_id uuid,
  comprador_nombre text,
  comprador_verificado boolean
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
      )
  from public.pedidos as pedido
  join public.negocios as negocio
    on negocio.id = pedido.negocio_id
  join public.perfiles as perfil
    on perfil.id = pedido.comprador_id
  where pedido.negocio_id = p_negocio_id
    and negocio.owner_id = (select auth.uid());
$function$;

revoke all on function public.obtener_resumen_compradores_pedidos(uuid)
  from public, anon, authenticated;
grant execute on function public.obtener_resumen_compradores_pedidos(uuid)
  to authenticated;
