import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart'; // AppColors

class AnalyticsScreen extends StatefulWidget {
  final String userId;
  const AnalyticsScreen({super.key, required this.userId});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _db = FirebaseFirestore.instance;
  bool _loading = true;

  int    _takenDoses   = 0;
  int    _totalDoses   = 0;
  int    _streak       = 0;
  double _adherencePct = 0;

  // 7 entries, one per day oldest→newest
  final List<_DayData> _chartData = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    // ── 1. Fetch ALL history docs once ──────────────────────────────────────
    // Each doc was written by FirestoreService.markAsTaken() with fields:
    //   takenAt  : ISO-8601 string   e.g. "2025-06-15T08:03:22.000"
    //   successful: bool
    final histSnap = await _db
        .collection('users')
        .doc(widget.userId)
        .collection('history')
        .get();

    // ── 2. Bucket by date string "yyyy-MM-dd" ────────────────────────────────
    // Map<dateKey, {taken, missed}>
    final Map<String, _Bucket> buckets = {};

    for (final doc in histSnap.docs) {
      final raw = doc.data()['takenAt'];
      if (raw == null) continue;
      DateTime dt;
      try {
        dt = DateTime.parse(raw as String);
      } catch (_) {
        continue;
      }
      final key =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      buckets.putIfAbsent(key, () => _Bucket());
      if (doc.data()['successful'] == true) {
        buckets[key]!.taken++;
      } else {
        buckets[key]!.missed++;
      }
    }

    // ── 3. Fetch today's medicines count for denominator ────────────────────
    // "Total doses" for today = how many medicines the user currently has.
    // For past days we don't have a reliable total, so we treat each history
    // doc as one dose (taken OR missed).
    final medSnap = await _db
        .collection('users')
        .doc(widget.userId)
        .collection('medicines')
        .get();
    final todayMedCount = medSnap.docs.length;

    // ── 4. Build 7-day chart ─────────────────────────────────────────────────
    final now = DateTime.now();
    _chartData.clear();
    int streak = 0;
    bool streakBroken = false;

    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final bucket = buckets[key] ?? _Bucket();

      // For today, total = number of current medicines (gives a real pending count)
      // For past days, total = taken + missed recorded in history
      final int dayTotal =
          i == 0 ? todayMedCount : (bucket.taken + bucket.missed);

      _chartData.add(_DayData(
        label  : _shortDay(day.weekday),
        taken  : bucket.taken,
        missed : bucket.missed,
        total  : dayTotal,
        isToday: i == 0,
      ));

      // Streak: consecutive days from today backwards where nothing was missed
      if (!streakBroken && i == 0) {
        // today counts only if at least one dose taken and none missed
        if (bucket.taken > 0 && bucket.missed == 0) {
          streak++;
        } else {
          streakBroken = true;
        }
      } else if (!streakBroken && i > 0) {
        if (bucket.taken > 0 && bucket.missed == 0) {
          streak++;
        } else if (bucket.taken + bucket.missed > 0) {
          streakBroken = true;
        }
        // days with no data at all don't break the streak
      }
    }

    // ── 5. Totals across 7 days ───────────────────────────────────────────────
    int taken7 = 0, total7 = 0;
    for (final d in _chartData) {
      taken7 += d.taken;
      total7 += d.total;
    }

    setState(() {
      _takenDoses   = taken7;
      _totalDoses   = total7;
      _streak       = streak;
      _adherencePct = total7 > 0 ? (taken7 / total7 * 100) : 0;
      _loading      = false;
    });
  }

  static String _shortDay(int weekday) {
    const d = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return d[weekday - 1];
  }

  int get _missedDoses => _totalDoses - _takenDoses;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
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
                  // ── Stat cards ─────────────────────────────────────────
                  Row(
                    children: [
                      _StatCard(
                        value: '${_adherencePct.round()}%',
                        label: 'Adherence',
                        color: AppColors.primary(context),
                        flex : 2,
                      ),
                      const SizedBox(width: 10),
                      _StatCard(
                        value: '$_streak',
                        label: 'Day streak 🔥',
                        color: kAccentAmber,
                        flex : 1,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _StatCard(
                        value: '$_takenDoses',
                        label: 'Taken (7d)',
                        color: AppColors.success(context),
                      ),
                      const SizedBox(width: 10),
                      _StatCard(
                        value: '$_missedDoses',
                        label: 'Missed (7d)',
                        color: AppColors.danger(context),
                      ),
                      const SizedBox(width: 10),
                      _StatCard(
                        value: '$_totalDoses',
                        label: 'Total (7d)',
                        color: AppColors.textSecondary(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── 7-day bar chart ────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Last 7 days',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Purple = today · Green = taken · Red = missed',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary(context)),
                        ),
                        const SizedBox(height: 20),
                        _BarChart(data: _chartData),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Daily breakdown ────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            'Daily breakdown',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                        ),
                        ..._chartData.reversed
                            .map((d) => _DayRow(data: d)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
    );
  }
}

// ─── Internal bucket ─────────────────────────────────────────────────────────

class _Bucket {
  int taken  = 0;
  int missed = 0;
}

// ─── Widgets ─────────────────────────────────────────────────────────────────

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
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder(context)),
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
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary(context)),
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

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (missedH > 0)
                        Container(
                          height: missedH,
                          decoration: BoxDecoration(
                            color: AppColors.dangerLight(context),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                        ),
                      if (takenH > 0)
                        Container(
                          height: takenH,
                          decoration: BoxDecoration(
                            color: d.isToday
                                ? AppColors.primary(context)
                                : AppColors.success(context),
                            borderRadius: BorderRadius.vertical(
                              top: missedH == 0
                                  ? const Radius.circular(4)
                                  : Radius.zero,
                            ),
                          ),
                        ),
                      if (d.total == 0)
                        Container(
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: AppColors.cardBorder(context),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  d.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        d.isToday ? FontWeight.w700 : FontWeight.normal,
                    color: d.isToday
                        ? AppColors.primary(context)
                        : AppColors.textSecondary(context),
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
      status      = 'No data';
      statusColor = AppColors.textSecondary(context);
      statusBg    = AppColors.cardBorder(context);
    } else if (data.missed == 0) {
      status      = 'All taken ✓';
      statusColor = AppColors.success(context);
      statusBg    = AppColors.successLight(context);
    } else if (data.taken == 0) {
      status      = 'All missed';
      statusColor = AppColors.danger(context);
      statusBg    = AppColors.dangerLight(context);
    } else {
      status      = '${data.taken}/${data.total}';
      statusColor = kAccentAmber;
      statusBg    = AppColors.warningLight(context);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.cardBorder(context), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Text(
            data.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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