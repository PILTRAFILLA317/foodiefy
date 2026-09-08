# Fase 09 · Importación móvil resumible y Compartir

## Qué cambia

La app usa `/v1/imports` con JWT de la sesión y API_BASE_URL del entorno.
La clave de idempotencia se conserva en disco antes del primer POST. Un timeout
no crea automáticamente otro intento: «Reintentar el mismo envío» reutiliza key
y payload. Un rechazo definitivo aparece como solicitud no aceptada, distinto
de un estado de job, y permite corregir la entrada.

Cada usuario tiene su registro local de intentos y resultados. Tras iniciar o
reanudar la app se reconcilian todas las páginas remotas; después se consultan
solo jobs no terminales por ID. Las páginas usan un resultado cada una para
respetar el límite local de respuesta de 2 MiB. Polling secuencial, sin solaparse,
con espera 3–18 s según fallos; se pausa al dejar foreground. Cerrar la pantalla
no cancela el job remoto. Un 401 permite una sola renovación/repetición por
request; si sigue fallando se detiene el polling hasta reintento explícito.
Logout oculta inmediatamente datos de A; respuestas tardías no aparecen en B.
Los registros locales de jobs quedan particionados por usuario para recuperar A
cuando vuelva a iniciar sesión. No se guardan tokens en estos registros.

La pantalla mantiene fondo, tipografía y botones existentes, permite editar URL
y muestra el stage recibido, nunca mensajes aleatorios ni porcentajes:

| Stage | Texto |
| --- | --- |
| resolving_source | Revisando el enlace… |
| extracting_metadata | Obteniendo la receta y descripción… |
| extracting_audio | Preparando el audio… |
| transcribing | Transcribiendo… |
| extracting_recipe | Analizando la receta… |
| analyzing_visual_evidence | Revisando información visual… |
| finalizing | Preparando el resultado… |

Queued se muestra como cola, sin afirmar que la etapa anterior sigue ejecutándose.
Los estados se expresan con texto/live region; el nuevo flujo no tiene animaciones
continuas y admite desplazamiento/texto escalado. El resultado abre el editor
existente como RecipeDraft revisable: partial, warnings, contradicciones y campos
faltantes visibles; nutrición desconocida no se inventa. Se muestra método/base
nutricional, y editar ingredientes invalida la nutrición anterior.

Guardar utiliza LibraryRepository de fase 04 con identidad de receta y operación
estables por job/usuario. Doble tap queda bloqueado; retry de un guardado cuya
respuesta se perdió no duplica. Descartar solo oculta el borrador, no borra una
receta guardada. Si el servidor ya aceptó un guardado y se cambia el contenido
antes de repetirlo con la misma operación, puede devolver conflicto: reabrir la
receta guardada, no crear otra importación para resolverlo.

## Ajustes compatibles en API

`POST /v1/imports` admite `{"url":"..."}` como antes o
`{"description":"texto pegado"}` con URL de origen opcional. Al proporcionar
description se procesa exclusivamente ese texto: no se descarga la URL ni se
intenta STT/visual. Description es un Fragment separado con source_kind=description,
source_type=pasted_text y procedencia manual; plataforma desconocida queda null.
Máximo 6000 bytes UTF-8 de texto y 8192 bytes de request completo. Se conservan
JWT, idempotencia, cuota activa/diaria y reservas del mismo pipeline/ledger.
Se regeneraron snapshots imports/evidence en API e imports en Flutter.

Cancelar impide nuevas etapas. Puede existir un gasto de una llamada ya enviada.
Se borran los medios temporales, pero transcript y respuestas de etapas quedan
privados hasta su TTL para diagnóstico; no se invalidan por un simple cierre de
pantalla. No se añadieron migraciones ni se cambió la política de modelos/gasto.

## Recepción nativa y límites

Se revisó share_handler 0.0.25 (última publicación en pub.dev: 2025-07-29) y su
README oficial. Su flujo cubre medios y apertura automática desde la extensión;
no se tomó esa publicación como prueba de mantenimiento activo en 2026 ni se
instaló el paquete. Para este alcance se usa MethodChannel `foodiefy/share` y
APIs nativas, con propietario claro del almacenamiento/TTL. No hay dependencia
nueva ni cambios de lockfiles.

Android: ACTION_SEND text/plain y singleTask; recepción fría en onCreate y
caliente en onNewIntent. Encola UUID + timestamp + hasta 10 URLs; no conserva
caption, JWT ni adjuntos. Acuse por ID después de persistir en Dart; repetir el
mismo evento no vuelve a encolarlo, pero un nuevo share del mismo enlace sí.
La copia de seguridad Android queda deshabilitada para evitar exportar la bandeja.

En iOS existe target real ShareExtension, con fuentes/Info.plist/entitlements,
dependencia de Runner y Embed App Extensions antes de Thin Binary. Usa
NSItemProvider URL/texto y una pantalla accesible de confirmación. **Guardar enlace
no abre automáticamente Foodiefy:** al terminar, el propietario abre la app y
confirma allí la importación. No se usan APIs privadas para lanzar el contenedor.
El mismo App Group en ambos targets guarda un archivo por evento, con protección
de archivo y exclusión de backup. Acuse elimina solo el archivo de ese ID, sin
borrar un share concurrente. Sin grupo/firma configurados devuelve error visible.

Bandejas limitadas a 20 eventos, 10 URLs por evento, entrada textual 32 KiB y TTL
24 horas, con recolección al leer/compartir/reanudar. La app conserva una cola FIFO
mínima, no reemplaza un share por el siguiente. Se debe seleccionar un enlace
cuando un evento contiene varios. No se pide acceso a galería, cookies o cuentas
sociales para recibir enlaces. Ningún callback de Compartir hace POST ni inicia IA.
Un enlace anónimo sobrevive al login; una bandeja vinculada a A se oculta al logout
antes de B. No se procesa contenido automáticamente al abrir la app.

## Preparación y comandos manuales exactos

Estos comandos de ejecución nativa **no los ejecutó el agente**: compilan/instalan
una app de desarrollo. No desinstalar la app anterior ni limpiar sus datos; conservar
los backups de recuperación antes de sustituir una instalación existente.

Desde `foodiefy_api/`, en dos terminales, con Supabase local existente activo:

```sh
rtk proxy .venv-recovery/bin/python -m scripts.run_imports_local api
rtk proxy .venv-recovery/bin/python -m scripts.run_imports_local worker
```

Ambos launchers mantienen el pago deshabilitado. Para web JSON-LD completa puede
haber resultado sin IA. Una receta que necesite Nano/STT devolverá un bloqueo
controlado hasta que el propietario autorice presupuesto/configuración. No activar
pago solo para comprobar el menú Compartir.

Desde `foodiefy/`, configuración local pública:

```sh
rtk proxy python3 tool/configure_supabase_local.py
rtk proxy flutter devices
```

Si config/supabase.local.json ya existe, el script no lo sobrescribe: comprobar
privadamente APP_ENV=local, LOCAL_RESCUE=false y endpoints de loopback. No pegar
el archivo/token al chat. API_BASE_URL no es un localhost hardcodeado; staging y
production exigen HTTPS. Dart defines requieren relanzar, no solo hot reload.

### Android real

Se detectó RMX3851 / Android 16 conectado. No se instaló ni probó esta versión.
Copiar su ID actual de `flutter devices` (el puerto inalámbrico puede cambiar):

```sh
rtk proxy adb -s '<ANDROID_DEVICE_ID>' reverse tcp:8000 tcp:8000
rtk proxy adb -s '<ANDROID_DEVICE_ID>' reverse tcp:54321 tcp:54321
rtk proxy flutter run -d '<ANDROID_DEVICE_ID>' --dart-define-from-file=config/supabase.local.json
```

Los reverse permiten usar 127.0.0.1 también desde el Android físico y respetan la
configuración HTTP debug limitada a loopback. Se mantiene el applicationId existente
com.example.foodiefy; firma debug local, sin inventar keystore release.

Después, compartir desde navegador o una app social una URL que se tenga derecho
a procesar, con Foodiefy cerrada y abierta. Debe aparecer Foodiefy en Compartir,
mostrar aviso de enlace pendiente y no generar job hasta pulsar Importar.

### iPhone real

No se detectó iPhone accesible: desbloquear, conectar por cable, confiar en este Mac
y activar Developer Mode. Faltan Team ID, Bundle ID registrado y App Group real;
no se han inventado ni provisionado. Una cuenta Apple sin capacidad App Groups no
permite verificar esta solución en dispositivo.

```sh
rtk proxy python3 tool/configure_share_ios.py --bundle-id '<BUNDLE_ID_REGISTRADO>' --team-id '<TEAM_ID_10_CARACTERES>' --app-group '<group.ID_REGISTRADO>'
rtk proxy open ios/Runner.xcworkspace
```

El script crea únicamente ios/Shared/Share.local.xcconfig ignorado, con identificadores
públicos. En Xcode → Runner y ShareExtension → Signing & Capabilities: mismo Team,
firma automática de desarrollo y el mismo App Group registrado. Runner usa el
Bundle ID indicado; la extensión añade `.ShareExtension`. No crear de nuevo el
target, que ya está versionado. Los defaults vacíos no son una firma válida.

Para el iPhone, usar un archivo público de configuración de desarrollo con URLs
HTTPS de API/Supabase accesibles desde el dispositivo; el 127.0.0.1 del Mac no es
accesible como localhost en el iPhone. No desactivar TLS/ATS ni poner secretos de
servidor en ese archivo. No se ha desplegado un endpoint HTTPS para esta prueba.

```sh
rtk proxy flutter run -d '<IPHONE_DEVICE_ID>' --dart-define-from-file='<CONFIG_PUBLICA_HTTPS.json>'
```

En Safari/Instagram/YouTube → Compartir → Más → Foodiefy. Guardar el enlace en la
extensión, abrir Foodiefy y seleccionar/importar. Repetir con app abierta/cerrada,
varios enlaces y login pendiente. La recepción nativa y el procesamiento de una
plataforma son verificaciones distintas: las redes sociales siguen bloqueadas
en backend producción/staging hasta verificar el aislamiento requerido.

## Comprobación funcional del propietario

1. Compartir no genera gasto ni job antes de confirmación autenticada; payload sin
   URL produce explicación, varios enlaces piden selección. Repetir el mismo
   enlace mediante un nuevo share debe permitir una importación legítima posterior.
2. Description/subtítulos: nunca Transcribiendo. Narración: Preparando audio →
   Transcribiendo → Analizando receta. Visual: solo Revisando información visual
   cuando el backend lo emite. El polling puede no observar etapas muy breves.
3. Cerrar/reabrir durante queued/running; abrir Tus importaciones y recuperar el
   mismo job. Cortar red tras POST y reintentar: mismo Idempotency-Key/job_id.
4. Logout A → login B: no jobs, URLs vinculadas ni borradores de A. Volver a A
   permite recuperar sus jobs remotos/locales.
5. Revisar partial/contradicciones y cantidades. Guardar dos veces o perder la
   respuesta del guardado deja una sola receta. Descartar no borra recetas previas.
6. Cancelar: mensaje de coste ya enviado y ninguna etapa posterior. Presupuesto
   agotado y texto pegado siguen sujetos a auth/cuotas del servidor.

Las rutas IA reales requieren las fuentes autorizadas y presupuesto humano de
fases 07/08; no hay autorización de gasto en esta entrega. No usar cookies ni
credenciales sociales para desbloquear fuentes.

## Verificación local reproducible

Desde Flutter:

```sh
rtk proxy flutter test --no-pub --reporter expanded
rtk proxy flutter analyze --no-pub --no-fatal-infos
```

Desde API:

```sh
rtk proxy env FOODIEFY_LOCAL_IMPORT_TESTS=1 .venv-recovery/bin/python -m pytest -q
rtk proxy .venv-recovery/bin/ruff check src tests scripts benchmarks
rtk proxy .venv-recovery/bin/python -m scripts.generate_import_contract --check
rtk proxy .venv-recovery/bin/python -m scripts.generate_evidence_contract --check
```

El opt-in PostgreSQL crea solo usuarios sintéticos, simula proveedores y restaura
controles. No ejecutarlo en paralelo a un piloto real. Sin opt-in, los tests de DB
se omiten, no se consideran superados. Resultados exactos en progress.md de ambos
repositorios. Swift typecheck/plist/Xcode project no sustituyen compilación, firma,
instalación ni prueba del menú real. No hubo builds, despliegues ni fase 10.

Referencias verificadas: https://pub.dev/api/packages/share_handler,
https://github.com/AboutShout/share_handler/tree/main/share_handler,
https://developer.android.com/training/sharing/receive,
https://developer.apple.com/documentation/foundation/nsextensioncontext/completeRequest(returningItems:completionHandler:),
https://supabase.com/docs/reference/dart/auth-refreshsession.
