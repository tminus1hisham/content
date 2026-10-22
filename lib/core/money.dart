import 'package:intl/intl.dart';

/// Formats an amount in minor units (cents) as KES, e.g. `KSh 1,250` or `KSh 1,250.50`.
String formatKes(int amountCents) {
  final format = NumberFormat.currency(
    locale: 'en',
    symbol: 'KSh ',
    decimalDigits: amountCents % 100 == 0 ? 0 : 2,
  );
  return format.format(amountCents / 100);
}
