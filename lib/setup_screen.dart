import 'package:flutter/material.dart';
import 'cycle_service.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final CycleService _cycleService = CycleService();
  final Color sageGreen = const Color(0xFFA8B3A0);

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _cycleLengthController = TextEditingController();
  final TextEditingController _periodDurationController =
      TextEditingController();

  DateTime? _selectedLastPeriodDate;
  String _selectedRegularity = 'Κανονικός';
  final List<String> _selectedSymptoms = [];
  bool _isLoading = false;

  final List<String> _regularityOptions = [
    'Κανονικός',
    'Ακανόνιστος',
    'Δεν γνωρίζω',
  ];
  final List<String> _commonSymptoms = [
    'Κράμπες',
    'Πονοκέφαλος',
    'Αλλαγές Διάθεσης',
    'Κόπωση',
    'Φούσκωμα',
    'Ακμή',
  ];

  bool get _usesUnknownCycleDetails => _selectedRegularity == 'Δεν γνωρίζω';

  Future<void> _submitForm() async {
    if (_usesUnknownCycleDetails) {
      await _saveDefaultCycleSettings();
      return;
    }

    if (!_formKey.currentState!.validate() ||
        _selectedLastPeriodDate == null ||
        _cycleLengthController.text.isEmpty ||
        _periodDurationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Συμπληρώστε σωστά όλα τα πεδία.'),
          backgroundColor: Color.fromARGB(255, 174, 50, 75),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _cycleService.saveInitialSettings(
        lastPeriodStart: _selectedLastPeriodDate!,
        cycleLength: int.parse(_cycleLengthController.text.trim()),
        periodDuration: int.parse(_periodDurationController.text.trim()),
        regularity: _selectedRegularity,
        typicalSymptoms: _selectedSymptoms,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ολοκληρώθηκε επιτυχώς!'),
            backgroundColor: Color.fromARGB(255, 10, 125, 14),
          ),
        );
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

  Future<void> _saveDefaultCycleSettings() async {
    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Χρήση προεπιλεγμένων τιμών;'),
        content: const Text(
          'Θα χρησιμοποιηθούν προεπιλεγμένες τιμές: περίοδος 6 ημερών και κύκλος 30 ημερών.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ΑΚΥΡΩΣΗ'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: sageGreen),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'ΣΥΝΕΧΕΙΑ',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (!mounted || shouldContinue != true) return;

    setState(() => _isLoading = true);
    try {
      await _cycleService.saveInitialSettings(
        lastPeriodStart: _selectedLastPeriodDate ?? DateTime.now(),
        cycleLength: 30,
        periodDuration: 6,
        regularity: 'Δεν γνωρίζω',
        typicalSymptoms: _selectedSymptoms,
      );
      await _cycleService.markProfileAsUsingDefaultSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Αποθηκεύτηκαν προεπιλεγμένες τιμές.'),
            backgroundColor: Color.fromARGB(255, 17, 136, 21),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              onTap: () async {
                DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2023),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _selectedLastPeriodDate = picked);
                }
              },
            ),
            const Divider(),
            TextFormField(
              controller: _cycleLengthController,
              enabled: !_usesUnknownCycleDetails,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Μέση Διάρκεια Κύκλου (π.χ. 28 μέρες)',
              ),
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _periodDurationController,
              enabled: !_usesUnknownCycleDetails,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Μέση Διάρκεια Περιόδου (π.χ. 5 μέρες)',
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Κανονικότητα Κύκλου',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            DropdownButtonFormField<String>(
              initialValue: _selectedRegularity,
              items: _regularityOptions
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _selectedRegularity = val!;
                  if (_usesUnknownCycleDetails) {
                    _cycleLengthController.text = '30';
                    _periodDurationController.text = '6';
                  }
                });
              },
            ),
            const SizedBox(height: 30),
            const Text(
              'Συνήθη Συμπτώματα (Προαιρετικό)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
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
                  onSelected: (selected) => setState(
                    () => selected
                        ? _selectedSymptoms.add(symptom)
                        : _selectedSymptoms.remove(symptom),
                  ),
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
                    : const Text(
                        'ΑΠΟΘΗΚΕΥΣΗ',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
