import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'user_profile_screen.dart';

class CommunityFeedScreen extends StatefulWidget {
  const CommunityFeedScreen({super.key});

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final Color sageGreen = const Color(0xFFA6B39E);

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    DateTime date = timestamp.toDate();
    return DateFormat('dd/MM/yyyy, HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ροή Κοινότητας', style: TextStyle(color: Colors.blueGrey)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.blueGrey),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Αναζήτηση Μελών',
            onPressed: () {
              // TODO: Μετάβαση στην Αναζήτηση (Εναλλακτική Ροή 3)
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Server-side filtering
        stream: FirebaseFirestore.instance
            .collection('community_posts')
            .where('isPublic', isEqualTo: true)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Δεν υπάρχουν ακόμα αναρτήσεις.\nΓίνε ο πρώτος που θα μοιραστεί ένα επίτευγμα!',
                textAlign: TextAlign.center,
              ),
            );
          }

          var posts = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              var data = posts[index].data() as Map<String, dynamic>;
              // Διαβάζουμε απευθείας το πεδίο username που σώσαμε
              String username = data['username'] ?? 'Άγνωστος'; 
              String content = data['content'] ?? '';
              Timestamp? timestamp = data['timestamp'];

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: GestureDetector(
                          onTap: () {
                            String targetUserId = data['userId'] ?? '';
                            if (targetUserId.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UserProfileScreen(targetUserId: targetUserId),
                                ),
                              );
                            }
                          },
                          child: CircleAvatar(
                            backgroundColor: Colors.blueGrey.shade100,
                            child: const Icon(Icons.person, color: Colors.blueGrey),
                          ),
                        ),
                        title: GestureDetector(
                          onTap: () {
                            String targetUserId = data['userId'] ?? '';
                            if (targetUserId.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UserProfileScreen(targetUserId: targetUserId),
                                ),
                              );
                            }
                          },
                          child: Text(
                            username,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        subtitle: Text(
                          _formatTimestamp(timestamp),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            Icon(Icons.workspace_premium, color: sageGreen, size: 30),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                content,
                                style: const TextStyle(fontSize: 15),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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