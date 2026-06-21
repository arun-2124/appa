import 'package:flutter/material.dart';
import '../services/claude_ai_service.dart';

class DrugInteractionScreen extends StatefulWidget {
  final List<String> existingMedications;
  final ClaudeAIService aiService;

  const DrugInteractionScreen({
    super.key,
    this.existingMedications = const [],
    required this.aiService,
  });

  @override
  State<DrugInteractionScreen> createState() => _DrugInteractionScreenState();
}

class _DrugInteractionScreenState extends State<DrugInteractionScreen> {
  final TextEditingController _medicineController = TextEditingController();
  final List<String> _medications = [];
  bool _isChecking = false;
  DrugInteractionResult? _result;
  String? _errorMessage;

  // Warm purple theme colors
  static const Color _purple = Color(0xFF7B5EA7);
  static const Color _purpleLight = Color(0xFFF3EEFB);
  static const Color _purpleMid = Color(0xFFC9B8E8);

  @override
  void initState() {
    super.initState();
    // Pre-load existing medications from the app
    if (widget.existingMedications.isNotEmpty) {
      _medications.addAll(widget.existingMedications);
    }
  }

  @override
  void dispose() {
    _medicineController.dispose();
    super.dispose();
  }

  void _addMedication() {
    final name = _medicineController.text.trim();
    if (name.isEmpty) return;
    if (_medications.contains(name)) {
      _showSnack('$name is already in the list');
      return;
    }
    setState(() {
      _medications.add(name);
      _result = null;
      _errorMessage = null;
    });
    _medicineController.clear();
  }

  void _removeMedication(String med) {
    setState(() {
      _medications.remove(med);
      _result = null;
    });
  }

  Future<void> _checkInteractions() async {
    if (_medications.length < 2) {
      _showSnack('Please add at least 2 medications');
      return;
    }

    setState(() {
      _isChecking = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final result =
          await widget.aiService.checkDrugInteractions(_medications);
      setState(() {
        _result = result;
        _isChecking = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage =
            'Could not check interactions. Please check your connection and try again.';
        _isChecking = false;
      });
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 16)),
        backgroundColor: _purple,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'high':
        return const Color(0xFFD32F2F);
      case 'moderate':
        return const Color(0xFFF57C00);
      case 'low':
        return const Color(0xFF388E3C);
      default:
        return Colors.grey;
    }
  }

  IconData _severityIcon(String severity) {
    switch (severity) {
      case 'high':
        return Icons.warning_rounded;
      case 'moderate':
        return Icons.info_rounded;
      case 'low':
        return Icons.check_circle_outline_rounded;
      default:
        return Icons.circle_outlined;
    }
  }

  String _severityLabel(String severity) {
    switch (severity) {
      case 'high':
        return 'HIGH RISK';
      case 'moderate':
        return 'MODERATE';
      case 'low':
        return 'LOW RISK';
      default:
        return severity.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FF),
      appBar: AppBar(
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        title: const Text(
          'Drug Interaction Checker',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _purpleLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _purpleMid),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: _purple, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Add your medicines below to check if they interact safely with each other.',
                      style: TextStyle(
                        fontSize: 15,
                        color: _purple,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Add medicine input
            Text(
              'Add Medicine',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _medicineController,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(fontSize: 17),
                    decoration: InputDecoration(
                      hintText: 'e.g., Metformin, Aspirin...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            BorderSide(color: Colors.grey[300]!, width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            BorderSide(color: Colors.grey[300]!, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: _purple, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                    onSubmitted: (_) => _addMedication(),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 56,
                  width: 56,
                  child: ElevatedButton(
                    onPressed: _addMedication,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _purple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Icon(Icons.add_rounded, size: 28),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Medicine chips
            if (_medications.isNotEmpty) ...[
              Text(
                'Medicines to check (${_medications.length})',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _medications
                    .map((med) => _MedicineChip(
                          label: med,
                          onRemove: () => _removeMedication(med),
                          color: _purple,
                        ))
                    .toList(),
              ),
              const SizedBox(height: 24),

              // Check button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isChecking ? null : _checkInteractions,
                  icon: _isChecking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.search_rounded, size: 22),
                  label: Text(
                    _isChecking ? 'Checking...' : 'Check Interactions',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _purple,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _purpleMid,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],

            // Error state
            if (_errorMessage != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFEF9A9A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Color(0xFFD32F2F)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                            fontSize: 15, color: Color(0xFFB71C1C)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Results
            if (_result != null) ...[
              const SizedBox(height: 28),
              _ResultsSection(
                result: _result!,
                severityColor: _severityColor,
                severityIcon: _severityIcon,
                severityLabel: _severityLabel,
                purpleColor: _purple,
              ),
            ],

            const SizedBox(height: 32),

            // Disclaimer
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '⚕️ This tool provides general information only. Always consult your doctor or pharmacist before making changes to your medications.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicineChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  final Color color;

  const _MedicineChip({
    required this.label,
    required this.onRemove,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.medication_rounded, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close_rounded, color: color, size: 18),
          ),
        ],
      ),
    );
  }
}

class _ResultsSection extends StatelessWidget {
  final DrugInteractionResult result;
  final Color Function(String) severityColor;
  final IconData Function(String) severityIcon;
  final String Function(String) severityLabel;
  final Color purpleColor;

  const _ResultsSection({
    required this.result,
    required this.severityColor,
    required this.severityIcon,
    required this.severityLabel,
    required this.purpleColor,
  });

  @override
  Widget build(BuildContext context) {
    final safeColor = result.isSafe ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    final safeBg = result.isSafe ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);
    final safeIcon = result.isSafe ? Icons.check_circle_rounded : Icons.warning_rounded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: safeBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: safeColor.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(safeIcon, color: safeColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.isSafe ? 'Generally Safe' : 'Caution Needed',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: safeColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.summary,
                      style: TextStyle(
                        fontSize: 15,
                        color: safeColor.withOpacity(0.85),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (result.interactions.isEmpty) ...[
          const SizedBox(height: 16),
          Center(
            child: Text(
              'No known interactions found between these medicines.',
              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
        ] else ...[
          const SizedBox(height: 20),
          Text(
            'Interactions Found (${result.interactions.length})',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          ...result.interactions.map((interaction) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _InteractionCard(
                  interaction: interaction,
                  severityColor: severityColor(interaction.severity),
                  severityIcon: severityIcon(interaction.severity),
                  severityLabel: severityLabel(interaction.severity),
                ),
              )),
        ],
      ],
    );
  }
}

class _InteractionCard extends StatefulWidget {
  final DrugInteraction interaction;
  final Color severityColor;
  final IconData severityIcon;
  final String severityLabel;

  const _InteractionCard({
    required this.interaction,
    required this.severityColor,
    required this.severityIcon,
    required this.severityLabel,
  });

  @override
  State<_InteractionCard> createState() => _InteractionCardState();
}

class _InteractionCardState extends State<_InteractionCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.severityColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: widget.severityColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(widget.severityIcon,
                            color: widget.severityColor, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          widget.severityLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: widget.severityColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.interaction.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C2C2A),
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),

          // Expandable details
          if (_expanded) ...[
            Divider(
                height: 1,
                color: widget.severityColor.withOpacity(0.2),
                thickness: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.interaction.description,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF444441),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F5FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lightbulb_outline_rounded,
                            color: Color(0xFF7B5EA7), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.interaction.advice,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF534AB7),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}