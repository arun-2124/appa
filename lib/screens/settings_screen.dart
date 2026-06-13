import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/voice_service.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';

const Color kPrimary       = Color(0xFF6B3FA0);
const Color kPrimaryLight  = Color(0xFFF0E6FF);
const Color kTextPrimary   = Color(0xFF1A1A2E);
const Color kTextSecondary = Color(0xFF6B6B80);
const Color kBackground    = Color(0xFFFAF7FF);
const Color kSurface       = Color(0xFFFFFFFF);
const Color kDanger        = Color(0xFFC62828);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool   _darkMode      = false;
  double _textScale     = 1.0;
  String _ttsLanguage   = 'en-IN';
  bool   _ttsEnabled    = true;
  bool   _soundEnabled  = true;
  bool   _vibration     = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _darkMode     = prefs.getBool('darkMode')     ?? false;
      _textScale    = prefs.getDouble('textScale')  ?? 1.0;
      _ttsLanguage  = prefs.getString('ttsLanguage') ?? 'en-IN';
      _ttsEnabled   = prefs.getBool('ttsEnabled')   ?? true;
      _soundEnabled = prefs.getBool('soundEnabled') ?? true;
      _vibration    = prefs.getBool('vibration')    ?? true;
    });
  }

  Future<void> _save(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool)   await prefs.setBool(key, value);
    if (value is double) await prefs.setDouble(key, value);
    if (value is String) await prefs.setString(key, value);
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── Appearance ────────────────────────────────────────────────────
          _SectionHeader(label: 'Appearance'),

          _SettingsTile(
            icon: Icons.dark_mode_outlined,
            title: 'Dark Mode',
            subtitle: 'Switch to dark theme',
            trailing: Switch(
              value: _darkMode,
              activeColor: kPrimary,
              onChanged: (val) {
                setState(() => _darkMode = val);
                _save('darkMode', val);
              },
            ),
          ),

          _SettingsTile(
            icon: Icons.text_fields,
            title: 'Large Text Mode',
            subtitle: _textScale > 1.0
                ? 'Large text enabled (1.3×)'
                : 'Normal text size',
            trailing: Switch(
              value: _textScale > 1.0,
              activeColor: kPrimary,
              onChanged: (val) {
                final scale = val ? 1.3 : 1.0;
                setState(() => _textScale = scale);
                _save('textScale', scale);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(val
                        ? 'Large text enabled — restart app to apply'
                        : 'Normal text size restored'),
                    backgroundColor: kPrimary,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // ── Voice & Language ──────────────────────────────────────────────
          _SectionHeader(label: 'Voice & Language'),

          _SettingsTile(
            icon: Icons.volume_up_outlined,
            title: 'Voice Reminders',
            subtitle: 'Speak medicine name when reminder fires',
            trailing: Switch(
              value: _ttsEnabled,
              activeColor: kPrimary,
              onChanged: (val) {
                setState(() => _ttsEnabled = val);
                _save('ttsEnabled', val);
              },
            ),
          ),

          _SettingsTile(
            icon: Icons.language,
            title: 'Reminder Language',
            subtitle: _ttsLanguage == 'ta-IN' ? 'Tamil (தமிழ்)' : 'English (India)',
            onTap: () => _showLanguagePicker(),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: OutlinedButton.icon(
              onPressed: () async {
                await VoiceService.init(language: _ttsLanguage);
                await VoiceService.speakReminder('Paracetamol', '500mg');
              },
              icon: const Icon(Icons.play_arrow_outlined, color: kPrimary),
              label: const Text('Test Voice',
                  style: TextStyle(color: kPrimary)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: kPrimary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Notifications ─────────────────────────────────────────────────
          _SectionHeader(label: 'Notifications'),

          _SettingsTile(
            icon: Icons.volume_up_outlined,
            title: 'Sound',
            subtitle: 'Play sound on notification',
            trailing: Switch(
              value: _soundEnabled,
              activeColor: kPrimary,
              onChanged: (val) {
                setState(() => _soundEnabled = val);
                _save('soundEnabled', val);
              },
            ),
          ),

          _SettingsTile(
            icon: Icons.vibration,
            title: 'Vibration',
            subtitle: 'Vibrate on notification',
            trailing: Switch(
              value: _vibration,
              activeColor: kPrimary,
              onChanged: (val) {
                setState(() => _vibration = val);
                _save('vibration', val);
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: OutlinedButton.icon(
              onPressed: () async {
                await NotificationService.showNow(
                  'Test notification',
                  'Your notifications are working!',
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Test notification sent'),
                    backgroundColor: kPrimary,
                  ),
                );
              },
              icon: const Icon(Icons.notifications_outlined, color: kPrimary),
              label: const Text('Send Test Notification',
                  style: TextStyle(color: kPrimary)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: kPrimary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Account ───────────────────────────────────────────────────────
          _SectionHeader(label: 'Account'),

          _SettingsTile(
            icon: Icons.logout,
            title: 'Sign Out',
            subtitle: 'Log out of your account',
            titleColor: kDanger,
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: kDanger),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Sign Out')),
                  ],
                ),
              );
              if (confirmed == true) {
                await AuthService.signOut();
              }
            },
          ),

          const SizedBox(height: 32),
          const Center(
            child: Text('Appa v1.0.0',
                style: TextStyle(fontSize: 12, color: kTextSecondary)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Reminder Language',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _LangOption(
              label: 'English (India)',
              code: 'en-IN',
              selected: _ttsLanguage == 'en-IN',
              onTap: () {
                setState(() => _ttsLanguage = 'en-IN');
                _save('ttsLanguage', 'en-IN');
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
            _LangOption(
              label: 'Tamil (தமிழ்)',
              code: 'ta-IN',
              selected: _ttsLanguage == 'ta-IN',
              onTap: () {
                setState(() => _ttsLanguage = 'ta-IN');
                _save('ttsLanguage', 'ta-IN');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helper widgets ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: kTextSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData    icon;
  final String      title;
  final String      subtitle;
  final Widget?     trailing;
  final VoidCallback? onTap;
  final Color       titleColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor = kTextPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E0F0)),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: kPrimaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: kPrimary, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: titleColor,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: kTextSecondary),
        ),
        trailing: trailing ??
            (onTap != null
                ? const Icon(Icons.chevron_right, color: kTextSecondary)
                : null),
        onTap: onTap,
      ),
    );
  }
}

class _LangOption extends StatelessWidget {
  final String label;
  final String code;
  final bool   selected;
  final VoidCallback onTap;

  const _LangOption({
    required this.label,
    required this.code,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? kPrimary : const Color(0xFFE8E0F0),
            width: selected ? 1.5 : 0.5,
          ),
          borderRadius: BorderRadius.circular(12),
          color: selected ? kPrimaryLight : kSurface,
        ),
        child: Row(
          children: [
            Text(label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: selected ? kPrimary : kTextPrimary,
                )),
            const Spacer(),
            if (selected)
              const Icon(Icons.check_circle, color: kPrimary, size: 20),
          ],
        ),
      ),
    );
  }
}