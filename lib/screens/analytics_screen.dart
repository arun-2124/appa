// ─────────────────────────────────────────────────────────────────────────────
// FILE:  lib/screens/analytics_screen.dart
// STEP:  Create this file at lib/screens/analytics_screen.dart
//        Then in main.dart add it to the bottom navigation (index 1)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

const Color kPrimary      = Color(0xFF6B3FA0);
const Color kPrimaryLight = Color(0xFFF0E6FF);
const Color kAccentAmber  = Color(0xFFEF9F27);
const Color kSuccess      = Color(0xFF2E7D32);
const Color kSuccessLight = Color(0xFFE8F5E9);
const Color kDanger       = Color(0xFFC62828);
const Color kDangerLight  = Color(0xFFFFEBEE);
const Color kTextPrimary  = Color(0xFF1A1A2E);
const Color kTextSecondary= Color(0xFF6B6B80);
const Color kBackground   = Color(0xFFFAF7FF);
const Color kSurface      = Color(0xFFFFFFFF);

class AnalyticsScreen extends StatefulWidget {
  final String userId;
  const AnalyticsScreen({super.key, required this.userId});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _db = FirebaseFirestore.instance;
  bool _loading = true;

  // Stats
  int    _totalDoses    = 0;
  int    _takenDoses    = 0;
  int    _missedDoses   = 0;
  int    _streak        = 0;
  double _adherencePct  = 0;

  // 7-day chart data  key=date string, value=map{taken,total}
  final List<_DayData> _chartData = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final now = DateTime.now();
    int taken = 0, missed = 0, total = 0, streak = 0;
    bool streakBroken = false;

    _chartData.clear();

    // Last 7 days
    for (int i = 6; i >= 0; i--) {
      final day    = now.subtract(Duration(days: i));
      final dateKey= DateFormat('yyyy-MM-dd').format(day);

      final snap = await _db
          .collection('users')
          .doc(widget.userId)
          .collection('history')
          .doc(dateKey)
          .collection('doses')
          .get();

      final dayTaken  = snap.docs.where((d) => d['missed'] == false).length;
      final dayMissed = snap.docs.where((d) => d['missed'] == true).length;
      final dayTotal  = snap.docs.length;

      taken  += dayTaken;
      missed += dayMissed;
      total  += dayTotal;

      _chartData.add(_DayData(
        label    : DateFormat('E').format(day),
        taken    : dayTaken,
        missed   : dayMissed,
        total    : dayTotal,
        isToday  : i == 0,
      ));

      // streak — count from today backwards while all taken
      if (!streakBroken) {
        if (dayTotal > 0 && dayMissed == 0) {
          streak++;
        } else if (dayTotal > 0) {
          streakBroken = true;
        }
      }
    }

    setState(() {
      _takenDoses   = taken;
      _missedDoses  = missed;
      _totalDoses   = total;
      _streak       = streak;
      _adherencePct = total > 0 ? (taken / total * 100) : 0;
      _loading      = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        title: const Text('Analytics'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Stat cards row ────────────────────────────────────────
                  Row(
                    children: [
                      _StatCard(
                        value : '${_adherencePct.round()}%',
                        label : 'Adherence',
                        color : kPrimary,
                        flex  : 2,
                      ),
                      const SizedBox(width: 10),
                      _StatCard(
                        value : '$_streak',
                        label : 'Day streak',
                        color : kAccentAmber,
                        flex  : 1,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _StatCard(
                        value : '$_takenDoses',
                        label : 'Taken (7d)',
                        color : kSuccess,
                      ),
                      const SizedBox(width: 10),
                      _StatCard(
                        value : '$_missedDoses',
                        label : 'Missed (7d)',
                        color : kDanger,
                      ),
                      const SizedBox(width: 10),
                      _StatCard(
                        value : '$_totalDoses',
                        label : 'Total (7d)',
                        color : kTextSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── 7-day bar chart ───────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE8E0F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Last 7 days',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: kTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Green = taken · Red = missed',
                          style: TextStyle(
                              fontSize: 12, color: kTextSecondary),
                        ),
                        const SizedBox(height: 20),
                        _BarChart(data: _chartData),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Daily breakdown list ──────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: kSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE8E0F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            'Daily breakdown',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: kTextPrimary,
                            ),
                          ),
                        ),
                        ..._chartData.reversed.map((d) => _DayRow(data: d)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color  color;
  final int    flex;

  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
    this.flex = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8E0F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 12, color: kTextSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayData {
  final String label;
  final int    taken;
  final int    missed;
  final int    total;
  final bool   isToday;

  const _DayData({
    required this.label,
    required this.taken,
    required this.missed,
    required this.total,
    required this.isToday,
  });

  double get takenFrac  => total > 0 ? taken  / total : 0;
  double get missedFrac => total > 0 ? missed / total : 0;
}

class _BarChart extends StatelessWidget {
  final List<_DayData> data;
  const _BarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    const maxH = 100.0;
    return SizedBox(
      height: maxH + 24,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.map((d) {
          final takenH  = d.takenFrac  * maxH;
          final missedH = d.missedFrac * maxH;
          final emptyH  = d.total == 0 ? 8.0 : 0.0;

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Bars
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (missedH > 0)
                        Container(
                          height: missedH,
                          decoration: BoxDecoration(
                            color: kDangerLight,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                        ),
                      if (takenH > 0)
                        Container(
                          height: takenH,
                          decoration: BoxDecoration(
                            color: d.isToday ? kPrimary : kSuccess,
                            borderRadius: BorderRadius.vertical(
                              top: missedH == 0
                                  ? const Radius.circular(4)
                                  : Radius.zero,
                              bottom: const Radius.circular(0),
                            ),
                          ),
                        ),
                      if (emptyH > 0)
                        Container(
                          height: emptyH,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8E0F0),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // Label
                Text(
                  d.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        d.isToday ? FontWeight.w700 : FontWeight.normal,
                    color: d.isToday ? kPrimary : kTextSecondary,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  final _DayData data;
  const _DayRow({required this.data});

  @override
  Widget build(BuildContext context) {
    String status;
    Color  statusColor;
    Color  statusBg;

    if (data.total == 0) {
      status = 'No data';
      statusColor = kTextSecondary;
      statusBg    = const Color(0xFFF5F5F5);
    } else if (data.missed == 0) {
      status = 'All taken';
      statusColor = kSuccess;
      statusBg    = kSuccessLight;
    } else if (data.taken == 0) {
      status = 'All missed';
      statusColor = kDanger;
      statusBg    = kDangerLight;
    } else {
      status = '${data.taken}/${data.total}';
      statusColor = kAccentAmber;
      statusBg    = const Color(0xFFFFF3E0);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF0EAF8), width: 0.5)),
      ),
      child: Row(
        children: [
          Text(
            data.label,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
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
  }
}