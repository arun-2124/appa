import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';

class HistoryScreen extends StatefulWidget {
  final String userId;
  const HistoryScreen({super.key, required this.userId});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime _selectedDate = DateTime.now();
  final _db = FirebaseFirestore.instance;

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String get _formattedDate =>
      DateFormat('EEE, d MMM yyyy').format(_selectedDate);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _prevDay() =>
      setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));

  void _nextDay() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    if (_selectedDate.isBefore(tomorrow)) {
      setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
    }
  }

  DateTime? _parseTakenAt(dynamic raw) {
    // ✅ FIX: FirestoreService.markAsTaken() writes `takenAt` via
    // DateTime.now().toIso8601String() in one place, so it's almost
    // certainly a String inside the history doc too — but this handles
    // a Firestore Timestamp as well, just in case HistoryEntry.toMap()
    // converts it differently.
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  // ─── Fetch dose records for selected date ─────────────────────────────────
  // ✅ FIX: the original code queried
  //   users/{uid}/history/{dateKey}/doses
  // but FirestoreService.markAsTaken() actually writes flat documents to
  //   users/{uid}/history/{medicineId}_{timestamp}
  // with fields {id, userId, medicineName, takenAt, successful} — a
  // completely different shape, so the old query could never find
  // anything. This reads the collection FirestoreService really writes,
  // matches each medicine by its 'id' field (falling back to name), and
  // checks 'successful' instead of the never-set 'missed' field.

  Future<Map<String, dynamic>> _fetchHistory(DateTime date) async {
    final historySnap = await _db
        .collection('users')
        .doc(widget.userId)
        .collection('history')
        .get();

    final medicinesSnap = await _db
        .collection('users')
        .doc(widget.userId)
        .collection('medicines')
        .get();

    final Map<String, Map<String, dynamic>> dosesByKey = {};
    for (final doc in historySnap.docs) {
      final data = doc.data();
      final takenAt = _parseTakenAt(data['takenAt']);
      if (takenAt == null || !_isSameDay(takenAt, date)) continue;

      final idKey = data['id']?.toString();
      if (idKey != null && idKey.isNotEmpty) {
        dosesByKey[idKey] = data;
      }
      final medName = data['medicineName']?.toString();
      if (medName != null && medName.isNotEmpty) {
        dosesByKey.putIfAbsent('name:$medName', () => data);
      }
    }

    final medicines = medicinesSnap.docs
        .map((d) => {...d.data(), 'id': d.id})
        .toList();

    return {'doses': dosesByKey, 'medicines': medicines};
  }

  Map<String, dynamic>? _doseFor(
      Map<String, dynamic> med, Map<String, Map<String, dynamic>> doses) {
    final id = med['id']?.toString();
    if (id != null && doses.containsKey(id)) return doses[id];
    final name = med['name']?.toString();
    if (name != null && doses.containsKey('name:$name')) {
      return doses['name:$name'];
    }
    return null;
  }

  // 'taken' | 'missed' | 'upcoming'
  String _statusFor(Map<String, dynamic> med, Map<String, dynamic>? dose, DateTime date) {
    if (dose != null && dose['successful'] == true) return 'taken';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = DateTime(date.year, date.month, date.day);

    if (selectedDay.isAfter(today)) return 'upcoming';
    if (selectedDay.isBefore(today)) return 'missed';

    // Selected day is today — compare against the scheduled time-of-day.
    final timeStr = (med['time'] ?? '').toString();
    final parts = timeStr.split(':');
    if (parts.length == 2) {
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour != null && minute != null) {
        final scheduled = DateTime(now.year, now.month, now.day, hour, minute);
        return now.isAfter(scheduled) ? 'missed' : 'upcoming';
      }
    }
    return 'upcoming';
  }

  // ─── 7-day mini calendar row ───────────────────────────────────────────────

  Widget _buildMiniCalendar(BuildContext context) {
    final today = DateTime.now();
    final days  = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));

    return Container(
      color: AppColors.primary(context),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: days.map((day) {
          final isSelected = _isSameDay(day, _selectedDate);
          final isToday    = _isSameDay(day, today);

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedDate = day),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('E').format(day)[0], // M T W T F S S
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected ? AppColors.primary(context) : Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? AppColors.primary(context) : Colors.white,
                      ),
                    ),
                    if (isToday)
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary(context) : Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('Medicine History'),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: _buildMiniCalendar(context),
        ),
      ),
      // ✅ FIX: rebuilds (and re-fetches) the instant a medicine is marked
      // taken elsewhere in the app, instead of only on tab switch.
      body: ValueListenableBuilder<int>(
        valueListenable: MedicineEvents.refreshTick,
        builder: (context, _, __) => Column(
          children: [
            // Date navigation
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _prevDay,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primaryLight(context),
                      foregroundColor: AppColors.primary(context),
                    ),
                  ),
                  Text(
                    _isSameDay(_selectedDate, DateTime.now())
                        ? 'Today'
                        : _formattedDate,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _nextDay,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primaryLight(context),
                      foregroundColor: AppColors.primary(context),
                    ),
                  ),
                ],
              ),
            ),

            // History list
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: _fetchHistory(_selectedDate),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: Text('No data'));
                  }

                  final doses     = snapshot.data!['doses'] as Map<String, Map<String, dynamic>>;
                  final medicines = snapshot.data!['medicines'] as List<Map<String, dynamic>>;

                  if (medicines.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('💊', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          Text('No medicines for this day',
                              style: TextStyle(fontSize: 16, color: AppColors.textSecondary(context))),
                        ],
                      ),
                    );
                  }

                  final taken  = medicines.where((m) => _statusFor(m, _doseFor(m, doses), _selectedDate) == 'taken').length;
                  final missed = medicines.where((m) => _statusFor(m, _doseFor(m, doses), _selectedDate) == 'missed').length;
                  final total  = medicines.length;
                  final pct    = total > 0 ? (taken / total * 100).round() : 0;

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Summary card
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surface(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.cardBorder(context)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _SummaryTile(value: '$taken', label: 'Taken', color: AppColors.success(context)),
                            _SummaryTile(value: '$missed', label: 'Missed', color: AppColors.danger(context)),
                            _SummaryTile(value: '$total', label: 'Total', color: AppColors.primary(context)),
                            _SummaryTile(value: '$pct%', label: 'Adherence', color: kAccentAmber),
                          ],
                        ),
                      ),

                      // Medicine rows
                      ...medicines.map((med) {
                        final dose   = _doseFor(med, doses);
                        final status = _statusFor(med, dose, _selectedDate);

                        Color statusColor;
                        Color statusBg;
                        String statusLabel;

                        switch (status) {
                          case 'taken':
                            statusColor = AppColors.success(context);
                            statusBg    = AppColors.successLight(context);
                            statusLabel = 'Taken';
                            break;
                          case 'missed':
                            statusColor = AppColors.danger(context);
                            statusBg    = AppColors.dangerLight(context);
                            statusLabel = 'Missed';
                            break;
                          default:
                            statusColor = AppColors.textSecondary(context);
                            statusBg    = AppColors.primaryLight(context);
                            statusLabel = 'Upcoming';
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface(context),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.cardBorder(context)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight(context),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: Text('💊', style: TextStyle(fontSize: 22)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      med['name'] ?? '',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary(context),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${med['dose']}  •  ${med['time']}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Summary tile widget ───────────────────────────────────────────────────

class _SummaryTile extends StatelessWidget {
  final String value;
  final String label;
  final Color  color;

  const _SummaryTile({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context)),
        ),
      ],
    );
  }
}