import 'package:erzurum_kampus/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Java'daki "Teklif Ver" BottomSheetDialog'unun tam Flutter karşılığı.
///
/// - Mevcut fiyatı %3, 5, 10, 15, 20, 30 indirimlerle gösterir.
/// - "Kendi Teklifinizi Oluşturun" ile manuel fiyat girişine açılır.
/// - Seçilen teklif [onOfferSelected] callback'i ile iletilir.
class OfferBottomSheet extends StatefulWidget {
  const OfferBottomSheet({
    super.key,
    required this.fiyat,
    required this.kategori,
    required this.onOfferSelected,
  });

  final double? fiyat;
  final String kategori;
  final void Function(String mesaj) onOfferSelected;

  /// Java'daki tıklama → BottomSheetDialog göster mantığı
  static Future<void> show({
    required BuildContext context,
    required String? fiyatStr,
    required String kategori,
    required void Function(String mesaj) onOfferSelected,
  }) {
    double? fiyat;
    if (fiyatStr != null && fiyatStr.isNotEmpty && fiyatStr != '-') {
      final cleaned = fiyatStr.replaceAll('₺', '').replaceAll('TL', '').trim();
      fiyat = double.tryParse(cleaned);
    }

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OfferBottomSheet(
        fiyat: fiyat,
        kategori: kategori,
        onOfferSelected: onOfferSelected,
      ),
    );
  }

  @override
  State<OfferBottomSheet> createState() => _OfferBottomSheetState();
}

class _OfferBottomSheetState extends State<OfferBottomSheet> {
  bool _showManuel = false;
  final _manuelController = TextEditingController();

  static const List<int> _indirimler = [3, 5, 10, 15, 20, 30];

  @override
  void dispose() {
    _manuelController.dispose();
    super.dispose();
  }

  /// Java'daki ekliTurBelirle(tur) metodu
  static String _ekliTur(String tur) {
    return switch (tur) {
      'Elektronik'        => 'Elektronik eşyanız',
      'Kitap & Ders'      => 'Kitabınız',
      'Kitap / Kırtasiye' => 'Kitabınız',
      'Giyim'             => 'Eşyanız',
      'Giyim / Aksesuar'  => 'Eşyanız',
      'Mobilya'           => 'Eşyanız',
      'Köpek'             => 'Köpeğiniz',
      'Kedi'              => 'Kediniz',
      'Kuş'               => 'Kuşunuz',
      _                   => tur.isNotEmpty ? tur : 'Eşyanız',
    };
  }

  void _secTeklif(double fiyat) {
    final ekliTur = _ekliTur(widget.kategori);
    final mesaj =
        'Merhaba, $ekliTur için ${fiyat.toStringAsFixed(2)}₺ teklifim var, ne dersiniz?';
    Navigator.pop(context);
    widget.onOfferSelected(mesaj);
  }

  void _gonderManuel() {
    final val = _manuelController.text.trim();
    if (val.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir teklif fiyatı girin.')),
      );
      return;
    }
    final fiyat = double.tryParse(val);
    if (fiyat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir sayı girin.')),
      );
      return;
    }
    _secTeklif(fiyat);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    final ekliTur = _ekliTur(widget.kategori);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Başlık ──────────────────────────────────────────────────
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_offer_outlined, color: AppColors.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Teklif Ver',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      ekliTur,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.border),
          const SizedBox(height: 16),

          if (!_showManuel) ...[
            // ── İndirim Butonları (Java'daki GridLayout) ───────────────
            if (widget.fiyat != null && widget.fiyat! > 0) ...[
              Text(
                'Hazır Teklifler',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _indirimler.map((oran) {
                  final yeniFiyat = widget.fiyat! - (widget.fiyat! * oran / 100);
                  return GestureDetector(
                    onTap: () => _secTeklif(yeniFiyat),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentGlow,
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '%$oran indirim',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${yeniFiyat.toStringAsFixed(2)} ₺',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // ── Manuel Teklif Butonu ──────────────────────────────────
            OutlinedButton.icon(
              onPressed: () => setState(() => _showManuel = true),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Kendi Teklifinizi Oluşturun'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                foregroundColor: AppColors.textPrimary,
              ),
            ),
          ] else ...[
            // ── Manuel Teklif Girişi ───────────────────────────────────
            Text(
              'Teklifinizi girin',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _manuelController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                prefixText: '₺ ',
                prefixStyle: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
                hintText: '0.00',
                filled: true,
                fillColor: AppColors.surfaceSecondary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.accent, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _showManuel = false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: const Text('Geri'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _gonderManuel,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Teklifi Gönder'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}