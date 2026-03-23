import 'package:intl/intl.dart';

class DateFormatters {
  static final DateFormat _fullDate = DateFormat('dd/MM/yyyy');
  static final DateFormat _friendlyDate = DateFormat("dd 'de' MMM", 'pt_BR');
  static final DateFormat _friendlyDateWithYear = DateFormat(
    "dd 'de' MMM 'de' yyyy",
    'pt_BR',
  );

  static String fullDate(DateTime date) => _fullDate.format(date);

  static String friendlyDate(DateTime date) => _friendlyDate.format(date);

  static String friendlyDateWithYear(DateTime date) =>
      _friendlyDateWithYear.format(date);
}
