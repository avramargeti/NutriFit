import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ProgressHistoryScreen extends StatelessWidget {
  const ProgressHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final Color sageGreen = const Color(0xFFA8B3A0);
    final Color slateGrey = const Color(0xFF8C9DA6);

    if (user == null) return const Scaffold(body: Center(child: Text('Παρακαλώ συνδεθείτε.')));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F5),
      appBar: AppBar(
        title: const Text('Ιστορικό Προόδου'),
        backgroundColor: Colors.white,
        foregroundColor: slateGrey,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('progress_history')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: sageGreen));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('Δεν υπάρχει ιστορικό ακόμα.', style: TextStyle(color: slateGrey, fontSize: 16)),
                ],
              ),
            );
          }

          var docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var docData = docs[index].data() as Map<String, dynamic>;
              var dateTimestamp = docData['date'] as Timestamp?;
              var report = docData['report'] as Map<String, dynamic>? ?? {};

              String dateStr = dateTimestamp != null 
                  ? DateFormat('d MMMM yyyy', 'el').format(dateTimestamp.toDate()) 
                  : 'Άγνωστη ημερομηνία';

              String status = report['status'] ?? '';
              
              Color statusColor = Colors.grey;
              IconData statusIcon = Icons.article;
              String statusText = 'Αναφορά';

              if (status == 'goal_met') {
                statusColor = sageGreen;
                statusIcon = Icons.emoji_events;
                statusText = 'Επιτυχία Στόχου';
              } else if (status == 'goal_not_met') {
                statusColor = Colors.orange.shade600;
                statusIcon = Icons.trending_up;
                statusText = 'Προσαρμογή Πλάνου';
              } else if (status == 'mid_week_review') {
                statusColor = Colors.blueAccent;
                statusIcon = Icons.query_stats;
                statusText = 'Ενδιάμεση Αναφορά';
              }

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(statusIcon, color: statusColor, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(statusText, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: statusColor)),
                                Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                            child: Text('${report['daysLogged'] ?? 0}/7 Ημέρες', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: slateGrey)),
                          )
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      if (report.containsKey('avgDailyCalories'))
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Μέσος Όρος:', style: TextStyle(color: Colors.grey)),
                            Text('${report['avgDailyCalories']} kcal', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      if (report.containsKey('targetDailyCalories'))
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Στόχος:', style: TextStyle(color: Colors.grey)),
                              Text('${report['targetDailyCalories']} kcal', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      if (report.containsKey('achievement'))
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 16),
                              const SizedBox(width: 6),
                              Text('Επίτευγμα: ${report['achievement']}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.amber.shade700)),
                            ],
                          ),
                        )
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