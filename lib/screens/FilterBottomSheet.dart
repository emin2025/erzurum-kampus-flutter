import 'package:erzurum_kampus/screens/FilterOptions.dart';
import 'package:erzurum_kampus/theme/app_colors.dart';
import 'package:flutter/material.dart';

// ════════════════════════════════════════════════════════════════════════════
//  FilterBottomSheet  —  Modern, glassmorphism + card layout
//  AppCategories ile tamamen uyumlu filtre seçenekleri
// ════════════════════════════════════════════════════════════════════════════

class FilterBottomSheet extends StatefulWidget {
  const FilterBottomSheet({
    super.key,
    required this.paylasimTuru,
    required this.currentFilter,
    required this.onApply,
    required this.onReset,
  });

  final String paylasimTuru;
  final FilterOptions currentFilter;
  final ValueChanged<FilterOptions> onApply;
  final VoidCallback onReset;

  static Future<void> show({
    required BuildContext context,
    required String paylasimTuru,
    required FilterOptions currentFilter,
    required ValueChanged<FilterOptions> onApply,
    required VoidCallback onReset,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => FilterBottomSheet(
        paylasimTuru: paylasimTuru,
        currentFilter: currentFilter,
        onApply: onApply,
        onReset: onReset,
      ),
    );
  }

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet>
    with SingleTickerProviderStateMixin {
  late FilterOptions _draft;
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _draft = widget.currentFilter.clone();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Map<String, List<String>> get _kategoriler =>
      FilterData.kategorilerForTur(widget.paylasimTuru);

  List<String> get _altKategoriler {
    if (_draft.kategori == null) return [];
    return _kategoriler[_draft.kategori] ?? [];
  }

  bool get _showEsyaDurumu => widget.paylasimTuru == PostType.ikinciEl;
  bool get _showAltKategori =>
      _draft.kategori != null && _altKategoriler.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: DraggableScrollableSheet(
        initialChildSize: 0.82,
        minChildSize: 0.5,
        maxChildSize: 0.96,
        snap: true,
        snapSizes: const [0.5, 0.82, 0.96],
        builder: (_, scrollCtrl) => _buildSheet(scrollCtrl),
      ),
    );
  }

  Widget _buildSheet(ScrollController scrollCtrl) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FE),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          _buildHeader(),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              children: [
                _buildUniversiteSection(),
                const SizedBox(height: 16),
                _buildKategoriSection(),
                if (_showAltKategori) ...[
                  const SizedBox(height: 16),
                  _buildAltKategoriSection(),
                ],
                if (_showEsyaDurumu) ...[
                  const SizedBox(height: 16),
                  _buildEsyaDurumuSection(),
                ],
                const SizedBox(height: 16),
                _buildHedefKitleSection(),
                const SizedBox(height: 16),
                _buildEtiketSection(),
                const SizedBox(height: 8),
              ],
            ),
          ),
          _buildActions(),
        ],
      ),
    );
  }

  // ── Handle ────────────────────────────────────────────────────────────────
  Widget _buildHandle() => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 8),
    child: Center(
      child: Container(
        width: 44, height: 5,
        decoration: BoxDecoration(
          color: const Color(0xFFDDE1EE),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    ),
  );

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final count = _draft.activeCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 20, 12),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filtrele',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1E1B4B), letterSpacing: -0.5),
                ),
                Text(
                  count == 0 ? 'Tüm ilanlar gösteriliyor' : '$count filtre aktif',
                  style: TextStyle(
                    fontSize: 12,
                    color: count > 0 ? const Color(0xFF6366F1) : const Color(0xFF94A3B8),
                    fontWeight: count > 0 ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (count > 0)
            GestureDetector(
              onTap: () {
                setState(() => _draft.reset());
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Temizle',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6366F1)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Üniversite ────────────────────────────────────────────────────────────
  Widget _buildUniversiteSection() {
    return _FilterCard(
      title: 'Üniversite',
      icon: Icons.school_rounded,
      iconColor: const Color(0xFF6366F1),
      child: _SegmentedPicker(
        options: FilterData.universiteler,
        selected: _draft.universite,
        labelBuilder: (u) {
          if (u.contains('Teknik')) return 'ETÜ';
          if (u.contains('Atatürk')) return 'ATA Üni.';
          return u;
        },
        onSelect: (v) => setState(() => _draft.universite = v),
      ),
    );
  }

  // ── Kategori ──────────────────────────────────────────────────────────────
  Widget _buildKategoriSection() {
    return _FilterCard(
      title: 'Kategori',
      icon: Icons.category_rounded,
      iconColor: const Color(0xFFF59E0B),
      child: _IconChipGrid(
        options: _kategoriler.keys.toList(),
        selected: _draft.kategori,
        onSelect: (v) => setState(() {
          _draft.kategori   = v;
          _draft.altKategori = null;
        }),
      ),
    );
  }

  // ── Alt Kategori ──────────────────────────────────────────────────────────
  Widget _buildAltKategoriSection() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      child: _FilterCard(
        title: 'Alt Kategori',
        icon: Icons.arrow_right_alt_rounded,
        iconColor: const Color(0xFF10B981),
        badge: _draft.kategori,
        child: _CompactChips(
          options: _altKategoriler,
          selected: _draft.altKategori,
          onSelect: (v) => setState(() => _draft.altKategori = v),
        ),
      ),
    );
  }

  // ── Eşya Durumu ───────────────────────────────────────────────────────────
  Widget _buildEsyaDurumuSection() {
    return _FilterCard(
      title: 'Eşya Durumu',
      icon: Icons.stars_rounded,
      iconColor: const Color(0xFFEC4899),
      child: _ConditionPicker(
        selected: _draft.esyaDurumu,
        onSelect: (v) => setState(() => _draft.esyaDurumu = v),
      ),
    );
  }

  // ── Hedef Kitle ───────────────────────────────────────────────────────────
  Widget _buildHedefKitleSection() {
    return _FilterCard(
      title: 'Hedef Kitle',
      icon: Icons.group_rounded,
      iconColor: const Color(0xFF14B8A6),
      child: _SegmentedPicker(
        options: FilterData.hedefKitleler,
        selected: _draft.hedefKitle,
        onSelect: (v) => setState(() => _draft.hedefKitle = v),
      ),
    );
  }

  // ── Etiket ────────────────────────────────────────────────────────────────
  Widget _buildEtiketSection() {
    return _FilterCard(
      title: 'Etikete Göre Ara',
      icon: Icons.local_offer_rounded,
      iconColor: const Color(0xFF8B5CF6),
      child: _EtiketInput(
        initialValue: _draft.etiket ?? '',
        onChanged: (v) => _draft.etiket = v.trim().toLowerCase(),
      ),
    );
  }

  // ── Alt Butonlar ──────────────────────────────────────────────────────────
  Widget _buildActions() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).padding.bottom + 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEF2FF), width: 1.5)),
      ),
      child: Row(
        children: [
          // Sıfırla
          GestureDetector(
            onTap: () {
              widget.onReset();
              Navigator.pop(context);
            },
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF64748B)),
                  SizedBox(width: 6),
                  Text('Sıfırla', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Uygula
          Expanded(
            child: GestureDetector(
              onTap: () {
                widget.onApply(_draft);
                Navigator.pop(context);
              },
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _draft.activeCount > 0 ? 'Uygula  •  ${_draft.activeCount}' : 'Uygula',
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  ALT BİLEŞENLER
// ════════════════════════════════════════════════════════════════════════════

// ── Kart sarmalayıcı ──────────────────────────────────────────────────────
class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
    this.badge,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: iconColor),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.3),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(badge!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: iconColor)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

// ── Segmented picker (2 seçenek için) ────────────────────────────────────
class _SegmentedPicker extends StatelessWidget {
  const _SegmentedPicker({
    required this.options,
    required this.selected,
    required this.onSelect,
    this.labelBuilder,
  });

  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelect;
  final String Function(String)? labelBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: options.map((opt) {
          final isSelected = opt == selected;
          final label = labelBuilder?.call(opt) ?? opt;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(isSelected ? null : opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: isSelected
                      ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))]
                      : [],
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? const Color(0xFF1E1B4B) : const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Kategori grid (2 sütun) ───────────────────────────────────────────────
class _IconChipGrid extends StatelessWidget {
  const _IconChipGrid({required this.options, required this.selected, required this.onSelect});

  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelect;

  static const _icons = <String, IconData>{
    'Elektronik':        Icons.devices_rounded,
    'Kitap / Kırtasiye': Icons.menu_book_rounded,
    'Giyim / Aksesuar':  Icons.checkroom_rounded,
    'Kimlik / Kart':     Icons.credit_card_rounded,
    'Spor / Outdoor':    Icons.sports_basketball_rounded,
    'Ev / Yaşam':        Icons.home_rounded,
    'Araç / Gereç':      Icons.build_rounded,
    'Anahtar / Kilit':   Icons.key_rounded,
    'Diğer':             Icons.more_horiz_rounded,
  };

  static const _colors = <String, Color>{
    'Elektronik':        Color(0xFF6366F1),
    'Kitap / Kırtasiye': Color(0xFFF59E0B),
    'Giyim / Aksesuar':  Color(0xFFEC4899),
    'Kimlik / Kart':     Color(0xFF14B8A6),
    'Spor / Outdoor':    Color(0xFF22C55E),
    'Ev / Yaşam':        Color(0xFF8B5CF6),
    'Araç / Gereç':      Color(0xFF64748B),
    'Anahtar / Kilit':   Color(0xFFEF4444),
    'Diğer':             Color(0xFF94A3B8),
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = opt == selected;
        final color = _colors[opt] ?? const Color(0xFF94A3B8);
        final icon  = _icons[opt]  ?? Icons.label_rounded;
        return GestureDetector(
          onTap: () => onSelect(isSelected ? null : opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? color : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : const Color(0xFFE8ECF4),
                width: 1.5,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: isSelected ? Colors.white : color),
                const SizedBox(width: 6),
                Text(
                  opt,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Kompakt metin chip'leri ───────────────────────────────────────────────
class _CompactChips extends StatelessWidget {
  const _CompactChips({required this.options, required this.selected, required this.onSelect});

  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = opt == selected;
        return GestureDetector(
          onTap: () => onSelect(isSelected ? null : opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF10B981) : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? const Color(0xFF10B981) : const Color(0xFFBBF7D0),
                width: 1.5,
              ),
            ),
            child: Text(
              opt,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF047857),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Eşya durumu kartları ──────────────────────────────────────────────────
class _ConditionPicker extends StatelessWidget {
  const _ConditionPicker({required this.selected, required this.onSelect});

  final String? selected;
  final ValueChanged<String?> onSelect;

  static const _items = [
    (raw: 'Sıfır',   emoji: '🌟', label: 'Sıfır',   color: Color(0xFF6366F1)),
    (raw: 'İyi',     emoji: '✅',  label: 'İyi',     color: Color(0xFF10B981)),
    (raw: 'Orta',    emoji: '🔶', label: 'Orta',    color: Color(0xFFF59E0B)),
    (raw: 'Hasarlı', emoji: '🔴', label: 'Hasarlı', color: Color(0xFFEF4444)),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _items.map((item) {
        final isSel = selected == item.raw;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(isSel ? null : item.raw),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: _items.last.raw == item.raw ? EdgeInsets.zero : const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSel ? item.color : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSel ? item.color : const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
                boxShadow: isSel
                    ? [BoxShadow(color: item.color.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))]
                    : [],
              ),
              child: Column(
                children: [
                  Text(item.emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSel ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Etiket metin girişi ───────────────────────────────────────────────────
class _EtiketInput extends StatefulWidget {
  const _EtiketInput({required this.initialValue, required this.onChanged});

  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  State<_EtiketInput> createState() => _EtiketInputState();
}

class _EtiketInputState extends State<_EtiketInput> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _ctrl,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.done,
      style: const TextStyle(fontSize: 14, color: Color(0xFF1E1B4B), fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: 'Örn: samsung, laptop, mont…',
        hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14),
        prefixIcon: const Icon(Icons.tag_rounded, size: 18, color: Color(0xFFCBD5E1)),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _ctrl,
          builder: (_, v, __) => v.text.isEmpty
              ? const SizedBox.shrink()
              : GestureDetector(
                  onTap: () {
                    _ctrl.clear();
                    widget.onChanged('');
                  },
                  child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFFCBD5E1)),
                ),
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2)),
        contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
      ),
    );
  }
}