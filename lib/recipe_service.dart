import 'package:flutter/material.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RecipeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> submitReview(
    String recipeId, 
    double general, 
    double ease, 
    double speed, 
    double nutrition, 
    double cost, 
    double clarity, 
    String comment
  ) async {
    final user = _auth.currentUser;
    if (user == null) return;

    List<double> allRatings = [general, ease, speed, nutrition, cost, clarity];
    List<double> validRatings = allRatings.where((r) => r > 0).toList();

    double currentReviewAvg = 0.0;
    if (validRatings.isNotEmpty) {
      double sumValid = validRatings.fold(0.0, (prev, curr) => prev + curr);
      currentReviewAvg = sumValid / validRatings.length;
    }

    final recipeRef = _db.collection('recipes').doc(recipeId);
    final doc = await recipeRef.get();
    
    List reviews = List.from(doc.data()?['reviews'] ?? []);
    int existingIndex = reviews.indexWhere((r) => r['userId'] == user.uid);
    
    Map<String, dynamic> reviewData = {
      'userId': user.uid,
      'rating': currentReviewAvg, 
      'general': general,         
      'ease': ease,               
      'speed': speed,
      'nutrition': nutrition,
      'cost': cost,
      'clarity': clarity,
      'comment': comment,
      'timestamp': Timestamp.now(),
    };

    if (existingIndex != -1) {
      reviews[existingIndex] = reviewData; 
    } else {
      reviews.add(reviewData); 
    }

    double totalSum = 0.0;
    for (var r in reviews) {
      totalSum += (r['rating'] as num).toDouble();
    }
    double recipeAvgRating = reviews.isEmpty ? 0.0 : totalSum / reviews.length;

    await recipeRef.update({
      'reviews': reviews,
      'avgRating': recipeAvgRating,   
      'totalReviews': reviews.length, 
    });
  }

  Future<void> promptAddToCookingBook(BuildContext context) async {
    final Color sageGreen = const Color(0xFFA8B3A0); 

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Cooking Book'),
          content: const Text('Επιθυμείτε την προσθήκη της συνταγής στο προσωπικό βιβλίο συνταγών σας;'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext); 
              },
              child: const Text('ΟΧΙ', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: sageGreen),
              onPressed: () {
                Navigator.pop(dialogContext); 
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Σύντομα διαθέσιμο! 🚧'),
                      backgroundColor: Colors.orange, 
                    ),
                  );
                }
              },
              child: const Text('ΝΑΙ', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
  // 3. Εμφάνιση παραθύρου με όλες τις αξιολογήσεις (ΜΕ ΑΝΑΔΙΠΛΟΥΜΕΝΗ ΚΑΡΤΑ)
  Future<void> showAllReviews(BuildContext context, List reviews) async {
    final Color sageGreen = const Color(0xFFA8B3A0); 

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.7, 
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Όλες οι Αξιολογήσεις', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const Divider(),
                
                Expanded(
                  child: reviews.isEmpty
                      ? const Center(child: Text('Δεν υπάρχουν αξιολογήσεις ακόμα. 🌟', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: reviews.length,
                          itemBuilder: (context, index) {
                            var review = reviews[index];
                            return FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance.collection('users').doc(review['userId']).get(),
                              builder: (context, snapshot) {
                                String username = "Φόρτωση...";
                                if (snapshot.hasData && snapshot.data!.exists) {
                                  var userData = snapshot.data!.data() as Map<String, dynamic>;
                                  username = userData['username'] ?? userData['name'] ?? 'Χρήστης';
                                }
                                
                                // ---- ΝΕΑ ΔΙΑΔΡΑΣΤΙΚΗ ΚΑΡΤΑ (ΕXPANSION TILE) ----
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  color: Colors.grey.shade50,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10), 
                                    side: BorderSide(color: Colors.grey.shade200)
                                  ),
                                  child: Theme(
                                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                    child: ExpansionTile(
                                      tilePadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                                      childrenPadding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
                                      
                                      title: Row(
                                        children: [
                                          CircleAvatar(radius: 14, backgroundColor: sageGreen, child: const Icon(Icons.person, size: 16, color: Colors.white)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis),
                                          ),
                                        ],
                                      ),
                                      
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text((review['rating'] as num).toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                                          const Icon(Icons.star, color: Colors.amber, size: 16),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                                        ],
                                      ),
                                      
                                      subtitle: (review['comment'] != null && review['comment'].toString().trim().isNotEmpty)
                                          ? Padding(
                                              padding: const EdgeInsets.only(top: 6.0),
                                              child: Text(
                                                review['comment'], 
                                                style: const TextStyle(fontSize: 14, color: Colors.black87),
                                                maxLines: 2, 
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            )
                                          : const Padding(
                                              padding: EdgeInsets.only(top: 6.0),
                                              child: Text('Πατήστε για αναλυτική βαθμολογία', style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
                                            ),
                                            
                                      children: [
                                        const Divider(height: 20),
                                        
                                        ...[
                                          {'label': 'Γενική Βαθμολογία', 'key': 'general'},
                                          {'label': 'Ευκολία Υλοποίησης', 'key': 'ease'},
                                          {'label': 'Γρήγορη Εκτέλεση', 'key': 'speed'},
                                          {'label': 'Θρεπτική Αξία', 'key': 'nutrition'},
                                          {'label': 'Κόστος Υλικών', 'key': 'cost'},
                                          {'label': 'Σαφήνεια Οδηγιών', 'key': 'clarity'},
                                        ].map((cat) {
                                          var val = review[cat['key']];
                                          if (val != null && (val as num) > 0) {
                                            return Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(cat['label'] as String, style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                                                  Row(
                                                    children: [
                                                      Text((val).toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                                      const Icon(Icons.star, color: Colors.amber, size: 14),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            );
                                          }
                                          return const SizedBox.shrink(); 
                                        }),
                                        
                                        if (review['comment'] != null && review['comment'].toString().trim().isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.grey.shade300)
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('Σχόλιο:', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                                                const SizedBox(height: 4),
                                                Text(review['comment'], style: const TextStyle(fontSize: 14, color: Colors.black87)),
                                              ],
                                            ),
                                          ),
                                        ]
                                      ],
                                    ),
                                  ),
                                );
                                // -----------------------------------------------
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}