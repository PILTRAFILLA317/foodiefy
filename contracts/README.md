# Snapshot de contrato API

## Jobs de importación · Fase 08

`imports.v1.schema.json` y `imports.v1.manifest.json` se generan desde
`foodiefy_api/src/imports/models.py`. Incluyen solicitud, aceptación, consulta,
paginación, estados y etapas independientes, sin porcentajes ficticios.
No contienen credenciales. Recibir el contrato no implementa polling ni UI.

Actualizar desde `foodiefy_api/`:

```sh
rtk proxy .venv-recovery/bin/python -m scripts.generate_import_contract --check
rtk proxy .venv-recovery/bin/python -m scripts.generate_import_contract --sync-flutter ../foodiefy/contracts
rtk proxy git -C ../foodiefy diff -- contracts
```

No editar el snapshot a mano. La integración móvil queda para Fase 09.

## Recetas · Fase 03

Snapshot de solo lectura de `RecipeDraft v1`. La fuente de verdad está en el
repositorio hermano `foodiefy_api`; Flutter no mantiene modelos Pydantic ni SQL.
`recipe-draft.v1.manifest.json` fija la versión y hashes del schema/fixtures.

Actualizar desde `foodiefy_api/`:

```sh
.venv-recovery/bin/python -m scripts.generate_contracts --check
.venv-recovery/bin/python -m scripts.generate_contracts --sync-flutter ../foodiefy/contracts
git -C ../foodiefy diff -- contracts
```

No conectes este snapshot a la sincronización legacy durante Fase 03. La
integración de persistencia/caché pertenece a Fase 04.
