// --- IMPORTS ---
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'dart:math' as math;
import 'package:package_info_plus/package_info_plus.dart';

// --- CONSTANTS & THEME ---
const Color kSaffron = Color(0xFFFF9933);

void main() {
  runApp(const SmaranApp());
}

class SmaranApp extends StatelessWidget {
  const SmaranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smaran',
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: kSaffron,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kSaffron,
          brightness: Brightness.light,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// --- HOME SCREEN ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // --- VARIABLES ---

  int _targetSankalpa = 16; // Default to 16
  static const int _roundSize = 108;
  int _counter = 0;
  int _malaCount = 0;
  bool _isFocusModeOn = false;

  // The Active Mantra to display in the header
  String _drawerMantra = "Hare Krishna";

  SharedPreferences? _prefs;
  final AudioPlayer _audioPlayer = AudioPlayer();
  late final AnimationController _shakeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  late final Animation<double> _shakeAnim = CurvedAnimation(
    parent: _shakeCtrl,
    curve: Curves.elasticIn,
  );

  @override
  void initState() {
    super.initState();
    _initPrefs();
    // Preload audio for instant playback
    _audioPlayer.setSource(AssetSource('audio/bell.mp3'));
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    // Load Counter Data
    int savedCounter = _prefs?.getInt('counter') ?? 0;
    int savedMala = _prefs?.getInt('mala_count') ?? 0;
    String? lastDate = _prefs?.getString('last_active_date');
    String today = DateTime.now().toString().split(' ')[0];

    // New Day Logic: Reset if date changed
    if (lastDate != null && lastDate != today && savedMala > 0) {
      String lastTime = _prefs?.getString('last_active_time') ?? "00:00";
      List<String> history = _prefs?.getStringList('history_log') ?? [];
      history.insert(
        0,
        "$lastDate | $lastTime | $savedMala Malas (Auto-Saved)",
      );
      await _prefs?.setStringList('history_log', history);
      savedCounter = 0;
      savedMala = 0;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New Day started! Yesterday saved to History. 🌅'),
          backgroundColor: Colors.green,
        ),
      );
    }

    setState(() {
      _counter = savedCounter;
      _malaCount = savedMala;
      _isFocusModeOn = _prefs?.getBool('isFocusModeOn') ?? false;
      // Load the active mantra from storage
      _drawerMantra = _prefs?.getString('active_mantra') ?? "Hare Krishna";
      _targetSankalpa = _prefs?.getInt('targetRounds') ?? 16;
    });

    await _saveData();
  }

  // Helper to refresh just the drawer info when returning from MantraScreen
  Future<void> _refreshDrawer() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _drawerMantra = prefs.getString('active_mantra') ?? "Hare Krishna";
    });
  }

  Future<void> _saveData() async {
    final prefs = _prefs;
    if (prefs == null) return;
    String today = DateTime.now().toString().split(' ')[0];
    final now = DateTime.now();
    int hour12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
    String amPm = now.hour >= 12 ? 'PM' : 'AM';
    String time = "$hour12:${now.minute.toString().padLeft(2, '0')} $amPm";

    await Future.wait([
      prefs.setInt('counter', _counter),
      prefs.setInt('mala_count', _malaCount),
      prefs.setString('last_active_date', today),
      prefs.setString('last_active_time', time),
    ]);
  }

  Future<void> _incrementCounter() async {
    if (_counter < _roundSize) {
      setState(() => _counter++);
      if (_counter == _roundSize) {
        setState(() => _malaCount++);
        bool vibe = _prefs?.getBool('isVibrationOn') ?? true;
        bool sound = _prefs?.getBool('isSoundOn') ?? true;
        if (vibe) HapticFeedback.heavyImpact();
        if (sound) {
          try {
            await _audioPlayer.stop();
            await _audioPlayer.play(AssetSource('audio/bell.mp3'));
          } catch (e) {
            debugPrint('Audio error: $e');
          }
        }
      } else {
        bool vibe = _prefs?.getBool('isVibrationOn') ?? true;
        if (vibe) HapticFeedback.lightImpact();
      }
    } else {
      setState(() => _counter = 1);
      bool vibe = _prefs?.getBool('isVibrationOn') ?? true;
      if (vibe) HapticFeedback.lightImpact();
    }
    await _saveData();
  }

  Future<void> _decrementCounter() async {
    if (_counter == 0) return;
    setState(() => _counter--);
    bool vibe = _prefs?.getBool('isVibrationOn') ?? true;
    if (vibe) HapticFeedback.lightImpact();
    await _saveData();
  }

  Future<void> _resetCounts({bool resetMala = false}) async {
    if (resetMala && _malaCount > 0) {
      final prefs = _prefs;
      List<String> history = prefs?.getStringList('history_log') ?? [];
      String date = DateTime.now().toString().split(' ')[0];
      final now = DateTime.now();
      int hour12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
      String amPm = now.hour >= 12 ? 'PM' : 'AM';
      String time = "$hour12:${now.minute.toString().padLeft(2, '0')} $amPm";
      history.insert(0, "$date | $time | $_malaCount Malas");
      await prefs?.setStringList('history_log', history);
    }
    setState(() {
      _counter = 0;
      if (resetMala) _malaCount = 0;
    });
    await _saveData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: Drawer(
        child: Container(
          color: Colors.white,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // --- UPDATED DRAWER HEADER ---
              // Uses a Custom Container instead of UserAccountsDrawerHeader to utilize full space
              Container(
                height: 240, // Taller to fit mantra
                decoration: const BoxDecoration(
                  color: Color.fromARGB(255, 255, 231, 194),
                  image: DecorationImage(
                    image: AssetImage('assets/images/another.jpeg'),
                    fit: BoxFit.cover,
                    opacity: 0.5,
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Small Label
                        const Text(
                          "Current Sankalpa:",
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // The Mantra Text - Expanded to fill space
                        Expanded(
                          child: Center(
                            child: SingleChildScrollView(
                              child: Text(
                                _drawerMantra,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.eagleLake(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.black87,
                                  height: 1.2,
                                  shadows: [
                                    const Shadow(
                                      blurRadius: 2,
                                      color: Colors.white,
                                      offset: Offset(1, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Focus Mode Switch
              SwitchListTile(
                secondary: Icon(
                  _isFocusModeOn ? Icons.visibility_off : Icons.visibility,
                  color: Colors.deepOrange,
                ),
                title: const Text('Focus Mode'),
                subtitle: const Text('Hide counter for deeper meditation'),
                value: _isFocusModeOn,
                activeThumbColor: Colors.deepOrange,
                onChanged: (val) async {
                  setState(() => _isFocusModeOn = val);
                  await _prefs?.setBool('isFocusModeOn', val);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
              ),

              // --- MANTRA LIBRARY ROW ---
              ListTile(
                leading: const Icon(
                  Icons.record_voice_over,
                  color: Colors.black87,
                ),
                title: const Text('Mantra Library'),
                subtitle: const Text('Set your active prayer'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MantraScreen(),
                    ),
                  ).then(
                    (_) => _refreshDrawer(),
                  ); // Refresh header when returning
                },
              ),

              ListTile(
                leading: const Icon(Icons.history, color: Colors.black87),
                title: const Text('History'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HistoryScreen(),
                    ),
                  ).then((_) => _initPrefs());
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings, color: Colors.black87),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  ).then((_) => _initPrefs());
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.delete_forever,
                  color: Colors.redAccent,
                ),
                title: const Text('Reset Everything'),
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Reset Everything?'),
                      content: const Text(
                        'This will save your current malas to history and reset the counter to zero.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text(
                            'Reset',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) await _resetCounts(resetMala: true);
                },
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: Column(
          mainAxisSize:
              MainAxisSize.min, // 1. Hugs the text vertically (doesn't stretch)
          crossAxisAlignment:
              CrossAxisAlignment.center, // 2. Forces children to be centered

          children: [
            Text(
              'Smaran',
              style: GoogleFonts.eagleLake(
                fontWeight: FontWeight.bold,
                color: const Color.fromARGB(239, 243, 242, 242),
              ),
            ),
            // The tiny subtitle showing "4 / 16"
            Text(
              "   $_malaCount / $_targetSankalpa 📿",
              style: GoogleFonts.lato(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: const Color.fromARGB(180, 255, 255, 255),
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),

        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: Container(color: Colors.white.withValues(alpha: 0.03)),
          ),
        ),

        // ...existing code...
        actions: [
          AnimatedBuilder(
            animation: _shakeAnim,
            builder: (context, child) {
              final dx = math.sin(_shakeAnim.value * math.pi * 8) * 6;
              return Transform.translate(offset: Offset(dx, 0), child: child);
            },
            child: GestureDetector(
              onLongPress: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Reset Everything?'),
                    content: const Text(
                      'Save current malas to history and reset to zero?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          'Reset',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _resetCounts(resetMala: true);
                }
              },
              child: IconButton(
                onPressed: () async {
                  await _resetCounts(resetMala: false);
                  if (!context.mounted) return;
                  if (_shakeCtrl.isAnimating) return;
                  _shakeCtrl.forward(from: 0);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Long press to Reset all Malas! 📿'),
                      duration: Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(
                  Icons.refresh,
                  color: Color.fromARGB(239, 243, 242, 242),
                ),
              ),
            ),
          ),
        ],

        // ...existing code...
      ),
      // Replace the entire body: GestureDetector(...) block with this:
      body: GestureDetector(
        onTap: () => _incrementCounter(),
        child: Stack(
          children: [
            // --- LAYER 1: Background Image ---
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: const AssetImage('assets/images/background.jpeg'),
                  fit: BoxFit.cover,
                  opacity: _isFocusModeOn ? 1.0 : 0.92,
                ),
              ),
            ),

            // --- LAYER 2: The Vignette (Subtle Dark Edges) ---
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Colors.transparent, // Center: Show the image clearly
                    Colors.black.withValues(alpha: 0.4), // Edges: Darken nicely
                  ],
                  center: Alignment.center,
                  radius:
                      1.1, // How wide the clear spot is (1.1 reaches corners)
                  stops: const [0.5, 1.0], // Start darkening halfway out
                ),
              ),
            ),

            // --- LAYER 3: The UI Content (Circle, Text, Buttons) ---
            SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_isFocusModeOn) ...[
                    const Spacer(flex: 2),
                    // Malas Completed Box
                    ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(56, 255, 255, 255),
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Malas Completed: ",
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                "$_malaCount",
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color.fromARGB(239, 243, 242, 242),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // The Progress Circle
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 300,
                          height: 300,
                          child: CircularProgressIndicator(
                            value: _counter / _roundSize,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.3,
                            ),
                            color: kSaffron,
                            strokeWidth: 20,
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$_counter',
                              style: const TextStyle(
                                fontSize: 90,
                                fontWeight: FontWeight.w600,
                                color: kSaffron,
                              ),
                            ),
                            const Text(
                              '/ 108',
                              style: TextStyle(
                                fontSize: 24,
                                color: Color.fromARGB(192, 255, 255, 255),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(flex: 2),
                  ] else ...[
                    const Spacer(),
                  ],
                  // Undo Button
                  TextButton.icon(
                    onPressed: () => _decrementCounter(),
                    icon: const Icon(
                      Icons.undo,
                      color: Color.fromARGB(210, 255, 255, 255),
                    ),
                    label: Text(
                      "Undo Last Bead",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: const Color.fromARGB(210, 255, 255, 255),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (_isFocusModeOn) const SizedBox(height: 50),
                  if (!_isFocusModeOn) const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- NEW MANTRA LIBRARY SCREEN ---
class MantraScreen extends StatefulWidget {
  const MantraScreen({super.key});

  @override
  State<MantraScreen> createState() => _MantraScreenState();
}

class _MantraScreenState extends State<MantraScreen> {
  List<String> _mantraList = [];
  String _activeMantra = "";

  @override
  void initState() {
    super.initState();
    _loadMantras();
  }

  Future<void> _loadMantras() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _mantraList =
          prefs.getStringList('saved_mantras') ??
          [
            "Hare Krishna Hare Krishna\nKrishna Krishna Hare Hare\nHare Rama Hare Rama\nRama Rama Hare Hare",
            "Jaya Sri Krishna Caitanya\nPrabhu Nityananda\nSri Advaita Gadadhara\nSrivasadi Gaura Bhakta Vrinda",
            "Om Namo Bhagavate Vasudevaya",
          ];
      _activeMantra = prefs.getString('active_mantra') ?? "Hare Krishna";
    });
  }

  // --- UPDATED: Shows Popup instead of SnackBar ---
  Future<void> _setActiveMantra(String mantra) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_mantra', mantra);
    setState(() {
      _activeMantra = mantra;
    });

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Updated"),
        content: const Text("Mantra is now displayed on the Drawer"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK", style: TextStyle(color: kSaffron)),
          ),
        ],
      ),
    );
  }

  void _showAddDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add New Mantra"),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "Enter mantra text here...",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                setState(() => _mantraList.add(controller.text));
                final prefs = await SharedPreferences.getInstance();
                await prefs.setStringList('saved_mantras', _mantraList);
                if (!context.mounted) return;
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kSaffron,
              foregroundColor: Colors.white,
            ),
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mantra Library"),
        backgroundColor: Colors.orange[50],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: kSaffron,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _mantraList.isEmpty
          ? const Center(
              child: Text(
                'No mantras yet.\nTap + to add one!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _mantraList.length,
              itemBuilder: (context, index) {
                final mantra = _mantraList[index];
                final isActive = mantra == _activeMantra;
                return Card(
                  elevation: isActive ? 4 : 1,
                  shape: RoundedRectangleBorder(
                    side: isActive
                        ? const BorderSide(color: kSaffron, width: 2)
                        : BorderSide.none,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => _setActiveMantra(mantra),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(
                            isActive
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: isActive ? kSaffron : Colors.grey,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              mantra,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isActive
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          if (!isActive)
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.grey,
                              ),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete Mantra?'),
                                    content: const Text(
                                      'This cannot be undone.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  setState(() => _mantraList.removeAt(index));
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.setStringList(
                                    'saved_mantras',
                                    _mantraList,
                                  );
                                }
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// --- HISTORY SCREEN ---
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<String> _pastHistory = [];
  int _todayMalaCount = 0;
  String _lastActiveTime = "--:--";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pastHistory = prefs.getStringList('history_log') ?? [];
      _todayMalaCount = prefs.getInt('mala_count') ?? 0;
      _lastActiveTime = prefs.getString('last_active_time') ?? "--:--";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chanting History"),
        backgroundColor: Colors.orange[50],
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.red),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear History?'),
                  content: const Text(
                    'This will delete all past records. This cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('history_log');
                setState(() => _pastHistory = []);
              }
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _pastHistory.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Card(
              color: Colors.orange[50],
              margin: const EdgeInsets.all(8.0),
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.whatshot, color: Colors.deepOrange),
                title: const Text(
                  "Today (In Progress)",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
                  ),
                ),
                subtitle: Text(
                  "$_todayMalaCount Malas • Last active: $_lastActiveTime",
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            );
          }
          final historyIndex = index - 1;
          final rawString = _pastHistory[historyIndex];
          final parts = rawString.split('|');
          String date = parts[0].trim();
          String time = "";
          String count = "";

          if (parts.length >= 3) {
            time = parts[1].trim();
            count = parts[2].trim();
          } else if (parts.length == 2) {
            time = "Unknown";
            count = parts[1].trim();
          }

          return ListTile(
            leading: const Icon(Icons.history_edu, color: Colors.grey),
            title: Text(
              date,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    "$time  •  $count",
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// --- SETTINGS SCREEN ---
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isVibrationOn = true;
  bool _isSoundOn = true;
  double _targetRounds = 16;
  String _appVersion = "Loading...";

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    setState(() {
      // This creates "Version 1.0.0 (Build 1)"
      _appVersion = "Version ${info.version} (${info.buildNumber})";
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isVibrationOn = prefs.getBool('isVibrationOn') ?? true;
      _isSoundOn = prefs.getBool('isSoundOn') ?? true;
      _targetRounds = (prefs.getInt('targetRounds') ?? 16).toDouble();
    });
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is double) {
      await prefs.setInt(key, value.toInt());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: Colors.orange[50],
      ),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.vibration),
            title: const Text("Haptic Feedback"),
            value: _isVibrationOn,
            activeThumbColor: Colors.deepOrange,
            onChanged: (val) {
              setState(() => _isVibrationOn = val);
              _updateSetting('isVibrationOn', val);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up),
            title: const Text("Chant Sound"),
            value: _isSoundOn,
            activeThumbColor: Colors.deepOrange,
            onChanged: (val) {
              setState(() => _isSoundOn = val);
              _updateSetting('isSoundOn', val);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.flag),
            title: const Text("Daily Sankalpa"),
            subtitle: Text("Goal: ${_targetRounds.round()} Rounds"),
            trailing: const Icon(Icons.edit, color: Colors.grey),
            onTap: () async {
              final controller = TextEditingController(
                text: _targetRounds.round().toString(),
              );
              final result = await showDialog<int>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Set Daily Sankalpa'),
                  content: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Enter number of rounds',
                      suffixText: 'rounds',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        final value = int.tryParse(controller.text);
                        if (value != null && value > 0) {
                          Navigator.pop(ctx, value);
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              );
              if (result != null) {
                setState(() => _targetRounds = result.toDouble());
                _updateSetting('targetRounds', result.toDouble());
              }
            },
          ),
          const SizedBox(height: 20), // Spacing
          // THE VERSION ROW
          Center(
            child: Text(
              _appVersion,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
