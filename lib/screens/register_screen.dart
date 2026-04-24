import 'package:erzurum_kampus/theme/app_colors.dart';
import 'package:erzurum_kampus/widgets/app_buttons.dart';
import 'package:erzurum_kampus/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  // ── Form ────────────────────────────────────
  final _formKey = GlobalKey<FormState>();

  // ── Controllers ────────────────────────────
  final _adController = TextEditingController();
  final _soyadController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // ── FocusNode'lar (form'da tab sırası için) ─
  final _soyadFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  // ── State ───────────────────────────────────
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _contractAccepted = false;
  bool _contractError = false;

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
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _adController.dispose();
    _soyadController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _soyadFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ── İş Mantığı ──────────────────────────────

  /// Her kelimenin baş harfini büyük yap.
  
 // ── İş Mantığı ──────────────────────────────

  /// Her kelimenin baş harfini büyük yap.
  String _capitalize(String str) {
    if (str.isEmpty) return str;
    return str
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  // Java'daki hata yakalama mantığının Flutter karşılığı
  String _mapFirebaseError(String errorCode) {
    switch (errorCode) {
      case 'weak-password':
        return 'Şifre çok zayıf. En az 6 karakter olmalı.';
      case 'email-already-in-use':
        return 'Bu e-posta adresi zaten kullanımda.';
      case 'invalid-email':
        return 'Geçersiz bir e-posta adresi girdiniz.';
      case 'network-request-failed':
        return 'İnternet bağlantınızı kontrol edin.';
      default:
        return 'Bir hata oluştu: $errorCode';
    }
  }

  // ── E-POSTA İLE KAYIT ──
  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();

    if (!_contractAccepted) {
      setState(() => _contractError = true);
      _showSnackBar('Devam etmek için kullanıcı sözleşmesini onaylayın.', isError: true);
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    final ad = _capitalize(_adController.text.trim());
    final soyad = _capitalize(_soyadController.text.trim());
    final email = _emailController.text.trim();
    final telefon = _phoneController.text.trim();
    final uluslararasiTelefon = telefon.isEmpty ? '' : '+90$telefon';
    final tamAd = '$ad $soyad';

    try {
      // 1. Firebase Authentication'da kullanıcı oluştur
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: _passwordController.text,
      );

      final user = credential.user;
      if (user != null) {
        // 2. Firestore'a Java'daki yapıyla aynı verileri kaydet
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': email,
          'ad': ad,
          'soyad': soyad,
          'telefon': uluslararasiTelefon,
          'tamAd': tamAd,
          'isEmailVerified': false,
          'girisYontemi': 'email',
          'pushToken': OneSignal.User.pushSubscription.id ?? '', // 🔥 YENİ EKLENDİ
          'profilResmiUrl': '',
          'yasalBeyan': "Kullanıcı Sözleşmesi'ni okudum. Yapacağım tüm paylaşımlardan (fotoğraf, yorum, yazı vb.) Türkiye Cumhuriyeti yasaları önünde bizzat sorumlu olduğumu, hakaret veya suç teşkil eden içeriklerde IP adresimin yetkili mercilerle paylaşılacağını kabul ediyorum.",
          'olusturmaTarihi': FieldValue.serverTimestamp(),
        });

        // 3. Doğrulama e-postası gönder
        await user.sendEmailVerification();
        
        // 4. Oturumu kapat (kullanıcı maili doğrulayıp Login sayfasından girmeli)
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;
        setState(() => _isLoading = false);
        _showSnackBar('Kayıt başarılı! Lütfen e-postanızı doğrulayın.');
        
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (!mounted) return;
          _navigateToLoginWithEmail(email);
        });
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

 // ── GOOGLE İLE KAYIT/GİRİŞ (Yeni V7 Mimarisi) ──
  Future<void> _handleGoogleRegister() async {
    if (!_contractAccepted) {
      setState(() => _contractError = true);
      _showSnackBar('Lütfen önce sözleşmeyi onaylayın.', isError: true);
      return;
    }

    try {
      // 1. V7 YENİLİĞİ: Artık kurucu metod yok, Singleton (instance) kullanıyoruz.
      final googleSignIn = GoogleSignIn.instance;
      
      // 2. V7 YENİLİĞİ: İşlemlere başlamadan önce initialize() çağırmak artık zorunlu.
      await googleSignIn.initialize();
      
      // Önceki oturumu temizle
      await googleSignIn.signOut(); 
      
      // 3. V7 YENİLİĞİ: signIn() komutu tamamen kaldırıldı, yerine authenticate() geldi.
      final GoogleSignInAccount? googleUser = await googleSignIn.authenticate();
      
      if (googleUser == null) {
        return; // Kullanıcı pencereyi kapattı veya iptal etti
      }

      setState(() => _isLoading = true);

      // 4. Sadece kimlik bilgilerini al (idToken buradan gelir)
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // 5. V7 YENİLİĞİ: Firebase için Access Token artık otomatik gelmiyor.
      // Sadece gerektiğinde yetki (scope) istemek için authorizationClient kullanıyoruz.
      final clientAuth = await googleUser.authorizationClient?.authorizeScopes(['email', 'profile']);

      // 6. Topladığımız bu iki yeni token ile Firebase'e giriş yapıyoruz
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: clientAuth?.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        final uid = firebaseUser.uid;
        
        // Kullanıcı Firestore'da var mı kontrol et
        final docSnapshot = await FirebaseFirestore.instance.collection('users').doc(uid).get();

        if (docSnapshot.exists) {

// Eski kullanıcı ise güncel cihaz token'ını veritabanına yazalım
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'pushToken': OneSignal.User.pushSubscription.id ?? '',
          });

          // Eski kullanıcı
          final mevcutAd = docSnapshot.data()?['ad'] ?? '';
          if (!mounted) return;
          _showSnackBar('Hoş geldin, $mevcutAd!');
          // TODO: Akış Sayfasına yönlendir
        } else {
          // Yeni kullanıcı: Bilgileri Firestore'a kaydet
          final ad = googleUser.displayName?.split(' ').first ?? '';
          final soyad = googleUser.displayName?.split(' ').skip(1).join(' ') ?? '';
          final tamAd = googleUser.displayName ?? '';
          final photoUrl = googleUser.photoUrl ?? '';

          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'email': firebaseUser.email,
            'ad': ad,
            'soyad': soyad,
            'tamAd': tamAd,
            'telefon': '',
            'profilResmiUrl': photoUrl,
            'isEmailVerified': true, 
            'girisYontemi': 'google',
            'pushToken': OneSignal.User.pushSubscription.id ?? '', // 🔥 YENİ EKLENDİ
            'yasalBeyan': "Kullanıcı Sözleşmesi'ni okudum. Yapacağım tüm paylaşımlardan (fotoğraf, yorum, yazı vb.) Türkiye Cumhuriyeti yasaları önünde bizzat sorumlu olduğumu, hakaret veya suç teşkil eden içeriklerde IP adresimin yetkili mercilerle paylaşılacağını kabul ediyorum.",
            'olusturmaTarihi': FieldValue.serverTimestamp(),
          });

          if (!mounted) return;
          _showSnackBar('Hoş geldin, $ad! Hesabın oluşturuldu.');
          // TODO: Akış Sayfasına yönlendir
        }
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Google ile giriş başarısız oldu.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToLoginWithEmail(String email) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(initialEmail: email),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  // ── Validatorlar ─────────────────────────────

  String? _validateAd(String? v) {
    if (v == null || v.trim().isEmpty) return 'Ad gerekli';
    return null;
  }

  String? _validateSoyad(String? v) {
    if (v == null || v.trim().isEmpty) return 'Soyad gerekli';
    if (_adController.text.trim().length + v.trim().length >= 24) {
      return 'Ad + Soyad en fazla 23 karakter olabilir';
    }
    return null;
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'E-posta gerekli';
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
      return 'Geçerli bir e-posta giriniz';
    }
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.trim().isEmpty) return 'Şifre gerekli';
    if (v.length < 6) return 'En az 6 karakter olmalı';
    return null;
  }

  String? _validateConfirmPassword(String? v) {
    if (v == null || v.trim().isEmpty) return 'Şifre tekrarı gerekli';
    if (v != _passwordController.text) return 'Şifreler eşleşmiyor';
    return null;
  }

  // ── UI ──────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const _BackButton(),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeadline(),
                  const SizedBox(height: 32),
                  _buildNameRow(),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _emailController,
                    label: 'E-posta Adresi',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    focusNode: _emailFocus,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _phoneFocus.requestFocus(),
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _phoneController,
                    label: 'Telefon (İsteğe Bağlı)',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    prefixText: '+90 ',
                    autofillHints: const [AutofillHints.telephoneNumber],
                    focusNode: _phoneFocus,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
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
                    autofillHints: const [AutofillHints.newPassword],
                    focusNode: _passwordFocus,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) =>
                        _confirmPasswordFocus.requestFocus(),
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _confirmPasswordController,
                    label: 'Şifre Tekrar',
                    prefixIcon: Icons.lock_outline_rounded,
                    isPassword: true,
                    obscureText: _obscureConfirm,
                    onToggleObscure: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    autofillHints: const [AutofillHints.newPassword],
                    focusNode: _confirmPasswordFocus,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleRegister(),
                    validator: _validateConfirmPassword,
                  ),
                  const SizedBox(height: 24),
                  _ContractCheckbox(
                    accepted: _contractAccepted,
                    hasError: _contractError,
                    onChanged: (v) => setState(() {
                      _contractAccepted = v ?? false;
                      if (_contractAccepted) _contractError = false;
                    }),
                    onTapText: _showContractDialog,
                  ),
                  const SizedBox(height: 28),
                  PrimaryButton(
                    label: 'Kayıt Ol',
                    onPressed: _isLoading ? null : _handleRegister,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 20),
                  const OrDivider(),
                  const SizedBox(height: 20),
                  SocialButton(
                    label: 'Google ile Devam Et',
                    onPressed: _handleGoogleRegister,
                    iconWidget: Image.network(
                      'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg',
                      height: 22,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.g_mobiledata, size: 22),
                    ),
                  ),
                  const SizedBox(height: 36),
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
        Text('Aramıza Katıl', style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: 8),
        Text(
          'Erzurum Kampüs deneyimini yaşamak için hesabını oluştur.',
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildNameRow() {
    return Row(
      children: [
        Expanded(
          child: AppTextField(
            controller: _adController,
            label: 'Ad',
            prefixIcon: Icons.person_outline_rounded,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.givenName],
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _soyadFocus.requestFocus(),
            validator: _validateAd,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: AppTextField(
            controller: _soyadController,
            label: 'Soyad',
            prefixIcon: Icons.person_outline_rounded,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.familyName],
            focusNode: _soyadFocus,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _emailFocus.requestFocus(),
            validator: _validateSoyad,
          ),
        ),
      ],
    );
  }

  // ── Sözleşme Dialog ──────────────────────────
  void _showContractDialog() {
    showDialog(
      context: context,
      builder: (_) => const _ContractDialog(),
    ).then((accepted) {
      if (accepted == true) {
        setState(() {
          _contractAccepted = true;
          _contractError = false;
        });
      }
    });
  }
}

// ─────────────────────────────────────────────
// Alt bileşenler — sayfadan ayrıştırıldı
// ─────────────────────────────────────────────

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(
        Icons.arrow_back_ios_new_rounded,
        size: 20,
        color: AppColors.textPrimary,
      ),
      onPressed: () => Navigator.pop(context),
    );
  }
}

class _ContractCheckbox extends StatelessWidget {
  const _ContractCheckbox({
    required this.accepted,
    required this.hasError,
    required this.onChanged,
    required this.onTapText,
  });

  final bool accepted;
  final bool hasError;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onTapText;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: accepted,
            onChanged: onChanged,
            side: BorderSide(
              color: hasError ? AppColors.error : AppColors.border,
              width: 2,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: onTapText,
            child: Text.rich(
              TextSpan(
                text: 'Kullanıcı ',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color:
                      hasError ? AppColors.error : AppColors.textSecondary,
                ),
                children: [
                  TextSpan(
                    text: 'Sözleşmesi',
                    style: TextStyle(
                      color: hasError ? AppColors.error : AppColors.accent,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor:
                          hasError ? AppColors.error : AppColors.accent,
                    ),
                  ),
                  const TextSpan(text: "'ni okudum ve kabul ediyorum."),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Sözleşme içeriğini gösteren tam ekran dialog.
class _ContractDialog extends StatelessWidget {
  const _ContractDialog();

  static const _contractText =
      'KULLANICI SÖZLEŞMESİ VE YASAL SORUMLULUK BEYANI\n\n'
      '1. Taraflar ve Amaç\n'
      'Bu uygulama, öğrencilerin iletişim kurmasını sağlayan bir platformdur. '
      'Uygulama yönetimi yalnızca yer sağlayıcı konumundadır.\n\n'
      '2. Paylaşım Sorumluluğu\n'
      'Kullanıcı, uygulama içerisinde oluşturduğu profil, paylaştığı gönderi, '
      'yorum ve diğer tüm içeriklerin doğruluğundan bizzat sorumludur.\n\n'
      '3. Yasal Beyan\n'
      'Kullanıcı;\n'
      '• Yaptığı paylaşımların Türkiye Cumhuriyeti yasalarına aykırı olmayacağını,\n'
      '• Kişileri veya kurumları hedef alan, hakaret içeren veya suç teşkil eden '
      'içerikler paylaşmayacağını,\n'
      '• Bu tür bir paylaşım yapması durumunda doğacak tüm maddi, manevi, hukuki '
      've cezai sorumluluğun tamamen kendisine ait olduğunu,\n'
      '• Olası bir yasal süreçte uygulama yönetiminin kullanıcının IP adresini ve '
      'kayıt bilgilerini yetkili mercilerle paylaşacağını\n'
      'peşinen kabul ve beyan eder.\n\n'
      '4. Yaptırım\n'
      'Kurallara uymayan kullanıcıların hesapları süresiz olarak kapatılıp yasal '
      'süreçlere tabi tutulacaktır.';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.gavel_rounded,
                    size: 20,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Kullanıcı Sözleşmesi',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: AppColors.border),
            const SizedBox(height: 16),

            // İçerik
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: SingleChildScrollView(
                child: Text(
                  _contractText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.65,
                        color: AppColors.textPrimary,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Aksiyonlar
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(
                      'Kapat',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    label: 'Kabul Ediyorum',
                    height: 48,
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}