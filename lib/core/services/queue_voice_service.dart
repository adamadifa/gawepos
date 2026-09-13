import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../di/injection.dart';

class QueueVoiceService {
  static final QueueVoiceService _instance = QueueVoiceService._internal();
  factory QueueVoiceService() => _instance;
  QueueVoiceService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  ValueNotifier<String?> currentlySpeakingQueue = ValueNotifier<String?>(null);

  Future<void> _initTts() async {
    if (_isInitialized) return;
    try {
      // Prioritaskan engine Google Text-to-Speech jika tersedia di perangkat
      final engines = await _flutterTts.getEngines;
      if (engines is List && engines.contains("com.google.android.tts")) {
        await _flutterTts.setEngine("com.google.android.tts");
      }

      await _flutterTts.setLanguage("id-ID");

      // Cek dan set suara Indonesia spesifik jika ada di sistem
      final voices = await _flutterTts.getVoices;
      if (voices is List) {
        for (var voice in voices) {
          if (voice is Map) {
            final locale = voice['locale']?.toString() ?? '';
            if (locale.toLowerCase().startsWith('id')) {
              await _flutterTts.setVoice({"name": voice['name'], "locale": voice['locale']});
              break;
            }
          }
        }
      }

      await _flutterTts.setSpeechRate(0.5); // Kecepatan bicara natural
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setStartHandler(() {
        _isPlaying = true;
      });

      _flutterTts.setCompletionHandler(() {
        _isPlaying = false;
        currentlySpeakingQueue.value = null;
      });

      _flutterTts.setErrorHandler((msg) {
        _isPlaying = false;
        currentlySpeakingQueue.value = null;
        debugPrint("TTS Error: $msg");
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint("Gagal inisialisasi TTS: $e");
    }
  }

  /// Mendapatkan nomor antrean harian berikutnya (otomatis reset ke 1 setiap tanggal baru)
  static Future<int> getNextDailyQueueNumber() async {
    try {
      final db = getIt<AppDatabase>();
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final key = 'daily_queue_counter_$todayStr';

      final setting = await (db.select(db.settings)..where((tbl) => tbl.key.equals(key))).getSingleOrNull();
      int nextNumber = 1;

      if (setting != null && setting.value != null) {
        final currentVal = int.tryParse(setting.value!) ?? 0;
        nextNumber = currentVal + 1;
        await (db.update(db.settings)..where((tbl) => tbl.key.equals(key)))
            .write(SettingsCompanion(value: Value(nextNumber.toString())));
      } else {
        await db.into(db.settings).insert(
          SettingsCompanion.insert(key: key, value: Value(nextNumber.toString())),
        );
      }
      return nextNumber;
    } catch (e) {
      debugPrint("Gagal generate daily queue number: $e");
      return DateTime.now().minute + 1;
    }
  }

  /// Memanggil nomor antrean menggunakan suara AI Google Indonesia
  Future<void> speakQueueCall({
    required String queueNumber,
    String? customerName,
    String? tableName,
    String? customMessage,
  }) async {
    await _initTts();

    try {
      await stop();

      currentlySpeakingQueue.value = queueNumber;

      String speechText = '';

      if (customMessage != null && customMessage.isNotEmpty) {
        speechText = customMessage;
      } else {
        // Konversi format antrean misal "05" atau "5" agar dibaca jelas
        final formattedQueue = _formatQueueForSpeech(queueNumber);
        
        if (tableName != null && tableName.isNotEmpty) {
          if (customerName != null && customerName.isNotEmpty) {
            speechText = "Panggilan untuk $tableName, atas nama $customerName. Pesanan Anda sudah siap. Silakan ambil di konter.";
          } else {
            speechText = "Panggilan untuk $tableName. Pesanan Anda sudah siap. Silakan ambil di konter.";
          }
        } else if (customerName != null && customerName.isNotEmpty) {
          speechText = "Nomor antrean, $formattedQueue, atas nama $customerName. Pesanan Anda sudah siap. Silakan ambil di konter.";
        } else {
          speechText = "Nomor antrean, $formattedQueue. Pesanan Anda sudah siap. Silakan ambil di konter.";
        }
      }

      await _flutterTts.speak(speechText);
    } catch (e) {
      debugPrint("Gagal memanggil antrean: $e");
      currentlySpeakingQueue.value = null;
    }
  }

  /// Mengubah angka misal "05" -> "kosong lima", "12" -> "dua belas"
  String _formatQueueForSpeech(String q) {
    final clean = q.replaceAll(RegExp(r'[^0-9A-Za-z]'), '').trim();
    if (clean.startsWith('0') && clean.length > 1) {
      final rest = clean.substring(1);
      return "kosong $rest";
    }
    return clean;
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      _isPlaying = false;
      currentlySpeakingQueue.value = null;
    } catch (_) {}
  }
}
