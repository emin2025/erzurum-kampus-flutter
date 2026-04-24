import 'dart:async';
import 'package:erzurum_kampus/theme/app_colors.dart';
import 'package:erzurum_kampus/widgets/app_buttons.dart';
import 'package:erzurum_kampus/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  
  // ── Controllers ────────────────────────────
  final _emailController = TextEditingController();
  final _emailFocus = FocusNode();

  // ── State ───────────────────────────────────
  bool _isLoading = false;
  bool _isSuccess = false;
  
  // Sayaç değişkenleri
  static const String _prefsKey = "target_time";
  int _timeRemaining = 0;
  Timer? _timer;

  // ── Animasyon ───────────────────────────────
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    
    _fadeController.forward();
    
    // Sayfa açıldığında hafızadaki sayacı kontrol et
    _checkExistingTimer();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocus.dispose();
    _timer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  // ── İş Mantığı & Sayaç (Java'dan Çeviri) ─────

  Future<void> _checkExistingTimer() async {
    final prefs = await SharedPreferences.getInstance();
    final targetTime = prefs.getInt(_prefsKey) ?? 0;
    final currentTime = DateTime.now().millisecondsSinceEpoch;

    if (targetTime > currentTime) {
      // Süre bitmemiş, sayacı başlat
      final timeRemaining = ((targetTime - currentTime) / 1000).floor();
      _startResendTimer(timeRemaining);
    }
  }

  Future<void> _saveTimerState() async {
    final targetTime = DateTime.now().millisecondsSinceEpoch + 60000; // Şu an + 60 saniye
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, targetTime);
    _startResendTimer(60);
  }

  void _startResendTimer(int seconds) {
    setState(() => _timeRemaining = seconds);
    
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_timeRemaining > 0) {
        setState(() => _timeRemaining--);
      } else {
        timer.cancel();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_prefsKey);
      }
    });
  }

  Future<void> _handleResetPassword() async {
    FocusScope.of(context).unfocus();
    final email = _emailController.text.trim();

    if (email.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showSnackBar('Lütfen geçerli bir e-posta adresi giriniz.', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _isSuccess = false;
    });

    try {
      // 1. Kullanıcı veritabanında var mı kontrolü (Eski Java mantığı)
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      if (querySnapshot.docs.isEmpty) {
        if (!mounted) return;
        _showSnackBar('Bu e-posta adresiyle kayıtlı bir kullanıcı bulunamadı.', isError: true);
        setState(() => _isLoading = false);
        return;
      }

      // 2. Kullanıcı varsa şifre sıfırlama maili gönder
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isSuccess = true;
      });
      
      _showSnackBar('Şifre sıfırlama bağlantısı gönderildi.');
      await _saveTimerState(); // 60 saniyelik sayacı başlat
      
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('İşlem başarısız oldu: Müşteri hizmetleriyle iletişime geçin.', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.help_outline_rounded, color: AppColors.accent),
            SizedBox(width: 10),
            Text('Şifre Sıfırlama Yardımı', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text.rich(
          TextSpan(
            style: TextStyle(fontSize: 15, height: 1.6, color: AppColors.textPrimary),
            children: [
              TextSpan(text: 'Adım 1: ', style: TextStyle(fontWeight: FontWeight.bold)),
              TextSpan(text: 'Kayıtlı e-posta adresinizi girin.\n\n'),
              TextSpan(text: 'Adım 2: ', style: TextStyle(fontWeight: FontWeight.bold)),
              TextSpan(text: '"Şifreyi Sıfırla" butonuna basın.\n\n'),
              TextSpan(text: 'Adım 3: ', style: TextStyle(fontWeight: FontWeight.bold)),
              TextSpan(text: 'E-postanıza gelen bağlantıya tıklayın (Spam klasörünü kontrol etmeyi unutmayın).\n\n'),
              TextSpan(text: 'Dikkat: ', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
              TextSpan(text: 'Gönderilen bağlantı 24 saat içinde geçerliliğini yitirir.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anladım', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── UI ──────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Sayacın durumuna göre butonun aktifliği ve metni belirleniyor
    final bool isButtonDisabled = _isLoading || _timeRemaining > 0;
    final String buttonText = _timeRemaining > 0 
        ? 'Tekrar Gönder ($_timeRemaining sn)' 
        : 'Şifreyi Sıfırla';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showHelpDialog,
        backgroundColor: AppColors.accent,
        elevation: 4,
        child: const Icon(Icons.support_agent_rounded, color: Colors.white),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    'Şifremi Unuttum',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Endişelenme, şifreni sıfırlamak çok kolay. E-posta adresini gir, sana sıfırlama bağlantısını gönderelim.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Başarı Durumu Uyarı Afişi
                  if (_isSuccess) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.success.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 28),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Bağlantı başarıyla gönderildi! Lütfen e-postanızı (ve spam klasörünü) kontrol edin.',
                              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  AppTextField(
                    controller: _emailController,
                    label: 'Kayıtlı E-posta Adresiniz',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    focusNode: _emailFocus,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!isButtonDisabled) _handleResetPassword();
                    },
                  ),
                  const SizedBox(height: 32),
                  
                  PrimaryButton(
                    label: buttonText,
                    onPressed: isButtonDisabled ? null : _handleResetPassword,
                    isLoading: _isLoading,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}