import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'member_search_screen.dart';
import 'user_profile_screen.dart';
import 'recipes_list_screen.dart';

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

  Future<void> _handleShareRecipeTap(String targetUserId, String targetUsername) async {
    if (currentUser == null || targetUserId == currentUser!.uid) return;
    
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      DocumentSnapshot friendDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('friends')
          .doc(targetUserId)
          .get();

      if (!friendDoc.exists) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Πρέπει να είστε φίλοι για να στείλετε συνταγή!')),
        );
        return;
      }

      if (mounted) {
        _showRecipeSelectionSheet(targetUserId, targetUsername);
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Σφάλμα: $e')));
    }
  }

  void _showRecipeSelectionSheet(String targetUserId, String targetUsername) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Αποστολή Συνταγής σε: @$targetUsername', 
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const Divider(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUser!.uid)
                      .collection('cookingBook')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text('Δεν βρέθηκαν συνταγές στο Βιβλίο σας.', style: TextStyle(color: Colors.grey)),
                      );
                    }

                    var recipes = snapshot.data!.docs;

                    return ListView.builder(
                      itemCount: recipes.length,
                      itemBuilder: (context, index) {
                        var recipeData = recipes[index].data() as Map<String, dynamic>;
                        String recipeTitle = recipeData['title'] ?? 'Χωρίς Τίτλο';
                        String recipeId = recipes[index].id;
                        
                        String? imageUrl = recipeData['imageUrl'];

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: sageGreen.withValues(alpha: 0.2),
                            backgroundImage: (imageUrl != null && imageUrl.isNotEmpty) 
                                ? NetworkImage(imageUrl) 
                                : null,
                            child: (imageUrl == null || imageUrl.isEmpty)
                                ? Icon(Icons.restaurant, color: sageGreen)
                                : null,
                          ),
                          title: Text(recipeTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                          trailing: const Icon(Icons.send, color: Colors.blueAccent),
                          onTap: () {
                            Navigator.pop(context);
                            _sendRecipeToFriend(targetUserId, targetUsername, recipeId, recipeTitle, imageUrl);
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
      },
    );
  }

  Future<void> _sendRecipeToFriend(String targetUserId, String targetUsername, String recipeId, String recipeTitle, String? imageUrl) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    String myUsername = currentUser!.displayName ?? currentUser!.email ?? 'Κάποιος';

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUserId)
          .collection('messages')
          .add({
        'fromId': currentUser!.uid,
        'fromUsername': myUsername,
        'type': 'recipe_share',
        'recipeId': recipeId,
        'recipeTitle': recipeTitle,
        'imageUrl': imageUrl,
        'message': 'Σου έστειλα μια συνταγή: $recipeTitle!',
        'timestamp': FieldValue.serverTimestamp(),
      });

      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Η συνταγή στάλθηκε επιτυχώς στον/στην @$targetUsername!')),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Σφάλμα αποστολής: $e')));
    }
  }

  Future<void> _acceptRequest(String senderId, String senderName) async {
    if (currentUser == null) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('friends')
          .doc(senderId)
          .set({
        'friendId': senderId,
        'friendUsername': senderName,
        'friendsSince': FieldValue.serverTimestamp(),
      });

      String myUsername = currentUser!.displayName ?? currentUser!.email ?? 'Άγνωστος';
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(senderId)
          .collection('friends')
          .doc(currentUser!.uid)
          .set({
        'friendId': currentUser!.uid,
        'friendUsername': myUsername,
        'friendsSince': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('friendRequests')
          .doc(senderId)
          .delete();

      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Αποδεχτήκατε το αίτημα του/της @$senderName!')),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Σφάλμα: $e')));
    }
  }

  Future<void> _rejectRequest(String senderId) async {
    if (currentUser == null) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('friendRequests')
          .doc(senderId)
          .delete();

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Το αίτημα απορρίφθηκε.')),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Σφάλμα: $e')));
    }
  }

  void _showFriendRequests() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Αιτήματα Φιλίας', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const Divider(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUser!.uid)
                      .collection('friendRequests')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text('Δεν έχετε νέα αιτήματα φιλίας.', style: TextStyle(color: Colors.grey)),
                      );
                    }

                    var requests = snapshot.data!.docs;

                    return ListView.builder(
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        var reqData = requests[index].data() as Map<String, dynamic>;
                        String senderUsername = reqData['fromUsername'] ?? 'Άγνωστος';
                        String senderId = reqData['fromId'];

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: Colors.blueGrey.shade100,
                            child: const Icon(Icons.person, color: Colors.blueGrey),
                          ),
                          title: Text('@$senderUsername', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Θέλει να γίνετε φίλοι!'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () => _rejectRequest(senderId),
                              ),
                              IconButton(
                                icon: Icon(Icons.check_circle, color: sageGreen, size: 30),
                                onPressed: () => _acceptRequest(senderId, senderUsername),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showInboxSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Τα Εισερχόμενά Μου', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const Divider(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUser!.uid)
                      .collection('messages')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text('Δεν έχετε νέα μηνύματα.', style: TextStyle(color: Colors.grey)),
                      );
                    }

                    var messages = snapshot.data!.docs;

                    return ListView.builder(
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        var msgData = messages[index].data() as Map<String, dynamic>;
                        String fromUsername = msgData['fromUsername'] ?? 'Κάποιος';
                        String recipeTitle = msgData['recipeTitle'] ?? 'Συνταγή';
                        String recipeId = msgData['recipeId'] ?? '';
                        String messageDocId = messages[index].id;
                        String? imageUrl = msgData['imageUrl'];

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: sageGreen.withValues(alpha: 0.2),
                            backgroundImage: (imageUrl != null && imageUrl.isNotEmpty) 
                                ? NetworkImage(imageUrl) 
                                : null,
                            child: (imageUrl == null || imageUrl.isEmpty)
                                ? Icon(Icons.restaurant_menu, color: sageGreen)
                                : null,
                          ),
                          title: Text('@$fromUsername', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Έστειλε συνταγή: $recipeTitle'),
                          
                          onTap: () async {
                            Navigator.pop(context);

                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const Center(child: CircularProgressIndicator()),
                            );

                            try {
                              DocumentSnapshot recipeDoc = await FirebaseFirestore.instance
                                  .collection('recipes')
                                  .doc(recipeId)
                                  .get();

                              if (!context.mounted) return;
                              Navigator.pop(context);

                              if (recipeDoc.exists) {
                                var recipeData = recipeDoc.data() as Map<String, dynamic>;

                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.white, 
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(25))
                                    ),
                                    child: RecipeDetailsSheet(
                                      recipeId: recipeId,
                                      data: recipeData,
                                    ),
                                  ),
                                );

                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(currentUser!.uid)
                                    .collection('messages')
                                    .doc(messageDocId)
                                    .delete();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Η συνταγή δεν υπάρχει πια στην κεντρική βάση.')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Σφάλμα: $e')),
                                );
                              }
                            }
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
      },
    );
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
            icon: const Icon(Icons.mail_outline),
            tooltip: 'Εισερχόμενα',
            onPressed: _showInboxSheet,
          ),
          IconButton(
            icon: const Icon(Icons.people),
            tooltip: 'Αιτήματα Φιλίας',
            onPressed: _showFriendRequests,
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Αναζήτηση Μελών',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MemberSearchScreen()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
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
              String username = data['username'] ?? 'Άγνωστος';
              String content = data['content'] ?? '';
              Timestamp? timestamp = data['timestamp'];

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
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
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: Colors.blueGrey.shade100,
                            child: const Icon(Icons.person, color: Colors.blueGrey),
                          ),
                          title: Text(
                            username,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Text(
                            _formatTimestamp(timestamp),
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: currentUser!.uid != (data['userId'] ?? '') 
                            ? IconButton(
                                icon: Icon(Icons.send_rounded, color: sageGreen),
                                tooltip: 'Αποστολή Συνταγής',
                                onPressed: () {
                                  _handleShareRecipeTap(data['userId'], username);
                                },
                              )
                            : null,
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
                ),
              );
            },
          );
        },
      ),
    );
  }
}