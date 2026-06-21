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
import 'screens/analytics_screen.dart';        // ✅ fixed — reads correct Firestore path
import 'screens/settings_screen.dart';
import 'screens/caretaker_screen.dart';
import 'screens/prescription_ocr_screen.dart';
import 'screens/medicine_verification_screen.dart'; // camera check screen
import 'screens/ai_assistant_screen.dart';          // ✅ Gemini-powered chat
import 'package:appa/services/inference_service.dart';

// ─── Color tokens (LIGHT) ───────────────────────────────────────────────
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
const Color kCardBorder    = Color(0xFFE8E0F0);
const Color kTakenBorder   = Color(0xFFA5D6A7);

// ─── Color tokens (DARK) ────────────────────────────────────────────────
const Color kPrimaryDark       = Color(0xFFB28EDB);
const Color kPrimaryLightDark  = Color(0xFF2A2240);
const Color kSuccessDark       = Color(0xFF66BB6A);
const Color kSuccessLightDark  = Color(0xFF1C3320);
const Color kWarningDark       = Color(0xFFFFB74D);
const Color kWarningLightDark  = Color(0xFF3A2A12);
const Color kDangerDark        = Color(0xFFEF5350);
const Color kDangerLightDark   = Color(0xFF3A1A1A);
const Color kBackgroundDark    = Color(0xFF14101F);
const Color kSurfaceDark       = Color(0xFF1E1830);
const Color kTextPrimaryDark   = Color(0xFFF2EFFA);
const Color kTextSecondaryDark = Color(0xFFB0A8C2);
const Color kCardBorderDark    = Color(0xFF332A4A);
const Color kTakenBorderDark   = Color(0xFF3D6B40);

// ─── Theme-aware color lookup ──────────────────────────────────────────
class AppColors {
  static bool _isDark(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark;

  static Color primary(BuildContext c) => _isDark(c) ? kPrimaryDark : kPrimary;
  static Color primaryLight(BuildContext c) =>
      _isDark(c) ? kPrimaryLightDark : kPrimaryLight;
  static Color background(BuildContext c) =>
      _isDark(c) ? kBackgroundDark : kBackground;
  static Color surface(BuildContext c) => _isDark(c) ? kSurfaceDark : kSurface;
  static Color textPrimary(BuildContext c) =>
      _isDark(c) ? kTextPrimaryDark : kTextPrimary;
  static Color textSecondary(BuildContext c) =>
      _isDark(c) ? kTextSecondaryDark : kTextSecondary;
  static Color cardBorder(BuildContext c) =>
      _isDark(c) ? kCardBorderDark : kCardBorder;
  static Color takenBorder(BuildContext c) =>
      _isDark(c) ? kTakenBorderDark : kTakenBorder;
  static Color success(BuildContext c) => _isDark(c) ? kSuccessDark : kSuccess;
  static Color successLight(BuildContext c) =>
      _isDark(c) ? kSuccessLightDark : kSuccessLight;
  static Color warning(BuildContext c) => _isDark(c) ? kWarningDark : kWarning;
  static Color warningLight(BuildContext c) =>
      _isDark(c) ? kWarningLightDark : kWarningLight;
  static Color danger(BuildContext c) => _isDark(c) ? kDangerDark : kDanger;
  static Color dangerLight(BuildContext c) =>
      _isDark(c) ? kDangerLightDark : kDangerLight;
}

// ─── Theme mode controller ──────────────────────────────────────────────
class ThemeController {
  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  static void cycle() {
    switch (themeMode.value) {
      case ThemeMode.light:
        themeMode.value = ThemeMode.dark;
        break;
      case ThemeMode.dark:
        themeMode.value = ThemeMode.system;
        break;
      case ThemeMode.system:
        themeMode.value = ThemeMode.light;
        break;
    }
  }

  static IconData icon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode_outlined;
      case ThemeMode.dark:
        return Icons.dark_mode_outlined;
      case ThemeMode.system:
        return Icons.brightness_auto_outlined;
    }
  }
}

// ─── Cross-screen refresh signal ────────────────────────────────────────
class MedicineEvents {
  static final ValueNotifier<int> refreshTick = ValueNotifier<int>(0);
  static void notifyChanged() => refreshTick.value++;
}

// ─── Entry point ──────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.init();
  await InferenceService.init();
  runApp(const AppaApp());
}

// ─── Theme builder ───────────────────────────────────────────────────────

ThemeData _buildTheme(Brightness brightness) {
  final bool dark = brightness == Brightness.dark;

  final Color primary       = dark ? kPrimaryDark : kPrimary;
  final Color primaryBg     = dark ? kPrimaryLightDark : kPrimaryLight;
  final Color background    = dark ? kBackgroundDark : kBackground;
  final Color surface       = dark ? kSurfaceDark : kSurface;
  final Color textSecondary = dark ? kTextSecondaryDark : kTextSecondary;
  final Color cardBorder    = dark ? kCardBorderDark : kCardBorder;
  final Color danger        = dark ? kDangerDark : kDanger;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor : kPrimary,
      primary   : primary,
      secondary : kAccentAmber,
      surface   : surface,
      error     : danger,
      brightness: brightness,
    ),
    scaffoldBackgroundColor: background,
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? kSurfaceDark : kPrimary,
      foregroundColor: dark ? kTextPrimaryDark : Colors.white,
      centerTitle: true,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: dark ? kTextPrimaryDark : Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
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
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 4,
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cardBorder, width: 1),
      ),
      margin: const EdgeInsets.only(bottom: 14),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: primaryBg,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
      labelStyle: TextStyle(color: textSecondary, fontSize: 15),
      floatingLabelStyle: TextStyle(color: primary, fontSize: 13),
    ),
  );
}

// ─── Root App ─────────────────────────────────────────────────────────────

class AppaApp extends StatelessWidget {
  const AppaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Appa',
          themeMode: mode,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          home: const AuthWrapper(),
        );
      },
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
    final screens = [
      HomeScreen(userId: widget.userId),
      HistoryScreen(userId: widget.userId),
      AnalyticsScreen(userId: widget.userId),
      AiAssistantScreen(userId: widget.userId),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: AppColors.surface(context),
        indicatorColor: AppColors.primaryLight(context),
        destinations: [
          NavigationDestination(
            icon        : const Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppColors.primary(context)),
            label       : 'Home',
          ),
          NavigationDestination(
            icon        : const Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today,
                color: AppColors.primary(context)),
            label       : 'History',
          ),
          NavigationDestination(
            icon        : const Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart,
                color: AppColors.primary(context)),
            label       : 'Analytics',
          ),
          NavigationDestination(
            icon        : const Icon(Icons.smart_toy_outlined),
            selectedIcon:
                Icon(Icons.smart_toy, color: AppColors.primary(context)),
            label       : 'AI Chat',
          ),
          NavigationDestination(
            icon        : const Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings,
                color: AppColors.primary(context)),
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
                  style: TextStyle(color: AppColors.danger(context), fontSize: 13),
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

class HomeScreen extends StatefulWidget {
  final String userId;
  final bool   isCaregiverView;

  const HomeScreen({
    super.key,
    required this.userId,
    this.isCaregiverView = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  // ── Daily reset on open ───────────────────────────────────────────────────
  // Resets taken→false for any medicine last taken on a previous day,
  // so the "Mark as Taken" button reappears every morning automatically.
  @override
  void initState() {
    super.initState();
    FirestoreService.resetDailyMedicines(widget.userId);
  }

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
      MedicineEvents.notifyChanged();

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
      MedicineEvents.notifyChanged();

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
      MedicineEvents.notifyChanged();
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
        backgroundColor: AppColors.surface(ctx),
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
                      color: AppColors.primaryLight(ctx),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('💊',
                        style: TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Medicine',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(ctx)),
                      ),
                      Text(
                        'Fill in the details below',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary(ctx)),
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
                decoration: InputDecoration(
                  labelText : 'Medicine name',
                  prefixIcon: Icon(Icons.medication_outlined,
                      color: AppColors.primary(ctx)),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: doseCtrl,
                decoration: InputDecoration(
                  labelText : 'Dose  (e.g. 500mg, 1 tablet)',
                  prefixIcon: Icon(Icons.scale_outlined, color: AppColors.primary(ctx)),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: timeCtrl,
                decoration: InputDecoration(
                  labelText : 'Time  (e.g. 08:00)',
                  prefixIcon: Icon(Icons.access_time_rounded,
                      color: AppColors.primary(ctx)),
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
                        side : BorderSide(color: AppColors.primary(ctx)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                            color: AppColors.primary(ctx),
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
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.themeMode,
            builder: (context, mode, _) {
              return IconButton(
                icon: Icon(ThemeController.icon(mode)),
                tooltip: 'Toggle theme (${mode.name})',
                onPressed: ThemeController.cycle,
              );
            },
          ),
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

      // ✅ NEW: Two stacked FABs — "Check Medicine" above "Add Medicine"
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'fab_check',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    MedicineVerificationScreen(userId: widget.userId),
              ),
            ),
            backgroundColor: AppColors.surface(context),
            foregroundColor: AppColors.primary(context),
            elevation: 2,
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text(
              'Check Medicine',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'fab_add',
            onPressed: _openAddDialog,
            icon : const Icon(Icons.add),
            label: const Text(
              'Add Medicine',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
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
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Text(
                      "Today's medicines",
                      style: TextStyle(
                        fontSize  : 20,
                        fontWeight: FontWeight.w700,
                        color     : AppColors.textPrimary(context),
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
        isTaken ? AppColors.takenBorder(context) : AppColors.cardBorder(context);
    final Color iconBg = isTaken ? AppColors.successLight(context) : AppColors.primaryLight(context);

    return Dismissible(
      key      : Key(medicine.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding  : const EdgeInsets.only(right: 20),
        margin   : const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color       : AppColors.dangerLight(context),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(Icons.delete_outline, color: AppColors.danger(context), size: 28),
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
                          style: TextStyle(
                            fontSize  : 22,
                            fontWeight: FontWeight.w700,
                            color     : AppColors.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          medicine.dose,
                          style: TextStyle(
                              fontSize: 16, color: AppColors.textSecondary(context)),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color       : isTaken ? AppColors.successLight(context) : AppColors.warningLight(context),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isTaken ? 'Done' : 'Pending',
                      style: TextStyle(
                        fontSize  : 12,
                        fontWeight: FontWeight.w600,
                        color     : isTaken ? AppColors.success(context) : AppColors.warning(context),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              Divider(height: 1, color: AppColors.cardBorder(context)),
              const SizedBox(height: 12),

              // Time chip
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color       : AppColors.primaryLight(context),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 15, color: AppColors.primary(context)),
                    const SizedBox(width: 5),
                    Text(
                      medicine.time,
                      style: TextStyle(
                        fontSize  : 13,
                        color     : AppColors.primary(context),
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
                    color       : AppColors.successLight(context),
                    borderRadius: BorderRadius.circular(14),
                    border      : Border.all(
                        color: AppColors.takenBorder(context)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: AppColors.success(context), size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Taken',
                        style: TextStyle(
                          fontSize  : 16,
                          fontWeight: FontWeight.w600,
                          color     : AppColors.success(context),
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
      decoration: BoxDecoration(
        color: AppColors.primary(context),
        borderRadius: const BorderRadius.only(
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('💊', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            'No medicines added yet',
            style: TextStyle(
              fontSize  : 22,
              fontWeight: FontWeight.w700,
              color     : AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + Add Medicine to get started',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary(context)),
          ),
        ],
      ),
    );
  }
}

// AiAssistantScreen is now in lib/screens/ai_assistant_screen.dart