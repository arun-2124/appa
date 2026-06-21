import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';          // AppColors
import '../models/medicine_model.dart';
import '../services/gemini_service.dart';

// ─── AI Assistant Screen ──────────────────────────────────────────────────────
// Talks to Gemini via GeminiService. Passes the user's current medicine list
// as context so the model can give relevant, personalised answers.
// Supports both English and Tamil.

class AiAssistantScreen extends StatefulWidget {
  final String userId;
  const AiAssistantScreen({super.key, required this.userId});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _inputCtrl  = TextEditingController();
  final _scrollCtrl = ScrollController();

  // Full conversation history sent to Gemini each turn
  // role = 'user' | 'model'
  final List<Map<String, String>> _history = [];

  // UI messages (same data, kept separately so we can add loading bubbles)
  final List<_Msg> _messages = [];

  bool _thinking = false;

  // Medicines loaded from Firestore so Gemini has real context
  List<Medicine> _medicines = [];
  bool _medLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadMedicines();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Load user's medicines once ─────────────────────────────────────────────
  Future<void> _loadMedicines() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('medicines')
        .orderBy('time')
        .get();

    if (!mounted) return;
    setState(() {
      _medicines = snap.docs
          .map((d) => Medicine.fromMap(d.data()))
          .toList();
      _medLoaded = true;
    });
  }

  // ── Build system prompt with real medicine list ────────────────────────────
  String get _systemPrompt {
    final medList = _medicines.isEmpty
        ? 'No medicines added yet.'
        : _medicines
            .map((m) =>
                '- ${m.name}, ${m.dose}, at ${m.time}'
                '${m.taken ? " (already taken today)" : " (not yet taken)"}')
            .join('\n');

    return '''
You are a warm, caring medicine assistant for elderly patients in India.
The patient's current medicines are:
$medList

Rules:
- Use simple, easy-to-understand language — the user is elderly.
- If the user writes in Tamil (தமிழ்), reply fully in Tamil.
- For dosage changes or serious symptoms, always say "please consult your doctor".
- Never recommend stopping or changing medicines without doctor advice.
- You can explain what a medicine is for, common side effects, food interactions, and general health tips.
- Keep answers concise (3–5 sentences max).
- Be warm, encouraging, and patient.
''';
  }

  // ── Send a message ─────────────────────────────────────────────────────────
  Future<void> _send(String text) async {
    text = text.trim();
    if (text.isEmpty || _thinking) return;

    _inputCtrl.clear();
    setState(() {
      _messages.add(_Msg(text: text, isUser: true));
      _history.add({'role': 'user', 'text': text});
      _thinking = true;
    });
    _scrollToBottom();

    try {
      final reply = await GeminiService.generateReply(
        prompt           : text,
        history          : _history.length > 1
            ? _history.sublist(0, _history.length - 1)
            : null,
        systemInstruction: _systemPrompt,
      );

      if (!mounted) return;
      setState(() {
        _messages.add(_Msg(text: reply, isUser: false));
        _history.add({'role': 'model', 'text': reply});
        _thinking = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(_Msg(
          text   : 'Sorry, I could not connect right now. Please check your internet and try again.',
          isUser : false,
          isError: true,
        ));
        // Remove the failed user turn from history so retry is clean
        if (_history.isNotEmpty && _history.last['role'] == 'user') {
          _history.removeLast();
        }
        _thinking = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve   : Curves.easeOut,
        );
      }
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('Medicine Assistant'),
      ),
      body: Column(
        children: [
          // Chat area
          Expanded(
            child: !_medLoaded
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _WelcomeView(
                        medicines: _medicines,
                        onSuggestion: _send,
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding   : const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        itemCount : _messages.length + (_thinking ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i == _messages.length) {
                            return const _TypingBubble();
                          }
                          return _ChatBubble(msg: _messages[i]);
                        },
                      ),
          ),

          // Input bar
          Container(
            color  : AppColors.surface(context),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child  : SafeArea(
              top  : false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller     : _inputCtrl,
                      textInputAction: TextInputAction.send,
                      onSubmitted    : _send,
                      decoration     : InputDecoration(
                        hintText: 'Ask about your medicines…',
                        hintStyle: TextStyle(
                            color   : AppColors.textSecondary(context),
                            fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _thinking
                        ? null
                        : () => _send(_inputCtrl.text),
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Welcome view ─────────────────────────────────────────────────────────────

class _WelcomeView extends StatelessWidget {
  final List<Medicine>       medicines;
  final void Function(String) onSuggestion;

  const _WelcomeView({
    required this.medicines,
    required this.onSuggestion,
  });

  @override
  Widget build(BuildContext context) {
    final suggestions = [
      if (medicines.isNotEmpty)
        'What is ${medicines.first.name} used for?',
      'Can I take my medicines on an empty stomach?',
      'What are common side effects I should watch for?',
      'மருந்து எடுக்க மறந்தால் என்ன செய்வது?', // Tamil: what if I forget?
    ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 20),
        const Center(child: Text('🤖', style: TextStyle(fontSize: 56))),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Medicine Assistant',
            style: TextStyle(
              fontSize  : 20,
              fontWeight: FontWeight.w700,
              color     : AppColors.textPrimary(context),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'Ask me anything about your medicines\nin English or Tamil (தமிழ்)',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: AppColors.textSecondary(context)),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Try asking:',
          style: TextStyle(
            fontSize  : 13,
            fontWeight: FontWeight.w600,
            color     : AppColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 10),
        ...suggestions.map(
          (s) => GestureDetector(
            onTap: () => onSuggestion(s),
            child: Container(
              margin   : const EdgeInsets.only(bottom: 8),
              padding  : const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder(context)),
              ),
              child: Row(
                children: [
                  Icon(Icons.chat_bubble_outline_rounded,
                      size: 16, color: AppColors.primary(context)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s,
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary(context)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Chat bubble ──────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final _Msg msg;
  const _ChatBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 10,
          left  : msg.isUser ? 56 : 0,
          right : msg.isUser ? 0  : 56,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: msg.isUser
              ? AppColors.primary(context)
              : msg.isError
                  ? AppColors.dangerLight(context)
                  : AppColors.surface(context),
          borderRadius: BorderRadius.only(
            topLeft    : const Radius.circular(16),
            topRight   : const Radius.circular(16),
            bottomLeft : Radius.circular(msg.isUser ? 16 : 4),
            bottomRight: Radius.circular(msg.isUser ? 4  : 16),
          ),
          border: msg.isUser
              ? null
              : Border.all(color: AppColors.cardBorder(context)),
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            fontSize: 14,
            height  : 1.5,
            color   : msg.isUser
                ? Colors.white
                : msg.isError
                    ? AppColors.danger(context)
                    : AppColors.textPrimary(context),
          ),
        ),
      ),
    );
  }
}

// ─── Typing indicator ─────────────────────────────────────────────────────────

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin   : const EdgeInsets.only(bottom: 10, right: 56),
        padding  : const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width : 16,
              height: 16,
              child : CircularProgressIndicator(
                  strokeWidth: 2,
                  color      : AppColors.primary(context)),
            ),
            const SizedBox(width: 8),
            Text(
              'Thinking…',
              style: TextStyle(
                  fontSize: 13,
                  color   : AppColors.textSecondary(context)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Message model ────────────────────────────────────────────────────────────

class _Msg {
  final String text;
  final bool   isUser;
  final bool   isError;

  const _Msg({
    required this.text,
    required this.isUser,
    this.isError = false,
  });
}