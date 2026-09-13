import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:posmobile/core/database/app_database.dart';
import 'package:posmobile/core/di/injection.dart';
import 'package:posmobile/core/services/queue_voice_service.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    if (getIt.isRegistered<AppDatabase>()) {
      getIt.unregister<AppDatabase>();
    }
    getIt.registerSingleton<AppDatabase>(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('Pengujian Nomor Antrean Harian Otomatis', () {
    test('Nomor urut bertambah secara sekuensial (1, 2, 3...)', () async {
      final q1 = await QueueVoiceService.getNextDailyQueueNumber();
      final q2 = await QueueVoiceService.getNextDailyQueueNumber();
      final q3 = await QueueVoiceService.getNextDailyQueueNumber();

      expect(q1, equals(1));
      expect(q2, equals(2));
      expect(q3, equals(3));
    });
  });
}
