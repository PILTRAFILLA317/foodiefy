# Progreso de recuperación · Foodiefy Flutter

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
