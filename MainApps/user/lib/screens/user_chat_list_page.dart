import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_chat_screen.dart'; // Import the ChatScreen code provided earlier

class ChatListPage extends StatefulWidget {
  final bool
  isClientApp; // True if this is the Client app, false if Student app
  const ChatListPage({super.key, required this.isClientApp});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final supabase = Supabase.instance.client;
  late final String currentUserId;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    currentUserId = supabase.auth.currentUser!.id;
  }

  // 🔹 FUNCTION TO DELETE ENTIRE CONVERSATION
  Future<void> _deleteConversation(String peerId, String peerName) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Delete Conversation?",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          "This will remove all messages with $peerName. This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Delete messages where I am sender and they are receiver OR vice versa
        await supabase
            .from('tbl_chat')
            .delete()
            .or(
              'and(from_userid.eq.$currentUserId,to_clientid.eq.$peerId),'
              'and(from_clientid.eq.$currentUserId,to_userid.eq.$peerId),'
              'and(from_userid.eq.$peerId,to_clientid.eq.$currentUserId),'
              'and(from_clientid.eq.$peerId,to_userid.eq.$currentUserId)',
            );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Conversation deleted"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        debugPrint("Delete error: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to delete conversation"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // 🔹 UPDATED TILE WITH LONG PRESS
  Widget _buildChatTile(
    String peerId,
    String name,
    dynamic chat,
    bool isUnread,
    Color teal,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              receiverId: peerId,
              receiverName: name,
              isReceiverClient: !widget.isClientApp,
            ),
          ),
        ),
        // 🔹 ADDED LONG PRESS TO DELETE
        onLongPress: () => _deleteConversation(peerId, name),
        leading: CircleAvatar(
          backgroundColor: teal.withOpacity(0.1),
          child: Text(
            name.isNotEmpty ? name[0] : "?",
            style: TextStyle(color: teal),
          ),
        ),
        title: Text(
          name,
          style: GoogleFonts.poppins(
            fontWeight: isUnread ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          chat['chat_content'],
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: isUnread
            ? const CircleAvatar(radius: 4, backgroundColor: Color(0xFF20A0A0))
            : null,
      ),
    );
  }

  Stream<List<Map<String, dynamic>>> _chatStream() async* {
    while (true) {
      if (!mounted) break;
      try {
        final data = await supabase
            .from('tbl_chat')
            .select()
            .order('chat_datetime', ascending: false);
        yield List<Map<String, dynamic>>.from(data);
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  // --- 1. BUILD METHOD (Applies Search UI) ---
  @override
  Widget build(BuildContext context) {
    const Color brandNavy = Color(0xFF102030);
    const Color brandTeal = Color(0xFF20A0A0);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        title: Text(
          "Messages",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: brandNavy,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          // 🔍 SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: "Search conversations...",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _chatStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(
                    child: CircularProgressIndicator(color: brandTeal),
                  );

                final allMessages = snapshot.data!;
                final Map<String, Map<String, dynamic>> lastMessages = {};

                for (var msg in allMessages) {
                  String? peerId;
                  if (widget.isClientApp) {
                    peerId = (msg['from_userid'] != null)
                        ? msg['from_userid']
                        : msg['to_userid'];
                  } else {
                    peerId = (msg['from_clientid'] != null)
                        ? msg['from_clientid']
                        : msg['to_clientid'];
                  }

                  if (peerId != null && !lastMessages.containsKey(peerId)) {
                    bool involvesMe =
                        msg['from_userid'] == currentUserId ||
                        msg['from_clientid'] == currentUserId ||
                        msg['to_userid'] == currentUserId ||
                        msg['to_clientid'] == currentUserId;
                    if (involvesMe) lastMessages[peerId] = msg;
                  }
                }

                if (lastMessages.isEmpty) return _buildEmptyState(brandNavy);

                return ListView.builder(
                  itemCount: lastMessages.keys.length,
                  itemBuilder: (context, index) {
                    String peerId = lastMessages.keys.elementAt(index);
                    var chat = lastMessages[peerId]!;

                    return FutureBuilder<Map<String, dynamic>>(
                      future: _getPeerDetails(peerId),
                      builder: (context, peerSnapshot) {
                        final peerName =
                            peerSnapshot.data?['name'] ?? "Loading...";

                        if (_searchQuery.isNotEmpty &&
                            !peerName.toLowerCase().contains(_searchQuery)) {
                          return const SizedBox.shrink();
                        }

                        final bool isUnread =
                            chat['chat_status'] == 0 &&
                            (chat['to_userid'] == currentUserId ||
                                chat['to_clientid'] == currentUserId);

                        return _buildChatTile(
                          peerId,
                          peerName,
                          chat,
                          isUnread,
                          brandTeal,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. LIST TILE WIDGET ---
  // Widget _buildChatTile(String peerId, String name, dynamic chat, bool isUnread, Color teal) {
  //   return Container(
  //     margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(12),
  //     ),
  //     child: ListTile(
  //       onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(
  //         receiverId: peerId,
  //         receiverName: name,
  //         isReceiverClient: !widget.isClientApp,
  //       ))),
  //       leading: CircleAvatar(
  //         backgroundColor: teal.withOpacity(0.1),
  //         child: Text(name.isNotEmpty ? name[0] : "?", style: TextStyle(color: teal)),
  //       ),
  //       title: Text(name, style: GoogleFonts.poppins(fontWeight: isUnread ? FontWeight.bold : FontWeight.w500, fontSize: 14)),
  //       subtitle: Text(chat['chat_content'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
  //       trailing: Column(
  //         mainAxisAlignment: MainAxisAlignment.center,
  //         children: [
  //           if (isUnread) const CircleAvatar(radius: 4, backgroundColor: Color(0xFF20A0A0)),
  //           const SizedBox(height: 4),
  //           Text(
  //             DateFormat('hh:mm a').format(DateTime.parse(chat['chat_datetime'])),
  //             style: const TextStyle(fontSize: 10, color: Colors.grey),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // --- 3. FETCH PEER DETAILS ---
  Future<Map<String, dynamic>> _getPeerDetails(String id) async {
    if (widget.isClientApp) {
      final data = await supabase
          .from('tbl_user')
          .select('user_name')
          .eq('id', id)
          .single();
      return {'name': data['user_name']};
    } else {
      final data = await supabase
          .from('tbl_client')
          .select('client_name')
          .eq('client_id', id)
          .single();
      return {'name': data['client_name']};
    }
  }

  // --- 4. EMPTY STATE ---
  Widget _buildEmptyState(Color navy) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 60,
            color: navy.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            "No messages yet",
            style: GoogleFonts.poppins(color: navy.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }
}
