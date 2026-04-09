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
  final db = await initDatabase();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider(db)),
      ],
      child: const QuizMasterApp(),
    ),
  );
}

// --- DATABASE LOGIC ---
Future<Database> initDatabase() async {
  String path = p.join(await getDatabasesPath(), 'quizmaster.db');
  return await openDatabase(
    path,
    version: 1,
    onCreate: (db, version) async {
      await db.execute('CREATE TABLE profiles (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, avatar TEXT)');
      await db.execute('CREATE TABLE questions (id INTEGER PRIMARY KEY, subject TEXT, difficulty TEXT, question_text TEXT, option_a TEXT, option_b TEXT, option_c TEXT, option_d TEXT, correct_index INTEGER, explanation TEXT)');
      await db.execute('CREATE TABLE sessions (id INTEGER PRIMARY KEY AUTOINCREMENT, profile_id INTEGER, subject TEXT, score INTEGER, total INTEGER, date TEXT)');
    },
  );
}

// --- STATE MANAGEMENT ---
class AppProvider extends ChangeNotifier {
  final Database db;
  Map<String, dynamic>? activeProfile;
  
  AppProvider(this.db);

  Future<void> seedQuestions() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('seeded') ?? false) return;

    final String response = await rootBundle.loadString('assets/questions.json');
    final List<dynamic> data = json.decode(response);
    
    Batch batch = db.batch();
    for (var q in data) {
      batch.insert('questions', {
        'subject': q['subject'],
        'difficulty': q['difficulty'],
        'question_text': q['question'],
        'option_a': q['options'][0],
        'option_b': q['options'][1],
        'option_c': q['options'][2],
        'option_d': q['options'][3],
        'correct_index': q['correctIndex'],
        'explanation': q['explanation']
      });
    }
    await batch.commit(noResult: true);
    await prefs.setBool('seeded', true);
  }

  Future<List<Map<String, dynamic>>> getQuestions(String subject, String diff, int limit) async {
    return await db.query('questions', 
      where: 'subject = ? AND difficulty = ?', 
      whereArgs: [subject, diff], 
      orderBy: 'RANDOM()', 
      limit: limit);
  }
}

// --- UI COMPONENTS ---
class QuizMasterApp extends StatelessWidget {
  const QuizMasterApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
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
    _bootstrap();
  }

  _bootstrap() async {
    await Provider.of<AppProvider>(context, listen: false).seedQuestions();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  final List<String> subjects = const [
    'Geography', 'History', 'Political Science', 'Physics', 'Biology', 'Chemistry', 'Mathematics', 'General Knowledge', 'General Science'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("QuizMaster Pro"), centerTitle: true),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10),
        itemCount: subjects.length,
        itemBuilder: (context, i) => Card(
          elevation: 4,
          child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QuizScreen(subject: subjects[i]))),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.school, size: 40, color: Colors.indigo),
                const SizedBox(height: 10),
                Text(subjects[i], style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class QuizScreen extends StatefulWidget {
  final String subject;
  const QuizScreen({super.key, required this.subject});
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<Map<String, dynamic>> questions = [];
  int currentIdx = 0;
  int score = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  _load() async {
    questions = await Provider.of<AppProvider>(context, listen: false).getQuestions(widget.subject, 'easy', 10);
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final q = questions[currentIdx];
    return Scaffold(
      appBar: AppBar(title: Text("${widget.subject} (${currentIdx + 1}/10)")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(q['question_text'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ...['a', 'b', 'c', 'd'].map((opt) {
              int idx = ['a', 'b', 'c', 'd'].indexOf(opt);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  onPressed: () {
                    if (idx == q['correct_index']) score++;
                    if (currentIdx < 9) {
                      setState(() => currentIdx++);
                    } else {
                      _showResult();
                    }
                  },
                  child: Text(q['option_$opt']),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  _showResult() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Quiz Complete!"),
        content: Text("You scored $score out of 10"),
        actions: [TextButton(onPressed: () => Navigator.popUntil(context, (r) => r.isFirst), child: const Text("Finish"))],
      ),
    );
  }
}
