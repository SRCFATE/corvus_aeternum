-- El visitante sin sesión no necesita estas tres.
--
-- Corvus es abierto para consultar, así que `anon` sí debe poder llamar a
-- `record_work_view`, `verify_aeternum_certificate`,
-- `get_work_aeternum_certificate`, `_conspiracy_summary` y —sin sesión, que es
-- justo el caso— `redeem_password_recovery_code`. Esas se quedan.
--
-- Las otras tres no tienen lectura pública posible: borrar tu cuenta exige ser
-- alguien, y conceder o retirar insignias exige ser administrador. Hoy fallan
-- solas para un visitante, porque `auth.uid()` es nulo y `is_admin(null)` es
-- falso, así que esto no cierra un agujero: quita tres firmas de la superficie
-- pública que nadie tiene por qué poder sondear.
--
-- Como antes, el permiso lo tiene PUBLIC por el default de PostgreSQL, no
-- `anon` a su nombre: hay que revocárselo a PUBLIC y volver a concederlo solo
-- a quien lo usa.
revoke execute on function public.delete_user() from public, anon;
grant execute on function public.delete_user() to authenticated;

-- Las de insignias no las llama la app; se dejan a `authenticated` porque su
-- propia guarda `is_admin()` ya rechaza a quien no lo sea, y así un panel de
-- administración futuro no se encuentra la puerta cerrada sin avisar.
revoke execute on function public.grant_badge(uuid, uuid, text) from public, anon;
grant execute on function public.grant_badge(uuid, uuid, text) to authenticated;

revoke execute on function public.revoke_badge(uuid, uuid) from public, anon;
grant execute on function public.revoke_badge(uuid, uuid) to authenticated;
