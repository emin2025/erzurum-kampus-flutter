import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:erzurum_kampus/screens/NotificationService.dart';
import 'package:erzurum_kampus/screens/PostDetailScreenState.dart';
import 'package:erzurum_kampus/screens/login_screen.dart';
import 'package:erzurum_kampus/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart'; // 1. Firebase Çekirdeği
import 'firebase_options.dart'; // 2. FlutterFire'ın oluşturduğu ayar dosyası (lib klasöründe olduğunu varsayıyoruz)
import 'package:intl/date_symbol_data_local.dart';
// 🔥 1. YENİ EKLENDİ: OneSignal Kütüphanesi 🔥
import 'package:onesignal_flutter/onesignal_flutter.dart';

// main fonksiyonunu asenkron (async) yapıyoruz çünkü Firebase başlatma işlemi zaman alır
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase'i mevcut platforma göre başlatıyoruz
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );


  // YENİ: Bildirim servisini başlat
await NotificationService.instance.initialize();


  // 🔥 2. YENİ EKLENDİ: OneSignal Motorunu Başlatıyoruz 🔥
  // Logları görmek için (hatanın nerede olduğunu söyler)
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  
  // 🚨 ÇOK ÖNEMLİ: Aşağıdaki tırnak içine kendi OneSignal App ID'ni yapıştır! 🚨
  OneSignal.initialize("91f1b684-c228-4c9a-9fa6-14a1bf370680");
  
  // Kullanıcıdan bildirim gönderme izni iste (Ekrana pop-up çıkartır)
  OneSignal.Notifications.requestPermission(true);
  // 🔥 -------------------------------------------------- 🔥

  // Durum çubuğunu şeffaf, içerikleri koyu yap
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

// 3. İŞTE ÇÖZÜM BURADA: Türkçe tarih sözlüğünü başlat
  await initializeDateFormatting('tr_TR', null);
  
  // Sadece dikey yönlendirmeye kilitle
  // Küçük bir profesyonel dokunuş: Kilitleme işlemi bittikten sonra uygulamayı başlatmak daha sağlıklıdır (.then ekledim)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(const ErzurumKampusApp());
  });
}

class ErzurumKampusApp extends StatefulWidget {
  const ErzurumKampusApp({super.key});

  @override
  State<ErzurumKampusApp> createState() => _ErzurumKampusAppState();
}

class _ErzurumKampusAppState extends State<ErzurumKampusApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();

    // 1. DURUM: Uygulama kapalıyken linkten açılırsa
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _ilanaYonlendir(uri);
      }
    });

    // 2. DURUM: Uygulama arka planda açıkken linke tıklanırsa
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      if (uri != null) {
        _ilanaYonlendir(uri);
      }
    }, onError: (err) {
      debugPrint("Deep Link Hatası: $err");
    });
  }

  void _ilanaYonlendir(Uri uri) {
    if (uri.path == '/post') {
      final String? postId = uri.queryParameters['postId'];
      
      if (postId != null && postId.isNotEmpty) {
        // NotificationService.navigatorKey sayesinde global yönlendirme yapıyoruz!
        NotificationService.navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(postId: postId), // Kendi sınıf adını yazmalısın
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NotificationService.navigatorKey, // Senin eklediğin sihirli anahtar
      title: 'Erzurum Kampüs',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const LoginScreen(),
    );
  }
}