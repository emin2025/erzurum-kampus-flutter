import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Java'daki OCR metodlarının (runOcrOnBitmap, extractNameFromOcr,
/// capitalizeName, isNoisyWord) tam Dart karşılığı.
/// Kayıp eşya görseli üzerinden isim tespiti yapar.
class OcrService {
  OcrService._();
  static final OcrService instance = OcrService._();

  final TextRecognizer _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  bool _alreadyRan = false;

  void resetOcrFlag() => _alreadyRan = false;

  /// Verilen dosyadan OCR çalıştırır.
  /// Tespit edilen ismi veya null döner.
  Future<String?> detectOwnerName(File imageFile) async {
    if (_alreadyRan) return null;

    final inputImage = InputImage.fromFile(imageFile);
    final RecognizedText result = await _recognizer.processImage(inputImage);

    _alreadyRan = true;
    return _extractNameFromText(result.text);
  }

  /// Java'daki extractNameFromOcr() — iki aşamalı strateji:
  ///  1. Açık etiket (Ad Soyad:, İsim:, Name:) → yanındaki değer
  ///  2. Satır başında büyük harfle başlayan tam 2 kelime
  String? _extractNameFromText(String rawText) {
    if (rawText.isEmpty) return null;

    // Strateji 1: Etiket + değer
    final labelPattern = RegExp(
      r'(?i)(ad[\s]*soyad|isim|name|ad[iı]|sahip)[\s:]+([a-zA-ZçÇğĞıİöÖşŞüÜ]+\s+[a-zA-ZçÇğĞıİöÖşŞüÜ]+)',
      caseSensitive: false,
    );
    final labelMatch = labelPattern.firstMatch(rawText);
    if (labelMatch != null && labelMatch.group(2) != null) {
      return _capitalizeName(labelMatch.group(2)!);
    }

    // Strateji 2: Satır analizi
    for (final line in rawText.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final words = trimmed.split(RegExp(r'\s+'));
      if (words.length == 2) {
        final w1 = words[0];
        final w2 = words[1];
        if (w1.length >= 2 &&
            w2.length >= 2 &&
            w1.length <= 20 &&
            w2.length <= 20 &&
            w1[0] == w1[0].toUpperCase() &&
            w2[0] == w2[0].toUpperCase()) {
          final candidate = '$w1 $w2';
          if (!_isNoisyWord(candidate)) {
            return candidate;
          }
        }
      }
    }

    return null;
  }

  /// Java'daki isNoisyWord() — yanlış pozitif filtreleme
  bool _isNoisyWord(String word) {
    const noisy = [
      'Erzurum', 'Atatürk', 'Teknik', 'Üniversite', 'Türkiye',
      'Cumhuriyet', 'Öğrenci', 'Kimlik', 'Kartı', 'Geçerli',
    ];
    final lower = word.toLowerCase();
    return noisy.any((n) => lower.contains(n.toLowerCase()));
  }

  /// Java'daki capitalizeName() — "nihat doğan" → "Nihat Doğan"
  String _capitalizeName(String name) {
    return name.trim().split(RegExp(r'\s+')).map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }

  void dispose() => _recognizer.close();
}