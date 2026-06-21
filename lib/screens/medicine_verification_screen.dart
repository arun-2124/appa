import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../main.dart'; // ✅ FIX: was '../app_theme.dart', which doesn't exist.
                        // AppColors actually lives in main.dart.
import '../services/inference_service.dart';

// ─── AI Medicine Check Screen ───────────────────────────────────────────
// This is built against your REAL InferenceService, which is an on-device
// TFLite image classifier (identifies pill/tablet shape from a photo) —
// it has no text-generation method, so it can't run a chat box. This
// screen does what the model actually supports: photograph a pill, get
// back a shape label + confidence so the person can sanity-check it.
//
// Needs the `image_picker` package added to pubspec.yaml, e.g.:
//   image_picker: ^1.0.7

class MedicineVerificationScreen extends StatefulWidget {
  final String userId;
  const MedicineVerificationScreen({super.key, required this.userId});

  @override
  State<MedicineVerificationScreen> createState() =>
      _MedicineVerificationScreenState();
}

class _MedicineVerificationScreenState
    extends State<MedicineVerificationScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _image;
  bool _isChecking = false;
  Map<String, dynamic>? _result;
  String? _error;

  Future<void> _pickAndCheck(ImageSource source) async {
    setState(() {
      _error = null;
      _result = null;
    });

    final XFile? picked = await _picker.pickImage(source: source, maxWidth: 1024);
    if (picked == null) return;

    setState(() {
      _image = File(picked.path);
      _isChecking = true;
    });

    try {
      if (!InferenceService.isReady) {
        await InferenceService.init();
      }
      final bytes = await picked.readAsBytes();
      final result = InferenceService.classify(bytes);
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = "Couldn't analyze that photo: $e");
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(title: const Text('Check a Medicine')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Take or choose a photo of a tablet or capsule. The on-device '
              'model will identify its shape so you can double-check it '
              'against what you expect.',
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            if (_image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(_image!, height: 220, fit: BoxFit.cover),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isChecking
                        ? null
                        : () => _pickAndCheck(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isChecking
                        ? null
                        : () => _pickAndCheck(ImageSource.gallery),
                    icon: Icon(Icons.photo_library_outlined,
                        color: AppColors.primary(context)),
                    label: Text('Gallery',
                        style: TextStyle(color: AppColors.primary(context))),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.primary(context)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_isChecking)
              const Center(child: CircularProgressIndicator()),
            if (_error != null)
              Text(_error!, style: TextStyle(color: AppColors.danger(context))),
            if (_result != null) _ResultCard(result: _result!),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final Map<String, dynamic> result;
  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final String label = result['label'] as String;
    final double confidence = (result['confidence'] as double) * 100;

    return Container(
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
            'Detected: $label',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Confidence: ${confidence.toStringAsFixed(0)}%',
            style: TextStyle(color: AppColors.textSecondary(context)),
          ),
          const SizedBox(height: 10),
          Text(
            confidence >= 70
                ? "This looks like a good match, but please still confirm "
                    "the label yourself before taking it."
                : "The model isn't very confident here — please verify "
                    "visually or check with a pharmacist.",
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}