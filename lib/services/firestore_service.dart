import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medicine_model.dart';
import '../models/history_entry_model.dart';

class FirestoreService {
  static final _firestore = FirebaseFirestore.instance;

  // ── Add medicine ────────────────────────────────────────────────────────────
  static Future<void> addMedicine(Medicine medicine) async {
    await _firestore
        .collection('users')
        .doc(medicine.userId)
        .collection('medicines')
        .doc(medicine.id)
        .set(medicine.toMap());
  }

  // ── Get medicines stream (real-time) ────────────────────────────────────────
  static Stream<List<Medicine>> getMedicinesStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('medicines')
        .orderBy('time')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Medicine.fromMap(doc.data()))
            .toList());
  }

  // ── Mark as taken ───────────────────────────────────────────────────────────
  static Future<void> markAsTaken(
      String userId, String medicineId, String medicineName) async {
    final now = DateTime.now();

    // Update the medicine doc — taken:true + timestamp
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('medicines')
        .doc(medicineId)
        .update({
      'taken'  : true,
      'takenAt': now.toIso8601String(),
    });

    // Write a history entry — one doc per dose per day.
    // Key includes the DATE so it's idempotent: tapping twice on the same day
    // overwrites the same doc instead of creating duplicates.
    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final entry = HistoryEntry(
      id          : medicineId,
      userId      : userId,
      medicineName: medicineName,
      takenAt     : now,
      successful  : true,
    );

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('history')
        .doc('${medicineId}_$dateKey')   // stable key per medicine per day
        .set(entry.toMap());
  }

  // ── Daily reset ─────────────────────────────────────────────────────────────
  // Call this once when the HomeScreen loads.
  // It checks every medicine: if takenAt is from a PREVIOUS day, reset
  // taken → false so the "Mark as Taken" button appears again today.
  static Future<void> resetDailyMedicines(String userId) async {
    final now     = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('medicines')
        .get();

    final batch = _firestore.batch();
    bool hasChanges = false;

    for (final doc in snap.docs) {
      final data    = doc.data();
      final taken   = data['taken'] as bool? ?? false;
      final takenAt = data['takenAt'] as String?;

      if (!taken) continue; // already reset, skip

      if (takenAt == null) {
        // taken=true but no timestamp — reset it
        batch.update(doc.reference, {'taken': false, 'takenAt': null});
        hasChanges = true;
        continue;
      }

      DateTime takenDate;
      try {
        takenDate = DateTime.parse(takenAt);
      } catch (_) {
        batch.update(doc.reference, {'taken': false, 'takenAt': null});
        hasChanges = true;
        continue;
      }

      final takenDay = DateTime(takenDate.year, takenDate.month, takenDate.day);

      if (takenDay.isBefore(todayStart)) {
        // Taken on a previous day → reset for today
        batch.update(doc.reference, {'taken': false, 'takenAt': null});
        hasChanges = true;
      }
    }

    if (hasChanges) await batch.commit();
  }

  // ── Delete medicine ─────────────────────────────────────────────────────────
  static Future<void> deleteMedicine(String userId, String medicineId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('medicines')
        .doc(medicineId)
        .delete();
  }

  // ── Adherence % (last 30 days) ──────────────────────────────────────────────
  static Future<double> getAdherence(String userId) async {
    final thirtyDaysAgo =
        DateTime.now().subtract(const Duration(days: 30));

    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('history')
        .where('takenAt',
            isGreaterThanOrEqualTo: thirtyDaysAgo.toIso8601String())
        .get();

    if (snapshot.docs.isEmpty) return 0.0;

    final successful =
        snapshot.docs.where((doc) => doc['successful'] == true).length;
    return (successful / snapshot.docs.length) * 100;
  }

  // ── User profile ────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc =
        await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return doc.data();
  }
}