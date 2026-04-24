// ignore_for_file: avoid_print
import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  // ── Zorunlu Alanlar ───────────────────────────────────────────────────────
  final String? aciklama;
  final String? fiyat;
  final String? kategori;
  final String? konum;
  final List<String>? gosterilecekResimler;
  final String? tarihStr;
  final String? userId;
  final String? documentId;
  final List<String>? videoResim;
  final String? paylasimTuru;
  final String? tarih;

  // ── Opsiyonel Alanlar ─────────────────────────────────────────────────────
  String? altKategori;
  String? esyaDurumu;
  String? hedefKitle;
  String? universite;
  List<String>? etiketler;
  DateTime? timestamp;
  String? kayipEsyaSahibi;
  List<String>? videolar;

  Post({
    required this.aciklama,
    required this.fiyat,
    required this.kategori,
    required this.konum,
    required this.gosterilecekResimler,
    required this.tarihStr,
    required this.userId,
    required this.documentId,
    required this.videoResim,
    required this.paylasimTuru,
    required this.tarih,
  });

  // ══════════════════════════════════════════════════════════════════════════
  //  Firestore Map → Post
  //
  //  ÖNEMLI DEĞİŞİKLİKLER:
  //  • paylasimTuru boş/null olsa bile artık null dönmüyor.
  //    'paylasimTuru' yoksa fallback olarak 'paylasimturu', o da yoksa
  //    'İkinci El Eşya' varsayılanı kullanılır.
  //  • resimler listesi boş olsa bile Post nesnesi oluşturulur.
  //  • Hiçbir alan eksikliği fromMap'i patlatmaz.
  // ══════════════════════════════════════════════════════════════════════════

  static Post? fromMap(Map<String, dynamic> data, String snapId) {
    try {
      print('🔍 LOG 25 [PostModel]: fromMap başladı. ID: $snapId');

      // documentId: önce veri içindeki alan, yoksa snapshot ID
      final String docId = _str(data, 'documentId') ?? snapId;

      // paylasimTuru: birden fazla olası alan adını dene, hepsi boşsa varsayılan
      final String pTuru = _str(data, 'paylasimTuru') ??
          _str(data, 'paylasimturu') ??
          'İkinci El Eşya';

      final String? kategori = _str(data, 'kategori') ?? _str(data, 'tur');

      // Resimler — boş liste olması sorun değil, null dönmüyoruz
      final List<String> resimler  = _strList(data['resimler'])   ?? [];
      final List<String> vResimler = _strList(data['video_resim']) ?? [];

      // Gösterilecek resim listesi: önce gerçek resimler, yoksa video thumbnail
      final List<String> gosterilecek = resimler.isNotEmpty
          ? resimler
          : (vResimler.isNotEmpty ? vResimler : []);

      // Tarih parse
      DateTime? tarihDt;
      String    tarihMetni  = '';
      String?   rawTarihStr;

      final dynamic tarihObj = data['tarih'];
      if (tarihObj is Timestamp) {
        tarihDt     = tarihObj.toDate();
        rawTarihStr = _formatTr(tarihDt);
        tarihMetni  = rawTarihStr;
      } else if (tarihObj is String && tarihObj.isNotEmpty) {
        rawTarihStr = tarihObj;
        tarihMetni  = tarihObj;
      } else if (tarihObj is DateTime) {
        tarihDt     = tarihObj;
        rawTarihStr = _formatTr(tarihDt);
        tarihMetni  = rawTarihStr;
      }

      final post = Post(
        aciklama:             _str(data, 'aciklama'),
        fiyat:                _str(data, 'fiyat'),
        kategori:             kategori,
        konum:                _str(data, 'konum'),
        gosterilecekResimler: gosterilecek,
        tarihStr:             tarihMetni.isNotEmpty ? tarihMetni : null,
        userId:               _str(data, 'userId'),
        documentId:           docId,
        videoResim:           vResimler,
        paylasimTuru:         pTuru,
        tarih:                rawTarihStr,
      );

      post.altKategori     = _str(data, 'altKategori');
      post.esyaDurumu      = _str(data, 'esyaDurumu');
      post.hedefKitle      = _str(data, 'hedefKitle');
      post.universite      = _str(data, 'universite');
      post.etiketler       = _strList(data['etiketler']);
      post.timestamp       = tarihDt;
      post.kayipEsyaSahibi = _str(data, 'kayipEsyaSahibi');
      post.videolar        = _strList(data['videolar']) ?? [];

      print('🔍 LOG 27 [PostModel]: fromMap BAŞARILI. '
          'paylasimTuru=$pTuru, resim sayısı=${gosterilecek.length}');
      return post;
    } catch (e, st) {
      print('🚨 LOG 28 [PostModel]: Kritik fromMap hatası: $e\n$st');
      return null;
    }
  }

  // ── Yardımcılar ───────────────────────────────────────────────────────────

  static String? _str(Map<String, dynamic> data, String key) {
    final v = data[key];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static List<String>? _strList(dynamic obj) {
    if (obj == null) return null;
    try {
      return (obj as List).map((e) => e.toString()).toList();
    } catch (_) {
      return null;
    }
  }

  static const List<String> _aylar = [
    'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
  ];

  static String _formatTr(DateTime dt) {
    final gun    = dt.day.toString().padLeft(2, '0');
    final ay     = _aylar[dt.month - 1];
    final yil    = dt.year;
    final saat   = dt.hour.toString().padLeft(2, '0');
    final dakika = dt.minute.toString().padLeft(2, '0');
    return '$gun $ay $yil - $saat:$dakika';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Post &&
          runtimeType == other.runtimeType &&
          documentId == other.documentId;

  @override
  int get hashCode => documentId.hashCode;
}