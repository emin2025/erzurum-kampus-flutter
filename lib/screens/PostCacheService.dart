// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class UserInfo {
  final String ad;
  final String soyad;
  const UserInfo({required this.ad, required this.soyad});
  String get tamAd => '$ad $soyad';
  String get adKucuk => ad.toLowerCase();
}

class PostCacheService {
  PostCacheService._();
  static final PostCacheService instance = PostCacheService._();

  // ── Cache Map'leri ────────────────────────────────────────────────────────
  final Map<String, String?> _profilUrlCache   = {};
  final Map<String, UserInfo?> _kullaniciAdCache = {};
  final Map<String, bool> _favoriCache         = {};
  final Map<String, bool> _videoVarCache       = {};

  void clearAll() {
    _profilUrlCache.clear();
    _kullaniciAdCache.clear();
    _favoriCache.clear();
    _videoVarCache.clear();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PROFİL FOTOĞRAFI
  // ══════════════════════════════════════════════════════════════════════════
  Future<String?> getProfilUrl(String userId) async {
    if (userId.isEmpty) return null;
    if (_profilUrlCache.containsKey(userId)) return _profilUrlCache[userId];

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profil_images/${userId}_.jpg');
      
      final uri = await ref.getDownloadURL(); // URL büyük harfle düzeltildi
      _profilUrlCache[userId] = uri.toString();
      return uri.toString();
    } catch (e) {
      _profilUrlCache[userId] = null;
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  KULLANICI ADI
  // ══════════════════════════════════════════════════════════════════════════
  Future<UserInfo?> getKullaniciAdi(String userId) async {
    if (userId.isEmpty) return null;
    if (_kullaniciAdCache.containsKey(userId)) return _kullaniciAdCache[userId];

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
          
      if (doc.exists) {
        // Flutter'a uygun Map yapısı düzeltildi
        final data = doc.data() as Map<String, dynamic>?;
        final ad    = _capitalize(data?['ad'] as String? ?? '');
        final soyad = _capitalize(data?['soyad'] as String? ?? '');
        
        final info = UserInfo(ad: ad, soyad: soyad);
        _kullaniciAdCache[userId] = info;
        return info;
      }
      _kullaniciAdCache[userId] = null;
      return null;
    } catch (e) {
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FAVORİ DURUMU
  // ══════════════════════════════════════════════════════════════════════════
  Future<bool> isFavori({
    required String currentUserId,
    required String postId,
  }) async {
    if (currentUserId.isEmpty || postId.isEmpty) return false;
    final key = '${currentUserId}_$postId';
    if (_favoriCache.containsKey(key)) return _favoriCache[key]!;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('favorites')
          .doc(postId)
          .get();
      _favoriCache[key] = doc.exists;
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  Future<bool> toggleFavori({
    required String currentUserId,
    required String postId,
  }) async {
    final key = '${currentUserId}_$postId';
    final suankiDurum = _favoriCache[key] ?? false;
    final yeniDurum = !suankiDurum;

    _favoriCache[key] = yeniDurum;

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('favorites')
        .doc(postId);
    try {
      if (yeniDurum) {
        await ref.set({
          'postId': postId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } else {
        await ref.delete();
      }
    } catch (e) {
      _favoriCache[key] = suankiDurum;
      rethrow;
    }

    return yeniDurum;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  VİDEO VAR MI
  // ══════════════════════════════════════════════════════════════════════════
  Future<bool> videoVarMi({
    required String postId,
    List<String>? videoResimFromPost,
  }) async {
    if (videoResimFromPost != null && videoResimFromPost.isNotEmpty) {
      _videoVarCache[postId] = true;
      return true;
    }

    if (postId.isEmpty) return false;
    if (_videoVarCache.containsKey(postId)) return _videoVarCache[postId]!;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('Posts')
          .doc(postId)
          .get();
      final videolar = doc.data()?['videolar'] as List?;
      final varMi = videolar != null && videolar.isNotEmpty;
      _videoVarCache[postId] = varMi;
      return varMi;
    } catch (e) {
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  VİDEO URL'LERİ
  // ══════════════════════════════════════════════════════════════════════════
  Future<List<String>> getVideoUrls(String postId) async {
    if (postId.isEmpty) return [];

    try {
      final doc = await FirebaseFirestore.instance
          .collection('Posts')
          .doc(postId)
          .get();
      if (!doc.exists) return [];
      final videolar = doc.data()?['videolar'] as List?;
      if (videolar == null || videolar.isEmpty) return [];
      return videolar.map((e) => e.toString()).toList();
    } catch (e) {
      print('[PostCacheService] getVideoUrls HATA: $e');
      return [];
    }
  }

  // ── Yardımcı ─────────────────────────────────────────────────────────────
  static String _capitalize(String str) {
    if (str.isEmpty) return str;
    return str[0].toUpperCase() + str.substring(1).toLowerCase();
  }
}