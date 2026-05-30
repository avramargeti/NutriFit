import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cycle_service.dart';

class DailyLogScreen extends StatefulWidget {
  final DateTime initialDate;
  final Map<String, dynamic> profileData;

  const DailyLogScreen({super.key, required this.initialDate, required this.profileData});

  @override
  State<DailyLogScreen> createState() => _DailyLogScreenState();
}

class _DailyLogScreenState extends State<DailyLogScreen> {
  final CycleService _cycleService = CycleService();
  final Color sageGreen = const Color(0xFFA8B3A0);
  final _formKey = GlobalKey<FormState>();

  late DateTime selectedDate;
  String selectedFlow = 'Ελαφριά';
  String selectedMood = 'Ουδέτερη';
  final List<String> selectedLogSymptoms = [];
  bool isPeriodStart = false;

  final List<String> _flowIntensityOptions = ['Ελαφριά', 'Κανονική', 'Βαριά', 'Καμία ροή'];
  final List<String> _moodOptions = ['Καλή', 'Ουδέτερη', 'Κακή'];
  final List<String> _cycleLogSymptoms = ['Κράμπες', 'Πόνος στη μέση', 'Πονοκέφαλος', 'Ατονία', 'Κόπωση', 'Φούσκωμα'];

  @override
  void initState() {
    super.initState();
    selectedDate = widget.initialDate;
  }

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    return null;
  }

  Future<void> _saveEntry() async {
    if (!_formKey.currentState!.validate()) return;
    
    try {
      int currentCycleLength = widget.profileData['cycleLength'] as int? ?? 30;
      int periodDuration = widget.profileData['periodDuration'] as int? ?? 6;
      DateTime? lastPeriodStart = _parseDate(widget.profileData['lastPeriodStart']);
      DateTime? nextPeriodPredicted = _parseDate(widget.profileData['nextPeriodPredicted']);

      if (nextPeriodPredicted == null && lastPeriodStart != null) {
        nextPeriodPredicted = lastPeriodStart.add(Duration(days: currentCycleLength));
      }

      int finalCycleLength = currentCycleLength;

      if (isPeriodStart && nextPeriodPredicted != null && lastPeriodStart != null) {
        DateTime normSelected = _dateOnly(selectedDate);
        DateTime normPredicted = _dateOnly(nextPeriodPredicted);
        DateTime normLast = _dateOnly(lastPeriodStart);

        int deviation = normSelected.difference(normPredicted).inDays.abs();

        // Ελέγχει αν η απόκλιση είναι πάνω από 4 μέρες
        if (deviation >= 4) {
          bool? isConfirmed = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Απόκλιση Κύκλου', style: TextStyle(fontSize: 18))),
                ],
              ),
              content: Text(
                'Η ημερομηνία που επιλέξατε αποκλίνει κατά $deviation μέρες από την προβλεπόμενη ( ${normPredicted.day}/${normPredicted.month} ).\n\n'
                'Πρόκειται για κανονική έναρξη νέου κύκλου ή για μεμονωμένο συμβάν (π.χ. κηλίδες);'
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('ΜΕΜΟΝΩΜΕΝΟ ΣΥΜΒΑΝ', style: TextStyle(color: Color.fromARGB(255, 167, 3, 101))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: sageGreen),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('ΕΝΑΡΞΗ ΝΕΟΥ ΚΥΚΛΟΥ', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );

          if (isConfirmed == null) return; 

          if (isConfirmed) {
            int actualDaysPassed = normSelected.difference(normLast).inDays;
            if (actualDaysPassed > 0) {
              finalCycleLength = ((currentCycleLength + actualDaysPassed) / 2).round();
            }
          } else {
            isPeriodStart = false; 
          }
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(); 
      
      await _cycleService.logCycleEntry(
        entryDate: selectedDate,
        flowIntensity: selectedFlow,
        symptoms: selectedLogSymptoms,
        mood: selectedMood,
        isPeriodStart: isPeriodStart,
        cycleLength: finalCycleLength, 
        periodDuration: periodDuration,
        currentLastPeriodStart: lastPeriodStart,
      );

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Προέκυψε σφάλμα: $e'), backgroundColor: Colors.red)
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Καταγραφή Κύκλου'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ημερομηνία'),
                subtitle: Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2023), lastDate: DateTime.now());
                  if (picked != null) setState(() => selectedDate = picked);
                },
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(color: Colors.pink.shade50, borderRadius: BorderRadius.circular(10)),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  activeColor: Colors.pink.shade400,
                  title: const Text('Έναρξη περιόδου', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: const Text('Το τέλος υπολογίζεται αυτόματα.', style: TextStyle(fontSize: 12)),
                  value: isPeriodStart,
                  onChanged: (val) {
                    setState(() {
                      isPeriodStart = val;
                      if (val && selectedFlow == 'Καμία ροή') selectedFlow = 'Κανονική';
                    });
                  },
                ),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: selectedFlow,
                decoration: const InputDecoration(labelText: 'Ένταση Ροής'),
                items: _flowIntensityOptions.map((flow) => DropdownMenuItem(value: flow, child: Text(flow))).toList(),
                onChanged: (value) { if (value != null) setState(() => selectedFlow = value); },
              ),
              const SizedBox(height: 16),
              const Text('Συμπτώματα', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _cycleLogSymptoms.map((symptom) {
                  final isSelected = selectedLogSymptoms.contains(symptom);
                  return FilterChip(
                    label: Text(symptom), selected: isSelected, selectedColor: Colors.pink.shade100, checkmarkColor: Colors.pink.shade400,
                    onSelected: (selected) => setState(() => selected ? selectedLogSymptoms.add(symptom) : selectedLogSymptoms.remove(symptom)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedMood,
                decoration: const InputDecoration(labelText: 'Διάθεση'),
                items: _moodOptions.map((mood) => DropdownMenuItem(value: mood, child: Text(mood))).toList(),
                onChanged: (value) { if (value != null) setState(() => selectedMood = value); },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('ΑΚΥΡΩΣΗ')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: sageGreen),
          onPressed: _saveEntry,
          child: const Text('ΑΠΟΘΗΚΕΥΣΗ', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}