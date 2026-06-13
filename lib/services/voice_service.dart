import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  static final FlutterTts _tts      = FlutterTts();
  static bool   _initialized        = false;
  static String _language           = 'en-IN';

  // ─── Init ──────────────────────────────────────────────────────────────────

  static Future<void> init({String language = 'en-IN'}) async {
    _language = language;
    await _tts.setLanguage(language);
    await _tts.setSpeechRate(0.45);   // slower for elderly
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _initialized = true;
  }

  // ─── Change language at runtime ───────────────────────────────────────────

  static Future<void> setLanguage(String lang) async {
    _language = lang;
    await _tts.setLanguage(lang);
  }

  // ─── Speak medicine reminder ───────────────────────────────────────────────

  static Future<void> speakReminder(String medicineName, String dose) async {
    if (!_initialized) await init(language: _language);

    final String text = _language.startsWith('ta')
        ? 'ராஜம்மா, இப்போது $medicineName மருந்து எடுக்கும் நேரம். அளவு: $dose.'
        : 'Rajamma, it is time to take $medicineName. Dose: $dose. '
          'Please take your medicine now.';

    await _tts.speak(text);
  }

  // ─── Speak confirmation after marking taken ───────────────────────────────

  static Future<void> speakConfirmation(String medicineName) async {
    if (!_initialized) await init(language: _language);

    final String text = _language.startsWith('ta')
        ? '$medicineName மருந்து எடுத்துவிட்டீர்கள். நல்லது!'
        : 'Good. $medicineName has been marked as taken. Well done!';

    await _tts.speak(text);
  }

  // ─── Speak any custom text ────────────────────────────────────────────────

  static Future<void> speak(String text) async {
    if (!_initialized) await init(language: _language);
    await _tts.speak(text);
  }

  // ─── Stop ─────────────────────────────────────────────────────────────────

  static Future<void> stop() async {
    await _tts.stop();
  }
}