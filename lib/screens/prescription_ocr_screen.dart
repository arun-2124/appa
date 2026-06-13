// ─────────────────────────────────────────────────────────────────────────────
// FILE:  lib/screens/prescription_ocr_screen.dart
// STEP:  1. Create this file at lib/screens/prescription_ocr_screen.dart
//        2. Add to pubspec.yaml:
//              image_picker: ^1.1.2
//              http: ^1.2.0
//        3. Add to AndroidManifest.xml (inside <manifest>):
//              <uses-permission android:name="android.permission.CAMERA"/>
//              <uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
//        4. Add to ios/Runner/Info.plist:
//              <key>NSCameraUsageDescription</key>
//              <string>Take photo of doctor prescription</string>
//              <key>NSPhotoLibraryUsageDescription</key>
//              <string>Select prescription from photo library</string>
//        5. In main.dart → HomeScreen AppBar actions, add:
//              IconButton(
//                icon: const Icon(Icons.document_scanner_outlined),
//                onPressed: () => Navigator.push(context, MaterialPageRoute(
//                  builder: (_) => PrescriptionOcrScreen(userId: widget.userId))),
//              )
//        6. IMPORTANT: Replace 'YOUR_ANTHROPIC_API_KEY' with your real key
//           Get it from: https://console.anthropic.com
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../models/medicine_model.dart';

const Color kPrimary      = Color(0xFF6B3FA0);
const Color kPrimaryLight = Color(0xFFF0E6FF);
const Color kSuccess      = Color(0xFF2E7D32);
const Color kSuccessLight = Color(0xFFE8F5E9);
const Color kDanger       = Color(0xFFC62828);
const Color kDangerLight  = Color(0xFFFFEBEE);
const Color kTextPrimary  = Color(0xFF1A1A2E);
const Color kTextSecondary= Color(0xFF6B6B80);
const Color kBackground   = Color(0xFFFAF7FF);
const Color kSurface      = Color(0xFFFFFFFF);

// ⚠️ Replace with your Anthropic API key
// Get from: https://console.anthropic.com
const String _apiKey = 'YOUR_ANTHROPIC_API_KEY';

class PrescriptionOcrScreen extends StatefulWidget {
  final String userId;
  const PrescriptionOcrScreen({super.key, required this.userId});

  @override
  State<PrescriptionOcrScreen> createState() =>
      _PrescriptionOcrScreenState();
}

class _PrescriptionOcrScreenState extends State<PrescriptionOcrScreen> {
  File?        _image;
  bool         _scanning  = false;
  bool         _adding    = false;
  String       _error     = '';
  List<_ExtractedMedicine> _extracted = [];

  final _picker = ImagePicker();

  // ── Pick image ─────────────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    final xFile = await _picker.pickImage(
      source     : source,
      imageQuality: 85,
      maxWidth   : 1200,
    );
    if (xFile == null) return;
    setState(() {
      _image     = File(xFile.path);
      _extracted = [];
      _error     = '';
    });
    await _scanPrescription();
  }

  // ── Send to Claude Vision ──────────────────────────────────────────────────

  Future<void> _scanPrescription() async {
    if (_image == null) return;
    setState(() { _scanning = true; _error = ''; });

    try {
      final bytes  = await _image!.readAsBytes();
      final base64 = base64Encode(bytes);

      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type'     : 'application/json',
          'x-api-key'        : _apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model'     : 'claude-sonnet-4-20250514',
          'max_tokens': 1000,
          'messages'  : [
            {
              'role'   : 'user',
              'content': [
                {
                  'type'  : 'image',
                  'source': {
                    'type'      : 'base64',
                    'media_type': 'image/jpeg',
                    'data'      : base64,
                  },
                },
                {
                  'type': 'text',
                  'text': '''
You are a medical prescription reader.
Look at this prescription image and extract all medicines.
Return ONLY a valid JSON array. No explanation, no markdown, no backticks.
Format: [{"name":"medicine name","dose":"dose amount","time":"HH:MM in 24hr format"}]
If you cannot find a time, use "08:00" as default.
If no medicines found, return [].
''',
                },
              ],
            }
          ],
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('API error ${response.statusCode}: ${response.body}');
      }

      final data    = jsonDecode(response.body);
      final text    = (data['content'] as List)
          .where((c) => c['type'] == 'text')
          .map((c) => c['text'] as String)
          .join('');

      // Clean and parse JSON
      final clean   = text
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final list    = jsonDecode(clean) as List;
      setState(() {
        _extracted = list
            .map((m) => _ExtractedMedicine(
                  name    : m['name']   ?? '',
                  dose    : m['dose']   ?? '',
                  time    : m['time']   ?? '08:00',
                  selected: true,
                ))
            .where((m) => m.name.isNotEmpty)
            .toList();
      });

    } catch (e) {
      setState(() => _error = 'Could not read prescription: $e');
    } finally {
      setState(() => _scanning = false);
    }
  }

  // ── Add confirmed medicines ────────────────────────────────────────────────

  Future<void> _addAll() async {
    final toAdd = _extracted.where((m) => m.selected).toList();
    if (toAdd.isEmpty) return;

    setState(() => _adding = true);

    try {
      for (final m in toAdd) {
        final id = DateTime.now().millisecondsSinceEpoch.toString();
        final med = Medicine(
          id       : id,
          userId   : widget.userId,
          name     : m.name,
          dose     : m.dose,
          time     : m.time,
          createdAt: DateTime.now(),
        );
        await FirestoreService.addMedicine(med);
        await NotificationService.schedule(med);
        await Future.delayed(const Duration(milliseconds: 50));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${toAdd.length} medicine${toAdd.length > 1 ? 's' : ''} added!'),
          backgroundColor: kSuccess,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _error = 'Error adding medicines: $e');
    } finally {
      setState(() => _adding = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        title: const Text('Scan Prescription'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          // Pick buttons
          Row(
            children: [
              Expanded(
                child: _PickButton(
                  icon : Icons.camera_alt_outlined,
                  label: 'Take photo',
                  onTap: () => _pickImage(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PickButton(
                  icon : Icons.photo_library_outlined,
                  label: 'Choose from gallery',
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Preview
          if (_image != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(
                _image!,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
          if (_image != null) const SizedBox(height: 16),

          // Scanning indicator
          if (_scanning)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kPrimaryLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width : 20,
                    height: 20,
                    child : CircularProgressIndicator(
                        strokeWidth: 2, color: kPrimary),
                  ),
                  SizedBox(width: 14),
                  Text(
                    'Claude is reading the prescription…',
                    style: TextStyle(color: kPrimary),
                  ),
                ],
              ),
            ),

          // Error
          if (_error.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kDangerLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_error,
                  style: const TextStyle(color: kDanger, fontSize: 13)),
            ),

          // Results
          if (_extracted.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'Found medicines — select which to add:',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            ..._extracted.asMap().entries.map((entry) {
              final i = entry.key;
              final m = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: m.selected
                        ? kPrimary
                        : const Color(0xFFE8E0F0),
                    width: m.selected ? 1.5 : 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value     : m.selected,
                      activeColor: kPrimary,
                      onChanged  : (v) => setState(
                          () => _extracted[i] = m.copyWith(selected: v ?? true)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.name,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${m.dose}  •  ${m.time}',
                            style: const TextStyle(
                                fontSize: 12, color: kTextSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
            SizedBox(
              width : double.infinity,
              height: 52,
              child : ElevatedButton.icon(
                onPressed: _adding ? null : _addAll,
                icon : _adding
                    ? const SizedBox(
                        width : 18,
                        height: 18,
                        child : CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.add_circle_outline),
                label: Text(
                  'Add ${_extracted.where((m) => m.selected).length} medicine(s)',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Models ───────────────────────────────────────────────────────────────────

class _ExtractedMedicine {
  final String name;
  final String dose;
  final String time;
  final bool   selected;

  const _ExtractedMedicine({
    required this.name,
    required this.dose,
    required this.time,
    required this.selected,
  });

  _ExtractedMedicine copyWith({bool? selected}) => _ExtractedMedicine(
    name    : name,
    dose    : dose,
    time    : time,
    selected: selected ?? this.selected,
  );
}

// ─── Pick button ──────────────────────────────────────────────────────────────

class _PickButton extends StatelessWidget {
  final IconData   icon;
  final String     label;
  final VoidCallback onTap;

  const _PickButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: kPrimaryLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD0B0F0)),
        ),
        child: Column(
          children: [
            Icon(icon, color: kPrimary, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 12, color: kPrimary, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}