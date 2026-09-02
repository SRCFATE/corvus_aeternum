# Corvus Aeternum

Plataforma cultural digital para artistas, coleccionistas y críticos: publicar
obra, sellarla con certificado, reunirla en colecciones y sacarla a subasta.

Una sola base de código Flutter para **Android, iOS, web y escritorio**, con
Supabase como backend (Postgres + Auth + Storage + Edge Functions).

## Requisitos

- Flutter 3.44 o superior (Dart 3.12)
- Una cuenta de Supabase con el esquema de `docs/` aplicado

## Arrancar

```bash
flutter pub get
flutter run            # dispositivo o emulador
flutter run -d chrome  # web
```

Compilar la web para producción:

```bash
flutter build web --release
```

La URL y la clave publicable de Supabase viven en `lib/core/supabase_config.dart`.
La clave publicable está pensada para viajar en el cliente; lo que protege los
datos son las políticas RLS y de Storage, no esconderla.

## Estructura

```
lib/
├── core/         Tema, tokens de diseño, router (go_router) y errores RPC
├── models/       Clases de datos: Work, Artist, UserProfile, Auction…
├── services/     Acceso a Supabase (auth, perfiles, obras, storage…)
├── providers/    Estado compartido con provider (sesión, conspiración, atelier)
├── shared/       Widgets y layouts reutilizables
└── features/     Una carpeta por módulo: feed, atelier, obras, subastas,
                  colecciones, certificados, foros, arena, glosario…
```

La navegación es por URL en todas las plataformas: `/work/:id`, `/profile/:username`,
`/collection/:id`, `/auction/:id`, `/certificate/:number`.

## Despliegue

`main` es producción. Cada push ejecuta `.github/workflows/ci.yml`, que fija
Flutter 3.44.0, analiza, pasa las pruebas, compila y solo entonces publica
`build/web` en Cloudflare Pages con Wrangler. Si algo falla antes, no se
despliega. Una pull request ejecuta las mismas comprobaciones sin tocar
producción.

El artefacto no se versiona: el repositorio guarda la fuente y CI lo genera.
Hacen falta dos secretos en GitHub, `CLOUDFLARE_API_TOKEN` y
`CLOUDFLARE_ACCOUNT_ID`, con el permiso mínimo para desplegar Pages.

## Base de datos

Los esquemas SQL y las funciones están versionados en `docs/` y en `supabase/`.

## Pruebas

```bash
flutter test
flutter analyze
```
