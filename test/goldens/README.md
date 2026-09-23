# Referencias visuales

`literary_reader_palettes.png` se generó con **Flutter 3.44.0 en Windows**,
fuente Lora incluida en el repositorio, resolución 1080 × 1000, densidad 1 y
texto al 120 %. La comparación es exacta: no admite un porcentaje de error.

Flutter advierte que [las fuentes pueden rasterizarse de manera diferente entre
sistemas operativos](https://api.flutter.dev/flutter/flutter_test/matchesGoldenFile.html#including-fonts),
incluso con los mismos archivos tipográficos. La referencia de Windows no es una
referencia de Linux. Cambiar la versión de Flutter también requiere revisión.

## Ejecución

- Windows, comparación visual: `flutter test --tags golden`.
- Cualquier sistema, pruebas funcionales: `flutter test --exclude-tags golden`.
- Windows, suite completa: `flutter test`.

CI ejecuta la comparación en `windows-2022` con Flutter 3.44.0. El trabajo de
Linux conserva el análisis, las pruebas funcionales (incluidos límites de la
maquetación y contraste del lector) y la compilación web. Depende del trabajo
visual: una diferencia de píxeles impide el despliegue. Si falla, las imágenes
de `test/failures` se conservan como artefacto durante siete días.

## Actualizaciones deliberadas

En Windows con la misma versión de Flutter:

```sh
flutter test --update-goldens --tags golden
flutter test --tags golden
```

Revisar visualmente el PNG antes de incorporar una actualización. CI nunca
regenera ni acepta imágenes automáticamente. Para adoptar Linux como entorno
de referencia, generar y revisar allí una referencia nueva y cambiar el trabajo
visual en la misma revisión; no reutilizar el PNG de Windows.
