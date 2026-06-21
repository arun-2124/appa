import 'package:flutter/material.dart';
import '../services/claude_ai_service.dart';
import 'drug_interaction_screen.dart';
import 'medicine_chat_screen.dart';

/// Entry point for all AI features in Appa.
/// Shows two cards: Drug Interaction Checker and Medicine Chat Assistant.
class AIHubScreen extends StatelessWidget {
  final List<String> currentMedications;

  // Pass in your API key from secure storage (e.g. flutter_dotenv or Firebase Remote Config)
  final String claudeApiKey;

  const AIHubScreen({
    super.key,
    this.currentMedications = const [],
    required this.claudeApiKey,
  });

  @override
  Widget build(BuildContext context) {
    final aiService = ClaudeAIService(apiKey: claudeApiKey);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7B5EA7),
        foregroundColor: Colors.white,
        title: const Text(
          'AI Assistant',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'How can I help you today?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2C2C2A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Powered by AI — always confirm with your doctor.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 28),

              // Drug Interaction Checker card
              _AIFeatureCard(
                icon: Icons.compare_arrows_rounded,
                title: 'Drug Interaction Checker',
                subtitle:
                    'Check if your medicines are safe to take together. Get clear warnings and advice.',
                badgeText: currentMedications.isNotEmpty
                    ? '${currentMedications.length} meds loaded'
                    : null,
                color: const Color(0xFF7B5EA7),
                lightColor: const Color(0xFFF3EEFB),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DrugInteractionScreen(
                      existingMedications: currentMedications,
                      aiService: aiService,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Medicine Chat card
              _AIFeatureCard(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Ask Medicine Questions',
                subtitle:
                    'Ask anything about your medications — side effects, timing, food, missed doses and more.',
                badgeText: null,
                color: const Color(0xFF5E7EA7),
                lightColor: const Color(0xFFEEF3FB),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MedicineChatScreen(
                      currentMedications: currentMedications,
                      aiService: aiService,
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // Footer disclaimer
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.health_and_safety_outlined,
                        color: Colors.grey[500], size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This AI provides general information only. It is not a substitute for professional medical advice.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AIFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badgeText;
  final Color color;
  final Color lightColor;
  final VoidCallback onTap;

  const _AIFeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.color,
    required this.lightColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: lightColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2C2C2A),
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              badgeText!,
                              style: TextStyle(
                                fontSize: 11,
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: color.withOpacity(0.5), size: 16),
            ],
          ),
        ),
      ),
    );
  }
}