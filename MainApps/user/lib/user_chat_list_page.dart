import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'screens/chat_screen.dart';

class UserChatListPage extends StatefulWidget {
  const UserChatListPage({super.key});

  @override
  State<UserChatListPage> createState() => _UserChatListPageState();
}

class _UserChatListPageState extends State<UserChatListPage> {
  final supabase = Supabase.instance.client;
  String? currentUserId;
  bool isLoading = true;

  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);
  static const Color brandGrey = Color(0xFFF4F7F9);

  @override
  void initState() {
    super.initState();
    currentUserId = supabase.auth.currentUser?.id;
  }

  Stream<List<Map<String, dynamic>>> _chatListStream() async* {
    while (true) {
      if (currentUserId == null) yield [];
      try {
        final res = await supabase
            .from('tbl_chat')
            .select()
            .or('from_userid.eq.$currentUserId,to_userid.eq.$currentUserId')
            .order('chat_datetime', ascending: false);
        
        // Group by Peer (Client)
        Map<String, Map<String, dynamic>> conversations = {};
        for (var chat in res) {
          final peerId = chat['from_clientid'] ?? chat['to_clientid'];
          if (peerId != null && !conversations.containsKey(peerId)) {
            conversations[peerId] = chat;
          }
        }
        yield conversations.values.toList();
      } catch (e) {
        debugPrint("Chat list error: $e");
      }
      await Future.delayed(const Duration(seconds: 4));
    }
  }

  Future<Map<String, dynamic>> _fetchClientDetails(String clientId) async {
    try {
      final res = await supabase
          .from('tbl_client')
          .select('client_name, client_logo')
          .eq('client_id', clientId)
          .maybeSingle();
      return res ?? {'client_name': 'Client', 'client_logo': null};
    } catch (_) {
      return {'client_name': 'Client', 'client_logo': null};
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
            fontWeight: FontWeight.bold,
            color: brandNavy,
            fontSize: 20,
          ),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _chatListStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: brandTeal));
          }

          final conversations = snapshot.data ?? [];
          if (conversations.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final chat = conversations[index];
              final peerId = chat['from_clientid'] ?? chat['to_clientid'];
              return FutureBuilder<Map<String, dynamic>>(
                future: _fetchClientDetails(peerId),
                builder: (context, peerSnap) {
                  final peer = peerSnap.data ?? {'client_name': 'Loading...', 'client_logo': null};
                  return _buildConversationTile(chat, peer, peerId);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildConversationTile(Map<String, dynamic> chat, Map<String, dynamic> peer, String peerId) {
    final bool isUnread = chat['chat_status'] == 0 && chat['to_userid'] == currentUserId;
    final String time = DateFormat('hh:mm a').format(DateTime.parse(chat['chat_datetime']));

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            receiverId: peerId,
            receiverName: peer['client_name'],
            isReceiverClient: true,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: brandTeal.withOpacity(0.1),
              backgroundImage: peer['client_logo'] != null ? NetworkImage(peer['client_logo']) : null,
              child: peer['client_logo'] == null ? const Icon(Icons.business_rounded, color: brandTeal) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        peer['client_name'],
                        style: GoogleFonts.poppins(
                          fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                          fontSize: 15,
                          color: brandNavy,
                        ),
                      ),
                      Text(
                        time,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: isUnread ? brandTeal : Colors.black45,
                          fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    chat['chat_content'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: isUnread ? brandNavy : Colors.black54,
                      fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            if (isUnread)
              Container(
                margin: const EdgeInsets.only(left: 8),
                width: 10,
                height: 10,
                decoration: const BoxDecoration(color: brandTeal, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 64, color: brandNavy.withOpacity(0.1)),
          const SizedBox(height: 16),
          Text(
            "No conversations found",
            style: GoogleFonts.poppins(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
