import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> createTestSharedPreferences([
  Map<String, Object> initialValues = const {},
]) async {
  SharedPreferences.setMockInitialValues(initialValues);
  return SharedPreferences.getInstance();
}
