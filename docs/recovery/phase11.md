# Fase 11 · entorno público y CI Flutter

`config/staging.example.json` no contiene secretos ni destino inventado operativo. Crear `config/staging.local.json` (ignorado) solo con APP_ENV=staging, LOCAL_RESCUE=false, URL HTTPS real de API/Supabase y clave publishable/anon. El ejemplo vacío falla de forma controlada hasta configurarse.

`.github/workflows/ci.yml` fija Flutter 3.47.2, Python 3.14.0 y acciones por SHA, analiza/tests focalizados y valida integridad de snapshots. `tool/check_contracts.py` comprueba hashes, no afirma que un hermano remoto haya publicado su última versión. Sin checkout cruzado privado ni credenciales API en CI.

Gitleaks 8.28.0 y OSV Scanner 2.2.2 fijados, descarga verificada con checksum, logs saneados; herramientas en temporales. El escaneo de secretos cubre archivos versionados y nuevos no ignorados del checkout, **no todo el historial Git**. Auditar/revocar credenciales históricas es un procedimiento separado si se detecta exposición.

Comandos ejecutables sin build:

```sh
flutter analyze --no-pub --no-fatal-infos
flutter test --no-pub test/staging_config_test.dart test/session_repository_test.dart
python3 tool/check_contracts.py
python3 tool/security_scan.py secrets
python3 tool/security_scan.py dependencies
```

El propietario instala/ejecuta su app de desarrollo con el define-file revisado:

```sh
flutter run --dart-define-from-file=config/staging.local.json
```

Este último comando es manual y **NO EJECUTADO por Codex**. Compila la app, y los defines requieren reinicio completo. Desde datos móviles: login, importar receta web, verificar que jobs sobreviven reinicio de worker y abrir receta con imagen restaurada en lab. Nunca usar configuración de producción para restore.

Runbooks autoridad en ../foodiefy_api/docs/operations/ (repositorio hermano): deploy-rollback.md, variables.md, observability.md, backup-restore.md y staging-smoke.md. Staging real y soporte social Linux pendientes; no avanzamos a Fase 12.
