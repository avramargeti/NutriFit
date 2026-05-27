import 'package:flutter/material.dart';

class AddEditFitnessProgramScreen extends StatefulWidget {
  final Map<String, dynamic>? programData;
  final String? programId;
  final bool? isAdmin; 

  const AddEditFitnessProgramScreen({super.key, this.programData, this.programId, this.isAdmin});

  @override
  State<AddEditFitnessProgramScreen> createState() => _AddEditFitnessProgramScreenState();
}

class _AddEditFitnessProgramScreenState extends State<AddEditFitnessProgramScreen> {
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

  void _saveDummyProgram() {
    if (!_formKey.currentState!.validate()) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Το πρόγραμμα αποθηκεύτηκε επιτυχώς (Mockup)!'),
        backgroundColor: sageGreen,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.programId == null ? 'Νέο Πρόγραμμα' : 'Επεξεργασία Προγράμματος'),
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
                decoration: const InputDecoration(
                  labelText: 'Σύντομη Περιγραφή',
                  hintText: 'Τι περιλαμβάνει η προπόνηση;'
                ),
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _caloriesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Εκτιμώμενες Θερμίδες',
                  hintText: 'π.χ. 300'
                ),
              ),
              const SizedBox(height: 15),
              
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Κατηγορία'),
                items: _categories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => setState(() => _selectedCategory = val!),
              ),
              const SizedBox(height: 15),
              
              DropdownButtonFormField<String>(
                value: _selectedLocation,
                decoration: const InputDecoration(labelText: 'Τοποθεσία'),
                items: _locations.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => setState(() => _selectedLocation = val!),
              ),
              const SizedBox(height: 15),
              
              DropdownButtonFormField<String>(
                value: _selectedIntensity,
                decoration: const InputDecoration(labelText: 'Ένταση'),
                items: _intensities.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => setState(() => _selectedIntensity = val!),
              ),
              const SizedBox(height: 15),
              
              DropdownButtonFormField<String>(
                value: _selectedDuration,
                decoration: const InputDecoration(labelText: 'Διάρκεια'),
                items: _durations.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => setState(() => _selectedDuration = val!),
              ),
              const SizedBox(height: 30),
              
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: sageGreen, 
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 2,
                ),
                onPressed: _saveDummyProgram,
                child: const Text('ΑΠΟΘΗΚΕΥΣΗ', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}