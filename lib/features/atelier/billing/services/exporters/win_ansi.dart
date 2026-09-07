/// Puente entre el texto de un manuscrito y lo que el PDF sabe escribir.
///
/// Las fuentes estándar de un PDF declaran `WinAnsiEncoding` (CP-1252), pero
/// `dart_pdf` codifica las cadenas con Latin-1. Las dos tablas coinciden salvo
/// en el rango 0x80–0x9F, que es justo donde CP-1252 guarda los caracteres
/// tipográficos: la raya, las comillas curvas y los puntos suspensivos.
///
/// El resultado de esa discrepancia no era una fea aproximación, era una
/// excepción: `latin1.encode` **lanza** ante cualquier carácter fuera de su
/// tabla. Y la raya —U+2014— es el marcador de diálogo del español:
///
///     —¿Quién anda ahí? —preguntó Vela.
///
/// Es decir, la exportación a PDF habría reventado en la mayoría de novelas en
/// español escritas en Corvus. Aquí se traduce cada carácter a su byte de
/// CP-1252, de modo que el visor —al que ya se le dijo que lea WinAnsi— pinta
/// la raya de verdad. Sin fuentes incrustadas y sin perder tipografía.
library;

/// Los caracteres que CP-1252 tiene y Latin-1 no, con su byte de destino.
const _cp1252 = <int, int>{
  0x20AC: 0x80, // €
  0x201A: 0x82, // ‚
  0x0192: 0x83, // ƒ
  0x201E: 0x84, // „
  0x2026: 0x85, // …
  0x2020: 0x86, // †
  0x2021: 0x87, // ‡
  0x02C6: 0x88, // ˆ
  0x2030: 0x89, // ‰
  0x0160: 0x8A, // Š
  0x2039: 0x8B, // ‹
  0x0152: 0x8C, // Œ
  0x017D: 0x8E, // Ž
  0x2018: 0x91, // ‘
  0x2019: 0x92, // ’
  0x201C: 0x93, // “
  0x201D: 0x94, // ”
  0x2022: 0x95, // •
  0x2013: 0x96, // – raya corta
  0x2014: 0x97, // — raya de diálogo
  0x02DC: 0x98, // ˜
  0x2122: 0x99, // ™
  0x0161: 0x9A, // š
  0x203A: 0x9B, // ›
  0x0153: 0x9C, // œ
  0x017E: 0x9E, // ž
  0x0178: 0x9F, // Ÿ
};

/// Aproximaciones para lo que no cabe en CP-1252. Antes que perder el texto,
/// se sustituye por su equivalente más cercano; solo lo verdaderamente ajeno
/// —un emoji, un ideograma— cae al signo de interrogación.
const _aproximaciones = <int, String>{
  0x2010: '-', // ‐
  0x2011: '-', // ‑
  0x2015: '', // ― barra horizontal, se lee como raya
  0x2032: "'", // ′
  0x2033: '"', // ″
  0x00A0: ' ', // espacio duro
  0x202F: ' ', // espacio fino
  0x2009: ' ', // espacio delgado
  0x200B: '', // espacio de ancho cero
  0x2212: '-', // − menos matemático
};

/// Convierte el texto a algo que el PDF pueda escribir sin lanzar.
String toWinAnsi(String value) {
  final salida = StringBuffer();

  for (final rune in value.runes) {
    final mapeado = _cp1252[rune];
    if (mapeado != null) {
      salida.writeCharCode(mapeado);
      continue;
    }

    final aproximado = _aproximaciones[rune];
    if (aproximado != null) {
      salida.write(aproximado);
      continue;
    }

    // Latin-1 directo: todo el español —acentos, eñes, signos de apertura,
    // comillas angulares— vive aquí.
    if (rune <= 0xFF) {
      salida.writeCharCode(rune);
      continue;
    }

    // Lo que no tiene sitio. Se marca en vez de romper el archivo: perder un
    // carácter exótico es preferible a perder el manuscrito entero.
    salida.write('?');
  }

  return salida.toString();
}
