import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileScreen extends StatefulWidget {
  final String targetUserId;

  const UserProfileScreen({super.key, required this.targetUserId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final Color sageGreen = const Color(0xFFA6B39E);
  bool _isSendingRequest = false;

  Future<void> _sendFriendRequest() async {
    if (currentUser == null) return;

    setState(() {
      _isSendingRequest = true;
    });

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.targetUserId)
          .collection('friendRequests')
          .doc(currentUser!.uid)
          .set({
        'fromId': currentUser!.uid,
        'fromUsername': currentUser!.displayName ?? currentUser!.email,
        'status': 'pending', 
        'timestamp': FieldValue.serverTimestamp(),
      });

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Το αίτημα φιλίας στάλθηκε επιτυχώς!')),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Σφάλμα κατά την αποστολή: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingRequest = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) return const Scaffold(body: Center(child: Text('Παρακαλώ συνδεθείτε.')));

    bool isOwnProfile = currentUser!.uid == widget.targetUserId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Προφίλ Μέλους', style: TextStyle(color: Colors.blueGrey)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.blueGrey),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(widget.targetUserId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Ο χρήστης δεν βρέθηκε.'));
          }

          var userData = snapshot.data!.data() as Map<String, dynamic>;
          
          String username = userData['username'] ?? 'Άγνωστο';
          String fullName = userData['fullName'] ?? 'Δεν έχει οριστεί';
          String mainGoal = userData['mainGoal'] ?? 'Δεν έχει οριστεί';
          String dailyActivity = userData['dailyActivity'] ?? 'Δεν έχει οριστεί';
          var targetCalories = userData['targetCalories'] ?? '-';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.blueGrey.shade100,
                    child: const Icon(Icons.person, size: 50, color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '@$username',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                  ),
                  Text(
                    fullName,
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),

                  if (!isOwnProfile)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: sageGreen,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: _isSendingRequest ? null : _sendFriendRequest,
                      icon: _isSendingRequest 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.person_add, color: Colors.white),
                      label: const Text('Προσθήκη Φίλου', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),

                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),

                  _buildInfoTile(Icons.track_changes, 'Κύριος Στόχος', mainGoal),
                  _buildInfoTile(Icons.local_fire_department, 'Ημερήσιος Θερμιδικός Στόχος', '$targetCalories kcal'),
                  _buildInfoTile(Icons.directions_run, 'Καθημερινή Δραστηριότητα', dailyActivity),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String value) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: Icon(icon, color: sageGreen),
        title: Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
      ),
    );
  }
}