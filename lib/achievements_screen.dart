import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'community_feed_screen.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final Color sageGreen = const Color(0xFFA6B39E);

  void _showShareDialog(String achievementTitle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('Κοινοποίηση Επιτεύγματος', textAlign: TextAlign.center),
        content: Text('Πού θέλεις να κοινοποιήσεις το επίτευγμα:\n"$achievementTitle";'),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
            icon: const Icon(Icons.group, color: Colors.white),
            label: const Text('Μόνο Φίλοι', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.pop(context);
              _shareAchievement(achievementTitle, isPublic: false);
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: sageGreen),
            icon: const Icon(Icons.public, color: Colors.white),
            label: const Text('Δημόσια', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.pop(context);
              _shareAchievement(achievementTitle, isPublic: true);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _shareAchievement(String title, {required bool isPublic}) async {
    if (currentUser == null) return;

    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      
      String username = userDoc.exists && (userDoc.data() as Map).containsKey('username') 
          ? userDoc['username'] 
          : 'Άγνωστος';

      await FirebaseFirestore.instance.collection('community_posts').add({
        'userId': currentUser!.uid,
        'username': username,
        'type': 'achievement',
        'content': 'Μόλις κέρδισα το επίτευγμα: $title!',
        'isPublic': isPublic,
        'timestamp': FieldValue.serverTimestamp(),
      });

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Η δημοσίευση έγινε με επιτυχία!')),
      );
      navigator.pushReplacement(
        MaterialPageRoute(builder: (context) => const CommunityFeedScreen()),
      );
      
    } catch (e) {
      if (!context.mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Σφάλμα: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) return const Scaffold(body: Center(child: Text('Παρακαλώ συνδεθείτε.')));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Τα Επιτεύγματά μου', style: TextStyle(color: Colors.blueGrey)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.blueGrey),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .collection('achievements')
            .orderBy('earnedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('Δεν έχεις κατακτήσει ακόμα κάποιο επίτευγμα.\nΣυνέχισε την καλή προσπάθεια!', textAlign: TextAlign.center),
            );
          }

          var docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String achievementTitle = data['title'] ?? 'Άγνωστο Επίτευγμα';
              
              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: sageGreen,
                    child: const Icon(Icons.workspace_premium, color: Colors.white),
                  ),
                  title: Text(achievementTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: IconButton(
                    icon: const Icon(Icons.share, color: Colors.blueAccent),
                    onPressed: () => _showShareDialog(achievementTitle),
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