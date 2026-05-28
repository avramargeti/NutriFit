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
  
  final Map<String, dynamic>? existingReview; 
  
  const ReviewDialog({super.key, required this.onUpdate, this.existingReview});

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

  bool _isEditing = true;

  @override
  void initState() {
    super.initState();
    //Εναλλακτική Ροή 4
    if (widget.existingReview != null) {
      _isEditing = false; 
      
      _generalRating = (widget.existingReview!['general'] as num?)?.toDouble() ?? 0;
      _easeRating = (widget.existingReview!['ease'] as num?)?.toDouble() ?? 0;
      _speedRating = (widget.existingReview!['speed'] as num?)?.toDouble() ?? 0;
      _nutritionRating = (widget.existingReview!['nutrition'] as num?)?.toDouble() ?? 0;
      _costRating = (widget.existingReview!['cost'] as num?)?.toDouble() ?? 0;
      _clarityRating = (widget.existingReview!['clarity'] as num?)?.toDouble() ?? 0;
      _controller.text = widget.existingReview!['comment'] ?? '';
    }
  }

  // Συνάρτηση για τη δημιουργία της φόρμας αξιολόγησης
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

  Widget _buildReadOnlyCategory(String title, double rating) {
    if (rating == 0) return const SizedBox.shrink(); 
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
          Row(
            children: [
              Text(rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
              const Icon(Icons.star, color: Colors.amber, size: 18),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _isEditing 
          ? (widget.existingReview != null ? 'Τροποποίηση Αξιολόγησης' : 'Αξιολογήστε τη συνταγή')
          : 'Η Αξιολόγησή σας',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: _isEditing 
            ? 
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                      child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    
                  const Divider(),
                  const SizedBox(height: 5),
                  
                  _buildRatingCategory('Ευκολία Υλοποίησης', _easeRating, (rating) => setState(() => _easeRating = rating)),
                  _buildRatingCategory('Γρήγορη Εκτέλεση', _speedRating, (rating) => setState(() => _speedRating = rating)),
                  _buildRatingCategory('Θρεπτική Αξία', _nutritionRating, (rating) => setState(() => _nutritionRating = rating)),
                  _buildRatingCategory('Κόστος Υλικών', _costRating, (rating) => setState(() => _costRating = rating)),
                  _buildRatingCategory('Σαφήνεια Οδηγιών', _clarityRating, (rating) => setState(() => _clarityRating = rating)),
                  
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
              ):
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReadOnlyCategory('Γενική Βαθμολογία', _generalRating),
                  const Divider(),
                  _buildReadOnlyCategory('Ευκολία Υλοποίησης', _easeRating),
                  _buildReadOnlyCategory('Γρήγορη Εκτέλεση', _speedRating),
                  _buildReadOnlyCategory('Θρεπτική Αξία', _nutritionRating),
                  _buildReadOnlyCategory('Κόστος Υλικών', _costRating),
                  _buildReadOnlyCategory('Σαφήνεια Οδηγιών', _clarityRating),
                  
                  if (_controller.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('Σχόλιο:', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    Container(
                      width: double.maxFinite,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300)
                      ),
                      child: Text(_controller.text, style: const TextStyle(fontSize: 14)),
                    )
                  ]
                ],
              ),
        ),
      ),
      actions: _isEditing 
        ? 
          [
            TextButton(
              onPressed: () {
                if (widget.existingReview != null) {
                  setState(() => _isEditing = false); 
                } else {
                  Navigator.pop(context); 
                }
              }, 
              child: const Text('ΑΚΥΡΟ', style: TextStyle(color: Colors.grey))
            ),
            ElevatedButton(
              onPressed: () {
                if (_generalRating == 0) {
                  setState(() => _errorMessage = '⚠️ Παρακαλώ συμπληρώστε τη Γενική Βαθμολογία!');
                  return; 
                }
                widget.onUpdate(_generalRating, _easeRating, _speedRating, _nutritionRating, _costRating, _clarityRating, _controller.text);
                Navigator.pop(context);
              },
              child: Text(widget.existingReview != null ? 'ΑΠΟΘΗΚΕΥΣΗ' : 'ΥΠΟΒΟΛΗ'),
            ),
          ]
        : 
          [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text('ΚΛΕΙΣΙΜΟ', style: TextStyle(color: Colors.grey))
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.edit, size: 16),
              onPressed: () => setState(() => _isEditing = true), 
              label: const Text('ΤΡΟΠΟΠΟΙΗΣΗ'),
            ),
          ],
    );
  }
}