// ─────────────────────────────────────────────────────────────────────────────
// FILE:  lib/screens/caretaker_screen.dart
// STEP:  1. Create this file at lib/screens/caretaker_screen.dart
//        2. In AuthWrapper (main.dart), after fetching user profile,
//           if user.isCaregiver == true → route to CaretakerShell
//           else → route to MainShell (existing)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medicine_model.dart';
import '../services/auth_service.dart';

const Color kPrimary       = Color(0xFF534AB7);   // caretaker uses blue-purple
const Color kPrimaryLight  = Color(0xFFEEEDFE);
const Color kSuccess       = Color(0xFF2E7D32);
const Color kSuccessLight  = Color(0xFFE8F5E9);
const Color kDanger        = Color(0xFFC62828);
const Color kDangerLight   = Color(0xFFFFEBEE);
const Color kWarning       = Color(0xFFF57C00);
const Color kWarningLight  = Color(0xFFFFF3E0);
const Color kTextPrimary   = Color(0xFF1A1A2E);
const Color kTextSecondary = Color(0xFF6B6B80);
const Color kBackground    = Color(0xFFFAF7FF);
const Color kSurface       = Color(0xFFFFFFFF);

class CaretakerShell extends StatelessWidget {
  final String caregiverUid;
  const CaretakerShell({super.key, required this.caregiverUid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _getElderUid(caregiverUid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final elderUid = snap.data;
        if (elderUid == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Caretaker')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.link_off, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('No elder account linked yet.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => AuthService.signOut(),
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          );
        }
        return CaretakerDashboard(elderUid: elderUid);
      },
    );
  }

  Future<String?> _getElderUid(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    return doc.data()?['elderUid'] as String?;
  }
}

class CaretakerDashboard extends StatefulWidget {
  final String elderUid;
  const CaretakerDashboard({super.key, required this.elderUid});

  @override
  State<CaretakerDashboard> createState() => _CaretakerDashboardState();
}

class _CaretakerDashboardState extends State<CaretakerDashboard> {
  String _elderName = 'Elder';

  @override
  void initState() {
    super.initState();
    _loadElderName();
  }

  Future<void> _loadElderName() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.elderUid)
        .get();
    if (doc.exists && mounted) {
      setState(() => _elderName = doc.data()?['name'] ?? 'Elder');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        title: Text('Caring for $_elderName'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.elderUid)
            .collection('medicines')
            .orderBy('time')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No medicines added yet.',
                style: TextStyle(color: kTextSecondary),
              ),
            );
          }

          final medicines = docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            return Medicine.fromMap({...data, 'id': d.id});
          }).toList();

          final taken  = medicines.where((m) => m.taken).length;
          final total  = medicines.length;
          final pct    = total > 0 ? (taken / total * 100).round() : 0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary banner
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: kPrimary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.favorite_outline,
                        color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_elderName today',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                        Text(
                          '$taken of $total taken ($pct%)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Medicine cards (read-only)
              ...medicines.map((med) => _CaretakerMedicineCard(medicine: med)),
            ],
          );
        },
      ),
    );
  }
}

class _CaretakerMedicineCard extends StatelessWidget {
  final Medicine medicine;
  const _CaretakerMedicineCard({required this.medicine});

  @override
  Widget build(BuildContext context) {
    final isTaken = medicine.taken;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isTaken
              ? const Color(0xFFA5D6A7)
              : const Color(0xFFE8E0F0),
        ),
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
                  medicine.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary,
                  ),
                ),
                Text(
                  '${medicine.dose}  •  ${medicine.time}',
                  style: const TextStyle(
                      fontSize: 12, color: kTextSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isTaken ? kSuccessLight : kWarningLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isTaken ? 'Taken' : 'Pending',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isTaken ? kSuccess : kWarning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}