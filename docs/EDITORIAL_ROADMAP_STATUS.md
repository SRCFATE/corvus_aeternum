# Hoja de ruta editorial — estado de implementación

Actualizado: 23 de septiembre de 2026. Este documento distingue código implementado de criterios todavía pendientes. No equivale a una aprobación para producción.

## Primera entrega: fundamentos

- Guardado automático serializado, estado y hora visibles, reintento, respaldo local por cuenta/proyecto/elemento y recuperación al abrir.
- Aviso al salir, protección del navegador y comparación frente a una edición concurrente.
- Guardar o cambiar el estado editorial no publica. Actualizar la obra requiere revisión y confirmación explícitas.
- Comparación con la última edición enviada, fecha, estructura y avisos previos a publicar.
- Papelera de proyectos y elementos; conserva los identificadores y permite recuperarlos.
- Búsqueda global con teclado; menú Más por categorías; filtros y desplazamientos conservados durante la sesión en las listas principales.
- Escalas, tamaños táctiles y estados comunes; tarjeta de obra compartida en Descubrir y Colecciones.

- Primer guardado con identificador persistente: reintentar una respuesta perdida no duplica el elemento. Los cambios posteriores se guardan después; una edición concurrente abre la comparación. Varios borradores nuevos conservan respaldos separados y se pueden elegir al volver.
- Preparación y actualización de la publicación mediante una transacción que guarda obra, comparación e historial juntos. Rechaza revisiones desactualizadas, conserva el estado público y reconoce reintentos de una misma solicitud.

- Migas compartidas en obras, perfiles, colecciones, comunidades/conversaciones, subastas, certificados y espacios de trabajo. Accesibles por teclado, adaptables a texto ampliado; respetan la protección del editor y piden confirmar la salida desde formularios. Atelier y lectura conservan su contexto de proyecto/obra en la cabecera.

Pendiente de cerrar: adopción del sistema visual en todas las pantallas profundas y revisión del recorrido completo. La papelera no elimina automáticamente contenido por antigüedad.

## Segunda entrega: escritura

- Barra fija, formatos combinables, alineación por párrafo y estado mixto, deshacer/rehacer y menú contextual de selección.
- Comandos de bloque con `/`; título del capítulo separado; H1/H2/H3; citas y listas.
- Separadores de escena como bloques estructurados, con una representación compartida entre editor y lector. Conversión de separadores anteriores y conservación del formato al reabrir.
- Concentración por línea, oración o párrafo, atenuación, seguimiento del cursor y salida con Escape.
- Dossier/Flujo superpuestos; panel redimensionable y fijable en escritorio amplio; hoja inferior en móvil. Tamaño, fijación y pestaña persistentes.
- Fuente literaria local, tamaño e interlineado independientes de la publicación.
- Índice jerárquico con secciones contraíbles, sección visible y búsqueda con anterior/siguiente. Los resaltados no añaden atributos al documento ni cambian su selección.
- Historial manual y automático, comparación entre versiones y restauración con respaldo previo mediante las funciones existentes del servidor.

- Autor visible en el historial, obtenido del perfil autorizado por el servidor.

Pendiente de cerrar: sangría visual opcional y tratamiento dedicado del diálogo; pruebas prolongadas con documentos de gran tamaño. La restauración de una versión sobre el proyecto existente sigue aplicando los elementos que aún existen; la recuperación integral desde exportación crea una copia privada independiente.

## Tercera entrega: lectura y movilidad

- Lector oscuro, sepia y de alto contraste; fuente, ancho, tamaño e interlineado persistentes.
- Continuidad por cuenta/obra/capítulo, restauración de posición, índice, marcadores y eliminación de marcadores.
- Progreso de capítulo y obra, navegación por teclado y controles ocultables. Los capítulos se obtienen juntos y el siguiente ya está disponible al navegar.
- Controles táctiles, paneles móviles y pruebas de anchos pequeños/escalado de texto.
- Cargas con contenido anterior en Descubrir, Ranking y Colecciones; descarte de resultados obsoletos.
- Regresión visual del manuscrito en las tres paletas con fuente incluida en la aplicación.

- Medición local opcional de contenido visible y controles habilitados en lector y Ranking: ejecutar con `--dart-define=CORVUS_PERFORMANCE=true`, consultar `corvus.performance` y eventos `corvus.page.*` en herramientas de desarrollo. No recoge contenido, identificadores ni envía telemetría. Mide el primer cuadro con contenido y controles habilitados, no latencia de entrada ni inactividad global del navegador.
- Regresión con 100.000 palabras, 100 secciones y Unicode: índice y búsqueda mantienen sus posiciones. Ejecución local del 23/09: 15,7 ms para índice y 25,3 ms para búsqueda; valores orientativos de esa máquina, sin umbrales dependientes del equipo.

Pendiente de cerrar: mediciones en dispositivos reales y auditoría completa con lectores de pantalla reales. La revisión visual local no sustituye la comprobación en producción requerida por la hoja de ruta.

## Cuarta entrega: plataforma conectada

- Continuar escribiendo, cambios pendientes, progreso semanal y comentarios abiertos agrupados por proyecto.
- Referencias estables desde `@`, búsqueda por nombre/alias, consulta sin salir del editor y creación de fichas privadas desde la mención.
- El lector abre únicamente las fichas explícitamente públicas incluidas en la edición enviada. Fichas privadas y eliminadas no aportan relaciones o etiquetas a la publicación.
- Búsqueda global por título/cuerpo, categoría, proyecto, estado y fecha, con contexto, resaltado, historial y teclado. Las consultas conservan las políticas de acceso del servidor.
- Bloqueos de publicación por texto vacío, títulos ausentes, vínculos privados/no disponibles y marcas incompatibles; recomendaciones estructurales y comparación visible.

- Avisos de revisiones extensas basados en palabras añadidas/retiradas; una corrección pequeña en un párrafo largo no se considera una reescritura completa.
- Recuperación desde `proyecto.json`: resumen previo, copia privada, mapeo de identificadores y vínculos, relaciones e historial. Operación transaccional e idempotente al reintentar desde la misma vista previa. Límite de 10 MB, 2.000 elementos actuales, 10.000 relaciones y 1.000 versiones. El JSON se encuentra dentro del paquete exportado; no se abre directamente el ZIP.

- Revisión guiada de wikilinks antiguos: conversión a referencias estables, selección explícita ante nombres ambiguos, conservación de etiquetas personalizadas y exclusión de código/texto casual. Renombrar una ficha conserva su nombre anterior como alias; la revisión permite actualizar las menciones del capítulo abierto sin cambiar sus identificadores.

Límite: la revisión se aplica al capítulo abierto; no reescribe automáticamente todos los capítulos del proyecto. Los avisos temporales se basan en fechas y relaciones explícitas; no interpretan automáticamente toda la prosa.

## Quinta entrega: comunidad

- Comentarios sobre fragmentos, conversaciones, anclajes con contexto, avisos de texto eliminado, resolución y sugerencias.
- Permisos de lectura/comentario/edición consultados al servidor. Aceptar una sugerencia conserva una versión previa y guarda antes de resolver el comentario; reintentar la resolución no vuelve a aplicar el reemplazo.
- Tarjetas comunes con lectura directa y guardado en colecciones.
- Descubrir elimina obras duplicadas, prioriza las disciplinas del perfil con criterio visible y señala obras posteriores a la visita anterior.
- Ranking conserva filtros y ofrece cuatro vistas de obras además del índice existente de artistas: popularidad acumulada, selección editorial con motivo, crecimiento de visitas entre dos periodos de siete días y actividad por fecha de publicación. Cada criterio se explica en pantalla; devuelve hasta 40 obras públicas por disciplina, con tarjetas compartidas y acceso directo a lectura/colecciones.
- La selección editorial se gestiona desde la obra por administradores, con motivo obligatorio. No depende del campo de destacados editable por el autor. Tendencia requiere al menos tres visitas recientes y crecimiento positivo; no expone visitantes ni huellas.
- Comentarios en tiempo real mediante las políticas de lectura existentes, agrupación de eventos y reconciliación cada minuto. Conserva el comentario que se está redactando; cancela suscripciones al cerrar u ocultar el módulo. Inicio mantiene las agrupaciones por proyecto y evita avisos repetitivos.

Pendiente de cerrar: verificación de entrega de eventos con varias cuentas/dispositivos conectados. Los contadores acumulados no se presentan como tendencia ni como una medida objetiva de calidad.

## Verificación y límites

Última suite completa: **274 pruebas aprobadas**; `flutter analyze --no-pub` sin incidencias; `flutter build web --release --no-pub` completado. Ranking revisado visualmente con contenido ficticio a 360 px y a 1.280 px, incluido el motivo editorial completo; prueba funcional móvil adicional con texto al 140 %. Las pruebas de navegación incluyen texto al 200 % y bloqueo de salida con cambios pendientes. Compilación web `20260923-editorial-v4`, todavía sin desplegar.

Las pruebas cubren guardados superpuestos, respuesta perdida en el primer guardado, varios borradores pendientes, desconexión/recuperación, formato y separadores tras reabrir, aislamiento de cuentas, permisos y sugerencias, publicación transaccional, privacidad de fichas, búsqueda por teclado, panel fijado y Escape, continuidad de lectura, marcadores, tamaño móvil y regresión visual.

Las migraciones `atelier_private_project_import` y `atelier_atomic_publication` están aplicadas en Supabase. Se comprobó que sus funciones conservan RLS, usan permisos del invocador y no admiten ejecución anónima. Los scripts `tool/test_project_import.cjs` y `tool/test_atomic_publication.cjs` ejecutan PostgreSQL en memoria mediante PGlite 0.5.8; comprueban reversión ante fallos, referencias, historial, idempotencia y aislamiento. No crean obras ni proyectos en la base real. Para reproducirlos, `CORVUS_PGLITE` debe apuntar al paquete instalado; ejecutarlos con Node desde la raíz del proyecto.

La vista local de `tool/editorial_preview.dart` utiliza exclusivamente contenido ficticio en memoria. No inicializa Supabase ni publica obras. La compilación de la aplicación, las políticas reales con cuentas de cada rol y la validación visual en producción deben verificarse antes del despliegue final.

Las migraciones `atelier_comment_realtime` y `public_work_rankings` también están aplicadas. Se verificaron la publicación de eventos de comentarios y las cuatro consultas de Ranking. `tool/test_work_rankings.cjs` comprueba periodos, mínimos, crecimiento, permisos editoriales, filtros y exclusión de obras privadas/borradores con PostgreSQL en memoria. La función de Ranking usa intencionalmente `SECURITY DEFINER` para devolver solo agregados de visitas de obras públicas: no concede acceso a los registros de visitantes. El asesor señala su ejecución pública como una excepción deliberada; no se ampliaron permisos sobre `work_views`. Véase la [comprobación de funciones con privilegios del definidor](https://supabase.com/docs/guides/database/database-linter).

Fuente literaria: [Lora, distribución oficial de Google Fonts](https://github.com/google/fonts/tree/main/ofl/lora). Archivos incluidos en `assets/fonts/lora`, con licencia OFL adjunta; no depende de una descarga al leer.
