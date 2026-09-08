# Progreso de recuperación · Foodiefy Flutter

## Fase 11 · 2026-09-08

**Configuración pública de staging y CI preparadas; app en hosting real pendiente.**

### Decisiones y archivos/contratos afectados

- `config/staging.example.json`: HTTPS, APP_ENV staging, LOCAL_RESCUE=false y
  clave pública vacía; no secretos DB/IA/service_role en móvil.
- `.github/workflows/ci.yml`: Flutter 3.47.2 y acciones fijadas, lockfile exigido,
  analyze/tests focalizados y snapshots. No build ni release automático.
- `tool/check_contracts.py`, `tool/security_scan.py`: hashes de contratos locales,
  Gitleaks 8.28.0 y OSV Scanner 2.2.2 fijados. Contratos sin cambios de fase 11;
  los cambios previos de compra/nutrición de fase 10 se conservan.
- `test/staging_config_test.dart`, `docs/recovery/phase11.md`: rechazo de HTTP,
  rescue y secretos; configuración válida HTTPS y comandos manuales de ejecución.
- Docker, Railway, migraciones y runbooks operativos pertenecen al hermano API.

### Pruebas con resultado real

| Prueba | Resultado |
| --- | --- |
| staging_config + session_repository | **5 PASS** |
| flutter analyze --no-pub --no-fatal-infos | **0 errores, 0 warnings; 12 infos preexistentes** |
| Snapshots/hash de contratos | **PASS** |
| Gitleaks en archivos versionados/no ignorados | **0 hallazgos**, no escaneo histórico Git |
| OSV pubspec.lock | **0 avisos** |
| Sintaxis workflow YAML | **PASS**, ejecución GitHub Actions **NO EJECUTADA** |
| Dispositivo, datos móviles, builds/release, login/import remoto y restore | **NO EJECUTADO** |

API hermano: 177 tests PASS con Postgres local, 87 pgTAP PASS y controles de
readiness/seguridad; esta evidencia no prueba que la app funcione desde Railway.

### Bloqueos e instrucciones manuales

Seguir [phase11.md](phase11.md) para copiar configuración pública real y ejecutar
la app, y los runbooks del hermano para revisión de costes/proyecto/región,
build/deploy, promoción de SQL, alertas, restart y restore aislado. No hay URL real
ni proyecto staging provisionado por Codex. IMPORT_ENABLED y pagos cerrados;
rutas sociales/audio/visual Linux bloqueadas hasta prueba egress y hosting real.
La app podrá conectar al staging cuando se provisionen servicios y configuración;
no se certifica todavía importación desde datos móviles.

Siguiente entrada: pruebas manuales fase 11, sin avanzar a fase 12. Sin builds,
commits, despliegues ni migraciones remotas.
Commit propuesto, no ejecutado: `chore: prepare staging deployment and operational runbooks`.

## Fase 10 · 2026-09-08

**Compra personal offline y nutrición transparente implementadas. Pruebas locales
PASS; recálculo IA no habilitado y verificación nativa pendiente.**

### Decisiones y archivos/contratos afectados

- `lib/shopping/shopping_repository.dart`: outbox de compras con 200 operaciones,
  persist-before-send, payload/UUID estable, dependencias tras merge, conflictos
  explícitos, backoff/foreground/sondeo y guardia de cuenta/generación.
- `lib/repositories/local_cache.dart`: tabla Drift shopping_state separada por
  owner; no se elimina con limpieza de biblioteca. Inicialización aditiva sin
  cambiar dependencias, sin extender cola offline al resto de la aplicación.
- `app_repositories.dart`, `session_repository.dart`, `user_screen.dart`: gateway
  Supabase, guardia logout y elecciones sincronizar/cancelar/descartar. Pendientes
  de A se conservan privados en disco al expirar sesión, nunca se envían con B.
- `screens/shopping_screen.dart`, `home_screen.dart`, `recipe_detail_screen.dart`:
  CRUD manual, marcar/comprados/contador/vaciado confirmado, selección desde receta,
  revisión de cantidad/rango/unidad, raciones o multiplicador explícito. Cada
  selección se persiste atómicamente en cache antes de sincronizar sus ingredientes.
- `shopping/quantities.dart`: fracciones, escalado conservador y conversiones de
  nutrición que exigen raciones/masa; interfaz futura VerifiedIngredientNutrition.
- `widgets/honest_nutrition.dart`, `models/recipe.dart`, `recipe_codec.dart`,
  `create_recipe_screen.dart`: base/metodología/estimación visibles, desconocidos
  sin cero, invalidación de nutrición anterior al editar ingredientes, reemplazo
  explícito manual/etiqueta y porcentajes aproximados 4/4/9 solo con datos suficientes.
- `contracts/shopping.v1.*`, contracts/README y `test/shopping_test.dart`:
  snapshot API reproducible, fixtures sintéticos revisados y pruebas mínimas.
- Ambos repositorios estaban limpios al inicio. Grafo MCP no disponible; se usó
  inspección selectiva de fuentes. No se atribuye auditoría exhaustiva de grafo.

### Pruebas con resultado real

| Prueba | Resultado |
| --- | --- |
| Flutter suite `rtk proxy flutter test --no-pub --reporter expanded` | **PASS: 56 tests, 1 skip explícito** (HTTP anterior fase 04 no activado) |
| Focalizada final `flutter test --no-pub test/shopping_test.dart --reporter expanded` | **PASS: 9 tests**: 2→4, fracciones/unknown, per100g sin masa, persistencia/reinicio, respuesta perdida, A→B, tombstone, dependencia tras merge, conflicto revisado, límite atómico y nutrición/etiqueta |
| `flutter analyze --no-pub --no-fatal-infos` | **PASS: 0 errores, 0 warnings; 12 infos preexistentes** |
| API suite `python -m pytest -q` | **PASS: 151 tests; 15 skips explícitos** de integración imports opt-in; 172 avisos deprecación |
| API contrato/fixtures final `pytest -q tests/test_shopping_contract.py` | **PASS: 5 tests** |
| Generador shopping `--check --sync-flutter ../foodiefy/contracts`; generador RecipeDraft `--check` | **PASS**, snapshot/schema/manifest/fixtures coherentes |
| `supabase db push --local --yes` | **PASS**, tres migraciones incrementales aplicadas solo a foodiefy_api local existente, sin reset |
| `supabase test db --local` | **PASS: 83 pgTAP**, 21 nuevos shopping; replay, cantidades/unidades/formas, permisos A/B, revisión, auditoría, tombstone y máximo sin mínimo |
| `python -m scripts.test_shopping_local --local` | **PASS: Auth/PostgREST reales, 9 checks**, cuentas sintéticas locales; replay/merge/A-B/PATCH/tombstone |
| `supabase db advisors --local --type all --fail-on warn`, `db lint --local --level warning` | **PASS**, sin incidencias ni errores |
| Ruff `check src tests scripts`; `git diff --check` ambos repos | **PASS** |
| Dispositivo/simulador, modo avión físico, cierre/reapertura nativo y dos apps reales | **NO EJECUTADO**; tests usan SQLite real + transporte inyectado, y smoke HTTP separado |
| IA pagada, recálculo nutricional IA, medios remotos, producción, builds de app/contenedor, commits/despliegues | **NO EJECUTADO** |

La primera suite Flutter completa detectó que había cambiado el texto exacto de
«Nutrición no disponible»; se conservó ese texto y la ejecución posterior pasó.
Dos invocaciones de flutter test desde el padre fallaron antes de ejecutar tests;
se repitieron desde foodiefy. La documentación Drift inicialmente devolvió 404 en
rutas antiguas; se localizó desde su índice la ruta oficial actual. Los fallos no
cuentan como PASS. Se corrigieron los nuevos infos de estilo, sin tocar los 12
anteriores. SDKs/lockfiles se conservaron; no se instaló ninguna dependencia.

### Bloqueos y siguiente entrada

Guía completa y pasos manuales exactos: [phase10.md](phase10.md). Verificar Home →
carrito, dos recetas revisadas, raciones, kg/g frente a g/ml, modo avión y logout
con pendientes. La cache de compras no prueba por sí sola comportamiento nativo.

**Recálculo IA no habilitado**: falta proveedor nutricional, cuota/ledger y precio
específicos. La UI devuelve indisponibilidad explícita, sin llamada ni coste; no
presenta éxito simulado ni usa extracción para inventar macros. Se permiten entrada
manual/etiqueta y conversiones aritméticas válidas. Undo de aportaciones no soportado;
los snapshots/recibos se conservan. No se entrega base alimentaria ni catálogo.

Siguiente entrada: verificación manual de Fase 10 y definición/habilitación del
recálculo nutricional pendiente si se desea. No se avanzó a Fase 11. No hubo commits,
reset/clean, borrado legacy, modificaciones remotas ni builds.

Commit propuesto por repositorio, **no ejecutado**:
`feat: add offline shopping list and transparent nutrition`.

## Fase 09 · 2026-09-08

**Flujo móvil de jobs implementado y verificado con tests. Recepción nativa
configurada en código; firma/instalación/menú Compartir real pendientes.**

### Decisiones y archivos/contratos afectados

- `lib/services/import_service.dart`: cliente `/v1/imports` con JWT vigente de
  SessionRepository, API_BASE_URL por entorno, límite de respuesta/timeout,
  redirects desactivados y una sola renovación/repetición ante 401.
- `lib/imports/import_jobs.dart`: persistencia por usuario antes de POST,
  Idempotency-Key/payload estables, reanudación y conciliación paginada, GET por ID
  para jobs activos, polling sin solapamiento con backoff y pausa de lifecycle.
  401 persistente detiene polling; logout y epoch rechazan respuestas de A en B.
  Rechazo del envío se distingue de estado backend y permite corregir la entrada.
- `screens/import_recipe_screen.dart`: reemplazo del flujo legacy/mensajes
  aleatorios por URL editable, stages reales, cancelar, recuperar, pegar texto,
  revisar partial/contradicciones/faltantes y descartar solo borrador. Live region,
  texto escalable/scroll, sin porcentajes ni animaciones continuas nuevas.
- `create_recipe_screen.dart`, `recipe_codec.dart`: editor/repository existentes,
  identidad y operación estables por job para doble tap/retry; origen/campos
  estructurados preservados, nutrición indicada e invalidada si cambian ingredientes.
- `lib/imports/share_inbox.dart`, `main.dart`, `home_screen.dart`,
  `app_repositories.dart`, `session_repository.dart`: bandeja FIFO por evento,
  TTL 24 h, selección de múltiples URLs, preservación antes/durante login,
  deduplicación de recepción sin bloquear un share legítimo posterior. Compartir
  nunca inicia POST/IA; nuevo botón permite recuperar importaciones desde Home.
- Android Manifest/MainActivity: ACTION_SEND text/plain, singleTask, onCreate/
  onNewIntent, UUID/URL mínima en cola privada con acuse tras persistir en Dart.
  iOS Shared/ShareExtension/AppDelegate/Info.plist/entitlements/proyecto Xcode:
  target real, puente MethodChannel, App Group configurable y archivo por evento.
  Sin paquetes nuevos; share_handler 0.0.25 fue evaluado, no instalado. No se afirma
  mantenimiento activo del paquete en 2026 por una publicación de 2025.
- `tool/configure_share_ios.py`, `ios/Shared/Share.xcconfig`, `.gitignore`:
  plantilla sin Team/App Group inventados; configuración local ignorada solo con
  identifiers públicos proporcionados por el propietario. Firma no provisionada.
- Contrato imports regenerado desde API: description opcional y URL opcional
  cuando hay texto. API añade pasted_text sin fetch/STT, mismas cuotas y retiene
  transcript pagado al cancelar hasta TTL. Sin migraciones ni cambios de precios.
- [phase09.md](phase09.md), README y contracts/README: guía manual completa.
  Ambos repositorios estaban limpios al iniciar esta fase; no hubo commits,
  resets, borrado legacy, despliegues ni builds de app/contenedor.

### Pruebas y resultados reales

| Comando/prueba | Resultado |
| --- | --- |
| `rtk proxy flutter test --no-pub --reporter expanded` | **PASS: 47 tests; 1 skip explícito**, ejecución final |
| Nuevos tests de imports/share | **18 tests**: HTTP fake, JWT/refresh acotado, cuerpo separado, timeout/límites, persistencia/reapertura, no solapamiento, pausa y A→B, tres rutas de stage consumidas desde cliente fake, TTL/colas/dedup/login, guardado único y avisos con texto ampliado |
| `rtk proxy flutter analyze --no-pub --no-fatal-infos` | **PASS: 0 errores, 0 warnings; 12 infos preexistentes** |
| Swift typecheck ShareInbox + ShareViewController con SDK iOS simulator | PASS |
| Swift typecheck AppDelegate + ShareInbox con headers Flutter instalados | PASS |
| Plist/entitlements y Android Manifest | PASS de parseo; no prueba menú nativo |
| Snapshot imports API/Flutter y generadores `--check` | PASS, igualdad byte a byte |
| API con opt-in PostgreSQL local | **PASS: 161 tests**, incluye texto autenticado/ledger y transcript retenido tras cancelar |
| Ruff API | PASS |
| `flutter devices` | Android RMX3851 / Android 16 detectado; iPhone **no accesible** |
| HTTP real Flutter/Supabase de fase 04 en esta fase | **NO EJECUTADO**, omitido explícitamente en suite; no confundir con DB real de API |
| Kotlin compilado, builds, firma/instalación, compartir desde apps reales, cerrar/reabrir nativamente | **NO EJECUTADO** |
| IA pagada, fuentes de terceros, benchmark real, despliegues/migraciones remotas | **NO EJECUTADO** |

Los tests del importador retirado fueron sustituidos por el contrato de jobs.
Una aserción inicial de concurrencia necesitó esperar la entrada al transporte.
Las primeras pruebas de arranque/HTTP fake se bloquearon por mezclar futuros de
FakeAsync y runAsync; se interrumpieron, se corrigió el arnés y se ejecutó la suite
final anterior. Ruff detectó y corrigió un orden de imports en un test API. Ninguna
ejecución fallida/interrumpida cuenta como PASS. El índice de grafo seguía en
2026-09-07; la cobertura marcó archivos nuevos/cambiados y se verificó fuente real.

### Bloqueos, manual y siguiente entrada

[Guía exacta](phase09.md#preparación-y-comandos-manuales-exactos): iniciar API/worker
sin pago, configurar endpoints públicos, Android con adb reverse, registrar Team/
Bundle ID/App Group reales para ambos targets iOS y ejecutar instalación de desarrollo
manualmente. **iOS guarda el enlace y pide abrir Foodiefy; no lanza automáticamente
el contenedor desde la extensión.** No se certifica funcionamiento en dispositivo
solo por typecheck o por existir el target.

El propietario debe probar compartir Reel/Short con app cerrada/abierta, sin URL/
varias URLs, login intermedio, recuperar mismo job/key al cerrar/reabrir y guardar
una sola receta. Debe verificar tres rutas de evidencia con fuentes autorizadas y
presupuesto explícito; no se habilitó gasto. Se heredan bloqueos de extracción social
y aislamiento de medios en producción. Faltan iPhone accesible, firma/App Group y
endpoint de desarrollo alcanzable desde el iPhone. Siguiente entrada: verificación
manual de fase 09; no implementar fase 10 sin nueva instrucción.

Commit propuesto, **no ejecutado**: `feat: integrate staged resumable recipe imports`.

## Fase 08 · 2026-09-08

**Recibido contrato versionado de jobs. No se implementó integración móvil.**

- Archivos: `contracts/imports.v1.schema.json`, `imports.v1.manifest.json`,
  `contracts/README.md` y este progreso. Fuente única en el hermano API, generador
  `scripts.generate_import_contract`; estados y stages separados sin porcentajes.
- No cambian Dart, navegación, polling, RecipeDraft, persistencia ni dependencias.
  El contrato no contiene secretos/configuración privada del servidor.
- Generación `--check` y comparación byte a byte API/Flutter: **PASS**.
  SHA-256 schema:
  `96bf88da474f658d88326e6bb9be44852453679b56db3414b11e3a15eb387bc2`;
  manifest: `b5b055279b5333ec92324d2db71a93d33f6c41a43b42527550b12d2453ea33ac`.
- API: 159 tests (incluidos 14 Postgres locales), 62 pgTAP y advisors/lint PASS.
  Esa evidencia no prueba el comportamiento de la app.
- Flutter test/analyze/build, dispositivo, cerrar/reabrir la app para recuperar
  un job: **NO EJECUTADO**. IA pagada, descargas de terceros y despliegues:
  **NO EJECUTADO**. No hay integración que permita esa prueba móvil todavía.

Manual exacto para API/worker/reinicio/aislamiento/cuotas en el hermano:
`foodiefy_api/docs/recovery/phase08.md`. El propietario puede verificar jobs
desde el cliente CLI local; la comprobación física desde Flutter requiere la
integración de Fase 09. Se hereda el bloqueo de medios/redes sociales en entornos
de producción no verificados. Siguiente entrada: consumir este contrato en
Fase 09 únicamente cuando se solicite; esta entrega termina en Fase 08.

Commit propuesto, **no ejecutado**: `chore: sync durable import job contract`.

## Fase 04 · 2026-09-08

**Persistencia cloud privada y rescate legacy implementados sobre los repositorios existentes. Verificación local; no se avanza a la fase siguiente.**

### Decisiones y archivos afectados

- `lib/repositories/`: `SessionRepository`, `LibraryRepository` (recetas y colecciones), gateway Supabase inyectable, adaptador v1 y caché Drift/SQLite por `owner_id`. `ChangeNotifier` para sesión/listas; formularios conservan `setState`.
- `lib/recovery/legacy_recovery.dart` y pantalla de rescate: export raw previo, backup redundante, SHA-256, dry-run, orden/UUID por ocurrencia, correcciones sobre copias, resolución explícita de referencias, imágenes elegidas y plan reanudable vinculado a una cuenta. No se leyó ni migró contenido real del dispositivo del propietario.
- Fachadas en servicios anteriores: se retiraron escrituras best-effort en `user_recipes`/`collection_recipes` y el merge automático legacy. SharedPreferences legacy conserva lectura/exportación; sus escrituras fallan explícitamente.
- Pantallas existentes conectadas a repositorios; registro/login, confirmación pendiente, recuperación y callback. Botones OAuth y cuotas ficticias retirados del flujo de cuentas. Los enlaces de importación se conservan durante login. ImportService exige sesión y envía su bearer sin imprimirlo.
- Cambiar de cuenta/logout limpia estado/caché, invalida resultados tardíos y reemplaza todas las rutas privadas. También limpia la caché de imágenes de Flutter. El modo sin cuenta no asigna datos al siguiente usuario.
- Manifiestos iOS/Android para `io.supabase.foodiefy://login-callback`; Android debug permite HTTP solo en loopback/emulador. Los ajustes Gradle previos del propietario permanecen intactos.
- `pubspec.yaml`/lock: Supabase Flutter 2.10.3 conservado; Drift 2.34.3 y SQLite3 3.5.2 fijados; path_provider 2.1.5, crypto 3.0.7 y url_launcher 6.3.2 pasan a dependencias directas sin cambiar sus versiones. Dart mínimo 3.10 por Drift. No se ejecutó actualización masiva.
- `contracts/`: snapshot regenerado desde el hermano API para admitir URL/plataforma desconocidas como `null`. `tool/` contiene configurador público y prueba HTTP con guardia de loopback. `config/supabase.local.json` creado y excluido de Git.

### Pruebas y resultados reales

| Comando/prueba | Resultado |
| --- | --- |
| Flutter/Dart y `flutter pub get` | PASS: Flutter 3.47.2, Dart 3.13.2; lockfile resuelto sin actualización masiva. |
| `flutter test --no-pub --reporter compact` | **PASS, 46 tests; 1 skip explícito** (HTTP local desactivado en la suite por defecto). La prueba HTTP se ejecutó aparte y pasó. |
| `python3 tool/test_supabase_local.py` | **PASS, 1 test HTTP real**, ejecución final de 55 s: registro/login con dos cuentas sintéticas, guardar/reabrir en segundo cliente, editar, conflicto, colecciones/renombrar, mover/quitar, rollback de creación+asociación, borrar, Storage privado y aislamiento A/B/logout. |
| Tests de repositorio/rescate | **PASS, 9 tests focalizados finales**: lectura offline sin guardado ficticio, replay tras respuesta perdida, aislamiento/caché/respuestas tardías, reapertura, contrato, IDs vacíos/duplicados, relación ambigua, checksum, datos ilegibles, copia de imágenes y subida de una sola imagen elegida, enlace pendiente. |
| Auth y raíz de navegación | **PASS, 5 tests**: confirmación pendiente sin sesión, solicitud PKCE de recuperación y guardia de actualización, falta de configuración, eliminación de rutas privadas A→B y ausencia de usuario anónimo implícito. |
| `flutter analyze --no-pub --no-fatal-infos` | **PASS: 0 errores, 0 warnings; 12 infos preexistentes** sobre underscores/deprecaciones gráficas. Sin el flag, esos infos hacen que el comando termine con código 1; no se presenta como análisis completamente limpio. |
| XML Android / plist iOS | PASS de parseo y callback configurado. No demuestra navegación nativa. |
| Contrato y SQL del hermano | PASS: 19 pytest, 50 pgTAP, advisors/lint local sin incidencias; detalle en progress del API. |
| `git diff --check` | PASS en ambos repositorios. |
| App nativa, callback real de email en iOS/Android, dos simuladores/dispositivos y modo avión físico | **NO EJECUTADO**. |
| Rescate de datos reales, staging/producción, IA real/pagos, builds de app/contenedores, distribución | **NO EJECUTADO**. |

La primera prueba HTTP falló por configurar PKCE sin storage en el arnés de cliente puro; se corrigió el arnés para email/contraseña. La app conserva PKCE con el storage del SDK y tiene tests específicos de sus solicitudes. Un fixture inicial de imagen contenía solo su cabecera y fue rechazado correctamente: se sustituyó por un PNG sintético completo y el test focalizado pasó. Esas ejecuciones fallidas no se cuentan como PASS. El índice conservaba la generación de Fase 03; las comprobaciones de cobertura señalaron cambios/archivos nuevos y SQL parcial. Las decisiones finales se apoyan en fuente actual y pruebas, no en una supuesta auditoría completa del grafo.

### Operación manual, límites y siguiente entrada

Seguir [phase04.md](phase04.md): iniciar/reiniciar solo el Supabase local, usar `config/supabase.local.json`, probar cuenta A en dos dispositivos, logout/B, modo avión, recuperación por deep link y rescate interrumpido/repetido. En la app: **Tu cuenta → Rescatar datos antiguos / exportar backup → revisar → elegir y confirmar cuenta**. No hay una cuenta real autorizada para el rescate y el agente no ejecutó esa importación.

La prueba de HTTP local usa clientes Dart, no dos apps nativas. Las fotos cloud utilizan URLs firmadas caducables; su descarga offline y la eliminación automática de imágenes huérfanas no pertenecen a esta fase. El plan de rescate cubre una instantánea; el backup no se borra. Staging exige autorización específica de proyecto/entorno antes de cualquier operación remota. La siguiente entrada es la verificación manual de Fase 04, no implementar Fase 05.

Commit propuesto, **no ejecutado**: `feat: add cloud persistence and lossless legacy recovery`.

## Fase 03 · 2026-09-07

**Snapshot de contrato recibido. No se integra persistencia ni se continúa a Fase 04.**

### Cambios y límites

- `contracts/` contiene el JSON Schema `RecipeDraft v1`, manifest de versión y
  hashes, dos fixtures válidos y tres erróneos copiados desde `foodiefy_api`.
- La actualización es reproducible con
  `.venv-recovery/bin/python -m scripts.generate_contracts --sync-flutter
  ../foodiefy/contracts` desde el hermano API; `contracts/README.md` documenta el
  flujo. El snapshot no se edita a mano.
- No se tocaron modelos Dart, navegación, servicios legacy, Supabase runtime,
  UI, auth ni almacenamiento local. El enlace existente en `supabase/.temp` se
  conservó sin operaciones remotas.
- No hay `service_role`, secreto de IA/base de datos ni webhook en el snapshot.
  “Todas” sigue siendo una decisión virtual de UI; Flutter no envía UUID `0`.

### Pruebas reales

| Prueba | Resultado |
| --- | --- |
| Generación + copia desde API y comprobación `--check` | PASS |
| Hashes del schema/fixtures mediante manifest y tests API | PASS dentro de los 18 tests del hermano |
| Flutter test/analyze/build, simulador/dispositivo | **NO EJECUTADO**; no cambió código Dart/nativo |
| Supabase remoto/staging | **NO EJECUTADO** |

Siguiente punto: tras la verificación manual de dos usuarios contra Supabase
local, la Fase 04 podrá diseñar la adaptación explícita de estos campos a Dart,
persistencia remota y rescate legacy. No asumir que el snapshot ya sincroniza la
app.

Commit propuesto para este repositorio, **no ejecutado**: `chore: sync recipe contract v1`.

## Fase 01 · 2026-09-07

**Implementación de rescate terminada. Tests focalizados PASS; análisis global FAIL por trabajo previo. No se continúa a Fase 02.**

### Conservación y contexto

- Repositorios hermanos existentes `foodiefy/` y `foodiefy_api/`, independientes. No se creó Git en el padre, ni commits, resets, limpiezas o despliegues.
- Copia privada completa de ambos repositorios, incluyendo Git, cambios locales, build existente y `.venv` antiguo: `/Users/umartin-/Desktop/SprayNPray/FoodiefyBackup-20260907-161829`. Se copiaron además `simulator-foodiefy-app` y `simulator-foodiefy-data` del iPhone 17 encendido, antes de tocar su instalación (no se reinstaló ni lanzó Foodiefy).
- Igualdad de bytes verificada frente a la copia para el servicio previo `sync_service.dart`, `analysis_options.yaml` y los archivos iOS modificados al inicio. Podfiles ya borrados siguen sin restaurarse. El lockfile Flutter actual coincide exactamente con el inicial local; sus diferencias frente a HEAD eran anteriores.
- No existía resumen `progress.md` anterior. Se leyó el MASTER_PLAN del hermano API, cuya Fase 0 indica preservar instalaciones/datos y cuya Fase 1 coincide con este rescate.
- El propietario creó/enlazó un proyecto Supabase durante esta ejecución. Sus archivos `supabase/` se conservan; no se inspeccionaron secretos ni se realizaron operaciones remotas.
- Índice consultado: `Users-umartin-Desktop-SprayNPray-FoodiefyWorkspace`, generación inicial `2026-09-07T12:28:25Z`, tier Verify. Cobertura mostró metadatos cambiados en servicios/modelos; las decisiones se contrastaron con su fuente actual. No se confunde el índice con prueba de exhaustividad.

### Inventario verificable y decisiones

| Archivo/contrato | Estado inicial | Cambio de Fase 01 |
| --- | --- | --- |
| `pubspec.yaml`, `pubspec.lock` | App 1.0.0+1, SDK declarado ^3.8.1; paquetes ya resueltos localmente; `.env` asset obligatorio | Se fijan dependencias directas a las versiones resueltas existentes; se elimina el asset obligatorio. Lock local intacto. |
| `lib/main.dart` | Carga `.env` y Supabase incondicional, sin binding explícito previo | Binding primero, configuración tipada, error legible, marca RESCATE LOCAL, cloud solo tras configuración explícita. |
| `lib/config/app_config.dart`, `cloud_runtime.dart` | No existían | Entornos, HTTPS, rechazo de secretos móviles; cliente nullable asignado solo al finalizar inicialización. |
| `lib/models/recipe.dart` | Macros enteros y redondeo prematuro | Valores double nullable, validación finitos/no negativos, cero solo si explícito. `Recipe.fromJson` no cambia IDs legacy. |
| `lib/services/import_service.dart` | URL localhost fija, ID vacío, fallback 3500 kcal/400/50/200 g, impresión de response.body | Base configurable + `/api/analyze-recipe`, UUID v4 nuevo, sin macros ficticios ni logs de contenido. Cliente inyectado; conexión 5 s, solicitud 30 s. |
| Contrato HTTP importador | Esperaba `success=true` y `recipe` | Valida `titulo`, `ingredientes`, `pasos`; HTTP, timeout, red, JSON, success=false y campos ausentes generan `ImportRecipeException` con código/mensaje controlado. No hay fallback de éxito. |
| `lib/services/storage_service.dart` | Lectura/escritura global de lista; crear siempre añadía; actualización elegía primer ID coincidente | Lectura conserva IDs, exportación de strings raw, avisos solo con contadores. Mutaciones serializadas; se rechaza crear ID vacío/repetido y actualizar/borrar IDs ambiguos. Registros ajenos/ilegibles se conservan. |
| `lib/services/recipe_service.dart`, `collection_service.dart` | Acceso directo a Supabase tras guardar local | Sin acceso a Supabase en rescate; patrones cloud previos se conservan para fuera de rescate, sin certificarlos. |
| `lib/screens/create_recipe_screen.dart` | Guardaba siempre como nueva, incluso con ID de plantilla | Crear borrador vs `isEditing=true` explícito; conservar ID/createdAt al editar y UUID nuevo al crear. Campos nutricionales permiten decimales y validan entrada. |
| `lib/screens/home_screen.dart`, `import_recipe_screen.dart` | Plantillas sin intención de guardado explícita | Se distinguen plantilla existente y borrador importado; UI de importación informa bloqueo local, renueva cliente por intento y respeta mounted. |
| `lib/utils/auth_service.dart`, pantallas auth/Cuenta | Cliente estático/eager podía acceder antes de inicializar | Cliente lazy nullable, pantallas preservadas, auth deshabilitada en rescate. Cuenta permite copiar exportación legacy. |
| `lib/screens/recipe_detail_screen.dart` | Ocultaba nutrición ausente y mostraba 0 g en campos vacíos | Mensaje no disponible y gráfico solo con tres macros conocidos, sin convertir ausencias en ceros. |
| `scripts/legacy_config.py`, `config/*.example.json` | Sin ejemplos seguros | Conversión opcional de allowlist pública del `.env` antiguo a defines locales ignorados; no empaqueta `.env` ni activa cloud. |

La exportación nueva conserva recetas y colecciones como strings originales, incluidos datos no parseables. No exporta binarios de imágenes ni realiza migración cloud; la copia del contenedor preserva archivos. Los valores históricos que pudieran proceder del fallback no se borran sin conocer su origen. No se inventó un fixture runtime: los fixtures existen solo en tests mediante inyección.

### Pruebas y resultados reales

| Prueba | Resultado |
| --- | --- |
| `flutter --version` | Flutter 3.47.2 stable, Dart 3.13.2, DevTools 2.60.0 |
| `flutter pub get --offline` | PASS; lockfile local idéntico a la copia inicial |
| `flutter test --no-pub test/recovery_test.dart` | **PASS, 32 tests**: IDs diferentes/persistencia de dos imports, macros, errores de dominio, timeout, cero HTTP en rescate, conservación/exportación legacy, concurrencia, configuración, main real sin cloud, edición sin duplicado, cancelación y error visible |
| Conversor legacy con directorio temporal/fixtures | PASS: `.env` ausente, allowlist sin secretos de servidor, rechazo de clave privada |
| `flutter analyze --no-pub`, antes | **FAIL**: 31 diagnósticos = 6 errores, 4 warnings, 21 info |
| `flutter analyze --no-pub`, final | **FAIL**: 29 diagnósticos = los mismos 6 errores y 4 warnings, 19 info; sin diagnósticos nuevos |
| Comparación de archivos previos y `git diff --check` | PASS; no cambios a iOS/servicio de sync del propietario |
| Health desde simulador iPhone 17, iOS 26.3 | PASS: HTTP 200 usando `simctl spawn ... curl` hacia loopback con puerto efímero; **no es prueba de la app Flutter nativa** |
| App en dispositivo/simulador, transporte Flutter nativo, builds, distribución | **NO EJECUTADO** |
| IA real, descarga de modelos/medios, Supabase/RLS remoto, migraciones | **NO EJECUTADO** |

Hubo una primera pasada de tests con dos fallos del arnés de widgets (búsqueda del texto pintado por Banner y cola asíncrona compartida entre zonas); se corrigieron y la suite completa final pasó. No se cuentan esas ejecuciones fallidas como PASS.

### Bloqueos preexistentes

`lib/services/sync_service.dart` ya era un archivo local no versionado y permanece byte a byte igual. Sus seis errores son: `Recipe.copyWith` (línea 152), `RecipeCollection.copyWith` (163, 207, 273), `StorageService.setRecipes` (281) y `CollectionService.setCollections` (282), todos inexistentes antes de esta fase. El arranque de rescate no importa ese servicio. No se añadieron contratos de migración ni escrituras masivas para hacerlo compilar; el análisis global no queda certificado.

Persisten cuatro warnings previos en el editor, colecciones y diálogo de creación, además de deprecaciones/lints informativos. La configuración nativa iOS previa y la compilación/distribución requieren verificación del propietario; no se tocaron para forzar un resultado.

### Siguiente punto de entrada

Seguir los comandos y checklist del [README](../../README.md): abrir rescate, leer receta antigua, exportar JSON, crear receta sin nutrición y consultar health en el hermano API. Acordar por separado cómo resolver el servicio de sincronización previo antes de exigir un análisis global limpio. El enlace Supabase ya creado no habilita migraciones ni la fase siguiente.

Commit propuesto para este repositorio, **no ejecutado**: `chore: establish recoverable local baseline`.
