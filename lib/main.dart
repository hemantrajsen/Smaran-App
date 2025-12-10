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

    // SAFETY CHECK: Are we still on this screen?
    if (!mounted) return;

    setState(() {
      _counter = _prefs?.getInt('counter') ?? 0;
      _malaCount = _prefs?.getInt('mala_count') ?? 0;
    });
  }

  Future<void> _saveData() async {
    final prefs = _prefs;
    // Guard clause: If prefs aren't loaded yet, don't try to save
    if (prefs == null) return;

    // Save both values in parallel (faster)
    await Future.wait([
      prefs.setInt('counter', _counter),
      prefs.setInt('mala_count', _malaCount),
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
        HapticFeedback.heavyImpact(); // Strong vibration
        await _audioPlayer.play(AssetSource('audio/bell.mp3')); // Ding!
      } else {
        HapticFeedback.lightImpact(); // Normal vibration
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
    setState(() {
      _counter = 0;
      if (resetMala) {
        _malaCount = 0;
      }
    });
    HapticFeedback.mediumImpact();
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
