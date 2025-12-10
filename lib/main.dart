import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui'; // <--- Required for ImageFilter
import 'package:audioplayers/audioplayers.dart';
import 'dart:math' as math;

// --- SECTION 1: The Entry Point (KEEP THIS) ---
// This turns on the engine.
void main() {
  runApp(const SmaranApp());
}

// --- SECTION 2: The App Setup (KEEP THIS) ---
// This sets up the theme and routing.
class SmaranApp extends StatelessWidget {
  const SmaranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smaran',
      theme: ThemeData(primarySwatch: Colors.orange, useMaterial3: true),
      // This line points to the HomeScreen below
      home: const HomeScreen(),
    );
  }
}

// --- SECTION 3: The Logic & UI (CHANGE THIS) ---
// We deleted the old 'Stateless' version and replaced it with this
// new 'Stateful' version so we can update the count.

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // --- 1. CONSTANTS ---
  // A single place to change the round size.
  static const int _roundSize = 108;

  // --- 2. VARIABLES ---
  int _counter = 0;
  int _malaCount = 0;

  // Cache the preferences so we don't look them up every time
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

  // --- 3. LIFECYCLE METHODS ---
  @override
  void initState() {
    super.initState();
    _initPrefs(); // Start loading data immediately
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _audioPlayer.dispose(); // CLEANUP: Free up memory when app closes
    super.dispose();
  }

  // --- 4. ASYNC LOGIC ---
  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    // 1. Load the raw data
    int savedCounter = _prefs?.getInt('counter') ?? 0;
    int savedMala = _prefs?.getInt('mala_count') ?? 0;
    String? lastDate = _prefs?.getString('last_active_date');

    // 2. Get Today's Date
    String today = DateTime.now().toString().split(' ')[0];

    // 3. THE SMART CHECK: Is today a new day?
    if (lastDate != null && lastDate != today && savedMala > 0) {
      // YES! It is a new day, and we have unsaved data from the past.

      String lastTime = _prefs?.getString('last_active_time') ?? "00:00";

      // A. Save old data to History
      List<String> history = _prefs?.getStringList('history_log') ?? [];
      // Save using Yesterday's Time
      history.insert(0, "$lastDate | $lastTime | $savedMala Malas (Auto-Saved)");

      await _prefs?.setStringList('history_log', history);

      // B. Reset for the fresh new day
      savedCounter = 0;
      savedMala = 0;

      // C. Tell the user what happened
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'New Day started! Yesterday\'s rounds saved to History. 🌅',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    }

    // 4. Update the UI with the final values
    setState(() {
      _counter = savedCounter;
      _malaCount = savedMala;
    });

    // 5. Ensure we mark today as active immediately
    await _saveData();
  }

  Future<void> _saveData() async {
    final prefs = _prefs;
    // Guard clause: If prefs aren't loaded yet, don't try to save
    if (prefs == null) return;

    // Get Today's Date (Format: YYYY-MM-DD)
    String today = DateTime.now().toString().split(' ')[0];

    final now = DateTime.now();
    String time = "${now.hour}:${now.minute.toString().padLeft(2, '0')}";

    // Save both values in parallel (faster)
    await Future.wait([
      prefs.setInt('counter', _counter),
      prefs.setInt('mala_count', _malaCount),
      prefs.setString('last_active_date', today),
      prefs.setString('last_active_time', time),
    ]);
  }

  // --- 5. ACTION FUNCTIONS ---
  Future<void> _incrementCounter() async {
    // 1. If we are currently BELOW 108...
    if (_counter < _roundSize) {
      setState(() {
        _counter++; // Increment to 108
      });

      // 2. Did we JUST hit 108?
      if (_counter == _roundSize) {
        setState(() {
          _malaCount++; // Credit the Mala immediately
        });

        bool vibe = _prefs?.getBool('isVibrationOn') ?? true;
        bool sound = _prefs?.getBool('isSoundOn') ?? true;

        if (vibe) HapticFeedback.heavyImpact(); // Strong vibration
        if (sound)
          await _audioPlayer.play(AssetSource('audio/bell.mp3')); // Ding!
      } else {
        bool vibe = _prefs?.getBool('isVibrationOn') ?? true;
        if (vibe) HapticFeedback.lightImpact();
      }
    }
    // 3. If we are SITTING AT 108, the next tap starts a new round
    else {
      setState(() {
        _counter = 1; // Start fresh at 1
      });
      HapticFeedback.lightImpact();
    }

    await _saveData();
  }

  Future<void> _decrementCounter() async {
    if (_counter == 0) return; // Boundary check

    setState(() {
      _counter--;
    });
    HapticFeedback.lightImpact();
    await _saveData();
  }

  // Unified Reset Function
  Future<void> _resetCounts({bool resetMala = false}) async {
    if (resetMala) {
      final prefs = _prefs;
      // Check if we have rounds to save
      if (prefs != null && _malaCount > 0) {
        List<String> history = prefs.getStringList('history_log') ?? [];
        
        // 1. Get Date
        String date = DateTime.now().toString().split(' ')[0];
        
        // 2. Get Time (Right Now)
        final now = DateTime.now();
        String time = "${now.hour}:${now.minute.toString().padLeft(2, '0')}";

        // 3. THE FIX: Create the string with THREE parts (Date | Time | Count)
        // Previous code might have been missing the middle part!
        String entry = "$date | $time | $_malaCount Malas"; 

        // 4. Save to list
        history.insert(0, entry);
        await prefs.setStringList('history_log', history);
      }
    }

    // Reset the counters on screen
    setState(() {
      _counter = 0;
      if (resetMala) {
        _malaCount = 0;
      }
    });
    
    // Haptic Feedback check
    bool vibe = _prefs?.getBool('isVibrationOn') ?? true;
    if (vibe) HapticFeedback.mediumImpact();
    
    // Save the "0" state to memory
    await _saveData();
  }

  // Shake + hint when user taps expecting a full wipe
  Future<void> _triggerShakeHint() async {
    if (_shakeCtrl.isAnimating) return;
    _shakeCtrl.forward(from: 0);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Hold tight to Reset all Malas Completed!!!📿'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- 6. THE UI (Your Existing Design) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: Drawer(
        child: Container(
          color: Colors.white, // Background color of the drawer
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // 1. The Header (Profile/App Info)
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(
                  color: Colors.deepOrange, // Saffron header
                  image: DecorationImage(
                    image: AssetImage(
                      'assets/images/background.jpeg',
                    ), // Reusing your bg
                    fit: BoxFit.cover,
                    opacity: 0.5,
                  ),
                ),
                accountName: const Text(
                  "Hare Krishna",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                accountEmail: const Text(
                  "Keep Chanting...",
                  style: TextStyle(color: Colors.white70),
                ),
              ),

              // 2. Menu Items
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
                  );
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
                  );
                },
              ),
              const Divider(), // A thin line separator

              ListTile(
                leading: const Icon(
                  Icons.delete_forever,
                  color: Colors.redAccent,
                ),
                title: const Text('Reset Everything'),
                onTap: () async {
                  Navigator.pop(context); // Close drawer first
                  await _resetCounts(resetMala: true); // Call your reset logic
                  await _triggerShakeHint();
                },
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: const Text(
          'Smaran',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: Container(color: Colors.white.withOpacity(0.05)),
          ),
        ),
        actions: [
          AnimatedBuilder(
            animation: _shakeAnim,
            builder: (context, child) {
              final dx =
                  math.sin(_shakeAnim.value * math.pi * 8) * 6; // small wiggle
              return Transform.translate(offset: Offset(dx, 0), child: child);
            },
            child: IconButton(
              // Short Press: reset beads + warn that long-press clears all
              onPressed: () async {
                await _resetCounts(resetMala: false);
                await _triggerShakeHint();
              },
              icon: const Icon(
                Icons.refresh,
                color: Color.fromARGB(210, 0, 0, 0),
              ),
              tooltip:
                  'Tap: reset round. Long-press: reset round + total malas.',
              // Long Press: clear everything
              onLongPress: () => _resetCounts(resetMala: true),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => _incrementCounter(),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/background.jpeg'),
              fit: BoxFit.cover,
              opacity: 0.8,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Glass Box
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Malas Completed: ",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          "$_malaCount",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Circle Progress
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 300,
                    height: 300,
                    child: CircularProgressIndicator(
                      // Uses the constant now!
                      value: _counter / _roundSize,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      color: Colors.deepOrange,
                      strokeWidth: 20,
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$_counter',
                        style: const TextStyle(
                          fontSize: 80,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),
                      Text(
                        '/ $_roundSize', // Uses the constant
                        style: TextStyle(fontSize: 24, color: Colors.black54),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 50),

              // Undo Button
              TextButton.icon(
                onPressed: () => _decrementCounter(),
                icon: const Icon(
                  Icons.undo,
                  color: Color.fromARGB(210, 0, 0, 0),
                ),
                label: const Text(
                  "Undo Last Bead",
                  style: TextStyle(color: Color.fromARGB(210, 0, 0, 0)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- NEW HISTORY SCREEN CLASS ---
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<String> _pastHistory = [];
  int _todayMalaCount = 0;
  String _lastActiveTime = "--:--"; // <--- New Variable

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
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('history_log');
              setState(() => _pastHistory = []);
            },
          )
        ],
      ),
      body: ListView.builder(
        itemCount: _pastHistory.length + 1,
        itemBuilder: (context, index) {
          // --- TODAY'S ROW ---
          if (index == 0) {
            return Card(
              color: Colors.orange[50],
              margin: const EdgeInsets.all(8.0),
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.whatshot, color: Colors.deepOrange),
                title: const Text(
                  "Today (In Progress)",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange),
                ),
                subtitle: Text(
                  "$_todayMalaCount Malas • Last active: $_lastActiveTime",
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            );
          }

          // --- HISTORY ROWS ---
          final historyIndex = index - 1;
          final rawString = _pastHistory[historyIndex];
          final parts = rawString.split('|');

          // Safety Check: Handle old data format vs new format
          String date = parts[0].trim();
          String time = "";
          String count = "";

          if (parts.length >= 3) {
            // New Format: Date | Time | Count
            time = parts[1].trim();
            count = parts[2].trim();
          } else if (parts.length == 2) {
            // Old Format: Date | Count (Backward compatibility)
            time = "Unknown";
            count = parts[1].trim();
          }

          return ListTile(
            leading: const Icon(Icons.history_edu, color: Colors.grey),
            title: Text(date, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text("$time  •  ", style: TextStyle(color: Colors.grey[800])),
                Text(count, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// --- Settings Class --
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 1. Variables with Defaults
  bool _isVibrationOn = true;
  bool _isSoundOn = true;
  double _targetRounds = 16;

  @override
  void initState() {
    super.initState();
    _loadSettings(); // <--- Load saved settings when screen opens
  }

  // 2. Load Data Function
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isVibrationOn = prefs.getBool('isVibrationOn') ?? true;
      _isSoundOn = prefs.getBool('isSoundOn') ?? true;
      _targetRounds = (prefs.getInt('targetRounds') ?? 16).toDouble();
    });
  }

  // 3. Save Data Function (Updates instantly)
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
            activeColor: Colors.deepOrange,
            onChanged: (val) {
              setState(() => _isVibrationOn = val);
              _updateSetting('isVibrationOn', val); // <--- SAVES TO MEMORY
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up),
            title: const Text("Chant Sound"),
            value: _isSoundOn,
            activeColor: Colors.deepOrange,
            onChanged: (val) {
              setState(() => _isSoundOn = val);
              _updateSetting('isSoundOn', val); // <--- SAVES TO MEMORY
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.flag),
            title: const Text("Daily Target"),
            subtitle: Text("Goal: ${_targetRounds.round()} Rounds"),
          ),
          Slider(
            value: _targetRounds,
            min: 1,
            max: 64,
            divisions: 63,
            activeColor: Colors.deepOrange,
            label: _targetRounds.round().toString(),
            onChanged: (val) {
              setState(() => _targetRounds = val);
              _updateSetting('targetRounds', val); // <--- SAVES TO MEMORY
            },
          ),
        ],
      ),
    );
  }
}
