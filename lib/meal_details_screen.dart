import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MealDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> itemData;
  final String category;
  final String dateString;
  final bool isExercise;
  final String title;

  const MealDetailsScreen({
    super.key,
    required this.itemData,
    required this.category,
    required this.dateString,
    required this.isExercise,
    required this.title,
  });

  @override
  State<MealDetailsScreen> createState() => _MealDetailsScreenState();
}

class _MealDetailsScreenState extends State<MealDetailsScreen> {
  late TextEditingController qtyController;
  bool isLoading = false;
  final Color sageGreen = const Color(0xFFA8B3A0);

  @override
  void initState() {
    super.initState();
    qtyController = TextEditingController(
      text: widget.isExercise ? "30" : "100",
    );
  }

  @override
  void dispose() {
    qtyController.dispose();
    super.dispose();
  }

  double _parseNum(dynamic value) => (value is num)
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0.0;

  Future<void> _saveEntry() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final qty =
        double.tryParse(qtyController.text.trim().replaceAll(',', '.')) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Συμπλήρωσε έγκυρη ποσότητα.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      double calsPer100 = _parseNum(
        widget.itemData['caloriesPer100g'] ?? widget.itemData['calories'] ?? 0,
      );
      double protPer100 = _parseNum(
        widget.itemData['proteinPer100g'] ?? widget.itemData['protein'] ?? 0,
      );
      double carbPer100 = _parseNum(
        widget.itemData['carbsPer100g'] ?? widget.itemData['carbs'] ?? 0,
      );
      double fatPer100 = _parseNum(
        widget.itemData['fatsPer100g'] ?? widget.itemData['fats'] ?? 0,
      );

      double ratio = qty / 100.0;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('diary')
          .doc(widget.dateString)
          .set({
            'entries': FieldValue.arrayUnion([
              {
                'name': widget.title,
                'category': widget.category,
                'isExercise': widget.isExercise,
                'calories': (calsPer100 * ratio).round(),
                'protein': (protPer100 * ratio).round(),
                'carbs': (carbPer100 * ratio).round(),
                'fats': (fatPer100 * ratio).round(),
                'quantity': qty,
                'unit': widget.isExercise ? 'λεπτά' : 'g',
                'loggedAt': Timestamp.now(),
                'imageUrl': widget.itemData['imageUrl'] ?? '',
              },
            ]),
          }, SetOptions(merge: true));

      if (mounted) {
        Navigator.of(context)
          ..pop()
          ..pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Σφάλμα: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: qtyController,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              labelText: widget.isExercise ? 'Διάρκεια' : 'Ποσότητα',
              suffixText: widget.isExercise ? 'λεπτά' : 'g',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.pop(context),
          child: const Text('ΑΚΥΡΟ'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: sageGreen),
          onPressed: isLoading ? null : _saveEntry,
          child: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('ΚΑΤΑΧΩΡΗΣΗ', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
