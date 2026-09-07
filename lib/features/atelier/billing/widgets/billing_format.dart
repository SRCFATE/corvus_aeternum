/// Formato de fechas e importes para el módulo comercial.
///
/// No se usa `DateFormat(..., 'es')`: exigiría `initializeDateFormatting`, que
/// esta app nunca ha llamado, y una excepción de datos de locale a mitad del
/// centro de facturación sería un error absurdo de introducir. Doce nombres de
/// mes son más baratos que una dependencia de inicialización.
library;

const _meses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/// «4 de septiembre de 2026».
String formatBillingDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day} de ${_meses[local.month - 1]} de ${local.year}';
}

/// «4 sep 2026», para las filas del historial de pagos.
String formatShortDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day} ${_meses[local.month - 1].substring(0, 3)} ${local.year}';
}

/// Importe con separador de miles y la moneda detrás, como se lee en México:
/// «$99 MXN», «$1,290.50 MXN».
String formatMoney(double amount, String currency) {
  final entero = amount.truncate();
  final centavos = ((amount - entero) * 100).round();

  final digitos = entero.abs().toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digitos.length; i++) {
    if (i > 0 && (digitos.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digitos[i]);
  }

  final signo = amount < 0 ? '-' : '';
  final decimales = centavos == 0
      ? ''
      : '.${centavos.toString().padLeft(2, '0')}';

  return '$signo\$$buffer$decimales $currency';
}

/// Cómo se dice el intervalo de cobro en una frase.
String intervalLabel(String interval) => switch (interval) {
      'year' => 'al año',
      'month' => 'al mes',
      _ => 'pago único',
    };

String intervalShort(String interval) => switch (interval) {
      'year' => '/año',
      'month' => '/mes',
      _ => '',
    };
