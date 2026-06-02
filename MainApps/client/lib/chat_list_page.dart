import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ChatListPage extends StatefulWidget {
  final bool isClient;

  const ChatListPage({super.key, this.isClient = false});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> conversations = [];
  bool isLoading = true;

  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);
  static const Color brandGrey = Color(0xFFF4F7F9);

  @override
  void initState() {
    super.initState();
    _fetchConversations();
  }

  Future<void> _fetchConversations() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final userId = supabase.auth.currentUser!.id;

      if (widget.isClient) {
        // Get unique conversations for client (with users who worked on their projects)
        final messages = await supabase
            .from('tbl_message')
            .select('''
              *,
              sender_id,
              receiver_id
            ''')
            .or('sender_id.eq.$userId,receiver_id.eq.$userId')
            .order('created_at', ascending: false);

        // Group by other user
        Map<String, Map<String, dynamic>> convMap = {};

        for (var msg in messages) {
          final otherId =
              msg['sender_id'] == userId ? msg['receiver_id'] : msg['sender_id'];

          if (!convMap.containsKey(otherId)) {
            // Fetch user details
            final userData = await supabase
                .from('tbl_user')
                .select('id, user_name, user_photo')
                .eq('id', otherId)
                .maybeSingle();

            if (userData != null) {
              convMap[otherId] = {
                'user_id': otherId,
                'user_name': userData['user_name'],
                'user_photo': userData['user_photo'],
                'last_message': msg['message_text'],
                'last_time': msg['created_at'],
                'unread_count': msg['is_read'] ? 0 : 1,
                'work_id': msg['work_id'],
              };
            }
          }
        }

        setState(() {
          conversations = convMap.values.toList();
          conversations
              .sort((a, b) => (b['last_time'] as String).compareTo(a['last_time'] as String ?? ''));
          isLoading = false;
        });
      } else {
        // For user app - similar logic
        final messages = await supabase
            .from('tbl_message')
            .select('*')
            .or('sender_id.eq.$userId,receiver_id.eq.$userId')
            .order('created_at', ascending: false);

        Map<String, Map<String, dynamic>> convMap = {};

        for (var msg in messages) {
          final otherId =
              msg['sender_id'] == userId ? msg['receiver_id'] : msg['sender_id'];

          if (!convMap.containsKey(otherId)) {
            final userData = await supabase
                .from('tbl_client')
                .select('client_id, client_name, client_logo')
                .eq('client_id', otherId)
                .maybeSingle();

            if (userData != null) {
              convMap[otherId] = {
                'user_id': otherId,
                'user_name': userData['client_name'],
                'user_photo': userData['client_logo'],
                'last_message': msg['message_text'],
                'last_time': msg['created_at'],
                'unread_count': msg['is_read'] ? 0 : 1,
                'work_id': msg['work_id'],
              };
            }
          }
        }

        setState(() {
          conversations = convMap.values.toList();
          conversations
              .sort((a, b) => (b['last_time'] as String).compareTo(a['last_time'] as String ?? ''));
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading chats: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: brandGrey,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'Messages',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, color: brandNavy, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: brandTeal),
            )
          : conversations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'No conversations yet',
                        style: GoogleFonts.poppins(
                            fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: conversations.length,
                  itemBuilder: (context, index) {
                    final conv = conversations[index];
                    return ConversationTile(
                      data: conv,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatDetailPage(
                              userId: conv['user_id'],
                              userName: conv['user_name'],
                              userPhoto: conv['user_photo'],
                              workId: conv['work_id'],
                              isClientSending: widget.isClient,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}

class ConversationTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const ConversationTile({
    super.key,
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateTime = DateTime.parse(data['last_time']);
    final now = DateTime.now();
    String timeString;

    if (dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day) {
      timeString = DateFormat('HH:mm').format(dateTime);
    } else if (dateTime.year == now.year) {
      timeString = DateFormat('MMM dd').format(dateTime);
    } else {
      timeString = DateFormat('yy/MM/dd').format(dateTime);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFF20A0A0).withOpacity(0.2),
              backgroundImage: data['user_photo'] != null
                  ? NetworkImage(data['user_photo'])
                  : null,
              child: data['user_photo'] == null
                  ? Text(
                      data['user_name'][0].toUpperCase(),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Color(0xFF20A0A0)),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['user_name'] ?? 'Unknown',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data['last_message'] ?? 'No messages',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timeString,
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                ),
                if ((data['unread_count'] ?? 0) > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF20A0A0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${data['unread_count']}',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ChatDetailPage extends StatefulWidget {
  final String userId;
  final String userName;
  final String? userPhoto;
  final int? workId;
  final bool isClientSending;

  const ChatDetailPage({
    super.key,
    required this.userId,
    required this.userName,
    this.userPhoto,
    this.workId,
    this.isClientSending = false,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final supabase = Supabase.instance.client;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  List<Map<String, dynamic>> messages = [];
  bool isLoading = true;
  bool isSending = false;

  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);
  static const Color brandGrey = Color(0xFFF4F7F9);

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _setupRealtimeListener();
  }

  Future<void> _fetchMessages() async {
    try {
      final currentUserId = supabase.auth.currentUser!.id;
      final response = await supabase
          .from('tbl_message')
          .select('*')
          .or('sender_id.eq.$currentUserId,receiver_id.eq.$currentUserId')
          .or(
              'sender_id.eq.${widget.userId},receiver_id.eq.${widget.userId}')
          .order('created_at', ascending: true);

      // Filter for messages only between these two users
      final filtered = (response as List)
          .where((m) =>
              (m['sender_id'] == currentUserId &&
                  m['receiver_id'] == widget.userId) ||
              (m['sender_id'] == widget.userId &&
                  m['receiver_id'] == currentUserId))
          .toList();

      if (mounted) {
        setState(() {
          messages = filtered.cast<Map<String, dynamic>>();
          isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _setupRealtimeListener() {
    supabase
        .channel('public:tbl_message')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tbl_message',
          callback: (payload) {
            _fetchMessages();
          },
        )
        .subscribe();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    try {
      setState(() => isSending = true);
      final senderId = supabase.auth.currentUser!.id;

      await supabase.from('tbl_message').insert({
        'work_id': widget.workId,
        'sender_id': senderId,
        'receiver_id': widget.userId,
        'sender_type': widget.isClientSending ? 'client' : 'user',
        'message_text': text.trim(),
        'is_read': false,
      });

      _messageController.clear();
      _fetchMessages();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 200), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: brandTeal.withOpacity(0.2),
              backgroundImage: widget.userPhoto != null
                  ? NetworkImage(widget.userPhoto!)
                  : null,
              child: widget.userPhoto == null
                  ? Text(
                      widget.userName[0].toUpperCase(),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: brandTeal),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              widget.userName,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, color: brandNavy, fontSize: 16),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: brandNavy),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: brandTeal),
            )
          : Column(
              children: [
                Expanded(
                  child: messages.isEmpty
                      ? Center(
                          child: Text(
                            'No messages yet. Start the conversation!',
                            style: GoogleFonts.poppins(
                                fontSize: 14, color: Colors.grey[500]),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(12),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final msg = messages[index];
                            final isCurrentUser = msg['sender_id'] ==
                                supabase.auth.currentUser!.id;

                            return Align(
                              alignment: isCurrentUser
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isCurrentUser
                                      ? brandTeal
                                      : brandGrey,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      msg['message_text'] ?? '',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: isCurrentUser
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat('HH:mm').format(
                                          DateTime.parse(msg['created_at'])),
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: isCurrentUser
                                            ? Colors.white70
                                            : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: brandGrey)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          maxLines: null,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: GoogleFonts.poppins(
                                fontSize: 12, color: Colors.grey),
                            filled: true,
                            fillColor: brandGrey,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: brandTeal,
                        child: IconButton(
                          icon: const Icon(Icons.send,
                              size: 18, color: Colors.white),
                          onPressed: isSending
                              ? null
                              : () =>
                                  _sendMessage(_messageController.text),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
