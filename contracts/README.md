# Snapshot de contrato API

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
