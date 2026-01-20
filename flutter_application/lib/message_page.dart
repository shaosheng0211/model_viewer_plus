import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'custom_app_bar.dart';

const Color primaryColor = Color.fromARGB(255, 112, 210, 255);

class MessagePage extends StatelessWidget {

  final List<Map<String, dynamic>> chatList = [
    {
      'chatId': 'chat_0',
      'name': 'Driver',
      'subtitle': '~ Ariffin Bin Ismail',
      'lastMessage': 'Chat has ended. If you need further help, please...',
      'time': '19:32',
      'unread': 0,
      'isDriver': true,
      'canChat': false,
      'avatar': Icons.person,
    },
    {
      'chatId': 'chat_1',
      'name': 'Delivery Driver ~ No. 6622',
      'subtitle': '',
      'lastMessage': 'Delivery Driver ~ No. 6622 sent you an image.',
      'time': 'Wednesday',
      'unread': 0,
      'isDriver': true,
      'canChat': true,
      'avatar': Icons.delivery_dining,
    },
    {
      'chatId': 'chat_2',
      'name': 'Delivery Driver ~ No. 0441',
      'subtitle': '',
      'lastMessage': 'Chat has ended. If you need further help, ple...',
      'time': '07/06',
      'unread': 0,
      'isDriver': true,
      'canChat': false,
      'avatar': Icons.delivery_dining,
    },
    {
      'chatId': 'chat_3',
      'name': 'npntravelmalaysia',
      'subtitle': '~ NPN Travel Malaysia',
      'lastMessage': 'npntravelmalaysia sent you an image.',
      'time': '01/06',
      'unread': 0,
      'isDriver': false,
      'canChat': true,
      'avatar': Icons.travel_explore,
    },
    {
      'chatId': 'chat_4',
      'name': 'SKINTIFIC SABAH',
      'subtitle': '',
      'lastMessage': 'Thank you for shopping with us!',
      'time': '06/05',
      'unread': 0,
      'isDriver': false,
      'canChat': true,
      'avatar': Icons.store,
    },
    {
      'chatId': 'chat_5',
      'name': 'chengwoh',
      'subtitle': '~ Cheng Woh',
      'lastMessage': 'Please confirm if you received the item.',
      'time': '26/03',
      'unread': 0,
      'isDriver': false,
      'canChat': true,
      'avatar': Icons.storefront,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            CustomAppBar(title: 'Message'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: TextField(
                style: TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search',
                  prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: primaryColor),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: chatList.length,
                separatorBuilder: (context, index) => Divider(height: 1),
                itemBuilder: (context, index) {
                  final chat = chatList[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: primaryColor.withOpacity(0.2),
                      child: Icon(chat['avatar'], color: primaryColor),
                    ),
                    title: Text(chat['name'], style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      chat['lastMessage'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(chat['time'], style: TextStyle(fontSize: 12)),
                        if (chat['unread'] > 0)
                          Container(
                            margin: EdgeInsets.only(top: 4),
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade400,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              chat['unread'].toString(),
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatDetailPage(
                            chatId: chat['chatId'],
                            name: chat['name'],
                            subtitle: chat['subtitle'],
                            isDriver: chat['isDriver'],
                            canChat: chat['canChat'],
                            avatar: chat['avatar'],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatDetailPage extends StatefulWidget {
  final String chatId;
  final String name;
  final String subtitle;
  final bool isDriver;
  final bool canChat;
  final IconData avatar;

  ChatDetailPage({
    required this.chatId,
    required this.name,
    required this.subtitle,
    required this.isDriver,
    required this.canChat,
    required this.avatar,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final TextEditingController _messageController = TextEditingController();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  Stream<List<Map<String, dynamic>>> getCombinedMessages() async* {
    final chatHistoriesRef = _dbRef.child('chatHistories/${widget.chatId}');
    final messagesRef = _dbRef.child('messages/${widget.chatId}');

    await for (final event in chatHistoriesRef.onValue) {
      final historySnapshot = event.snapshot.value;

      List<Map<String, dynamic>> chatHistory = [];
      if (historySnapshot is List) {
        chatHistory = historySnapshot
            .where((e) => e != null)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else if (historySnapshot is Map) {
        chatHistory = (historySnapshot as Map).values
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      final userSnapshot = await messagesRef.get();
      final userMessagesRaw = userSnapshot.value as Map<dynamic, dynamic>? ?? {};
      final userMessages = userMessagesRaw.entries
          .map((e) => Map<String, dynamic>.from(e.value))
          .toList();

      final allMessages = [...chatHistory, ...userMessages];
      allMessages.sort((a, b) => (a['timestamp'] ?? 0).compareTo(b['timestamp'] ?? 0));

      yield allMessages;
    }
  }

  void sendMessage() {
    final msg = _messageController.text.trim();
    if (msg.isEmpty) return;

    final newMessage = {
      'type': 'text',
      'content': msg,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'sender': 'user',
    };

    _dbRef.child('messages/${widget.chatId}').push().set(newMessage);
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    bool showInput = !widget.isDriver || widget.canChat;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        titleTextStyle: TextStyle(color: Colors.black),
        leading: BackButton(),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: primaryColor.withOpacity(0.2),
              child: Icon(widget.avatar, color: primaryColor),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.name, style: TextStyle(fontSize: 16)),
                  if (widget.subtitle.isNotEmpty)
                    Text(widget.subtitle, style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (widget.isDriver)
            IconButton(
              icon: Icon(Icons.phone),
              onPressed: () {
                // Handle phone call here
              },
            ),
          IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: () {
              // Handle more options here
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: getCombinedMessages(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;

                return ListView.builder(
                  padding: EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isUser = msg['sender'] == 'user';

                    return Align(
                      alignment:
                          isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: 6),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isUser
                              ? primaryColor.withOpacity(0.2)
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: msg['type'] == 'text'
                            ? Text(msg['content'])
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(
                                  msg['content'],
                                  width: 200,
                                  height: 200,
                                  fit: BoxFit.cover,
                                ),
                              ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Divider(height: 1),
          if (showInput)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.white,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.add_circle_outline),
                    onPressed: () {},
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: primaryColor),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.send, color: primaryColor),
                    onPressed: sendMessage,
                  ),
                ],
              ),
            ),
          if (!showInput)
            Container(
              padding: EdgeInsets.all(12),
              width: double.infinity,
              color: Colors.white,
              child: Column(
                children: [
                  Text(
                    "Chat has ended. If you need further help, please click Help Centre.",
                    style: TextStyle(color: primaryColor),
                  ),
                  SizedBox(height: 8),
                  Text("Chat with driver has ended.",
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

