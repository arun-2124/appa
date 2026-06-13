import 'dart:typed_data';                                          // ✅ Fix 1: needed for Int64List
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzData;
import '../models/medicine_model.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId    = 'medicine_channel';
  static const String _channelName  = 'Medicine Reminders';
  static const String _snoozeId     = 'snooze_channel';
  static const String _snoozeChName = 'Snooze Reminders';
  static const String _ist          = 'Asia/Kolkata';

  // ─── Init ──────────────────────────────────────────────────────────────────

  static Future<void> init() async {
    tzData.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(_ist));

    const android  = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    await _requestPermissions();
  }

  static Future<void> _requestPermissions() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
  }

  // ─── Action handler (Take Now / Snooze) ────────────────────────────────────

  static void _onNotificationResponse(NotificationResponse response) async {
    final payload = response.payload; // medicine id
    final action  = response.actionId;
    if (payload == null) return;

    if (action == 'take_now') {
      await cancel(payload.hashCode);
    }
    if (action == 'snooze') {
      await snooze(payload);
    }
  }

  // ─── Notification channel details ─────────────────────────────────────────

  static NotificationDetails _mainDetails() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Daily medicine reminders',
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
        // ✅ Fix 2: use Int64List instead of plain List<int>
        vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
        playSound: true,
        actions: const [
          AndroidNotificationAction(
            'take_now',
            'Take Now ✅',
            showsUserInterface: false,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            'snooze',
            'Snooze 10 min ⏰',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      ),
    );
  }

  static NotificationDetails _snoozeDetails() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _snoozeId,
        _snoozeChName,
        channelDescription: 'Snoozed medicine reminders',
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 400, 200, 400]),
      ),
    );
  }

  // ─── Schedule daily repeating reminder ────────────────────────────────────

  static Future<void> schedule(Medicine medicine) async {
    final parts = medicine.time.split(':');
    if (parts.length != 2) return;

    final hour   = int.tryParse(parts[0]) ?? 8;
    final minute = int.tryParse(parts[1]) ?? 0;
    final loc    = tz.getLocation(_ist);
    final now    = tz.TZDateTime.now(loc);
    var   when   = tz.TZDateTime(loc, now.year, now.month, now.day, hour, minute);

    // If already passed today → schedule for tomorrow
    if (when.isBefore(now)) {
      when = when.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      medicine.id.hashCode,
      '💊 Time for ${medicine.name}',
      '${medicine.dose} — tap to confirm',
      when,
      _mainDetails(),
      payload: medicine.id,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,         // daily repeat
      // ✅ Fix 3: required parameter added
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ─── Reschedule all after device reboot ───────────────────────────────────

  static Future<void> rescheduleAll(List<Medicine> medicines) async {
    await _plugin.cancelAll();
    for (final med in medicines) {
      await schedule(med);
    }
  }

  // ─── Snooze (fires once, 10 min later) ────────────────────────────────────

  static Future<void> snooze(String medicineId, {int minutes = 10}) async {
    final loc  = tz.getLocation(_ist);
    final when = tz.TZDateTime.now(loc).add(Duration(minutes: minutes));

    await _plugin.zonedSchedule(
      medicineId.hashCode + 99999,
      '⏰ Snoozed reminder',
      'Time to take your medicine now',
      when,
      _snoozeDetails(),
      payload: medicineId,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      // ✅ Fix 3: required parameter added here too
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ─── Cancel ───────────────────────────────────────────────────────────────

  static Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  static Future<void> cancelByMedicineId(String medicineId) async {
    await _plugin.cancel(medicineId.hashCode);
    await _plugin.cancel(medicineId.hashCode + 99999); // also cancel snooze
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ─── Test notification (instant) ──────────────────────────────────────────

  static Future<void> showNow(String title, String body) async {
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      _mainDetails(),
    );
  }
}