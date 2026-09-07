/// Escapado de texto para los formatos que son XML por dentro: DOCX y EPUB.
///
/// No es una precaución teórica. Un manuscrito lleva `&`, comillas angulares y
/// signos de menor y mayor con toda naturalidad —`«dijo <en voz baja>»`— y sin
/// escapar, cualquiera de ellos rompe el archivo entero y Word se niega a
/// abrirlo.
library;

String escapeXml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

/// Un identificador seguro para nombres de archivo y anclas internas.
String slugify(String value, {String fallback = 'atelier'}) {
  const acentos = {
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n',
    'Á': 'a', 'É': 'e', 'Í': 'i', 'Ó': 'o', 'Ú': 'u', 'Ü': 'u', 'Ñ': 'n',
  };

  var texto = value.trim().toLowerCase();
  acentos.forEach((from, to) => texto = texto.replaceAll(from, to));

  texto = texto
      .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'-+'), '-');
  texto = texto.replaceAll(RegExp(r'^-+|-+$'), '');

  return texto.isEmpty ? fallback : texto;
}
