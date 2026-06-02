import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 🔹 Get Real-time Stream
  Stream<List<Map<String, dynamic>>> getChatStream() {
    return _supabase
        .from('tbl_chat')
        .stream(primaryKey: ['chat_id'])
        .order('chat_datetime', ascending: false);
  }

  // 🔹 Generic Send Message
  Future<void> sendMessage({
    required String content,
    required String senderId,
    required String receiverId,
    required bool isSenderClient,
  }) async {
    final Map<String, dynamic> data = {
      'chat_content': content,
      'chat_datetime': DateTime.now().toIso8601String(),
      'chat_status': 0,
    };

    if (isSenderClient) {
      data['from_clientid'] = senderId;
      data['to_userid'] = receiverId;
    } else {
      data['from_userid'] = senderId;
      data['to_clientid'] = receiverId;
    }

    await _supabase.from('tbl_chat').insert(data);
  }

  // 🔹 Mark as Read
  Future<void> markAsRead(String currentId, String peerId, bool isCurrentClient) async {
    final myColumn = isCurrentClient ? 'to_clientid' : 'to_userid';
    final peerColumn = isCurrentClient ? 'from_userid' : 'from_clientid';

    await _supabase.from('tbl_chat').update({'chat_status': 1})
        .eq(myColumn, currentId)
        .eq(peerColumn, peerId);
  }
}