# flutterquiz
Interactive Quiz App
# QuizMaster Pro
### Production App Development Plan — Flutter & SQLite
**University of Delhi | NEP UGCF 2022 | [cite_start]APP Development using Flutter** [cite: 3, 119]

[cite_start]QuizMaster Pro is a high-performance, offline-first educational platform designed to provide a comprehensive testing environment across nine academic subjects[cite: 4, 104]. [cite_start]Featuring a robust multi-profile system and an optimized SQLite backend, the app manages a massive bank of 4,500 questions with seamless performance[cite: 1, 4, 12].

## 🚀 Features

* **Massive Question Bank:** 4,500 unique questions distributed across 9 subjects[cite: 4, 6].
* [cite_start]**Difficulty Scaling:** Each subject features tiered difficulty—Easy, Medium, and Hard—to support progressive learning[cite: 6, 104].
* [cite_start]**Multi-Profile Support:** Isolated data scoping allows multiple users to maintain their own scores, history, and achievements on a single device[cite: 12, 104].
* **Advanced Analytics:** Real-time performance tracking with accuracy bars and subject-specific stats[cite: 75, 76].
* [cite_start]**Offline-First:** 100% functional without an internet connection, utilizing local SQLite storage for privacy and speed[cite: 4, 104].
* [cite_start]**Achievement System:** 9 unlockable badges triggered by performance milestones, such as "Speed Demon" or "Hard Mode Hero"[cite: 89, 90].

## 🏗️ Technical Stack

* **Framework:** Flutter (Cross-platform support for Android, iOS, Web, and Desktop)[cite: 115, 117].
* [cite_start]**Database:** `drift` (Type-safe SQLite ORM) for high-performance querying and native-level shuffle via `ORDER BY RANDOM()`[cite: 10, 104].
* [cite_start]**State Management:** `provider` for managing profile context and live quiz states[cite: 92, 104].
* **Storage:** `shared_preferences` for session persistence and `path_provider` for local DB management[cite: 92].
* [cite_start]**Visualization:** `fl_chart` for rendering performance data on the StatsScreen[cite: 92].

## 📂 Project Structure

[cite_start]The project follows a modular directory layout to ensure scalability[cite: 7, 8]:

```text
lib/
├── database/     # SQLite init, CRUD DAOs, and Question Seeder
├── models/       # Data models (Question, Profile, Session, etc.)
├── providers/    # State management for active profiles and live quiz logic
├── screens/      # All UI views (Home, Quiz, Stats, History, etc.)
├── widgets/      # Reusable UI components (OptionButton, TimerBar)
└── data/         # Question bundling and assets
[cite_start]
http://googleusercontent.com/immersive_entry_chip/0
http://googleusercontent.com/immersive_entry_chip/1
