import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// ─── Color tokens (same as main.dart) ─────────────────────────────────────
const Color kPrimary       = Color(0xFF6B3FA0);
const Color kPrimaryLight  = Color(0xFFF0E6FF);
const Color kSuccess       = Color(0xFF2E7D32);
const Color kSuccessLight  = Color(0xFFE8F5E9);
const Color kDanger        = Color(0xFFC62828);
const Color kDangerLight   = Color(0xFFFFEBEE);
const Color kTextPrimary   = Color(0xFF1A1A2E);
const Color kTextSecondary = Color(0xFF6B6B80);
const Color kBackground    = Color(0xFFFAF7FF);
const Color kSurface       = Color(0xFFFFFFFF);

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

  // ─── Fetch dose records for selected date ─────────────────────────────────

  Future<Map<String, dynamic>> _fetchHistory(DateTime date) async {
    final dateKey = DateFormat('yyyy-MM-dd').format(date);

    final dosesSnap = await _db
        .collection('users')
        .doc(widget.userId)
        .collection('history')
        .doc(dateKey)
        .collection('doses')
        .get();

    final medicinesSnap = await _db
        .collection('users')
        .doc(widget.userId)
        .collection('medicines')
        .get();

    final Map<String, Map<String, dynamic>> doses = {};
    for (final doc in dosesSnap.docs) {
      doses[doc.id] = doc.data();
    }

    final List<Map<String, dynamic>> medicines = medicinesSnap.docs
        .map((d) => {...d.data(), 'id': d.id})
        .toList();

    return {'doses': doses, 'medicines': medicines};
  }

  // ─── 7-day mini calendar row ───────────────────────────────────────────────

  Widget _buildMiniCalendar() {
    final today = DateTime.now();
    final days  = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));

    return Container(
      color: kPrimary,
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
                        color: isSelected ? kPrimary : Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? kPrimary : Colors.white,
                      ),
                    ),
                    if (isToday)
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isSelected ? kPrimary : Colors.white,
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
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        title: const Text('Medicine History'),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: _buildMiniCalendar(),
        ),
      ),
      body: Column(
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
                    backgroundColor: kPrimaryLight,
                    foregroundColor: kPrimary,
                  ),
                ),
                Text(
                  _isSameDay(_selectedDate, DateTime.now())
                      ? 'Today'
                      : _formattedDate,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _nextDay,
                  style: IconButton.styleFrom(
                    backgroundColor: kPrimaryLight,
                    foregroundColor: kPrimary,
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
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('💊', style: TextStyle(fontSize: 48)),
                        SizedBox(height: 12),
                        Text('No medicines for this day',
                            style: TextStyle(fontSize: 16, color: kTextSecondary)),
                      ],
                    ),
                  );
                }

                // Summary card
                final taken  = doses.values.where((d) => d['missed'] == false).length;
                final missed = doses.values.where((d) => d['missed'] == true).length;
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
                        color: kSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE8E0F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _SummaryTile(value: '$taken', label: 'Taken', color: kSuccess),
                          _SummaryTile(value: '$missed', label: 'Missed', color: kDanger),
                          _SummaryTile(value: '$total', label: 'Total', color: kPrimary),
                          _SummaryTile(value: '$pct%', label: 'Adherence', color: const Color(0xFFEF9F27)),
                        ],
                      ),
                    ),

                    // Medicine rows
                    ...medicines.map((med) {
                      final medId     = med['id'] as String;
                      final doseData  = doses[medId];
                      final wasTaken  = doseData != null && doseData['missed'] == false;
                      final wasMissed = doseData != null && doseData['missed'] == true;
                      final noRecord  = doseData == null;

                      Color statusColor;
                      String statusLabel;
                      Color statusBg;

                      if (wasTaken) {
                        statusColor = kSuccess;
                        statusBg    = kSuccessLight;
                        statusLabel = 'Taken';
                      } else if (wasMissed) {
                        statusColor = kDanger;
                        statusBg    = kDangerLight;
                        statusLabel = 'Missed';
                      } else {
                        statusColor = kTextSecondary;
                        statusBg    = const Color(0xFFF5F5F5);
                        statusLabel = noRecord ? 'No record' : 'Pending';
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: kSurface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE8E0F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: kPrimaryLight,
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
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: kTextPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${med['dose']}  •  ${med['time']}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: kTextSecondary,
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
          style: const TextStyle(fontSize: 11, color: kTextSecondary),
        ),
      ],
    );
  }
}