
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class InferenceService {
  static Interpreter? _interpreter;
  static List<String> _labels  = [];
  static int          _inputW  = 224;   // auto-detected in init()
  static int          _inputH  = 224;
  static bool         _ready   = false;

  // ─── Init ────────────────────────────────────────────────────────────────
  // Call once in MedicineVerificationScreen.initState()

  static Future<void> init() async {
    if (_ready) return;

    try {
      // Load your trained model
      _interpreter = await Interpreter.fromAsset(
        'assets/models/model.tflite',
        options: InterpreterOptions()..threads = 2,
      );

      // ✅ Auto-detect input size from model tensor shape
      // This handles 224x224, 128x128, 320x320 — whatever your model uses
      final inputShape = _interpreter!.getInputTensor(0).shape;
      // shape is [1, height, width, channels]  e.g. [1, 224, 224, 3]
      _inputH = inputShape[1];
      _inputW = inputShape[2];

      // Print shapes so you can verify in the terminal
      debugPrint('─────────────────────────────');
      debugPrint('✅ TFLite model loaded');
      debugPrint('   Input  shape : $inputShape');
      debugPrint('   Input  size  : ${_inputW}x${_inputH}');
      debugPrint('   Output shape : ${_interpreter!.getOutputTensor(0).shape}');
      debugPrint('─────────────────────────────');

      // Load labels.txt
      final raw = await rootBundle.loadString('assets/models/labels.txt');
      _labels   = raw.trim().split('\n').map((l) => l.trim()).toList();
      debugPrint('   Labels : $_labels');

      _ready = true;

    } catch (e) {
      debugPrint('❌ TFLite init failed: $e');
      // Don't rethrow — app will fall back to histogram check
    }
  }

  // ─── Classify ────────────────────────────────────────────────────────────
  // Returns: { label: "round", confidence: 0.94, allScores: [...] }
  // Safe to run in compute() isolate

  static Map<String, dynamic> classify(Uint8List imageBytes) {
    if (_interpreter == null) {
      throw StateError('InferenceService not ready. Call init() first.');
    }

    // 1. Decode
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) throw Exception('Could not decode image.');

    // 2. Resize to exactly what the model needs
    final resized = img.copyResize(
      decoded,
      width        : _inputW,
      height       : _inputH,
      interpolation: img.Interpolation.linear,
    );

    // 3. Convert to Float32 [1, H, W, 3] normalised 0.0–1.0
    final inputTensor = _toFloat32(resized);

    // 4. Output buffer [1, numClasses]
    final outputBuffer = List.generate(
      1,
      (_) => List.filled(_labels.length, 0.0),
    );

    // 5. Run inference
    _interpreter!.run(inputTensor, outputBuffer);

    // 6. Parse result
    final scores    = List<double>.from(outputBuffer[0]);
    final maxScore  = scores.reduce(max);
    final maxIndex  = scores.indexOf(maxScore);
    final label     = _labels.isNotEmpty
        ? _labels[maxIndex]
        : 'unknown';

    debugPrint('TFLite result: $label (${(maxScore * 100).round()}%)  all: $scores');

    return {
      'label'      : label,
      'confidence' : maxScore,
      'allScores'  : scores,
      'allLabels'  : List<String>.from(_labels),
    };
  }

  // ─── Convert image to Float32 tensor ─────────────────────────────────────

  static List _toFloat32(img.Image image) {
    final buffer = Float32List(_inputH * _inputW * 3);
    int idx = 0;

    for (int y = 0; y < _inputH; y++) {
      for (int x = 0; x < _inputW; x++) {
        final pixel  = image.getPixel(x, y);
        buffer[idx++] = pixel.r / 255.0;
        buffer[idx++] = pixel.g / 255.0;
        buffer[idx++] = pixel.b / 255.0;
      }
    }

    // Shape: [1, inputH, inputW, 3]
    return [buffer.reshape([_inputH, _inputW, 3])];
  }

  // ─── Getters ──────────────────────────────────────────────────────────────

  static bool         get isReady  => _ready;
  static List<String> get labels   => List.unmodifiable(_labels);
  static int          get inputWidth  => _inputW;
  static int          get inputHeight => _inputH;

  // ─── Dispose ─────────────────────────────────────────────────────────────
  // Call in MedicineVerificationScreen.dispose()

  static void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _ready       = false;
    debugPrint('TFLite interpreter closed.');
  }
}