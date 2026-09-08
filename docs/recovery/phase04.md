# Fase 04 · Cloud privado y rescate legacy

La app utiliza Supabase como fuente de verdad para recetas y colecciones. Una
cuenta real es necesaria para guardar e importar. El modo local predeterminado
permite leer y exportar datos antiguos; ya no modifica SharedPreferences.

## Arquitectura y contratos

- `SessionRepository`: sesión del SDK, registro con confirmación pendiente o
  sesión real, login, logout local con revocación remota, recuperación PKCE y
  cambio de contraseña. El enlace pendiente de importación se conserva en
  `pending_import_v1`; nunca se almacena una contraseña en él.
- `LibraryRepository`: recetas y colecciones, estado reactivo mediante
  `ChangeNotifier`, caché por propietario e inyección de `CloudGateway`.
  Los servicios anteriores son fachadas de compatibilidad. Los widgets no
  consultan PostgREST. `SyncService` rechaza la antigua fusión automática.
- `LocalCache`: Drift 2.34.3 / SQLite3 3.5.2, versión de esquema 1, en
  Application Support `cloud-cache.sqlite`. Guarda snapshots confirmados y
  claves de operaciones por `owner_id`. No permite editar recetas offline.
  El formulario abierto permanece intacto si falla la confirmación cloud.
- La transición de sesión vacía listas inmediatamente, invalida resultados
  tardíos y limpia la caché del propietario anterior. La raíz de navegación
  cambia de clave y elimina rutas/formularios privados; también vacía la caché
  de imágenes de Flutter. El backup legacy no se reasigna a otra cuenta.
- El hermano API sigue siendo la fuente de verdad de `RecipeDraft v1`.
  `url` y `platform` aceptan `null`: una receta manual no necesita un origen
  inventado. Snapshot y hashes regenerados mediante el generador de Fase 03.
  Los campos estructurados de recetas cloud se conservan al editar texto sin
  cambiarlo. Nutrición legacy sin base/procedencia permanece en el raw; no se
  transforma en una estimación inventada.
- `cloud_mutation_v1` envuelve los RPCs de Fase 03 y guarda un recibo privado
  por propietario/operación. Repetir la misma solicitud devuelve su resultado;
  reutilizar la clave con otro contenido se rechaza. Editar exige revisión.
  Crear dentro de una colección es una sola transacción. Cambiar asociaciones
  exige el conjunto anterior y es atómico. Quitar de una colección no borra la
  receta. Borrar una receta retira sus asociaciones y deja el tombstone.
- `library_snapshot_v1` devuelve una vista coherente de recetas/hijos,
  colecciones y referencias de imágenes; no añade Realtime ni sync general.
  Usa **Actualizar** para consultar cambios de otro dispositivo.

## Preparar el entorno LOCAL

Desde `foodiefy_api/`:

```sh
rtk proxy supabase start
rtk proxy supabase db push --local
rtk proxy supabase test db --local supabase/tests/database
rtk proxy supabase db advisors --local --type all --level info --fail-on warn
rtk proxy supabase db lint --local --level warning --fail-on warning
```

Destino comprobado en esta fase: proyecto CLI `foodiefy_api`, contenedor
`supabase_db_foodiefy_api`, API `http://127.0.0.1:54321`, PostgreSQL local
puerto 54322. No se ha reseteado la base ni usado `--linked`.

Si Supabase ya estaba iniciado con la configuración anterior, reinícialo para
cargar `additional_redirect_urls` del archivo actual. Desde `foodiefy_api/`,
`rtk proxy supabase stop` seguido de `rtk proxy supabase start`; no usar
`--no-backup`, `db reset` ni borrar volúmenes. La configuración local admite
`io.supabase.foodiefy://login-callback`. El registro local de las pruebas no
requiere confirmar email; la interfaz también gestiona la configuración con
confirmación activada.

Desde `foodiefy/`:

```sh
rtk proxy python3 tool/configure_supabase_local.py
rtk proxy flutter run --dart-define-from-file=config/supabase.local.json
```

El configurador solo acepta la instancia hermana en loopback y escribe la
clave pública `anon`; nunca imprime ni copia claves de servidor. No sobrescribe
un archivo existente. Se ha creado `config/supabase.local.json` para el
simulador iOS/Mac, excluido de Git. El comando `flutter run` de arriba es para
el propietario: **no se ha ejecutado ni compilado la app en esta fase**.

Para un emulador Android, crea el archivo mediante
`rtk proxy python3 tool/configure_supabase_local.py --android-emulator` cuando
no exista ya el archivo; el host será `10.0.2.2`. El manifiesto de debug permite
HTTP solo en localhost, 127.0.0.1 y 10.0.2.2. No se ha probado el emulador.
La configuración pública también apunta a la API local en el puerto 8000;
las funciones de IA siguen deshabilitadas por defecto en el hermano API.

Staging/producción no se han configurado ni modificado. Antes de promover,
mostrar y autorizar expresamente el proyecto/destino, revisar las migraciones
y configurar el callback en Supabase Auth. Usar HTTPS y una clave pública.
Google/Apple no tienen botones activos en esta fase.

## Rescatar los datos existentes

1. Conservar la instalación que contiene los SharedPreferences antiguos. No
   desinstalarla ni borrar sus datos. Abrir **Tu cuenta → Rescatar datos antiguos /
   exportar backup**. Se escribe el raw antes de cualquier importación.
2. La app crea `legacy-quarantine/raw.json`, `raw.backup.json` y `plan.json`
   en Application Support. La pantalla muestra el directorio y el SHA-256.
   **Exportar raw: copiar JSON** permite guardar una copia externa privada.
   Conservar también el directorio completo/contenedor de la app: el JSON raw
   referencia las imágenes originales; las copias duraderas y su mapeo están
   en la cuarentena y el plan. No añadir estos datos a Git.
3. Revisar el dry-run. Cada ocurrencia tiene un índice y UUID nuevo persistido,
   incluidos IDs vacíos/repetidos. Los strings originales, campos desconocidos
   y registros ilegibles permanecen intactos. La lista conserva su orden.
4. Usar **Revisar copia raw** para corregir una copia de un objeto inválido;
   el raw original no cambia. Las colecciones pueden revisarse con `name` y
   `recipeIds`. Para cada relación ambigua/ausente elegir una ocurrencia
   concreta, o **Conservar raw sin asociar**. No se adivina una asociación.
   “Todas” es virtual; no crea una colección cloud.
5. Las imágenes solo se buscan por las rutas incluidas en las recetas, sin
   recorrer el dispositivo. Las existentes se copian a la cuarentena y se
   registra su checksum. Las faltantes se marcan y la receta se conserva.
   Marcar individualmente **Subir esta imagen privada**. Las URLs remotas
   antiguas se registran como referencias caducables, sin descarga automática.
6. Iniciar sesión en la cuenta elegida, volver al rescate y pulsar **Elegir
   cuenta y confirmar importación**. Revisar el email y UUID del diálogo y
   confirmar. No se ha elegido ninguna cuenta ni importado datos reales por
   el agente. La primera confirmación vincula ese plan a esa cuenta.
7. Ante error, cierre o pérdida de conexión, volver con la misma cuenta y
   pulsar **Reanudar / verificar sin duplicar**. El plan guarda IDs, operaciones
   y progreso antes de cada paso. Al terminar se comprueba que cada receta,
   sus recuentos de ingredientes/pasos y las asociaciones elegidas existen en
   cloud. Repetir la verificación no crea otra copia. No borrar el backup.

Las fotos elegidas se suben al bucket privado `recipe-images` bajo
`owner_id/recipe_id/checksum.ext` (JPEG, PNG o WebP, máximo 10 MB). La referencia
solo se guarda con la transacción de receta. Si el usuario abandona un guardado
fallido tras subir una foto, puede quedar un objeto privado sin referencia; no
se añade una limpieza destructiva automática. Las fotos cloud se muestran con
URLs firmadas de una hora; su descarga/caché offline no está incluida.

## Conflictos y límites operativos

- **Revisión o asociaciones modificadas en otro dispositivo:** guardar no se
  confirma. El formulario queda abierto; conservar el texto deseado, actualizar
  la lista y reabrir el registro antes de repetir la edición.
- **Resultado perdido después del commit:** reintentar el mismo contenido
  conserva la clave y recupera el recibo del servidor. No cambiar el borrador
  hasta resolver esa operación. La recuperación legacy guarda sus propias
  claves para reanudarse tras logout o reinicio.
- **Otro propietario:** se oculta el estado visual anterior. El rescate
  vinculado exige volver a su cuenta; nunca importa al siguiente usuario.
- **Checksum distinto:** el rescate se detiene antes de importar. No modificar
  ni eliminar el backup para superar la comprobación.
- **Registros ya importados modificados o borrados después:** la verificación
  informa del recuento/referencia que no coincide; no resucita recetas ni
  sobreescribe ediciones posteriores.
- El plan cubre la instantánea inicial del almacenamiento antiguo. No combina
  automáticamente nuevos exports de otras instalaciones. No hay usuarios
  anónimos cloud, cuotas, feed, lista de compra offline ni cola general de sync.

## Pruebas reproducibles

Desde Flutter, las pruebas ordinarias no usan IA ni Supabase remoto:

```sh
rtk proxy flutter test --no-pub
rtk proxy flutter analyze --no-pub --no-fatal-infos
rtk proxy python3 tool/test_supabase_local.py
```

El último comando activa únicamente el test HTTP real contra el proyecto
local comprobado. Genera dos cuentas sintéticas y prueba CRUD, reapertura desde
un segundo cliente, revisión obsoleta, rollback de creación/asociación,
colecciones, Storage privado y aislamiento A/B/logout. Las cuentas sintéticas
y tombstones de prueba permanecen en esa instancia local. Sin activación, ese
test se muestra como **NO EJECUTADO/skip**, nunca como PASS.

Resultados efectivos y omisiones: [progress.md](progress.md).

## Verificación manual del propietario

1. Arrancar en el simulador/dispositivo con la configuración pública indicada.
   Registrar A; si exige confirmación, verificar que no se anuncia sesión hasta
   abrir el email. Probar login, recuperación y callback en arranque frío y con
   la app abierta; guardar la nueva contraseña e iniciar sesión con ella.
2. Crear una receta con A, también desde una colección. En un segundo
   dispositivo con A, pulsar **Actualizar** y comprobar receta, ingredientes,
   pasos y foto elegida. Editar desde ambos y comprobar el conflicto de revisión.
3. Mover/asociar/quitar una receta; quitar debe conservarla en Todas. Eliminar
   una receta debe retirarla de las colecciones. Renombrar y borrar colección.
4. Cerrar sesión e iniciar B: no deben aparecer rutas, formularios, listas ni
   fotos de A. La cuarentena no se importa ni se reasigna a B.
5. Con A y recetas cargadas, activar modo avión: leerlas, intentar guardar y
   comprobar el error y el formulario conservado. Volver a conectar y reintentar.
6. Revisar/confirmar el rescate según los pasos anteriores. Interrumpirlo y
   reanudar; ejecutarlo dos veces y verificar los mismos UUID/recuentos, una
   relación ambigua resuelta expresamente y una foto faltante conservada como
   incidencia. Exportar/copiar el backup fuera de la instalación.

## Versiones y documentación oficial consultada

- [Supabase Flutter 2.10.3](https://pub.dev/documentation/supabase_flutter/2.10.3/)
  y firmas de los paquetes resueltos: Supabase 2.10.0, GoTrue 2.16.0 y
  StorageClient 2.4.1. El SDK usa PKCE en la app, persiste su verificador y
  reproduce el último evento de sesión para los nuevos listeners.
- [Auth Flutter y deep links](https://supabase.com/docs/guides/getting-started/tutorials/with-flutter),
  [registro](https://supabase.com/docs/reference/dart/auth-signup),
  [recuperación](https://supabase.com/docs/reference/dart/auth-resetpasswordforemail),
  [changelog](https://supabase.com/changelog).
- [Drift setup](https://drift.simonbinder.eu/setup/),
  [GeneratedDatabase 2.34.3](https://pub.dev/documentation/drift/2.34.3/drift/GeneratedDatabase-class.html).
  SQL pequeño mediante `customSelect/customStatement` y migración de esquema,
  sin una segunda capa de modelos generados. Drift exige Dart >=3.10; el
  proyecto dispone de Dart 3.13.2. Lockfile actualizado solo para las nuevas
  dependencias; Supabase y sus versiones transitivas permanecen fijadas.
