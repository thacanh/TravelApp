import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';

// ── Data models ─────────────────────────────────────────────────────────────

class ChatSessionSummary {
  final int id;
  final String? title;
  final DateTime updatedAt;

  ChatSessionSummary({required this.id, this.title, required this.updatedAt});

  factory ChatSessionSummary.fromJson(Map<String, dynamic> j) =>
      ChatSessionSummary(
        id: j['id'],
        title: j['title'],
        updatedAt: DateTime.tryParse(j['updated_at'] ?? '') ?? DateTime.now(),
      );
}

class ChatMessageModel {
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime createdAt;

  ChatMessageModel(
      {required this.role, required this.content, required this.createdAt});

  factory ChatMessageModel.fromJson(Map<String, dynamic> j) => ChatMessageModel(
        role: j['role'],
        content: j['content'],
        createdAt: DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
      );
}

// ── Chatbot Screen ───────────────────────────────────────────────────────────

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final ApiService _api = ApiService();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<ChatSessionSummary> _sessions = [];
  int? _currentSessionId;
  String? _currentSessionTitle;
  List<ChatMessageModel> _messages = [];
  bool _isLoading = false;
  bool _loadingSessions = false;

  final List<String> _welcomeSuggestions = [
    'Bãi biển đẹp nhất Việt Nam?',
    'Lịch trình 3 ngày Đà Nẵng',
    'Ẩm thực Hà Nội nên thử',
  ];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── API calls ──────────────────────────────────────────────────────────────

  Future<void> _loadSessions() async {
    setState(() => _loadingSessions = true);
    try {
      final res = await _api.getChatSessions();
      if (res.statusCode == 200) {
        final list = (res.data as List)
            .map((j) => ChatSessionSummary.fromJson(j))
            .toList();
        setState(() => _sessions = list);
        if (_currentSessionId == null && list.isNotEmpty) {
          await _openSession(list.first);
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingSessions = false);
    }
  }

  Future<void> _openSession(ChatSessionSummary s) async {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
    setState(() {
      _currentSessionId = s.id;
      _currentSessionTitle = s.title;
      _messages = [];
      _isLoading = true;
    });
    try {
      final res = await _api.getChatSession(s.id);
      if (res.statusCode == 200) {
        final msgs = (res.data['messages'] as List)
            .map((j) => ChatMessageModel.fromJson(j))
            .toList();
        if (mounted) setState(() => _messages = msgs);
        _scrollToBottom();
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _newSession() {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
    setState(() {
      _currentSessionId = null;
      _currentSessionTitle = null;
      _messages = [];
    });
  }

  Future<void> _deleteSession(int sessionId) async {
    try {
      await _api.deleteChatSession(sessionId);
      setState(() {
        _sessions.removeWhere((s) => s.id == sessionId);
        if (_currentSessionId == sessionId) {
          _currentSessionId = null;
          _currentSessionTitle = null;
          _messages = [];
        }
      });
    } catch (_) {}
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;
    _textController.clear();

    setState(() {
      _messages.add(ChatMessageModel(
          role: 'user', content: text, createdAt: DateTime.now()));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final res =
          await _api.sendChatMessage(text, sessionId: _currentSessionId);
      if (res.statusCode == 201 || res.statusCode == 200) {
        final data = res.data;
        final newSessionId = data['session_id'] as int;
        final aiContent = data['content'] as String;

        _loadSessions(); // refresh sidebar list

        if (mounted) {
          setState(() {
            _currentSessionId = newSessionId;
            _messages.add(ChatMessageModel(
              role: 'assistant',
              content: aiContent,
              createdAt:
                  DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
            ));
          });
          _scrollToBottom();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessageModel(
            role: 'assistant',
            content: 'Xin lỗi, có lỗi xảy ra. Vui lòng thử lại. 😔',
            createdAt: DateTime.now(),
          ));
        });
        _scrollToBottom();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Hôm nay';
    if (diff.inDays == 1) return 'Hôm qua';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _confirmDelete(int sessionId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa cuộc trò chuyện?'),
        content: const Text('Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[400]),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteSession(sessionId);
            },
            child:
                const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF7F8FA),
      drawer: _buildDrawer(),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty && !_isLoading
                ? _buildEmptyState()
                : _buildMessageList(),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        tooltip: 'Phiên trò chuyện',
      ),
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF00BCD4)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentSessionTitle ?? 'TRAWIME AI',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _isLoading ? 'Đang suy nghĩ...' : 'Trợ lý du lịch',
                  style: TextStyle(
                    fontSize: 11,
                    color: _isLoading
                        ? const Color(0xFF6C63FF)
                        : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.add_comment_outlined),
          onPressed: _newSession,
          tooltip: 'Tạo cuộc trò chuyện mới',
        ),
      ],
    );
  }

  // ── Drawer ─────────────────────────────────────────────────────────────────

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
                16, MediaQuery.of(context).padding.top + 16, 16, 16),
            decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.smart_toy_rounded,
                        color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('TRAWIME AI',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_comment_outlined,
                          color: Colors.white, size: 20),
                      onPressed: _newSession,
                      tooltip: 'Cuộc trò chuyện mới',
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_sessions.length} cuộc trò chuyện',
                  style:
                      TextStyle(color: Colors.white.withAlpha(180), fontSize: 12),
                ),
              ],
            ),
          ),
          // Session list
          Expanded(
            child: _loadingSessions
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2))
                : _sessions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text(
                              'Chưa có cuộc trò chuyện nào\nHãy bắt đầu nhé!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _sessions.length,
                        itemBuilder: (_, i) =>
                            _buildSessionTile(_sessions[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionTile(ChatSessionSummary s) {
    final isActive = s.id == _currentSessionId;
    return InkWell(
      onTap: () => _openSession(s),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primaryColor.withAlpha(20)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isActive
              ? Border.all(color: AppTheme.primaryColor.withAlpha(60))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 18,
              color: isActive ? AppTheme.primaryColor : Colors.grey[400],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.title ?? 'Cuộc trò chuyện',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.normal,
                      color: isActive ? AppTheme.primaryColor : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(s.updatedAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  size: 18, color: Colors.grey[400]),
              onPressed: () => _confirmDelete(s.id),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }

  // ── Chat area ──────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF00BCD4)]),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.smart_toy_rounded,
                  color: Colors.white, size: 42),
            ),
            const SizedBox(height: 20),
            const Text('Xin chào! Tôi là TRAWIME AI',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Hỏi tôi về địa điểm du lịch, lịch trình\nvà ẩm thực Việt Nam.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[500], height: 1.5),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _welcomeSuggestions
                  .map((s) => _buildSuggestionChip(s))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _messages.length && _isLoading) return _buildThinkingBubble();
        return _buildBubble(_messages[i]);
      },
    );
  }

  Widget _buildBubble(ChatMessageModel msg) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF00BCD4)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smart_toy_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF6C63FF) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withAlpha(12),
                      blurRadius: 6,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: isUser
                  ? SelectableText(
                      msg.content,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        height: 1.5,
                      ),
                    )
                  : _buildAiMessageContent(msg.content),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildThinkingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF00BCD4)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.smart_toy_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withAlpha(12),
                    blurRadius: 6,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: const Color(0xFF6C63FF).withAlpha(200),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'AI đang suy nghĩ...',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return InkWell(
      onTap: () => _sendMessage(text),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFF6C63FF).withAlpha(70)),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 4,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6C63FF),
              fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 10, 12, MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 10,
              offset: const Offset(0, -2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: 'Hỏi về du lịch...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 12),
              ),
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (t) => _sendMessage(t),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF00BCD4)]),
              borderRadius: BorderRadius.circular(23),
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              onPressed:
                  _isLoading ? null : () => _sendMessage(_textController.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// Render tin nhắn AI: strip **, * đầu dòng → bullet, ## → header
Widget _buildAiMessageContent(String text) {
  final lines = text.split('\n');
  final widgets = <Widget>[];
  for (final line in lines) {
    final trimmed = line.trim().replaceAll('**', '');
    if (trimmed.isEmpty) {
      widgets.add(const SizedBox(height: 4));
      continue;
    }
    // Header ##
    if (trimmed.startsWith('## ')) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 2),
        child: Text(
          trimmed.substring(3),
          style: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 14.5, color: Colors.black87, height: 1.3),
        ),
      ));
      continue;
    }
    // Bullet: - • *
    if (RegExp(r'^[-•*]\s').hasMatch(trimmed)) {
      final content = trimmed.replaceFirst(RegExp(r'^[-•*]\s+'), '');
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 7),
              child: Icon(Icons.circle, size: 5, color: Color(0xFF6C63FF)),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: SelectableText(
                content,
                style: const TextStyle(fontSize: 14.5, height: 1.5, color: Colors.black87),
              ),
            ),
          ],
        ),
      ));
      continue;
    }
    // Normal
    widgets.add(SelectableText(
      trimmed,
      style: const TextStyle(fontSize: 14.5, height: 1.5, color: Colors.black87),
    ));
  }
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
}
