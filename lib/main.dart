import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui'; // <--- Required for ImageFilter
import 'package:audioplayers/audioplayers.dart';

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

class _HomeScreenState extends State<HomeScreen> {
  int _counter = 0; // The variable holding the count
  int _malaCount = 0;

  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _loadData(); // <--- Load saved data when app starts
  }

  // --- NEW: FUNCTION TO LOAD DATA ---
  // "async" means this might take a few milliseconds, don't freeze the UI
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Get the integer. If it doesn't exist (first time), return 0.
      _counter = prefs.getInt('counter') ?? 0;
      _malaCount = prefs.getInt('mala_count') ?? 0;
    });
  }

  // --- NEW: FUNCTION TO SAVE DATA ---
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('counter', _counter);
    await prefs.setInt('mala_count', _malaCount);
  }

  void _incrementCounter() {
    HapticFeedback.lightImpact(); // The bead feel

    setState(() {
      if (_counter < 108) {
        _counter++;

        if (_counter == 108) {
          _malaCount++;
          _counter = 0;
          _audioPlayer.play(AssetSource('audio/bell.mp3'));
          HapticFeedback.heavyImpact();
        } else {
          HapticFeedback.lightImpact();
        }
      } else {
        // ROUND COMPLETE!
        HapticFeedback.heavyImpact();
      }
    });
    _saveData(); // <--- SAVE TO DISK IMMEDIATELY
  }

  // Function to remove the last bead (Mistake correction)
  void _decrementCounter() {
    setState(() {
      if (_counter > 0) {
        _counter--;
        HapticFeedback.lightImpact();
      }
    });
    _saveData(); // <--- SAVE HERE TOO
  }

  // Function to wipe everything
  void _resetCounts() {
    setState(() {
      _counter = 0;

      HapticFeedback.mediumImpact();
    });
    _saveData(); // <--- SAVE the reset state TOO
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 1. KEY MAGIC: Allows the background image to flow BEHIND the header
      extendBodyBehindAppBar: true,

      appBar: AppBar(
        title: const Text(
          'Smaran',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color.fromARGB(105, 0, 0, 0),
          ),
        ),
        centerTitle: true,

        // 2. Make the standard color invisible
        backgroundColor: Colors.transparent,
        elevation: 0, // Removes the shadow
        // 3. The Glass Effect specifically for the Header
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              color: Colors.white.withOpacity(0.05), // Milky white tint
            ),
          ),
        ),

        // Your existing Reset/Undo buttons
        actions: [
          IconButton(
            onPressed: _resetCounts,
            icon: const Icon(Icons.refresh, color: Colors.brown),
            tooltip: 'Reset Round',
            onLongPress: () {
              setState(() {
                _counter = 0;
                _malaCount = 0;
                HapticFeedback.heavyImpact();
              });
              _saveData();
            },
          ),
        ],
      ),

      // Your existing Body code (Background Image + Glass Box + Counter)
      body: GestureDetector(
        onTap: _incrementCounter,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/background.jpeg'),
              fit: BoxFit.cover,
              // Adjust opacity if you want the image brighter/darker
              opacity: 0.58,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- Your Glass "Malas Completed" Box ---
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

              // --- Your Circle Counter ---
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 300,
                    height: 300,
                    child: CircularProgressIndicator(
                      value: _counter / 108,
                      backgroundColor: Colors.white.withOpacity(
                        0.44,
                      ), // Glassy track
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
                      const Text(
                        '/ 108',
                        style: TextStyle(fontSize: 24, color: Colors.black54),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 50),

              // --- Undo Button ---
              TextButton.icon(
                onPressed: _decrementCounter,
                icon: const Icon(Icons.undo, color: Colors.black54),
                label: const Text(
                  "Undo Last Bead",
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
