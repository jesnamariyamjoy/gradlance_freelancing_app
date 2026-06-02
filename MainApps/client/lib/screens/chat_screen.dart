import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final bool isReceiverClient;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
    required this.isReceiverClient,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? currentUserId;
  String? receiverAvatar;
  String? receiverContact;
  File? _imagePreview;
  bool isUploading = false;

  @override
  void initState() {
    super.initState();
    currentUserId = supabase.auth.currentUser!.id;
    _markMessagesAsRead();
    _fetchReceiverAvatar();
  }

  Future<void> _fetchReceiverAvatar() async {
    try {
      if (widget.isReceiverClient) {
        final data = await supabase
            .from('tbl_client')
            .select('client_logo, client_contact')
            .eq('client_id', widget.receiverId)
            .maybeSingle();
        if (data != null && mounted) {
          setState(() {
            receiverAvatar = data['client_logo'];
            receiverContact = data['client_contact'];
          });
        }
      } else {
        final data = await supabase
            .from('tbl_user')
            .select('user_photo, user_contact')
            .eq('id', widget.receiverId)
            .maybeSingle();
        if (data != null && mounted) {
          setState(() {
            receiverAvatar = data['user_photo'];
            receiverContact = data['user_contact'];
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _makeCall() async {
    if (receiverContact == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Contact info not available")),
      );
      return;
    }
    final Uri url = Uri.parse("tel:$receiverContact");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      final columnToUpdate = widget.isReceiverClient
          ? 'to_userid'
          : 'to_clientid';
      await supabase
          .from('tbl_chat')
          .update({'chat_status': 1})
          .eq(columnToUpdate, currentUserId!)
          .eq(
            widget.isReceiverClient ? 'from_clientid' : 'from_userid',
            widget.receiverId,
          );
    } catch (e) {
      debugPrint("Error marking read: $e");
    }
  }

  Future<void> _sendMessage({String? fileUrl}) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && fileUrl == null) return;

    if (text.isNotEmpty) _messageController.clear();

    try {
      final Map<String, dynamic> messageData = {
        'chat_content': fileUrl ?? text,
        'chat_datetime': DateTime.now().toIso8601String(),
        'chat_status': 0,
      };

      if (widget.isReceiverClient) {
        messageData['from_userid'] = currentUserId;
        messageData['to_clientid'] = widget.receiverId;
      } else {
        messageData['from_clientid'] = currentUserId;
        messageData['to_userid'] = widget.receiverId;
      }

      await supabase.from('tbl_chat').insert(messageData);

      try {
        await supabase.from('notifications').insert({
          'user_id': widget.receiverId,
          'title': "New Message",
          'message': 'You received a new message from ${widget.receiverName}',
          'type': 'chat',
          'target_id': currentUserId,
        });
      } catch (_) {}

      _scrollToBottom();
    } catch (e) {
      debugPrint("Error sending: $e");
    }
  }

  Future<void> _uploadAndSend() async {
    if (_imagePreview == null) return;

    setState(() => isUploading = true);
    try {
      final fileName =
          "chat_${DateTime.now().millisecondsSinceEpoch}${path.extension(_imagePreview!.path)}";
      await supabase.storage.from('Chat').upload(fileName, _imagePreview!);
      final publicUrl = supabase.storage.from('Chat').getPublicUrl(fileName);

      await _sendMessage(fileUrl: publicUrl);
      setState(() {
        _imagePreview = null;
        isUploading = false;
      });
    } catch (e) {
      setState(() => isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Upload failed"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _pickFile() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (image != null) {
      setState(() {
        _imagePreview = File(image.path);
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Stream<List<Map<String, dynamic>>> _chatStream() async* {
    while (true) {
      try {
        final data = await supabase
            .from('tbl_chat')
            .select()
            .order('chat_datetime', ascending: false);
        yield List<Map<String, dynamic>>.from(data);
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color brandNavy = Color(0xFF102030);
    const Color brandTeal = Color(0xFF20A0A0);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: Colors.white,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: brandNavy,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: brandTeal.withOpacity(0.1),
              backgroundImage: receiverAvatar != null
                  ? NetworkImage(receiverAvatar!)
                  : null,
              child: receiverAvatar == null
                  ? const Icon(Icons.person_rounded, size: 20, color: brandTeal)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.receiverName,
                    style: GoogleFonts.poppins(
                      color: brandNavy,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    "Online",
                    style: GoogleFonts.poppins(
                      color: brandTeal,
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_outlined, color: brandTeal, size: 22),
            onPressed: _makeCall,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
            onSelected: (value) {
              if (value == 'clear') _clearChat();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'clear',
                child: Text(
                  "Clear Chat",
                  style: GoogleFonts.poppins(color: Colors.redAccent),
                ),
              ),
              PopupMenuItem(
                value: 'report',
                child: Text("Report User", style: GoogleFonts.poppins()),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_imagePreview != null) _buildImagePreviewOverlay(brandTeal),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _chatStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(
                    child: CircularProgressIndicator(color: brandTeal),
                  );

                final chats = snapshot.data!.where((m) {
                  bool involvedMe =
                      m['from_userid'] == currentUserId ||
                      m['from_clientid'] == currentUserId ||
                      m['to_userid'] == currentUserId ||
                      m['to_clientid'] == currentUserId;
                  bool involvedPeer =
                      m['from_userid'] == widget.receiverId ||
                      m['from_clientid'] == widget.receiverId ||
                      m['to_userid'] == widget.receiverId ||
                      m['to_clientid'] == widget.receiverId;
                  return involvedMe && involvedPeer;
                }).toList();

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    final chat = chats[index];
                    final bool isMe =
                        chat['from_userid'] == currentUserId ||
                        chat['from_clientid'] == currentUserId;
                    return GestureDetector(
                      onLongPress: () => _deleteMessageDialog(chat['chat_id']),
                      child: _buildBubble(
                        chat['chat_content'],
                        isMe,
                        chat['chat_datetime'],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          _buildInput(brandNavy, brandTeal),
        ],
      ),
    );
  }

  Widget _buildImagePreviewOverlay(Color brandTeal) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.image_outlined, color: brandTeal),
              const SizedBox(width: 8),
              Text(
                "Image Preview",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => setState(() => _imagePreview = null),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(_imagePreview!, height: 150, fit: BoxFit.cover),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isUploading ? null : _uploadAndSend,
              icon: isUploading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(isUploading ? "Uploading..." : "Send Image"),
              style: ElevatedButton.styleFrom(
                backgroundColor: brandTeal,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(String text, bool isMe, String timestamp) {
    final time = DateFormat('hh:mm a').format(DateTime.parse(timestamp));
    final bool isImage =
        text.contains('supabase.co') &&
        (text.endsWith('.png') ||
            text.endsWith('.jpg') ||
            text.endsWith('.jpeg'));

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isImage ? 4 : 14,
              vertical: isImage ? 4 : 10,
            ),
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFF20A0A0) : Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5),
              ],
            ),
            child: isImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      text,
                      width: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image),
                    ),
                  )
                : Text(
                    text,
                    style: GoogleFonts.poppins(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
          ),
          Text(time, style: const TextStyle(fontSize: 9, color: Colors.grey)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildInput(Color navy, Color teal) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(color: Colors.white),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.image_rounded,
                color: Colors.grey,
                size: 26,
              ),
              onPressed: _pickFile,
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: "Type a message...",
                  filled: true,
                  fillColor: const Color(0xFFF4F7F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: teal,
              radius: 22,
              child: IconButton(
                onPressed: () => _sendMessage(),
                icon: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _clearChat() async {
    try {
      final res = await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(
            "Clear Chat",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: const Text("Delete all messages for your side?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Clear", style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (res == true) {
        await supabase
            .from('tbl_chat')
            .delete()
            .eq('from_clientid', currentUserId!)
            .eq('to_userid', widget.receiverId);
        await supabase
            .from('tbl_chat')
            .delete()
            .eq('to_clientid', currentUserId!)
            .eq('from_userid', widget.receiverId);
      }
    } catch (_) {}
  }

  void _deleteMessageDialog(dynamic chatId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: Colors.blueGrey),
              title: Text("Reply", style: GoogleFonts.poppins()),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: Colors.blueGrey),
              title: Text("Copy Link", style: GoogleFonts.poppins()),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
              ),
              title: Text(
                "Delete Message",
                style: GoogleFonts.poppins(color: Colors.redAccent),
              ),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await supabase
                      .from('tbl_chat')
                      .delete()
                      .eq('chat_id', chatId);
                } catch (_) {}
              },
            ),
          ],
        ),
      ),
    );
  }
}
