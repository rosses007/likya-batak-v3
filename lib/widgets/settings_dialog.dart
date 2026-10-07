import 'package:flutter/material.dart';
import '../services/sound_service.dart';
import '../providers/game_provider.dart';
import '../services/ad_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsDialog extends StatefulWidget {
  final List<String> currentNames;
  final bool sortAscending;
  final double gameSpeed;
  final int totalRounds;
  final BatakGameMode gameMode;
  final HandLayoutMode handLayoutMode;
  final TableColor tableColor;
  final AdService? adService;
  final Function({
    required List<String> names,
    required bool sortAscending,
    required double speed,
    required int rounds,
    required BatakGameMode mode,
    required HandLayoutMode layout,
    required TableColor color,
  }) onSave;

  const SettingsDialog({
    super.key,
    required this.currentNames,
    required this.sortAscending,
    required this.gameSpeed,
    required this.totalRounds,
    required this.gameMode,
    required this.handLayoutMode,
    required this.tableColor,
    required this.onSave,
    this.adService,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  AdService get _ads => widget.adService ?? AdService.instance;
  static final Uri _privacyPolicy = Uri.parse('https://likyabatak.netlify.app/privacy/');

  Future<void> _openPrivacyPolicy() async {
    try {
      if (!await launchUrl(_privacyPolicy, mode: LaunchMode.externalApplication)) {
        throw StateError('Browser unavailable');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gizlilik politikası açılamadı.')),
      );
    }
  }

  late List<TextEditingController> _nameControllers;
  late bool _sortAscending;
  late double _speed;
  late int _rounds;
  late BatakGameMode _gameMode;
  late HandLayoutMode _layoutMode;
  late TableColor _tableColor;

  bool _soundEnabled = SoundService.soundEnabled;
  double _volume = SoundService.volume * 100;

  @override
  void initState() {
    super.initState();
    _nameControllers = List.generate(
      4,
      (i) => TextEditingController(
        text: i < widget.currentNames.length ? widget.currentNames[i] : "Oyuncu ${i + 1}",
      ),
    );
    _sortAscending = widget.sortAscending;
    _speed = widget.gameSpeed;
    _rounds = widget.totalRounds;
    _gameMode = widget.gameMode;
    _layoutMode = widget.handLayoutMode;
    _tableColor = widget.tableColor;
  }

  @override
  void dispose() {
    for (var c in _nameControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1B4D24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF8D4925), width: 3),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: Text(
                  "AYARLAR & SEÇENEKLER",
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Oyun Modu (Tekli / Eşli)
              _buildRow(
                label: "Oyun Modu",
                child: _buildWoodContainer(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<BatakGameMode>(
                      value: _gameMode,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF6A3315),
                      isDense: true,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      items: const [
                        DropdownMenuItem(
                          value: BatakGameMode.single,
                          child: Text("Tekli İhaleli Batak"),
                        ),
                        DropdownMenuItem(
                          value: BatakGameMode.partner,
                          child: Text("Eşli Batak (Ortaklı)"),
                        ),
                        DropdownMenuItem(
                          value: BatakGameMode.kozMaca,
                          child: Text("Koz Maça (İhalesiz)"),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _gameMode = val);
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // Oyun Eli Sayısı (1'den 7'ye kadar)
              _buildRow(
                label: "Oyun Sayısı (Tur)",
                child: _buildWoodContainer(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _rounds,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF6A3315),
                      isDense: true,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      items: [1, 2, 3, 4, 5, 6, 7].map((count) {
                        return DropdownMenuItem(
                          value: count,
                          child: Text("$count El (Tur)"),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _rounds = val);
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // Kart Düzeni (Çapraz Yelpaze / İki Sıra)
              _buildRow(
                label: "Kart Düzeni",
                child: _buildWoodContainer(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<HandLayoutMode>(
                      value: _layoutMode,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF6A3315),
                      isDense: true,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      items: const [
                        DropdownMenuItem(
                          value: HandLayoutMode.fanned,
                          child: Text("Çapraz (Yelpaze)"),
                        ),
                        DropdownMenuItem(
                          value: HandLayoutMode.twoRow,
                          child: Text("İki Sıra (Katmanlı)"),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _layoutMode = val);
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // Masa Fon Rengi
              _buildRow(
                label: "Masa Fon Rengi",
                child: _buildWoodContainer(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<TableColor>(
                      value: _tableColor,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF6A3315),
                      isDense: true,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      items: const [
                        DropdownMenuItem(
                          value: TableColor.green,
                          child: Text("Zümrüt Yeşil Çuha"),
                        ),
                        DropdownMenuItem(
                          value: TableColor.blue,
                          child: Text("Kraliyet Mavisi"),
                        ),
                        DropdownMenuItem(
                          value: TableColor.red,
                          child: Text("Bordo Çuha"),
                        ),
                        DropdownMenuItem(
                          value: TableColor.dark,
                          child: Text("Kömür Siyahı"),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _tableColor = val);
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // Kart Dizme Şekli
              _buildRow(
                label: "Kart Sıralaması",
                child: _buildWoodContainer(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<bool>(
                      value: _sortAscending,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF6A3315),
                      isDense: true,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      items: const [
                        DropdownMenuItem(
                          value: true,
                          child: Text("Küçükten büyüğe"),
                        ),
                        DropdownMenuItem(
                          value: false,
                          child: Text("Büyükten küçüğe"),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _sortAscending = val);
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Oyun Hızı Slider
              _buildRow(
                label: "Oyun Hızı",
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF8D4925),
                    inactiveTrackColor: Colors.black38,
                    thumbColor: const Color(0xFFD4A373),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                  ),
                  child: Slider(
                    value: _speed,
                    min: 0.8,
                    max: 2.2,
                    divisions: 4,
                    onChanged: (val) => setState(() => _speed = val),
                  ),
                ),
              ),

              // Ses (Aç/Kapa ve Slider)
              Row(
                children: [
                  Checkbox(
                    value: _soundEnabled,
                    activeColor: const Color(0xFF8D4925),
                    checkColor: Colors.white,
                    onChanged: (val) {
                      setState(() {
                        _soundEnabled = val ?? true;
                        SoundService.soundEnabled = _soundEnabled;
                      });
                    },
                  ),
                  Text(
                    "Ses (${_volume.round()})",
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFF8D4925),
                        inactiveTrackColor: Colors.black38,
                        thumbColor: const Color(0xFFD4A373),
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                      ),
                      child: Slider(
                        value: _volume,
                        min: 0,
                        max: 100,
                        onChanged: _soundEnabled
                            ? (val) {
                                setState(() {
                                  _volume = val;
                                  SoundService.volume = val / 100;
                                });
                              }
                            : null,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Oyuncu İsimleri
              for (int i = 0; i < 4; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: _buildRow(
                    label: i == 0 ? "Oyuncu 1 (Siz)" : (widget.gameMode == BatakGameMode.partner && i == 2 ? "Oyuncu 3 (Eşiniz)" : "Oyuncu ${i + 1}"),
                    child: Container(
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8D4925),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF53240D)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.centerLeft,
                      child: TextField(
                        controller: _nameControllers[i],
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 12),

              TextButton.icon(
                onPressed: _openPrivacyPolicy,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Gizlilik Politikası'),
              ),
              AnimatedBuilder(
                animation: _ads,
                builder: (context, _) => _ads.privacyOptionsRequired
                    ? TextButton.icon(
                        onPressed: _ads.showPrivacyOptions,
                        icon: const Icon(Icons.privacy_tip_outlined),
                        label: const Text('Gizlilik Seçenekleri'),
                      )
                    : const SizedBox.shrink(),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B3212),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Color(0xFFD4A373), width: 1.5),
                  ),
                  elevation: 4,
                ),
                onPressed: () {
                  List<String> names = _nameControllers.map((c) => c.text.trim()).toList();
                  widget.onSave(
                    names: names,
                    sortAscending: _sortAscending,
                    speed: _speed,
                    rounds: _rounds,
                    mode: _gameMode,
                    layout: _layoutMode,
                    color: _tableColor,
                  );
                  Navigator.pop(context);
                },
                child: const Text(
                  "Kaydet ve Oyuna Dön",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  "Likya Batak • v1.2.0 (Build 3) • Kapalı Beta",
                  style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow({required String label, required Widget child}) {
    return Row(
      children: [
        SizedBox(
          width: 125,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: child),
      ],
    );
  }

  Widget _buildWoodContainer({required Widget child}) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF8D4925),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF53240D)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.centerLeft,
      child: child,
    );
  }
}
