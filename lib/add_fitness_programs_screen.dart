import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddFitnessProgramScreen extends StatefulWidget {
  final Map<String, dynamic>? programData;
  final String? programId;
  final bool? isAdmin; 

  const AddFitnessProgramScreen({super.key, this.programData, this.programId, this.isAdmin});

  @override
  State<AddFitnessProgramScreen> createState() => _AddFitnessProgramScreenState();
}

class _AddFitnessProgramScreenState extends State<AddFitnessProgramScreen> {
  final Color sageGreen = const Color(0xFFA8B3A0);
  final Color slateGrey = const Color(0xFF8C9DA6);

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController; 
  late TextEditingController _caloriesController; 
  
  String _selectedCategory = 'Cardio / Τρέξιμο';
  String _selectedLocation = 'Σπίτι';
  String _selectedIntensity = 'Χαμηλή';
  String _selectedDuration = '< 30 λεπτά';

  final List<String> _categories = [
    'Cardio / Τρέξιμο', 'Βάρη / Ενδυνάμωση', 'Yoga', 'Pilates', 
    'Κολύμβηση', 'Αθλήματα', 'Ποδηλασία', 'CrossFit', 'Ευεξία'
  ];
  final List<String> _locations = ['Σπίτι', 'Γυμναστήριο', 'Εξωτερικός Χώρος'];
  final List<String> _intensities = ['Χαμηλή', 'Μέτρια', 'Υψηλή'];
  final List<String> _durations = ['< 30 λεπτά', '30-45 λεπτά', '> 45 λεπτά'];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.programData?['name'] ?? '');
    _descriptionController = TextEditingController(text: widget.programData?['description'] ?? '');
    _caloriesController = TextEditingController(text: widget.programData?['estimatedCalories']?.toString() ?? '');

    if (widget.programData != null) {
      if (_categories.contains(widget.programData!['category'])) {
        _selectedCategory = widget.programData!['category'];
      }
      if (_locations.contains(widget.programData!['location'])) {
        _selectedLocation = widget.programData!['location'];
      }
      if (_intensities.contains(widget.programData!['intensity'])) {
        _selectedIntensity = widget.programData!['intensity'];
      }
      if (_durations.contains(widget.programData!['duration'])) {
        _selectedDuration = widget.programData!['duration'];
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  Future<void> _saveProgram() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      int parsedCalories = int.tryParse(_caloriesController.text.trim()) ?? 0;

      final programData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'estimatedCalories': parsedCalories, 
        'category': _selectedCategory,
        'location': _selectedLocation,
        'intensity': _selectedIntensity,
        'duration': _selectedDuration,
      };

      if (widget.programId != null) {
        await FirebaseFirestore.instance
            .collection('fitness_programs')
            .doc(widget.programId)
            .update(programData);
      } else {
        programData['createdBy'] = user.uid; 
        programData['createdAt'] = FieldValue.serverTimestamp();
        
        await FirebaseFirestore.instance
            .collection('fitness_programs')
            .add(programData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.programId != null ? 'Το πρόγραμμα ενημερώθηκε!' : 'Το πρόγραμμα αποθηκεύτηκε επιτυχώς!'),
            backgroundColor: sageGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Σφάλμα: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.programId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Επεξεργασία Προγράμματος' : 'Νέο Πρόγραμμα'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Όνομα Προγράμματος'),
                validator: (val) => val == null || val.isEmpty ? 'Απαιτείται όνομα' : null,
              ),
              const SizedBox(height: 15),
              
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Σύντομη Περιγραφή', hintText: 'Τι περιλαμβάνει η προπόνηση;'),
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _caloriesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Εκτιμώμενες Θερμίδες', hintText: 'π.χ. 300'),
              ),
              const SizedBox(height: 15),
              
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Κατηγορία'),
                items: _categories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => setState(() => _selectedCategory = val!),
              ),
              const SizedBox(height: 15),
              
              DropdownButtonFormField<String>(
                initialValue: _selectedLocation,
                decoration: const InputDecoration(labelText: 'Τοποθεσία'),
                items: _locations.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => setState(() => _selectedLocation = val!),
              ),
              const SizedBox(height: 15),
              
              DropdownButtonFormField<String>(
                initialValue: _selectedIntensity,
                decoration: const InputDecoration(labelText: 'Ένταση'),
                items: _intensities.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => setState(() => _selectedIntensity = val!),
              ),
              const SizedBox(height: 15),
              
              DropdownButtonFormField<String>(
                initialValue: _selectedDuration,
                decoration: const InputDecoration(labelText: 'Διάρκεια'),
                items: _durations.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => setState(() => _selectedDuration = val!),
              ),
              const SizedBox(height: 30),
              
              _isLoading 
                ? Center(child: CircularProgressIndicator(color: sageGreen))
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: sageGreen, 
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 2,
                    ),
                    onPressed: _saveProgram,
                    child: Text(isEditing ? 'ΕΝΗΜΕΡΩΣΗ' : 'ΑΠΟΘΗΚΕΥΣΗ', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}