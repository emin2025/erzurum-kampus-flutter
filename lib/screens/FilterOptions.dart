// ─────────────────────────────────────────────────────────────────────────────
// FilterOptions.dart  —  Tek kaynak, hem NewPostScreen hem FilterBottomSheet
// tarafından kullanılır. Kategoriler, alt kategoriler ve filtre seçenekleri
// bu dosyada tanımlanır; başka hiçbir yerde tekrarlanmaz.
// ─────────────────────────────────────────────────────────────────────────────

// ══════════════════════════════════════════════════════════════════════════════
//  PAYLAŞIM TÜRÜ  (NewPostScreen._PostType ile eşleşir)
// ══════════════════════════════════════════════════════════════════════════════

/// Firestore'da saklanan paylasimTuru string değerleri
abstract final class PostType {
  static const String ikinciEl  = 'İkinci El Eşya';
  static const String kayipEsya = 'Kayıp Eşya';
  static const String bagis     = 'Bağış';
}

// ══════════════════════════════════════════════════════════════════════════════
//  ORTAK KATEGORİ + ALT KATEGORİ HARİTASI
//  NewPostScreen VE FilterBottomSheet bu sabit Map'i kullanır.
// ══════════════════════════════════════════════════════════════════════════════

abstract final class AppCategories {

  // ── İkinci El ─────────────────────────────────────────────────────────────
  static const Map<String, List<String>> ikinciEl = {
    'Elektronik':        ['Telefon', 'Tablet', 'Laptop', 'Kulaklık / Hoparlör', 'Şarj Aleti / Kablo', 'Kamera', 'Oyun Konsolu', 'Diğer'],
    'Kitap / Kırtasiye': ['Ders Kitabı', 'Kaynak Kitap', 'Roman', 'Defter / Not', 'Kalem / Malzeme', 'Diğer'],
    'Giyim / Aksesuar':  ['Kıyafet', 'Ayakkabı', 'Çanta', 'Saat', 'Gözlük', 'Takı / Mücevher', 'Diğer'],
    'Spor / Outdoor':    ['Spor Ekipmanı', 'Kamp Malzemesi', 'Bisiklet', 'Diğer'],
    'Ev / Yaşam':        ['Mobilya', 'Mutfak', 'Beyaz Eşya', 'Dekorasyon', 'Diğer'],
    'Araç / Gereç':      ['El Aletleri', 'Temizlik', 'Diğer'],
    'Diğer':             ['Belirtilmedi'],
  };

  // ── Kayıp Eşya ────────────────────────────────────────────────────────────
  static const Map<String, List<String>> kayipEsya = {
    'Kimlik / Kart':     ['Öğrenci Kartı', 'Banka Kartı', 'Kimlik / Pasaport', 'Ehliyet', 'Diğer'],
    'Elektronik':        ['Telefon', 'Tablet', 'Kulaklık / Hoparlör', 'Şarj Aleti / Kablo', 'Kamera', 'Diğer'],
    'Giyim / Aksesuar':  ['Kıyafet', 'Ayakkabı', 'Çanta', 'Cüzdan', 'Saat', 'Gözlük', 'Diğer'],
    'Kitap / Kırtasiye': ['Ders Kitabı', 'Defter / Not', 'Kalem / Malzeme', 'Diğer'],
    'Spor / Outdoor':    ['Spor Ekipmanı', 'Diğer'],
    'Anahtar / Kilit':   ['Ev Anahtarı', 'Araç Anahtarı', 'Bisiklet Kilidi', 'Diğer'],
    'Diğer':             ['Belirtilmedi'],
  };

  // ── Bağış ─────────────────────────────────────────────────────────────────
  static const Map<String, List<String>> bagis = {
    'Giyim / Aksesuar':  ['Kıyafet', 'Ayakkabı', 'Çanta', 'Diğer'],
    'Kitap / Kırtasiye': ['Ders Kitabı', 'Kaynak Kitap', 'Roman', 'Defter / Not', 'Diğer'],
    'Ev / Yaşam':        ['Mobilya', 'Mutfak', 'Dekorasyon', 'Diğer'],
    'Elektronik':        ['Telefon', 'Tablet', 'Laptop', 'Kulaklık / Hoparlör', 'Diğer'],
    'Spor / Outdoor':    ['Spor Ekipmanı', 'Diğer'],
    'Diğer':             ['Belirtilmedi'],
  };

  /// Verilen paylasimTuru için doğru kategori haritasını döner.
  static Map<String, List<String>> forPostType(String paylasimTuru) {
    switch (paylasimTuru) {
      case PostType.ikinciEl:  return ikinciEl;
      case PostType.kayipEsya: return kayipEsya;
      case PostType.bagis:     return bagis;
      default:                 return ikinciEl;
    }
  }

  /// NewPostScreen'de kullanılan _PostType enum'u için overload.
  static Map<String, List<String>> forEnum(PostTypeEnum t) {
    switch (t) {
      case PostTypeEnum.ikinciEl:  return ikinciEl;
      case PostTypeEnum.kayipEsya: return kayipEsya;
      case PostTypeEnum.bagis:     return bagis;
    }
  }
}

/// NewPostScreen._PostType yerine bu enum kullanılır — import kolaylığı için
enum PostTypeEnum { ikinciEl, kayipEsya, bagis }

// ══════════════════════════════════════════════════════════════════════════════
//  ORTAK FİLTRE SABİTLERİ
// ══════════════════════════════════════════════════════════════════════════════

abstract final class FilterData {
  static const List<String> universiteler = [
    'Erzurum Teknik Üniversitesi',
    'Atatürk Üniversitesi',
  ];

  static const List<String> hedefKitleler = [
    'Herkes',
    'Sadece Öğrenciler',
  ];

  /// Eşya durumu etiketleri — NewPostScreen._conditionLabels ile birebir eşleşir.
  /// Emoji'li versiyonu gösterim için, saf metin versiyonu Firestore için.
  static const List<String> esyaDurumlariRaw = [
    'Sıfır',
    'İyi',
    'Orta',
    'Hasarlı',
  ];

  static const Map<String, String> esyaDurumuEmoji = {
    'Sıfır':  '🌟 Sıfır',
    'İyi':    '✅ İyi',
    'Orta':   '🔶 Orta',
    'Hasarlı':'🔴 Hasarlı',
  };

  /// FilterBottomSheet'in paylasimTuru'na göre doğru kategori listesini döner.
  static Map<String, List<String>> kategorilerForTur(String paylasimTuru) =>
      AppCategories.forPostType(paylasimTuru);
}

// ══════════════════════════════════════════════════════════════════════════════
//  FilterOptions  —  Aktif filtre durumunu taşır
// ══════════════════════════════════════════════════════════════════════════════

class FilterOptions {
  String? universite;
  String? paylasimTuru;   // 'İkinci El Eşya' | 'Kayıp Eşya' | 'Bağış'
  String? kategori;
  String? altKategori;
  String? esyaDurumu;
  String? hedefKitle;
  String? etiket;

  FilterOptions({
    this.universite,
    this.paylasimTuru,
    this.kategori,
    this.altKategori,
    this.esyaDurumu,
    this.hedefKitle,
    this.etiket,
  });

  bool get isEmpty =>
      universite    == null &&
      paylasimTuru  == null &&
      kategori      == null &&
      altKategori   == null &&
      esyaDurumu    == null &&
      hedefKitle    == null &&
      (etiket == null || etiket!.isEmpty);

  int get activeCount {
    int c = 0;
    if (universite   != null) c++;
    if (paylasimTuru != null) c++;
    if (kategori     != null) c++;
    if (altKategori  != null) c++;
    if (esyaDurumu   != null) c++;
    if (hedefKitle   != null) c++;
    if (etiket != null && etiket!.isNotEmpty) c++;
    return c;
  }

  void reset() {
    universite   = null;
    paylasimTuru = null;
    kategori     = null;
    altKategori  = null;
    esyaDurumu   = null;
    hedefKitle   = null;
    etiket       = null;
  }

  FilterOptions clone() => FilterOptions(
    universite:   universite,
    paylasimTuru: paylasimTuru,
    kategori:     kategori,
    altKategori:  altKategori,
    esyaDurumu:   esyaDurumu,
    hedefKitle:   hedefKitle,
    etiket:       etiket,
  );

  FilterOptions copyWith({
    String? universite,
    String? paylasimTuru,
    String? kategori,
    String? altKategori,
    String? esyaDurumu,
    String? hedefKitle,
    String? etiket,
  }) => FilterOptions(
    universite:   universite   ?? this.universite,
    paylasimTuru: paylasimTuru ?? this.paylasimTuru,
    kategori:     kategori     ?? this.kategori,
    altKategori:  altKategori  ?? this.altKategori,
    esyaDurumu:   esyaDurumu   ?? this.esyaDurumu,
    hedefKitle:   hedefKitle   ?? this.hedefKitle,
    etiket:       etiket       ?? this.etiket,
  );
}