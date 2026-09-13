# Auth foundation — 8 septiembre 2026

## Comportamiento y decisiones

- El arranque muestra inicialización mientras prepara configuración, Supabase y
  repositorios. Un fallo de arranque muestra un error sin contenido privado.
- `SessionRepository.status` distingue inicialización de una sesión caducada,
  ausencia de sesión, sesión válida y recuperación de contraseña. `AuthGate`
  elige Auth, Home o nueva contraseña; recuperación tiene prioridad sobre Home.
- Un cambio de estado de acceso o cuenta reconstruye el Navigator y limpia la
  caché de imágenes. También se oculta el banner de importación compartida fuera
  de una sesión normal autenticada. No se conservan rutas privadas para Back.
- Supabase Flutter 2.10.3 / GoTrue 2.16.0 siguen siendo responsables de guardar y
  renovar sesiones y procesar enlaces PKCE. No hay almacenamiento manual de
  contraseñas/tokens. La instantánea caducada de arranque no concede acceso;
  se espera una renovación del SDK, con límite de espera de 20 segundos.
  Un temporizador notifica la caducidad si el SDK no logra renovar a tiempo.
- Signup usa `signUp` y admite `session == null` como confirmación pendiente.
  `VerifyEmailScreen` muestra email, explicación, reenviar y utilizar otro email.
  Solo el evento real de Auth permite entrar. El reenvío tiene bloqueo concurrente
  y espera mínima de 60 segundos, también después de un fallo; el proveedor sigue
  imponiendo sus propios límites y sus errores se muestran sin reintentos automáticos.
- Nueva contraseña requiere un evento `passwordRecovery` con sesión válida.
  Se comprueba también en el repositorio antes de `updateUser`. Después de cambiarla
  el gate muestra Home. El evento de recuperación se conserva al crear tarde el
  repositorio gracias al stream del SDK instalado; hay una prueba para ese caso.
- Logout conserva la protección existente de compras pendientes. Tras resolverla,
  oculta la sesión antes de esperar la revocación. Si falla la red, permanece en
  Auth y muestra el error. Los repositorios existentes conservan sus límites por
  usuario y su limpieza al cambiar la sesión.
- `auth_errors.dart` centraliza traducciones. DEBUG registra tipo, código, estado,
  stack acotado y mensajes originales solo cuando pertenecen a una lista segura.
  Los mensajes arbitrarios se omiten para evitar credenciales o URLs con tokens.
  Se desactiva el logging crudo del SDK en el arranque. RELEASE muestra mensajes
  comprensibles; los desconocidos incluyen la referencia `AUTH_UNKNOWN`.
- El valor por defecto de `LOCAL_RESCUE` es `false`. El rescate histórico sigue
  disponible únicamente con `LOCAL_RESCUE=true` y `APP_ENV=local` en desarrollo.
  No se han eliminado instalaciones, cachés antiguas ni datos legacy.
- `API_BASE_URL` puede omitirse; Supabase Auth funciona con su URL y clave pública.
  Si se proporciona una URL, se mantienen sus validaciones de seguridad. No se
  inventa ninguna URL ni se comprueba conectividad de la API durante Auth.
- Home solo cambia para retirar su redirect secundario al login. No hay rediseño,
  cambios en recetas/compra/IA, OAuth, dependencias, API, migraciones, RLS ni RPCs.

## Configuración manual de Supabase

El propietario debe incluir exactamente:

`io.supabase.foodiefy://login-callback`

en **Supabase → Authentication → URL Configuration → Redirect URLs**.
Comprobar que el proveedor Email está activo y **Confirm email** continúa activo.
No se ha modificado el Dashboard. No se han creado usuarios ni enviado emails.

iOS ya declara `io.supabase.foodiefy` en `CFBundleURLSchemes` y desactiva el
deep linking del router Flutter. Android ya declara el mismo esquema con host
`login-callback`, `singleTask` y `flutter_deeplinking_enabled=false`. Se conservan
ambos archivos. El mismo callback se usa en signup, resend y reset de contraseña.

Para probar Auth sin API, usar una configuración propia con `SUPABASE_URL`,
`SUPABASE_PUBLISHABLE_KEY` (o anon pública), `APP_ENV` y `LOCAL_RESCUE=false`;
omitir `API_BASE_URL`. No usar `config/local.example.json` para la prueba normal:
ese archivo activa expresamente el rescate histórico.

## Evidencia automatizada

Ejecutado en este repositorio:

- `rtk proxy flutter test --no-pub`: **72 PASS, 1 omitido**.
  Incluye 13 pruebas nuevas de Auth con cliente SDK y HTTP simulado, además de
  las pruebas existentes de cambio de cuenta, persistencia, importación y compra.
- `rtk proxy flutter analyze --no-pub --no-fatal-infos`: sin errores ni warnings;
  permanecen 12 avisos informativos en archivos no modificados por esta fase.
- Registro sin sesión → VerifyEmail; confirmación PKCE → Home; login real del SDK
  con transporte simulado; recovery previo al repositorio → nueva contraseña →
  Home; bloqueo de nueva contraseña sin recovery; logout elimina rutas incluso
  con fallo de red; restauración válida/caducada/irrecuperable; cooldown y errores;
  guard de cambios pendientes; diagnóstico sin secretos; configuración sin API.
- La suite local real `supabase_local_test.dart` queda **NO EJECUTADA** por su
  opt-in existente. No se ejecutó `tool/test_supabase_local.py`.

Las pruebas simulan el callback en el SDK y la instantánea restaurada. No prueban
entrega real de correo, apertura del sistema operativo, almacenamiento tras matar
el proceso ni configuración remota. No se ejecutaron builds, despliegues ni pruebas
físicas. La siguiente checklist sigue pendiente en iOS y Android.

## Checklist física exacta

### A. Registro
1. Abrir Foodiefy sin sesión y con configuración normal (`LOCAL_RESCUE=false`).
2. Comprobar que solo Auth es accesible, también si llega un enlace compartido.
3. Crear una cuenta con un email que puedas leer.
4. Comprobar que aparece VerifyEmail con ese email, loading y reenvío bloqueado
   inicialmente; después de la espera, reenviar una vez y comprobar el nuevo bloqueo.
5. Comprobar que el usuario aparece en Supabase Authentication sin confirmar.
6. Verificar que no se entra a Home antes de confirmar, tampoco mediante Back.
   Comprobar que «Utilizar otro email» vuelve al formulario.

### B. Confirmación
1. Abrir el email en el dispositivo donde se solicitó el registro (PKCE).
2. Pulsar el enlace.
3. Comprobar que Foodiefy abre mediante `io.supabase.foodiefy://login-callback`.
4. Comprobar que se crea la sesión real.
5. Comprobar que Home aparece automáticamente. Repetir con la app cerrada.

### C. Persistencia
1. Cerrar completamente la app autenticada.
2. Reabrirla.
3. Comprobar que sigue autenticada sin pedir credenciales.
4. Repetir tras caducar el access token: con renovación válida debe entrar a Home;
   con sesión revocada/irrecuperable debe volver a Auth. Sin conexión y con token
   caducado no debe abrir contenido privado.

### D. Logout
1. Abrir una pantalla privada y cerrar sesión desde la cuenta. Si hay compras
   pendientes, probar cancelar y después sincronizar o descartar explícitamente.
2. Comprobar que vuelve a Auth tras cerrar sesión.
3. Pulsar Back y comprobar que no vuelve a datos privados. Reabrir la app para
   comprobar que la sesión cerrada no reaparece. Probar además con fallo de red.

### E. Login
1. Iniciar sesión con credenciales correctas y comprobar Home.
2. Usar password incorrecta: «El email o la contraseña no son correctos.»
3. Usar una cuenta sin confirmar: «Verifica tu correo antes de iniciar sesión.»
4. Probar sin conexión y comprobar el error de red. No forzar límites con envíos
   masivos; si el proveedor limita un intento, comprobar el mensaje de espera.
5. Repetir sin `API_BASE_URL`: Auth, logout y funciones solo Supabase deben operar;
   una importación debe indicar indisponibilidad.

### F. Recovery
1. Solicitar recuperación desde Auth.
2. Abrir el email en el mismo dispositivo.
3. Pulsar el enlace y comprobar que Foodiefy abre nueva contraseña, también con
   la app previamente cerrada; no debe abrir Home antes de terminar el cambio.
4. Cambiar contraseña y comprobar la transición automática a Home.
5. Cerrar sesión e iniciar sesión con la contraseña nueva; la anterior debe fallar.

Commit recomendado (no realizado):
`feat(auth): enforce global auth gate and email verification`
