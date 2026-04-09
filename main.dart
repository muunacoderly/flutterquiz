import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize SQLite Database
  final database = await initDatabase();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => QuizController(database)),
      ],
      child: const QuizMasterApp(),
    ),
  );
}

// --- DATABASE INITIALIZATION ---
Future<Database> initDatabase() async {
  String path = p.join(await getDatabasesPath(), 'quiz_master.db');
  return await openDatabase(
    path,
    version: 1,
    onCreate: (db, version) async {
      // Questions Table (Subject-wise 4,500 rows)
      await db.execute('''
        CREATE TABLE questions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          subject TEXT,
          difficulty TEXT,
          question_text TEXT,
          option_a TEXT,
          option_b TEXT,
          option_c TEXT,
          option_d TEXT,
          correct_index INTEGER,
          explanation TEXT
        )
      ''');
      // Profiles Table
      await db.execute('CREATE TABLE profiles (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, avatar TEXT)');
      // History/Sessions Table
      await db.execute('CREATE TABLE sessions (id INTEGER PRIMARY KEY AUTOINCREMENT, subject TEXT, score INTEGER, total INTEGER, date TEXT)');
    },
  );
}

// --- STATE & LOGIC CONTROLLER ---
class QuizController with ChangeNotifier {
  final Database db;
  bool isSeeding = false;
  double seedProgress = 0.0;

  QuizController(this.db);

  // Parse assets/questions.json and insert into SQLite
  Future<void> checkAndSeed() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('db_seeded') ?? false) return;

    isSeeding = true;
    notifyListeners();

    try {
      final String response = await rootBundle.loadString('assets/questions.json');
      final List<dynamic> data = json.decode(response);
      
      Batch batch = db.batch();
      for (int i = 0; i < data.length; i++) {
        var q = data[i];
        batch.insert('questions', {
          'subject': q['subject'],
          'difficulty': q['difficulty'] ?? 'easy',
          'question_text': q['question'],
          'option_a': q['options'][0],
          'option_b': q['options'][1],
          'option_c': q['options'][2],
          'option_d': q['options'][3],
          'correct_index': q['correctIndex'],
          'explanation': q['explanation'] ?? ''
        });
        
        // Commit in chunks of 500 for performance
        if (i % 500 == 0) {
          await batch.commit(noResult: true);
          batch = db.batch();
          seedProgress = i / data.length;
          notifyListeners();
        }
      }
      await batch.commit(noResult: true);
      await prefs.setBool('db_seeded', true);
    } catch (e) {
      debugPrint("Error seeding: $e");
    }

    isSeeding = false;
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> loadQuestions(String subject, int limit) async {
    return await db.query(
      'questions',
      where: 'subject = ?',
      whereArgs: [subject],
      orderBy: 'RANDOM()',
      limit: limit,
    );
  }

  Future<void> saveResult(String subject, int score, int total) async {
    await db.insert('sessions', {
      'subject': subject,
      'score': score,
      'total': total,
      'date': DateTime.now().toIso8601String(),
    });
  }
}

// --- UI LAYERS ---

class QuizMasterApp extends StatelessWidget {
  const QuizMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuizMaster Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.light),
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  _init() async {
    final controller = Provider.of<QuizController>(context, listen: false);
    await controller.checkAndSeed();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<QuizController>();
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.quiz_rounded, size: 100, color: Colors.deepPurple),
            const SizedBox(height: 24),
            if (controller.isSeeding) ...[
              const Text("Optimizing 4,500 Questions...", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(value: controller.seedProgress),
              ),
            ] else 
              const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  // 1. Remove 'const' from here
  HomeScreen({super.key}); 

  // 2. Ensure 'const' is NOT used before the [ bracket
  final List<Map<String, dynamic>> subjects = [
    {'name': 'Geography', 'icon': Icons.public, 'color': Colors.blue},
    {'name': 'History', 'icon': Icons.history_edu, 'color': Colors.brown},
    {'name': 'Political Science', 'icon': Icons.gavel, 'color': Colors.red},
    {'name': 'Physics', 'icon': Icons.bolt, 'color': Colors.orange},
    {'name': 'Biology', 'icon': Icons.biotech, 'color': Colors.green},
    {'name': 'Chemistry', 'icon': Icons.science, 'color': Colors.purple},
    {'name': 'Mathematics', 'icon': Icons.functions, 'color': Colors.indigo},
    {'name': 'General Knowledge', 'icon': Icons.psychology, 'color': Colors.teal},
    // Remember to use 'biotech' or 'science' instead of 'microscope'
    {'name': 'General Science', 'icon': Icons.biotech, 'color': Colors.blueGrey},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("QuizMaster Pro"), centerTitle: true),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, 
          crossAxisSpacing: 16, 
          mainAxisSpacing: 16
        ),
        itemCount: subjects.length,
        itemBuilder: (context, i) {
          return Card(
            clipBehavior: Clip.antiAlias,
            elevation: 4,
            child: InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QuizPlayScreen(subject: subjects[i]['name']))),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(subjects[i]['icon'], size: 50, color: subjects[i]['color']),
                  const SizedBox(height: 8),
                  Text(subjects[i]['name'], textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Text("500 Questions", style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class QuizPlayScreen extends StatefulWidget {
  final String subject;
  const QuizPlayScreen({super.key, required this.subject});

  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> {
  List<Map<String, dynamic>> questions = [];
  int currentIdx = 0;
  int score = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  _load() async {
    final list = await Provider.of<QuizController>(context, listen: false).loadQuestions(widget.subject, 10);
    setState(() {
      questions = list;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (questions.isEmpty) return const Scaffold(body: Center(child: Text("No questions found for this subject.")));

    final q = questions[currentIdx];

    return Scaffold(
      appBar: AppBar(title: Text("${widget.subject} (${currentIdx + 1}/10)")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(q['question_text'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            _buildOption(0, q['option_a']),
            _buildOption(1, q['option_b']),
            _buildOption(2, q['option_c']),
            _buildOption(3, q['option_d']),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(int index, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
        onPressed: () => _handleAnswer(index),
        child: Text(text, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  void _handleAnswer(int selected) {
    if (selected == questions[currentIdx]['correct_index']) score++;
    
    if (currentIdx < 9) {
      setState(() => currentIdx++);
    } else {
      Provider.of<QuizController>(context, listen: false).saveResult(widget.subject, score, 10);
      _showResult();
    }
  }

  void _showResult() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Quiz Finished!"),
        content: Text("Subject: ${widget.subject}\nScore: $score / 10"),
        actions: [
          TextButton(
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst), 
            child: const Text("Back to Home")
          )
        ],
      ),
    );
  }
}
