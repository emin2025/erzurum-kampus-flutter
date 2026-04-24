import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

/// Firebase Storage yükleme + Firestore kaydetme servisi.
class PostUploadService {
  PostUploadService._();
  static final PostUploadService instance = PostUploadService._();

  final _db      = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _auth    = FirebaseAuth.instance;
  final _uuid    = const Uuid();

  String get _uid => _auth.currentUser!.uid;

  // ══════════════════════════════════════════════════════════════════════════
  //  YENİ İLAN YAYINLA
  //  Döndürür: oluşturulan Firestore document ID (hata olursa exception fırlatır)
  // ══════════════════════════════════════════════════════════════════════════

  Future<String> publishPost({
    required String paylasimTuru,
    required String konum,
    required String fiyat,
    required String aciklama,
    required String kategori,
    required String altKategori,
    required String universite,
    required String esyaDurumu,
    required String hedefKitle,
    required List<String> etiketler,
    required String kayipEsyaSahibi,
    required List<File> imageFiles,
    required List<File> videoFiles,
    required List<File> thumbnailFiles,
    required Function(double) onProgress,
  }) async {
    print('🔍 LOG 1 [UploadService]: Yükleme başlatıldı. '
        'Resim: ${imageFiles.length}, Video: ${videoFiles.length}');

    // Her ilan için benzersiz bir klasör oluşturuyoruz.
    // Böylece eş zamanlı yüklemelerde dosyalar birbirinin üzerine yazmaz.
    final folder = '${_uid}_${_uuid.v4()}';

    final int totalFiles =
        imageFiles.length + videoFiles.length + thumbnailFiles.length;
    int uploadedFiles = 0;

    void _tick() {
      uploadedFiles++;
      onProgress(uploadedFiles / (totalFiles == 0 ? 1 : totalFiles));
    }

    // ── 1. FOTOĞRAFLARI YÜKLE ─────────────────────────────────────────────
    final List<String> yuklenenResimler = [];
    for (int i = 0; i < imageFiles.length; i++) {
      final ref = _storage.ref('post_images/$folder/${_uuid.v4()}_$i.jpg');
      print('🔍 LOG 2 [UploadService]: Resim yükleniyor → ${ref.fullPath}');
      final task = ref.putFile(
        imageFiles[i],
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final snap = await task;
      final url  = await snap.ref.getDownloadURL();
      yuklenenResimler.add(url);
      print('🔍 LOG 3 [UploadService]: Resim yüklendi → $url');
      _tick();
    }

    // ── 2. VİDEOLARI YÜKLE ───────────────────────────────────────────────
    final List<String> yuklenenVideolar = [];
    for (int i = 0; i < videoFiles.length; i++) {
      final ref = _storage.ref('post_videos/$folder/${_uuid.v4()}_$i.mp4');
      print('🔍 LOG 4 [UploadService]: Video yükleniyor → ${ref.fullPath}');
      final task = ref.putFile(
        videoFiles[i],
        SettableMetadata(contentType: 'video/mp4'),
      );
      final snap = await task;
      final url  = await snap.ref.getDownloadURL();
      yuklenenVideolar.add(url);
      _tick();
    }

    // ── 3. THUMBNAIL'LARI YÜKLE ──────────────────────────────────────────
    final List<String> yuklenenThumbnails = [];
    for (int i = 0; i < thumbnailFiles.length; i++) {
      final ref = _storage.ref('post_thumbnails/$folder/${_uuid.v4()}_$i.jpg');
      print('🔍 LOG 5 [UploadService]: Thumbnail yükleniyor → ${ref.fullPath}');
      final task = ref.putFile(
        thumbnailFiles[i],
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final snap = await task;
      final url  = await snap.ref.getDownloadURL();
      yuklenenThumbnails.add(url);
      _tick();
    }

    print('🔍 LOG 6 [UploadService]: Tüm medyalar yüklendi. '
        'Resim URL sayısı: ${yuklenenResimler.length}. Firestore\'a yazılıyor...');

    // ── 4. FIRESTORE'A KAYDET ─────────────────────────────────────────────
    // Önce ref alıyoruz ki ID'yi önceden bilip hem belgeye hem data'ya yazabilelim.
    final docRef = _db.collection('Posts').doc();
    final docId  = docRef.id;

    await docRef.set({
      'documentId':      docId,
      'userId':          _uid,
      'tarih':           FieldValue.serverTimestamp(),
      'paylasimTuru':    paylasimTuru,
      'kategori':        kategori,
      'altKategori':     altKategori,
      'konum':           konum,
      'fiyat':           fiyat,
      'aciklama':        aciklama,
      'esyaDurumu':      esyaDurumu,
      'hedefKitle':      hedefKitle,
      'universite':      universite,
      'etiketler':       etiketler,
      'kayipEsyaSahibi': kayipEsyaSahibi,
      'resimler':        yuklenenResimler,   // ← Artık dolu geliyor
      'videolar':        yuklenenVideolar,
      'video_resim':     yuklenenThumbnails,
    });

    print('🔍 LOG 7 [UploadService]: Firestore\'a yazıldı. ID: $docId');
    return docId; // ← NewPostScreen bu ID'yi alıp bildirime iletecek
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  GÜNCELLE
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> updatePost({
    required String postId,
    required String konum,
    required String fiyat,
    required String aciklama,
    required String kategori,
    required String altKategori,
    required List<File> imageFiles,
    required List<File> videoFiles,
    required List<File> thumbnailFiles,
    void Function(double progress)? onProgress,
  }) async {
    // Eski medyaları sil
    final snap = await _db.collection('Posts').doc(postId).get();
    if (snap.exists) {
      _deleteOldMedia(snap, 'resimler');
      _deleteOldMedia(snap, 'videolar');
      _deleteOldMedia(snap, 'video_resim');
    }

    final folder = '${_uid}_${_uuid.v4()}';
    final imgs   = <String>[];
    final vids   = <String>[];
    final thumbs = <String>[];

    final int total = imageFiles.length + videoFiles.length + thumbnailFiles.length;
    int done = 0;
    void tick() { done++; onProgress?.call(done / (total == 0 ? 1 : total)); }

    for (final f in imageFiles) {
      final ref = _storage.ref('post_images/$folder/${_uuid.v4()}.jpg');
      await ref.putFile(f, SettableMetadata(contentType: 'image/jpeg'));
      imgs.add(await ref.getDownloadURL());
      tick();
    }
    for (final f in videoFiles) {
      final ref = _storage.ref('post_videos/$folder/${_uuid.v4()}.mp4');
      await ref.putFile(f, SettableMetadata(contentType: 'video/mp4'));
      vids.add(await ref.getDownloadURL());
      tick();
    }
    for (final f in thumbnailFiles) {
      final ref = _storage.ref('post_thumbnails/$folder/${_uuid.v4()}_thumb.jpg');
      await ref.putFile(f, SettableMetadata(contentType: 'image/jpeg'));
      thumbs.add(await ref.getDownloadURL());
      tick();
    }

    await _db.collection('Posts').doc(postId).update({
      'konum':       konum,
      'fiyat':       fiyat,
      'aciklama':    aciklama,
      'kategori':    kategori,
      'altKategori': altKategori,
      'tarih':       FieldValue.serverTimestamp(),
      'resimler':    imgs,
      'videolar':    vids,
      'video_resim': thumbs,
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DÜZENLEME MODU — mevcut veriyi çek
  // ══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> fetchPostForEdit(String postId) async {
    final snap = await _db.collection('Posts').doc(postId).get();
    return snap.exists ? snap.data() : null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  YARDIMCI — Eski medya URL'lerini Storage'dan sil
  // ══════════════════════════════════════════════════════════════════════════

  void _deleteOldMedia(DocumentSnapshot snap, String field) {
    final urls = snap.get(field) as List?;
    if (urls == null) return;
    for (final url in urls) {
      try {
        _storage.refFromURL(url.toString()).delete();
      } catch (_) {}
    }
  }
}