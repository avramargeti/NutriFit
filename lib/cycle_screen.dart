import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'cycle_service.dart';

class CycleScreen extends StatefulWidget {
  const CycleScreen({super.key});

  @override
  State<CycleScreen> createState() => _CycleScreenState();
}

class _CycleScreenState extends State<CycleScreen> {
  final CycleService _cycleService = CycleService();
  final Color sageGreen = const Color(0xFFA8B3A0);

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _cycleLengthController = TextEditingController();
  final TextEditingController _periodDurationController = TextEditingController();
  DateTime? _selectedLastPeriodDate;
  bool _isLoading = false;

  String _selectedRegularity = 'Κανονικός';
  List<String> _selectedSymptoms = [];

  final List<String> _regularityOptions = ['Κανονικός', 'Ακανόνιστος', 'Δεν γνωρίζω'];
  final List<String> _commonSymptoms = [
    'Κράμπες', 'Πονοκέφαλος', 'Αλλαγές Διάθεσης', 
    'Κόπωση', 'Φούσκωμα', 'Ακμή'
  ];

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ο Κύκλος μου', style: TextStyle(color: Colors.white)),
        backgroundColor: sageGreen,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: uid == null
          ? const Center(child: Text('Παρακαλώ συνδεθείτε'))
          : StreamBuilder<DocumentSnapshot>(
              stream: _cycleService.getUserCycleProfile(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text('Σφάλμα φόρτωσης δεδομένων'));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: sageGreen));
                }

                final hasData = snapshot.hasData && snapshot.data!.exists;

                if (!hasData) {
                  return _buildSetupForm();
                } else {
                  return _buildCalendarView(snapshot.data!.data() as Map<String, dynamic>);
                }
              },
            ),
    );
  }

  Widget _buildSetupForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Αρχική Ρύθμιση Κύκλου',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Τελευταία Περίοδος (Έναρξη)'),
              subtitle: Text(
                _selectedLastPeriodDate == null 
                  ? 'Επιλέξτε ημερομηνία' 
                  : '${_selectedLastPeriodDate!.day}/${_selectedLastPeriodDate!.month}/${_selectedLastPeriodDate!.year}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),
            const Divider(),

            TextFormField(
              controller: _cycleLengthController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Μέση Διάρκεια Κύκλου (π.χ. 28 μέρες)'),
              validator: (value) => value!.isEmpty ? 'Συμπληρώστε τη διάρκεια' : null,
            ),
            const SizedBox(height: 15),

            TextFormField(
              controller: _periodDurationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Μέση Διάρκεια Περιόδου (π.χ. 5 μέρες)'),
              validator: (value) => value!.isEmpty ? 'Συμπληρώστε τη διάρκεια' : null,
            ),
            const SizedBox(height: 30),

            const Text('Κανονικότητα Κύκλου', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            DropdownButtonFormField<String>(
              value: _selectedRegularity,
              items: _regularityOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) => setState(() => _selectedRegularity = val!),
            ),
            const SizedBox(height: 30),

            const Text('Συνήθη Συμπτώματα (Προαιρετικό)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _commonSymptoms.map((symptom) {
                final isSelected = _selectedSymptoms.contains(symptom);
                return FilterChip(
                  label: Text(symptom),
                  selected: isSelected,
                  selectedColor: Colors.pink.shade100,
                  checkmarkColor: Colors.pink.shade400,
                  labelStyle: TextStyle(color: isSelected ? Colors.pink.shade700 : Colors.black87),
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        _selectedSymptoms.add(symptom);
                      } else {
                        _selectedSymptoms.remove(symptom);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: sageGreen),
                onPressed: _isLoading ? null : _submitForm,
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('ΑΠΟΘΗΚΕΥΣΗ', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarView(Map<String, dynamic> data) {
    DateTime nextPeriod = (data['nextPeriodPredicted'] as Timestamp).toDate();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_month, size: 80, color: Colors.grey),
          const SizedBox(height: 20),
          const Text('Το Ημερολόγιό σας είναι έτοιμο!', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 10),
          Text(
            'Πρόβλεψη Επόμενης Περιόδου:\n${nextPeriod.day}/${nextPeriod.month}/${nextPeriod.year}',
            textAlign: TextAlign.center,
            style: TextStyle(color: sageGreen, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedLastPeriodDate = picked);
    }
  }

  bool _validateData() {
    bool isFormValid = _formKey.currentState!.validate();
    bool isDateSelected = _selectedLastPeriodDate != null;

    if (!isFormValid || !isDateSelected) {
      String errorMsg = 'Παρακαλώ συμπληρώστε σωστά όλα τα πεδία.';
      if (!isDateSelected) {
        errorMsg = 'Παρακαλώ επιλέξτε ημερομηνία τελευταίας περιόδου.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.orange),
      );
      return false; 
    }
    return true; 
  }

  Future<void> _submitForm() async {
    if (!_validateData()) return; 

    setState(() => _isLoading = true);
    try {
      await _cycleService.saveInitialSettings(
        lastPeriodStart: _selectedLastPeriodDate!,
        cycleLength: int.parse(_cycleLengthController.text),
        periodDuration: int.parse(_periodDurationController.text),
        regularity: _selectedRegularity,    // Στέλνουμε το νέο πεδίο
        typicalSymptoms: _selectedSymptoms, // Στέλνουμε το νέο πεδίο
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Η ρύθμιση του κύκλου ολοκληρώθηκε επιτυχώς!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Σφάλμα: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}