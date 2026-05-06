import 'package:intl/intl.dart';

class DateUtils {
  static final DateFormat _apiFormat = DateFormat('dd-MM-yyyy');
  static final DateFormat _displayFormat = DateFormat('MMMM d, yyyy');
  static final DateFormat _shortFormat = DateFormat('MMM d, yyyy');

  static String toApiFormat(DateTime date) => _apiFormat.format(date);

  static DateTime? fromApiFormat(String date) {
    try {
      return _apiFormat.parse(date);
    } catch (_) {
      return null;
    }
  }

  static String toDisplayFormat(String apiDate) {
    final date = fromApiFormat(apiDate);
    if (date == null) return apiDate;
    return _displayFormat.format(date);
  }

  static String toShortFormat(String apiDate) {
    final date = fromApiFormat(apiDate);
    if (date == null) return apiDate;
    return _shortFormat.format(date);
  }

  static String todayApiFormat() => toApiFormat(DateTime.now());
}
