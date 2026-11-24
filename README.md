# CEI Inmobiliaria

App móvil de CEI Corporation para que los clientes de sus proyectos inmobiliarios consulten su saldo, suban sus boletas de pago, pidan información y vean el avance de su proyecto.

**Estado: prototipo de demostración.** Funciona con datos de ejemplo y no guarda nada al cerrar la página. Falta conectar la base de datos (ver "Siguientes pasos").

## Roles

| Rol | Qué hace |
|---|---|
| **Cliente** | Crea su cuenta y queda en revisión hasta que el administrador le asigna proyecto y lote. Ve su saldo y plan de pagos, sube boletas, ve su recibo o factura, hace solicitudes (videos, información, fotos), ve renders y avance de obra, contacta a CEI y agenda visitas. |
| **Administrador** | Crea proyectos, asigna proyecto, lote, plan de pagos y rol a cada usuario, aprueba o rechaza boletas y emite el recibo o la factura, responde solicitudes y sube renders. |
| **Supervisor de proyecto** | Ve solo su proyecto, publica avances de obra con foto y atiende solicitudes. No ve los pagos. |

## Archivos

- `index.html`: la app completa (HTML, CSS y JavaScript en un solo archivo, sin dependencias de compilación).
- `supabase/schema.sql`: tablas, roles y reglas de seguridad por cliente para Supabase.
- `assets/`: logos de CEI en dorado con fondo transparente.

## Ver la app

Abre `index.html` en el navegador, o publícalo con GitHub Pages (Settings > Pages > Deploy from a branch > `main` / root). En la pantalla de inicio hay accesos de demostración para los tres roles.

## Siguientes pasos

1. Crear el proyecto Supabase de la app y ejecutar `supabase/schema.sql`.
2. Crear los buckets privados `boletas` y `media` en Storage.
3. Conectar `index.html` a Supabase (registro, inicio de sesión, pagos, solicitudes, imágenes).
4. Facturación legal: conectar un certificador FEL de SAT (hoy el recibo y la factura son una vista de ejemplo).
5. Pendientes sugeridos: estado de cuenta en PDF, notificaciones de vencimiento, documentos del cliente (escritura, contrato, plano) y bitácora de cambios.

Este repositorio es público: no guardes aquí claves de servicio ni datos reales de clientes.
