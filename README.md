# Foodiefy · Fase 04

Cliente Flutter existente con cuentas email/contraseña, persistencia privada
Supabase, caché de lectura por propietario y rescate legacy revisable. Las
recetas antiguas permanecen en SharedPreferences, ahora de solo lectura; no se
asignan a una cuenta sin confirmación. No se ha desplegado en remoto.

La [guía de Fase 04](docs/recovery/phase04.md) contiene los comandos de arranque,
exportación/backup/checksum, revisión de conflictos, reanudación y verificación
manual. [Progreso y resultados reales](docs/recovery/progress.md).

## Usar el entorno local

En el hermano `foodiefy_api/`, iniciar Supabase y aplicar solo las migraciones
locales con `rtk proxy supabase start` y `rtk proxy supabase db push --local`.
En este repositorio:

```sh
rtk proxy flutter pub get
rtk proxy python3 tool/configure_supabase_local.py
rtk proxy flutter run --dart-define-from-file=config/supabase.local.json
```

El configurador no sobrescribe el archivo público si ya existe. El archivo
local del simulador iOS/Mac se ha preparado en esta fase y está excluido de Git.
`flutter run` queda para el propietario; no se ha ejecutado ningún build de app.
Para mantener solo rescate/lectura, usar `config/local.example.json`.
No se cargan `.env` ni secretos de servidor desde el móvil.

## Validación sin builds de aplicación

```sh
rtk proxy flutter test --no-pub
rtk proxy flutter analyze --no-pub --no-fatal-infos
rtk proxy python3 tool/test_supabase_local.py
```

La prueba HTTP es opt-in, restringida al Supabase hermano en loopback y usa
cuentas sintéticas; la suite por defecto la marca como no ejecutada. Ninguna
prueba necesita IA, llamadas de pago ni un proyecto remoto.

Supabase conserva la versión 2.10.3. Drift 2.34.3 y SQLite3 3.5.2 están fijados
junto a su lockfile; requieren Dart >=3.10 (entorno probado: Flutter 3.47.2,
Dart 3.13.2). El contrato JSON se genera en `foodiefy_api` y se copia a
`contracts/`; no editar ese snapshot a mano.

Commit propuesto, no ejecutado:
`feat: add cloud persistence and lossless legacy recovery`.
