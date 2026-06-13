import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medicine_model.dart';
import '../models/history_entry_model.dart';

class FirestoreService {
  static final _firestore = FirebaseFirestore.instance;

  // Add medicine
  static Future<void> addMedicine(Medicine medicine) async {
    await _firestore
        .collection('users')
        .doc(medicine.userId)
        .collection('medicines')
        .doc(medicine.id)
        .set(medicine.toMap());
  }

  // Get medicines stream (real-time)
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

  // Mark as taken
  static Future<void> markAsTaken(String userId, String medicineId, String medicineName) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('medicines')
        .doc(medicineId)
        .update({
      'taken': true,
      'takenAt': DateTime.now().toIso8601String(),
    });

    // Add to history
    final entry = HistoryEntry(
      id: medicineId,
      userId: userId,
      medicineName: medicineName,
      takenAt: DateTime.now(),
      successful: true,
    );

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('history')
        .doc('${medicineId}_${DateTime.now().toIso8601String()}')
        .set(entry.toMap());
  }

  // Delete medicine
  static Future<void> deleteMedicine(String userId, String medicineId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('medicines')
        .doc(medicineId)
        .delete();
  }

  // Get adherence percentage (last 30 days)
  static Future<double> getAdherence(String userId) async {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('history')
        .where('takenAt',
            isGreaterThanOrEqualTo: thirtyDaysAgo.toIso8601String())
        .get();

    if (snapshot.docs.isEmpty) return 0.0;

    final successful = snapshot.docs.where((doc) => doc['successful'] == true).length;
    return (successful / snapshot.docs.length) * 100;
  }
  static Future<Map<String, dynamic>?> getUserProfile(String uid) async {
  final doc = await _firestore.collection('users').doc(uid).get();
  if (!doc.exists) return null;
  return doc.data();
  }
}