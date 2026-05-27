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
}