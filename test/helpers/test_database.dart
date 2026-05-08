import 'package:diary_client/core/storage/app_database.dart';
import 'package:drift/native.dart';

AppDatabase createTestDatabase() =>
    AppDatabase.forTesting(NativeDatabase.memory());
