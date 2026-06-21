// ─────────────────────────────────────────────────────────────────────────────
// FILE:  lib/screens/ai_chat_screen.dart
// STEP:  1. Create at lib/screens/ai_chat_screen.dart
//        2. Add to pubspec.yaml:  http: ^1.2.0  (if not already added)
//        3. In main.dart, add a chat FAB or bottom nav item:
//              NavigationDestination(
//                icon: Icon(Icons.chat_bubble_outline),
//                selectedIcon: Icon(Icons.chat_bubble, color: kPrimary),
//                label: 'Ask AI',
//              )
//           Then add AiChatScreen(userId: userId, medicines: []) to screens list
//
//        4. ⚠️ REPLACE THE LINE BELOW with your real Anthropic API key
//           Get one at: https://console.anthropic.com/settings/keys
//           It will look like: sk-ant-api03-XXXXXXXXXXXX...
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/medicine_model.dart';

const Color kPrimary      = Color(0xFF6B3FA0);
const Color kPrimaryLight = Color(0xFFF0E6FF);
const Color kTextPrimary  = Color(0xFF1A1A2E);
const Color kTextSecondary= Color(0xFF6B6B80);
const Color kBackground   = Color(0xFFFAF7FF);
const Color kSurface      = Color(0xFFFFFFFF);
const Color kDanger       = Color(0xFFC62828);

// ⚠️ PASTE YOUR REAL KEY HERE — replace the placeholder text below.
// It must start with "sk-ant-" — if it still says YOUR_ANTHROPIC_API_KEY,
// every chat message will fail.
const String _apiKey = 'YOUR_ANTHROPIC_API_KEY';

bool get _isApiKeyConfigured =>
    _apiKey.isNotEmpty && _apiKey != 'YOUR_ANTHROPIC_API_KEY';

class AiChatScreen extends StatefulWidget {
  final String        userId;
  final List<Medicine> medicines;  // pass current medicines for context

  const AiChatScreen({
    super.key,
    required this.userId,
    required this.medicines,
  });

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _ctrl       = TextEditingController();
  final _scroll     = ScrollController();
  final List<_Msg>  _messages = [];
  bool  _loading    = false;

  // Build system prompt with user's medicines as context
  String get _systemPrompt {
    final medList = widget.medicines.isEmpty
        ? 'No medicines added yet.'
        : widget.medicines
            .map((m) => '- ${m.name} ${m.dose} at ${m.time}')
            .join('\n');

    return '''
You are a helpful, friendly medicine assistant for elderly patients in India.
The patient's current medicines are:
$medList

Rules:
- Answer in simple, easy-to-understand language
- If the user writes in Tamil (தமிழ்), reply in Tamil
- For questions about dosage changes or serious symptoms, always say "please consult your doctor"
- Never recommend stopping or changing medicines without doctor advice
- Be warm and caring — the user is an elderly person
- Keep answers short and clear (max 3-4 sentences)
- You can explain what a medicine is for, side effects, food interactions, and general health tips
''';
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _loading) return;

    // ✅ Check the key BEFORE making a network call, with a clear message.
    if (!_isApiKeyConfigured) {
      setState(() {
        _messages.add(_Msg(text: text, isUser: true));
        _messages.add(_Msg(
          text: 'AI chat is not set up yet — the API key is missing. '
              '(Developer: replace _apiKey in ai_chat_screen.dart)',
          isUser : false,
          isError: true,
        ));
      });
      _ctrl.clear();
      _scrollToBottom();
      return;
    }

    _ctrl.clear();
    setState(() {
      _messages.add(_Msg(text: text, isUser: true));
      _loading = true;
    });
    _scrollToBottom();

    try {
      // Build conversation history for Claude
      final history = _messages
          .where((m) => !m.isLoading && !m.isError)
          .map((m) => {
                'role'   : m.isUser ? 'user' : 'assistant',
                'content': m.text,
              })
          .toList();

      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type'     : 'application/json',
          'x-api-key'        : _apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model'     : 'claude-sonnet-4-20250514',
          'max_tokens': 500,
          'system'    : _systemPrompt,
          'messages'  : history,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        // ✅ Surface the real status + body instead of a generic message.
        String detail = response.body;
        try {
          final errJson = jsonDecode(response.body);
          detail = errJson['error']?['message']?.toString() ?? response.body;
        } catch (_) {}
        throw Exception('API error ${response.statusCode}: $detail');
      }

      final data  = jsonDecode(response.body);
      final reply = (data['content'] as List)
          .where((c) => c['type'] == 'text')
          .map((c) => c['text'] as String)
          .join('');

      setState(() {
        _messages.add(_Msg(text: reply, isUser: false));
        _loading = false;
      });
    } on http.ClientException catch (e) {
      // Genuine network-layer failure (no internet, DNS, etc.)
      setState(() {
        _messages.add(_Msg(
          text   : 'Could not reach the server. Please check your internet connection.\n($e)',
          isUser : false,
          isError: true,
        ));
        _loading = false;
      });
    } catch (e) {
      // ✅ Show the actual error (key invalid, rate limit, bad request, etc.)
      // instead of always blaming "internet".
      setState(() {
        _messages.add(_Msg(
          text   : 'Sorry, something went wrong: $e',
          isUser : false,
          isError: true,
        ));
        _loading = false;
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve   : Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        title: const Text('Medicine Assistant'),
        centerTitle: true,
      ),
      body: Column(
        children: [

          // Chat messages
          Expanded(
            child: _messages.isEmpty
                ? _WelcomeView(medicines: widget.medicines)
                : ListView.builder(
                    controller  : _scroll,
                    padding     : const EdgeInsets.all(16),
                    itemCount   : _messages.length + (_loading ? 1 : 0),
                    itemBuilder : (context, i) {
                      if (i == _messages.length) {
                        return const _TypingBubble();
                      }
                      return _ChatBubble(msg: _messages[i]);
                    },
                  ),
          ),

          // Input bar
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            color  : kSurface,
            child  : SafeArea(
              top  : false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller  : _ctrl,
                      decoration  : InputDecoration(
                        hintText     : 'Ask about your medicines…',
                        hintStyle    : const TextStyle(
                            fontSize: 14, color: kTextSecondary),
                        filled       : true,
                        fillColor    : kBackground,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide  : BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                      textInputAction: TextInputAction.send,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      width : 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color : kPrimary,
                        shape : BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                    ),
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

// ─── Welcome screen ───────────────────────────────────────────────────────────

class _WelcomeView extends StatelessWidget {
  final List<Medicine> medicines;
  const _WelcomeView({required this.medicines});

  @override
  Widget build(BuildContext context) {
    const suggestions = [
      'What is Metformin for?',
      'Can I take Calcium on empty stomach?',
      'What are the side effects?',
      'மருந்து எடுக்க மறந்தால் என்ன செய்வது?',
    ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 20),
        const Center(
          child: Text('🤖', style: TextStyle(fontSize: 48)),
        ),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'Medicine Assistant',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text(
            'Ask me anything about your medicines\nin English or Tamil',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: kTextSecondary),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Try asking:',
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        ...suggestions.map(
          (s) => GestureDetector(
            onTap: () {
              (context
                  .findAncestorStateOfType<_AiChatScreenState>()
                  ?._ctrl
                  .text = s);
              context
                  .findAncestorStateOfType<_AiChatScreenState>()
                  ?._send();
            },
            child: Container(
              margin    : const EdgeInsets.only(bottom: 8),
              padding   : const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color       : kSurface,
                borderRadius: BorderRadius.circular(12),
                border      : Border.all(color: const Color(0xFFE8E0F0)),
              ),
              child: Text(s, style: const TextStyle(fontSize: 13)),
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
      alignment:
          msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin   : EdgeInsets.only(
          bottom: 10,
          left  : msg.isUser ? 48 : 0,
          right : msg.isUser ? 0  : 48,
        ),
        padding  : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color       : msg.isUser
              ? kPrimary
              : msg.isError
                  ? const Color(0xFFFFEBEE)
                  : kSurface,
          borderRadius: BorderRadius.only(
            topLeft    : const Radius.circular(16),
            topRight   : const Radius.circular(16),
            bottomLeft :
                Radius.circular(msg.isUser ? 16 : 4),
            bottomRight:
                Radius.circular(msg.isUser ? 4  : 16),
          ),
          border: msg.isUser
              ? null
              : Border.all(color: const Color(0xFFE8E0F0)),
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            fontSize: 14,
            color   : msg.isUser
                ? Colors.white
                : msg.isError
                    ? kDanger
                    : kTextPrimary,
            height  : 1.5,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child    : Container(
        margin   : const EdgeInsets.only(bottom: 10, right: 48),
        padding  : const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color       : kSurface,
          borderRadius: BorderRadius.circular(16),
          border      : Border.all(color: const Color(0xFFE8E0F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children    : const [
            SizedBox(
              width : 16,
              height: 16,
              child : CircularProgressIndicator(
                  strokeWidth: 2, color: kPrimary),
            ),
            SizedBox(width: 8),
            Text('Thinking…',
                style: TextStyle(fontSize: 13, color: kTextSecondary)),
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
  final bool   isLoading;
  final bool   isError;

  const _Msg({
    required this.text,
    required this.isUser,
    this.isLoading = false,
    this.isError   = false,
  });
}