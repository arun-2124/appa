
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/notification_service.dart';
import 'models/medicine_model.dart';
import 'screens/history_screen.dart';
import 'screens/analytics_screen.dart';       
import 'screens/settings_screen.dart';
import 'screens/caretaker_screen.dart';       
import 'screens/prescription_ocr_screen.dart'; 
import 'screens/medicine_verification_screen.dart'; 


// =============================================================================
// SUMMARY OF CHANGES
// =============================================================================
//
// File                         What changed
// ──────────────────────────── ────────────────────────────────────────────────
// lib/main.dart                _MainShellState  — 4 screens matching 4 tabs
// lib/main.dart                AuthWrapper      — inline _getProfile, no missing method
// lib/main.dart                HomeScreen       — isCaregiverView param added
// lib/main.dart                HomeScreen AppBar— scan button only for caretaker
// lib/main.dart (medicine card)— "Verify tablet" button opens Camera 1
// lib/main.dart imports        — added 4 missing imports
//
// =============================================================================


// ─── Color tokens ─────────────────────────────────────────────────────────
const Color kPrimary       = Color(0xFF6B3FA0);
const Color kPrimaryLight  = Color(0xFFF0E6FF);
const Color kAccentAmber   = Color(0xFFEF9F27);
const Color kSuccess       = Color(0xFF2E7D32);
const Color kSuccessLight  = Color(0xFFE8F5E9);
const Color kWarning       = Color(0xFFF57C00);
const Color kWarningLight  = Color(0xFFFFF3E0);
const Color kDanger        = Color(0xFFC62828);
const Color kDangerLight   = Color(0xFFFFEBEE);
const Color kBackground    = Color(0xFFFAF7FF);
const Color kSurface       = Color(0xFFFFFFFF);
const Color kTextPrimary   = Color(0xFF1A1A2E);
const Color kTextSecondary = Color(0xFF6B6B80);

// ─── Entry point ──────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.init();
  await InferenceService.init();
  runApp(const AppaApp());
}

// ─── Root App ─────────────────────────────────────────────────────────────

class AppaApp extends StatelessWidget {
  const AppaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Appa',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimary,
          primary: kPrimary,
          secondary: kAccentAmber,
          surface: kSurface,
          error: kDanger,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: kBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
        cardTheme: CardThemeData(
          color: kSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFE8E0F0), width: 1),
          ),
          margin: const EdgeInsets.only(bottom: 14),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: kPrimaryLight,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kPrimary, width: 1.5),
          ),
          labelStyle: const TextStyle(color: kTextSecondary, fontSize: 15),
          floatingLabelStyle: const TextStyle(color: kPrimary, fontSize: 13),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

// ─── Auth Wrapper ─────────────────────────────────────────────────────────

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData) return const LoginScreen();

        final uid = snapshot.data!.uid;

        return FutureBuilder<Map<String, dynamic>?>(
          future: _getProfile(uid),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final profile     = userSnap.data;
            final isCaregiver = profile?['isCaregiver'] == true;

            if (isCaregiver) {
              return CaretakerShell(caregiverUid: uid);
            }

            return MainShell(userId: uid);
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _getProfile(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    return doc.data();
  }
}

// ─── Main Shell ───────────────────────────────────────────────────────────
// ✅ FIX 2: Added missing MainShell StatefulWidget class

class MainShell extends StatefulWidget {
  final String userId;
  const MainShell({super.key, required this.userId});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {

    // ⚠️ ORDER must match the destinations list below — 4 screens, 4 tabs
    final screens = [
      HomeScreen(userId: widget.userId),          // index 0 → Home
      HistoryScreen(userId: widget.userId),        // index 1 → History
      AnalyticsScreen(userId: widget.userId),      // index 2 → Analytics
      const SettingsScreen(),                      // index 3 → Settings
    ];

    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: Colors.white,
        indicatorColor: kPrimaryLight,
        destinations: const [
          NavigationDestination(
            icon        : Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: kPrimary),
            label       : 'Home',
          ),
          NavigationDestination(
            icon        : Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today, color: kPrimary),
            label       : 'History',
          ),
          NavigationDestination(
            icon        : Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart, color: kPrimary),
            label       : 'Analytics',
          ),
          NavigationDestination(
            icon        : Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: kPrimary),
            label       : 'Settings',
          ),
        ],
      ),
    );
  }
}

// ─── Login Screen ─────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl     = TextEditingController();

  bool   _isSignUp  = false;
  bool   _isLoading = false;
  String _error     = '';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _isLoading = true; _error = ''; });
    try {
      if (_isSignUp) {
        await AuthService.signUp(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
          _nameCtrl.text.trim(),
        );
      } else {
        await AuthService.signIn(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Appa')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text('💊',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text(
              'Medicine Reminder for Elders',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _emailCtrl,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordCtrl,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              obscureText: true,
            ),
            if (_isSignUp) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Your name',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error,
                  style: const TextStyle(color: kDanger, fontSize: 13),
                ),
              ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_isSignUp ? 'Create Account' : 'Sign In'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () =>
                  setState(() { _isSignUp = !_isSignUp; _error = ''; }),
              child: Text(
                _isSignUp
                    ? 'Already have an account? Sign In'
                    : 'New here? Create Account',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Home Screen ──────────────────────────────────────────────────────────
// ✅ FIX 3: Added isCaregiverView parameter

class HomeScreen extends StatefulWidget {
  final String userId;
  final bool   isCaregiverView; // true = caretaker sees scan button

  const HomeScreen({
    super.key,
    required this.userId,
    this.isCaregiverView = false, // default false = elder view (Rajamma)
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  // ── Add medicine ──────────────────────────────────────────────────────────
  Future<void> _addMedicine(String name, String dose, String time) async {
    final String id = DateTime.now().millisecondsSinceEpoch.toString();
    final medicine = Medicine(
      id       : id,
      userId   : widget.userId,
      name     : name,
      dose     : dose,
      time     : time,
      createdAt: DateTime.now(),
    );

    try {
      await FirestoreService.addMedicine(medicine);
      await NotificationService.schedule(medicine);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content  : Text('$name added — reminder set for $time'),
          backgroundColor: kPrimary,
          behavior : SnackBarBehavior.floating,
          shape    : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: kDanger),
      );
    }
  }

  // ── Mark taken ────────────────────────────────────────────────────────────
  Future<void> _markTaken(String medicineId, String medicineName) async {
    try {
      await FirestoreService.markAsTaken(
          widget.userId, medicineId, medicineName);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content  : Text('$medicineName marked as taken'),
          backgroundColor: kSuccess,
          behavior : SnackBarBehavior.floating,
          shape    : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: kDanger),
      );
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────
  Future<void> _deleteMedicine(String medicineId) async {
    try {
      await FirestoreService.deleteMedicine(widget.userId, medicineId);
      await NotificationService.cancelByMedicineId(medicineId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: kDanger),
      );
    }
  }

  // ── Add dialog ────────────────────────────────────────────────────────────
  void _openAddDialog() {
    final nameCtrl = TextEditingController();
    final doseCtrl = TextEditingController();
    final timeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        backgroundColor: kSurface,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kPrimaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('💊',
                        style: TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Medicine',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: kTextPrimary),
                      ),
                      Text(
                        'Fill in the details below',
                        style: TextStyle(
                            fontSize: 13, color: kTextSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Fields
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText : 'Medicine name',
                  prefixIcon: Icon(Icons.medication_outlined,
                      color: kPrimary),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: doseCtrl,
                decoration: const InputDecoration(
                  labelText : 'Dose  (e.g. 500mg, 1 tablet)',
                  prefixIcon: Icon(Icons.scale_outlined, color: kPrimary),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: timeCtrl,
                decoration: const InputDecoration(
                  labelText : 'Time  (e.g. 08:00)',
                  prefixIcon: Icon(Icons.access_time_rounded,
                      color: kPrimary),
                ),
                keyboardType: TextInputType.datetime,
              ),
              const SizedBox(height: 28),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 52),
                        side : const BorderSide(color: kPrimary),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                            color: kPrimary,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (nameCtrl.text.isNotEmpty &&
                            doseCtrl.text.isNotEmpty &&
                            timeCtrl.text.isNotEmpty) {
                          _addMedicine(
                            nameCtrl.text.trim(),
                            doseCtrl.text.trim(),
                            timeCtrl.text.trim(),
                          );
                          Navigator.pop(ctx);
                        }
                      },
                      child: const Text('Add'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('💊 Appa'),
        actions: [
  if (widget.isCaregiverView)
    IconButton(
      icon: const Icon(Icons.document_scanner_outlined),
      tooltip: 'Scan prescription',
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PrescriptionOcrScreen(userId: widget.userId),
        ),
      ),
    ),
],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDialog,
        icon : const Icon(Icons.add),
        label: const Text(
          'Add Medicine',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: StreamBuilder<List<Medicine>>(
        stream: FirestoreService.getMedicinesStream(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final medicines  = snapshot.data ?? [];
          final takenCount = medicines.where((m) => m.taken).length;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _HeaderSection(
                  takenCount: takenCount,
                  totalCount: medicines.length,
                ),
              ),
              if (medicines.isNotEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Text(
                      "Today's medicines",
                      style: TextStyle(
                        fontSize  : 20,
                        fontWeight: FontWeight.w700,
                        color     : kTextPrimary,
                      ),
                    ),
                  ),
                ),
              medicines.isEmpty
                  ? const SliverFillRemaining(child: _EmptyState())
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                      sliver : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final med = medicines[index];
                            return _MedicineCard(
                              medicine  : med,
                              onMarkTaken: () =>
                                  _markTaken(med.id, med.name),
                              onDelete  : () =>
                                  _deleteMedicine(med.id),
                            );
                          },
                          childCount: medicines.length,
                        ),
                      ),
                    ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Medicine Card ────────────────────────────────────────────────────────

class _MedicineCard extends StatelessWidget {
  final Medicine     medicine;
  final VoidCallback onMarkTaken;
  final VoidCallback onDelete;

  const _MedicineCard({
    required this.medicine,
    required this.onMarkTaken,
    required this.onDelete,
  });

  String get _icon {
    final name = medicine.name.toLowerCase();
    if (name.contains('vitamin') || name.contains('d3')) return '🌞';
    if (name.contains('calcium')) return '🦴';
    if (name.contains('iron'))    return '💪';
    if (name.contains('syrup'))   return '🧴';
    return '💊';
  }

  @override
  Widget build(BuildContext context) {
    final bool  isTaken     = medicine.taken;
    final Color borderColor =
        isTaken ? const Color(0xFFA5D6A7) : const Color(0xFFE8E0F0);
    final Color iconBg = isTaken ? kSuccessLight : kPrimaryLight;

    return Dismissible(
      key      : Key(medicine.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding  : const EdgeInsets.only(right: 20),
        margin   : const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color       : kDangerLight,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline, color: kDanger, size: 28),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side        : BorderSide(color: borderColor, width: 1.2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child  : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row
              Row(
                children: [
                  Container(
                    width : 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color       : iconBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(_icon,
                          style: const TextStyle(fontSize: 26)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          medicine.name,
                          style: const TextStyle(
                            fontSize  : 22,
                            fontWeight: FontWeight.w700,
                            color     : kTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          medicine.dose,
                          style: const TextStyle(
                              fontSize: 16, color: kTextSecondary),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color       : isTaken ? kSuccessLight : kWarningLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isTaken ? 'Done' : 'Pending',
                      style: TextStyle(
                        fontSize  : 12,
                        fontWeight: FontWeight.w600,
                        color     : isTaken ? kSuccess : kWarning,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFF0EAF8)),
              const SizedBox(height: 12),

              // Time chip
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color       : kPrimaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 15, color: kPrimary),
                    const SizedBox(width: 5),
                    Text(
                      medicine.time,
                      style: const TextStyle(
                        fontSize  : 13,
                        color     : kPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Mark as Taken button (pending only)
              if (!isTaken)
                SizedBox(
                  width : double.infinity,
                  height: 52,
                  child : ElevatedButton.icon(
                    onPressed: onMarkTaken,
                    icon : const Icon(Icons.check_circle_outline, size: 22),
                    label: const Text('Mark as Taken'),
                  ),
                ),

              // Taken confirmation surface
              if (isTaken)
                Container(
                  width : double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color       : kSuccessLight,
                    borderRadius: BorderRadius.circular(14),
                    border      : Border.all(
                        color: const Color(0xFFA5D6A7)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: kSuccess, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Taken',
                        style: TextStyle(
                          fontSize  : 16,
                          fontWeight: FontWeight.w600,
                          color     : kSuccess,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Header Section ───────────────────────────────────────────────────────

class _HeaderSection extends StatelessWidget {
  final int takenCount;
  final int totalCount;

  const _HeaderSection({
    required this.takenCount,
    required this.totalCount,
  });

  String get _progressLabel {
    if (totalCount == 0) return 'No medicines added yet';
    if (takenCount == 0) return "None taken yet — let's go!";
    if (takenCount == totalCount) return 'All done for today!';
    return '$takenCount of $totalCount taken';
  }

  String get _todayLabel {
    final now = DateTime.now();
    const days   = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final double progress =
        totalCount == 0 ? 0.0 : takenCount / totalCount;

    return Container(
      decoration: const BoxDecoration(
        color: kPrimary,
        borderRadius: BorderRadius.only(
          bottomLeft : Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good morning,',
                      style: TextStyle(
                          fontSize: 15, color: Color(0xCCFFFFFF)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Rajamma',
                      style: TextStyle(
                        fontSize  : 26,
                        fontWeight: FontWeight.w700,
                        color     : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color       : Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _todayLabel,
                  style: const TextStyle(
                    fontSize  : 12,
                    color     : Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color       : Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border      : Border.all(
                  color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Daily progress',
                      style: TextStyle(
                          fontSize: 13, color: Color(0xCCFFFFFF)),
                    ),
                    Text(
                      _progressLabel,
                      style: const TextStyle(
                        fontSize  : 13,
                        color     : Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value          : progress,
                    minHeight      : 8,
                    backgroundColor: Colors.white.withOpacity(0.25),
                    valueColor     : const AlwaysStoppedAnimation<Color>(
                        kAccentAmber),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('💊', style: TextStyle(fontSize: 64)),
          SizedBox(height: 16),
          Text(
            'No medicines added yet',
            style: TextStyle(
              fontSize  : 22,
              fontWeight: FontWeight.w700,
              color     : kTextPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Tap + Add Medicine to get started',
            style: TextStyle(fontSize: 16, color: kTextSecondary),
          ),
        ],
      ),
    );
  }
}