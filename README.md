# Foodiefy · Fase 01

Recuperación del cliente Flutter existente. El modo predeterminado es **RESCATE LOCAL**: abre sin `.env`, Supabase ni API de IA. Mantiene navegación, recetas y colecciones en SharedPreferences. No instala una aplicación nueva ni migra datos.

## Arranque local

Entorno verificado: Flutter **3.47.2**, Dart **3.13.2**, macOS. Dependencias directas fijadas a las versiones del lockfile local previo; `pubspec.lock` se conserva sin cambios respecto a la copia inicial. Usa la misma versión de Flutter para reproducir la resolución.

Desde `foodiefy/`:

```sh
flutter pub get --enforce-lockfile
flutter test --no-pub test/recovery_test.dart
flutter analyze --no-pub
```

Aquí se ejecutó `flutter pub get --offline`, los tests y el análisis. Los 32 tests pasan. **El análisis global falla** por seis errores previos en `lib/services/sync_service.dart`, un archivo local no conectado al arranque, además de avisos existentes. Detalles y evidencia en [progress.md](docs/recovery/progress.md). No se ocultaron mediante exclusiones del analizador.

Para el propietario, después de conservar los datos de la instalación antigua:

```sh
flutter devices
flutter run --dart-define-from-file=config/local.example.json -d <ID_DEL_DISPOSITIVO>
```

La opción `--dart-define-from-file` se verificó con `flutter run --help`. **No se ejecutó `flutter run` ni ningún build en esta fase.** Arrancar en un dispositivo puede compilar: corresponde a la verificación manual del propietario. No desinstales ni borres los datos de la app antigua. Mantén su identificador `com.example.foodiefy`.

## Configuración pública tipada

`AppConfig` acepta `APP_ENV=local|staging|production`, `LOCAL_RESCUE=true|false`, `API_BASE_URL`, `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY`. Acepta temporalmente `SUPABASE_ANON_KEY` con rol JWT `anon`. Rechaza claves de servidor, URLs con credenciales, query o fragmentos, entornos desconocidos y cloud incompleto con un mensaje legible.

- Sin defines: `APP_ENV=local`, `LOCAL_RESCUE=true`; no se inicializa Supabase ni se envían importaciones.
- HTTP: solo desarrollo local, en loopback, `10/8`, `172.16/12` o `192.168/16`. Staging/production exigen HTTPS. Release rechaza entorno local y rescate.
- `API_BASE_URL` es la base **sin `/api` final**. El importador añade `/api/analyze-recipe`.
- `config/production.example.json` es deliberadamente incompleto; no contiene credenciales reales ni habilita producción por sí solo.
- Los valores se fijan al iniciar/compilar; hot reload no cambia los defines.

El `.env` antiguo se conserva pero **no se empaqueta como asset**. Compatibilidad opcional, sin imprimir valores ni copiar secretos de servidor:

```sh
python3 scripts/legacy_config.py
flutter run --dart-define-from-file=config/legacy.local.json -d <ID_DEL_DISPOSITIVO>
```

El conversor lee solo `API_BASE_URL`, `SUPABASE_URL` y las dos variantes de clave pública, ignora las demás, rechaza claves privadas y deja rescate activo. Funciona también si no existe `assets/.env`. El resultado está ignorado en Git. No pases un `.env` de servidor directamente a Flutter. No es necesario ejecutar este conversor para rescatar recetas.

## Direcciones de la API

Arranca el hermano `foodiefy_api/` según su README. No hacen falta keys.

| Cliente | API_BASE_URL | Verificación |
| --- | --- | --- |
| Mac / simulador iOS | `http://127.0.0.1:8000` | Health consultado desde el Mac y mediante `simctl spawn` en iPhone 17 / iOS 26.3, con puerto efímero. No se lanzó la app Flutter. |
| Emulador Android estándar | `http://10.0.2.2:8000` | Alias oficial del loopback del host; emulador NO EJECUTADO. |
| Móvil físico | `http://<IP_LAN_DEL_MAC>:8000` | Misma Wi-Fi, API escuchando en `0.0.0.0`; comprobar `/health/live` en el navegador del móvil. NO EJECUTADO. |

Para obtener la IP, usa Ajustes del Sistema → Wi-Fi → Detalles → TCP/IP, o `ipconfig getifaddr en0` si esa es tu interfaz Wi-Fi. En un móvil físico `localhost` apunta al propio móvil. Las políticas nativas HTTP/ATS/red local requieren validación del propietario antes de habilitar cloud; esta fase no modifica los archivos iOS previos ni certifica transporte HTTP desde la app.

## Qué funciona y qué queda deshabilitado

- Lectura y creación manual local; las importaciones de los tests usan exclusivamente un cliente HTTP inyectado, sin red ni costes.
- UUID v4 independiente para cada importación nueva. El editor diferencia crear un borrador de actualizar una receta existente (`isEditing: true`); actualizar conserva identidad y fecha original.
- Nutrición ausente muestra **Nutrición no disponible**; campos parciales muestran disponibilidad por campo. Números negativos, no finitos o mal formados pasan a `null`; se conservan decimales. No se sustituyen datos históricos ya guardados sin conocer su procedencia.
- Cuenta → **Exportar datos legacy** → **Copiar JSON**. Guarda el portapapeles en un archivo privado. Exporta strings originales de recetas y colecciones, incluyendo registros ilegibles y campos desconocidos. Las imágenes se referencian por ruta; copia por separado el contenedor de la instalación para conservar sus archivos. No es una migración ni un importador de backups.
- IDs legacy vacíos/repetidos se contabilizan sin imprimir IDs ni contenido. No se cambian al leer. Editar o borrar un ID ambiguo se rechaza; guardar otras recetas conserva los registros originales.
- En rescate: auth, sincronización e importación cloud deshabilitadas. Las pantallas originales se mantienen. El antiguo botón de compartir una receta sigue pendiente; la exportación está en Cuenta.
- El proyecto Supabase enlazado por el propietario se conserva. No se ejecutaron operaciones remotas, RLS ni migraciones.

## Verificación manual del propietario

1. Abre sin configuración cloud y comprueba la marca RESCATE LOCAL.
2. Abre Todas las recetas y una receta antigua, si existe; exporta desde Cuenta antes de otras operaciones.
3. Ejecuta los tests: importan dos recetas de fixture por caso y comprueban UUID distintos y persistencia local, sin servidor.
4. Crea una receta manual sin nutrición y comprueba “Nutrición no disponible”.
5. Inicia la API y consulta health. Una importación real deshabilitada es el resultado esperado.

Fuentes oficiales consultadas: [Supabase Flutter 2.10.3](https://github.com/supabase/supabase-flutter/blob/supabase_flutter-v2.10.3/packages/supabase_flutter/lib/src/supabase.dart), [HTTP 1.5.0 IOClient](https://pub.dev/documentation/http/1.5.0/io_client/IOClient/IOClient.html), [timeout de conexión Dart](https://api.dart.dev/dart-io/HttpClient/connectionTimeout.html), [UUID 4.5.2](https://pub.dev/documentation/uuid/4.5.2/uuid/Uuid/v4.html), [red del emulador Android](https://developer.android.com/studio/run/emulator-networking-address).

Commit propuesto, no ejecutado: `chore: establish recoverable local baseline`.
