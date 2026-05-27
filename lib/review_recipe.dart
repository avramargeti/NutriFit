import 'package:flutter/material.dart';

class ReviewDialog extends StatefulWidget {
  final Function(
    double general, 
    double ease, 
    double speed, 
    double nutrition, 
    double cost, 
    double clarity, 
    String comment
  ) onUpdate;
  
  const ReviewDialog({super.key, required this.onUpdate});

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  double _generalRating = 0; 
  double _easeRating = 0;
  double _speedRating = 0;
  double _nutritionRating = 0;
  double _costRating = 0;
  double _clarityRating = 0;
  String? _errorMessage;
  
  final TextEditingController _controller = TextEditingController();

  //Συνάρτηση για τη δημιουργία κάθε αξιολόγησης(είτε υποχρεωτική είτε προαιρετική)
  Widget _buildRatingCategory(String title, double currentRating, Function(double) onRatingChanged, {bool isMandatory = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: title,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 15),
            children: [
              if (isMandatory) 
                const TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              if (!isMandatory) 
                const TextSpan(text: ' (Προαιρετικό)', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.normal)),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: List.generate(5, (i) => IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              i < currentRating ? Icons.star : Icons.star_border, 
              color: Colors.amber,
              size: isMandatory ? 30 : 22, 
            ),
            onPressed: () {
              if (currentRating == i + 1.0) {
                onRatingChanged(0.0); 
              } else {
                onRatingChanged(i + 1.0); 
              }
            },
          )),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Αξιολογήστε τη συνταγή'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //Υποχρεωτική Κατηγορία Αξιολόγησης
              _buildRatingCategory(
                'Γενική Βαθμολογία', 
                _generalRating, 
                (rating) => setState(() {
                  _generalRating = rating;
                  _errorMessage = null; 
                }),
                isMandatory: true,
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),

              const Divider(),
              const SizedBox(height: 5),
              
              //Προαιρετικές Κατηγορίες Αξιολόγησης
              _buildRatingCategory(
                'Ευκολία Υλοποίησης', 
                _easeRating, 
                (rating) => setState(() => _easeRating = rating),
              ),
              _buildRatingCategory(
                'Γρήγορη Εκτέλεση', 
                _speedRating, 
                (rating) => setState(() => _speedRating = rating),
              ),
              _buildRatingCategory(
                'Θρεπτική Αξία', 
                _nutritionRating, 
                (rating) => setState(() => _nutritionRating = rating),
              ),
              _buildRatingCategory(
                'Κόστος Υλικών', 
                _costRating, 
                (rating) => setState(() => _costRating = rating),
              ),
              _buildRatingCategory(
                'Σαφήνεια Οδηγιών', 
                _clarityRating, 
                (rating) => setState(() => _clarityRating = rating),
              ),
              
              const SizedBox(height: 5),
              const Divider(),
              const SizedBox(height: 5),
              
              TextField(
                controller: _controller, 
                maxLines: 3, 
                decoration: const InputDecoration(
                  hintText: 'Γράψτε τα σχόλιά σας...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(10),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), 
          child: const Text('ΑΚΥΡΟ', style: TextStyle(color: Colors.grey))
        ),
        ElevatedButton(
          onPressed: () {
            if (_generalRating == 0) {
              setState(() {
                _errorMessage = '⚠️ Παρακαλώ συμπληρώστε τη Γενική Βαθμολογία!';
              });
              return;
            }

            widget.onUpdate(
              _generalRating, 
              _easeRating, 
              _speedRating, 
              _nutritionRating, 
              _costRating, 
              _clarityRating, 
              _controller.text
            );
            
            Navigator.pop(context);
          },
          child: const Text('ΥΠΟΒΟΛΗ'),
        ),
      ],
    ); 
  } 
} 