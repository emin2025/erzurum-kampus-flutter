import 'package:erzurum_kampus/screens/feed_screen.dart';
import 'package:erzurum_kampus/screens/forgot_password_screen.dart';
import 'package:erzurum_kampus/theme/app_colors.dart';
import 'package:erzurum_kampus/widgets/app_buttons.dart';
import 'package:erzurum_kampus/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'register_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends StatefulWidget {
  /// Kayıt ekranından yönlendirilirken e-postayı önceden doldurur.
  const LoginScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  // ── Controllers ────────────────────────────
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  // ── State ───────────────────────────────────
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  bool _showVerificationBanner = false;

  // ── Animasyon ───────────────────────────────
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  // ── Lifecycle ───────────────────────────────
  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailController.text = widget.initialEmail!;
      _showVerificationBanner = true;
    }

    _checkCurrentUser();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ── İş Mantığı ──────────────────────────────

// ── İş Mantığı ──────────────────────────────

  // Firebase hatalarını Türkçeleştirme
  String _mapFirebaseError(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return 'Bu e-posta adresiyle kayıtlı bir hesap bulunamadı.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-posta veya şifre hatalı.';
      case 'user-disabled':
        return 'Bu hesap yöneticiler tarafından engellenmiş.';
      case 'too-many-requests':
        return 'Çok fazla başarısız deneme yaptınız. Lütfen daha sonra tekrar deneyin.';
      default:
        return 'Giriş yapılamadı. Lütfen bilgilerinizi kontrol edin.';
    }
  }

  // ── ONESIGNAL TOKEN GÜNCELLEME ──
  Future<void> _updatePushToken(String uid) async {
    try {
      // OneSignal'dan cihazın o anki bildirim kimliğini alıyoruz
      final pushToken = OneSignal.User.pushSubscription.id;
      if (pushToken != null && pushToken.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'pushToken': pushToken,
        });
      }
    } catch (e) {
      debugPrint("Token güncellenemedi: $e");
    }
  }

  // ── 1. OTOMATİK OTURUM KONTROLÜ ──
 // ── 1. OTOMATİK OTURUM KONTROLÜ ──
  void _checkCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    // Eğer kullanıcı zaten giriş yapmışsa
    if (user != null) {
      if (user.emailVerified || user.providerData.any((provider) => provider.providerId == 'google.com')) {
        
        // 🔥 UYGULAMAYA OTOMATİK GİRERKEN BİLE TOKENI GÜNCELLE 🔥
        _updatePushToken(user.uid); 
        
        // E-postası doğrulanmışsa veya Google ile girmişse bekletmeden içeri al
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigateToFeed();
        });
      } else {
        // E-postası doğrulanmamışsa uyarıyı göster ve oturumu arka planda kapat
        setState(() => _showVerificationBanner = true);
        FirebaseAuth.instance.signOut();
      }
    }
  }
  // ── 2. E-POSTA İLE GİRİŞ ──
  Future<void> _handleEmailLogin() async {
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Lütfen tüm alanları doldurunuz.', isError: true);
      return;
    }
    if (!_isValidEmail(email)) {
      _showSnackBar('Geçerli bir e-posta adresi giriniz.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user?.emailVerified == true) {

        await _updatePushToken(credential.user!.uid);        
        
        if (!mounted) return;
        setState(() => _isLoading = false);
        _navigateToFeed();
      } else {
        setState(() { 
          _showVerificationBanner = true; 
          _isLoading = false; 
        });
        _showSnackBar('Lütfen e-postanızı doğrulayın. Spam klasörünü kontrol etmeyi unutmayın.', isError: true);
        await FirebaseAuth.instance.signOut();
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar(_mapFirebaseError(e.code), isError: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('Beklenmeyen bir hata oluştu.', isError: true);
    }
  }

  // ── 3. GOOGLE İLE GİRİŞ (V7 Mimarisi) ──
  // ── 3. GOOGLE İLE GİRİŞ (V7 Mimarisi) ──
  Future<void> _handleGoogleLogin() async {
    FocusScope.of(context).unfocus();
    setState(() => _isGoogleLoading = true);

    try {
      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize();
      await googleSignIn.signOut(); // Hesap seçiciyi zorla açmak için
      
      final GoogleSignInAccount? googleUser = await googleSignIn.authenticate();
      
      if (googleUser == null) {
        setState(() => _isGoogleLoading = false);
        return; 
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final clientAuth = await googleUser.authorizationClient?.authorizeScopes(['email', 'profile']);

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: clientAuth?.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        final uid = firebaseUser.uid;
        
        // 🔥 TOKEN'I BURADA BİR KERE ALIYORUZ VE KONSOLA YAZDIRIYORUZ 🔥
        final pushToken = OneSignal.User.pushSubscription.id ?? '';
        debugPrint("💡 GOOGLE GİRİŞ - Çekilen Push Token: $pushToken");
        
        final docSnapshot = await FirebaseFirestore.instance.collection('users').doc(uid).get();

        if (!docSnapshot.exists) {
          // YENİ KULLANICI: Token'ı doğrudan kaydın içine gömüyoruz
          final ad = googleUser.displayName?.split(' ').first ?? '';
          final soyad = googleUser.displayName?.split(' ').skip(1).join(' ') ?? '';
          
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'email': firebaseUser.email,
            'ad': ad,
            'soyad': soyad,
            'tamAd': googleUser.displayName ?? '',
            'telefon': '',
            'photoUrl': googleUser.photoUrl ?? '',
            'isEmailVerified': true,
            'girisYontemi': 'google',
            'pushToken': pushToken, // 🔥 DOĞRUDAN SET İÇİNE EKLENDİ
            'yasalBeyan': 'Giriş ekranından Google ile onaylandı.',
            'olusturmaTarihi': FieldValue.serverTimestamp(),
          });
        } else {
          // ESKİ KULLANICI: Zaten hesabı var, sadece yeni token'ı güncelliyoruz
          if (pushToken.isNotEmpty) {
            await FirebaseFirestore.instance.collection('users').doc(uid).update({
              'pushToken': pushToken,
            });
          }
        }

        if (!mounted) return;
        _showSnackBar('Giriş başarılı, yönlendiriliyorsunuz...');
        _navigateToFeed();
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Google ile giriş yapılırken bir hata oluştu.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }
 

  void _navigateToFeed() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const FeedScreen()),
    );
  }

  bool _isValidEmail(String email) =>
      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  // ── UI ──────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
                  const SizedBox(height: 48),
                  _AppLogo(),
                  const SizedBox(height: 36),
                  _buildHeadline(),
                  const SizedBox(height: 32),
                  if (_showVerificationBanner) ...[
                    _VerificationBanner(),
                    const SizedBox(height: 20),
                  ],
                  AppTextField(
                    controller: _emailController,
                    label: 'E-posta Adresi',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    focusNode: _emailFocusNode,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _passwordController,
                    label: 'Şifre',
                    prefixIcon: Icons.lock_outline_rounded,
                    isPassword: true,
                    obscureText: _obscurePassword,
                    onToggleObscure: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    autofillHints: const [AutofillHints.password],
                    focusNode: _passwordFocusNode,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleEmailLogin(),
                  ),
                  const SizedBox(height: 8),
                  _buildForgotPassword(),
                  const SizedBox(height: 28),
                  PrimaryButton(
                    label: 'Giriş Yap',
                    onPressed:
                        (_isLoading || _isGoogleLoading) ? null : _handleEmailLogin,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 24),
                  const OrDivider(),
                  const SizedBox(height: 24),
                  SocialButton(
                    label: 'Google ile Giriş Yap',
                    isLoading: _isGoogleLoading,
                    onPressed:
                        (_isLoading || _isGoogleLoading) ? null : _handleGoogleLogin,
                    iconWidget: Image.network(
                      'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg',
                      height: 22,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.g_mobiledata, size: 22),
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildRegisterLink(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeadline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hoş Geldin',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Erzurum Kampüs dünyasına giriş yap.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }

 Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
          );
        },
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text(
          'Şifremi Unuttum',
          style: TextStyle(
            color: AppColors.accent,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Hesabın yok mu?',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RegisterScreen()),
            );
          },
          child: const Text(
            'Kayıt Ol',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Ayrı küçük widget'lar ─────────────────────

/// Uygulama logosu — _LoginScreenState dışına çıkarıldı, const widget.
class _AppLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF312E81), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentGlow,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(
        Icons.school_rounded,
        size: 34,
        color: Colors.white,
      ),
    );
  }
}

/// E-posta doğrulama uyarı afişi.
class _VerificationBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.mark_email_unread_outlined,
            size: 20,
            color: AppColors.warning,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'E-postanıza gönderilen doğrulama linkine tıklayarak hesabınızı onaylayın. Spam klasörünüzü de kontrol edin.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}