// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:erzurum_kampus/screens/PostDetailScreenState.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String _appId = '91f1b684-c228-4c9a-9fa6-14a1bf370680';

  /// main.dart'ta MaterialApp'e bu key verilmeli:
  /// navigatorKey: NotificationService.navigatorKey
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // ══════════════════════════════════════════════════════════════════════════
  //  BAŞLAT
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> initialize() async {
    OneSignal.initialize(_appId);
    await OneSignal.Notifications.requestPermission(true);

    // Bildirime tıklanınca tetiklenir (uygulama arka planda veya kapalıyken de)
    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      print('🔍 LOG 10 [NotifService]: Bildirime tıklandı! Ham veri: $data');

      if (data == null) {
        print('🚨 LOG 11 [NotifService]: additionalData null, yönlendirme iptal.');
        return;
      }

      final rawId = data['postId'];
      if (rawId == null) {
        print('🚨 LOG 11 [NotifService]: postId alanı yok, yönlendirme iptal.');
        return;
      }

      final postId = rawId.toString().trim();
      if (postId.isEmpty) {
        print('🚨 LOG 11 [NotifService]: postId boş string, yönlendirme iptal.');
        return;
      }

      print('🔍 LOG 12 [NotifService]: postId alındı: "$postId" → Sayfa açılıyor.');
      _openPostDetail(postId);
    });

    // Uygulama öndeyken gelen bildirimleri de göster
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      event.preventDefault();
      event.notification.display();
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  KAYIP EŞYA BİLDİRİMİ GÖNDER
  //  • Tüm kullanıcılar çekilip Türkçe-karakter-duyarsız eşleşme yapılır.
  //  • Eşleşen kullanıcının pushToken'ına OneSignal bildirimi atılır.
  //  • data alanına postId eklenir → tıklamada doğru sayfayı açmak için.
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> sendKayipEsyaNotification({
    required String postId,
    required String kayipEsyaSahibi,
    required String oneSignalRestApiKey,
  }) async {
    print('🔍 LOG 13 [NotifService]: Bildirim gönderme başladı. '
        'Hedef isim: "$kayipEsyaSahibi", İlan ID: "$postId"');

    final isimTemiz = kayipEsyaSahibi.trim();
    if (isimTemiz.isEmpty) {
      print('🚨 LOG 14 [NotifService]: Eşya sahibi adı boş, bildirim iptal.');
      return;
    }
    if (oneSignalRestApiKey.isEmpty) {
      print('🚨 LOG 14 [NotifService]: OneSignal API key boş, bildirim iptal.');
      return;
    }
    if (postId.trim().isEmpty) {
      print('🚨 LOG 14 [NotifService]: postId boş, bildirim iptal.');
      return;
    }

    final arananNorm = _normalize(isimTemiz);
    print('🔍 LOG 15 [NotifService]: Normalize edilmiş arama: "$arananNorm"');

    // Tüm kullanıcıları çek ve isim karşılaştır
    // Not: Kullanıcı sayısı çok büyürse bunu sunucu tarafında yapmalısın.
    final snapshot =
        await FirebaseFirestore.instance.collection('users').get();

    String? targetPushToken;
    String? gercekIsim;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final ad     = (data['ad']     as String? ?? '').trim();
      final soyad  = (data['soyad']  as String? ?? '').trim();
      final tamAd  = '$ad $soyad'.trim();
      final dbNorm = _normalize(tamAd);

      if (dbNorm == arananNorm) {
        targetPushToken = data['pushToken'] as String?;
        gercekIsim      = tamAd;
        print('🔍 LOG 16 [NotifService]: Eşleşme bulundu! '
            'Gerçek isim: "$gercekIsim", token: $targetPushToken');
        break;
      }
    }

    if (targetPushToken == null || targetPushToken.isEmpty) {
      print('🚨 LOG 17 [NotifService]: Kullanıcı bulunamadı veya pushToken yok. '
          'Bildirim iptal.');
      return;
    }

    final response = await http.post(
      Uri.parse('https://onesignal.com/api/v1/notifications'),
      headers: {
        'Content-Type':  'application/json',
        'Authorization': 'Basic $oneSignalRestApiKey',
      },
      body: jsonEncode({
        'app_id':             _appId,
        'include_player_ids': [targetPushToken],
        'headings':  {'en': 'Kayıp Eşyan Bulunmuş Olabilir! 🥳'},
        'contents':  {
          'en': '$gercekIsim, biri senin adına bir kayıp eşya ilanı paylaştı. '
                'Hemen kontrol et!',
        },
        // ← postId burada gönderiliyor; tıklamada bu data yakalanır
        'data': {'postId': postId.trim()},
      }),
    );

    print('🔍 LOG 18 [NotifService]: OneSignal yanıtı: '
        '${response.statusCode} — ${response.body}');
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DETAY SAYFASINI AÇ
  // ══════════════════════════════════════════════════════════════════════════

  void _openPostDetail(String postId) {
    print('🔍 LOG 19 [NotifService]: PostDetailScreen açılıyor. ID: "$postId"');

    final nav = navigatorKey.currentState;
    if (nav == null) {
      print('🚨 LOG 20 [NotifService]: navigatorKey.currentState null! '
          'main.dart\'ta MaterialApp\'e navigatorKey atandı mı?');
      return;
    }

    nav.push(
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(postId: postId),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  YARDIMCI — Türkçe karakter & büyük/küçük harf normalizasyonu
  // ══════════════════════════════════════════════════════════════════════════

  String _normalize(String text) {
    if (text.isEmpty) return '';
    return text
        .toLowerCase()
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('İ', 'i')
        .replaceAll('I', 'i')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}