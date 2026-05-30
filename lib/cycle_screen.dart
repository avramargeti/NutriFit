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
  static const int _defaultCycleLength = 30;
  static const int _defaultPeriodDuration = 6;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _cycleLengthController = TextEditingController();
  final TextEditingController _periodDurationController = TextEditingController();
  
  DateTime? _selectedLastPeriodDate;
  DateTime _currentCalendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedCalendarDate = DateTime.now();
  bool _isLoading = false;

  String _selectedRegularity = 'Κανονικός';
  final List<String> _selectedSymptoms = [];

  final List<String> _regularityOptions = ['Κανονικός', 'Ακανόνιστος', 'Δεν γνωρίζω'];
  final List<String> _commonSymptoms = ['Κράμπες', 'Πονοκέφαλος', 'Αλλαγές Διάθεσης', 'Κόπωση', 'Φούσκωμα', 'Ακμή'];
  final List<String> _flowIntensityOptions = ['Ελαφριά', 'Κανονική', 'Βαριά', 'Καμία ροή'];
  final List<String> _moodOptions = ['Καλή', 'Ουδέτερη', 'Κακή'];
  final List<String> _cycleLogSymptoms = ['Κράμπες', 'Πόνος στη μέση', 'Πονοκέφαλος', 'Ατονία', 'Κόπωση', 'Φούσκωμα'];
  final List<String> _monthNames = ['Ιανουάριος', 'Φεβρουάριος', 'Μάρτιος', 'Απρίλιος', 'Μάιος', 'Ιούνιος', 'Ιούλιος', 'Αύγουστος', 'Σεπτέμβριος', 'Οκτώβριος', 'Νοέμβριος', 'Δεκέμβριος'];

  bool get _usesUnknownCycleDetails => _selectedRegularity == 'Δεν γνωρίζω';

  @override
  void dispose() {
    _cycleLengthController.dispose();
    _periodDurationController.dispose();
    super.dispose();
  }

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
                if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: sageGreen));

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
            const Text('Αρχική Ρύθμιση Κύκλου', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Τελευταία Περίοδος (Έναρξη)'),
              subtitle: Text(
                _selectedLastPeriodDate == null ? 'Επιλέξτε ημερομηνία' : '${_selectedLastPeriodDate!.day}/${_selectedLastPeriodDate!.month}/${_selectedLastPeriodDate!.year}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),
            const Divider(),
            TextFormField(
              controller: _cycleLengthController,
              enabled: !_usesUnknownCycleDetails,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Μέση Διάρκεια Κύκλου (π.χ. 28 μέρες)'),
              validator: (value) => !_usesUnknownCycleDetails && (value == null || value.trim().isEmpty) ? 'Συμπληρώστε τη μέση διάρκεια κύκλου' : null,
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _periodDurationController,
              enabled: !_usesUnknownCycleDetails,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Μέση Διάρκεια Περιόδου (π.χ. 5 μέρες)'),
              validator: (value) => !_usesUnknownCycleDetails && (value == null || value.trim().isEmpty) ? 'Συμπληρώστε τη μέση διάρκεια περιόδου' : null,
            ),
            const SizedBox(height: 30),
            const Text('Κανονικότητα Κύκλου', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            DropdownButtonFormField<String>(
              initialValue: _selectedRegularity,
              items: _regularityOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedRegularity = val!;
                  if (_usesUnknownCycleDetails) {
                    _cycleLengthController.text = '$_defaultCycleLength';
                    _periodDurationController.text = '$_defaultPeriodDuration';
                  }
                });
              },
            ),
            if (_usesUnknownCycleDetails) ...[
              const SizedBox(height: 10),
              Text('Θα χρησιμοποιηθούν προεπιλεγμένες τιμές: κύκλος 30 ημερών και περίοδος 6 ημερών.', style: TextStyle(color: Colors.grey.shade700)),
            ],
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
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) _selectedSymptoms.add(symptom);
                      else _selectedSymptoms.remove(symptom);
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
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('ΑΠΟΘΗΚΕΥΣΗ', style: TextStyle(color: Colors.white, fontSize: 16)),
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
    final DateTime? lastPeriodStart = (data['lastPeriodStart'] as Timestamp?)?.toDate();
    final DateTime? fertilityWindowStart = (data['fertilityWindowStart'] as Timestamp?)?.toDate();
    final DateTime? fertilityWindowEnd = (data['fertilityWindowEnd'] as Timestamp?)?.toDate();
    final recommendation = data['lastRecommendation'] as String?;
    final cycleLength = data['cycleLength'] as int? ?? _defaultCycleLength;
    final periodDuration = data['periodDuration'] as int? ?? _defaultPeriodDuration;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMonthHeader(),
          const SizedBox(height: 8),
          _buildMonthCalendar(
            profileData: data,
            lastPeriodStart: lastPeriodStart,
            nextPeriod: nextPeriod,
            fertilityWindowStart: fertilityWindowStart,
            fertilityWindowEnd: fertilityWindowEnd,
            cycleLength: cycleLength,
            periodDuration: periodDuration,
          ),
          const SizedBox(height: 16),
          
          if (recommendation != null && recommendation.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.pink.shade50, 
                borderRadius: BorderRadius.circular(8), 
                border: Border.all(color: Colors.pink.shade100)
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.favorite, color: Colors.pink.shade300),
                  const SizedBox(width: 10),
                  Expanded(child: Text(recommendation)),
                ],
              ),
            ),
            const SizedBox(height: 16), 
          ],

          _buildInfoTile(icon: Icons.water_drop, title: 'Τρέχων Κύκλος', subtitle: 'Κύκλος $cycleLength ημερών • Περίοδος $periodDuration ημερών'),
          if (lastPeriodStart != null) _buildInfoTile(icon: Icons.event, title: 'Τελευταία Περίοδος', subtitle: _formatDate(lastPeriodStart)),
          _buildInfoTile(icon: Icons.calendar_today, title: 'Πρόβλεψη Επόμενης Περιόδου', subtitle: _formatDate(nextPeriod)),
          if (fertilityWindowStart != null && fertilityWindowEnd != null)
            _buildInfoTile(icon: Icons.spa, title: 'Παράθυρο Γονιμότητας', subtitle: '${_formatDate(fertilityWindowStart)} - ${_formatDate(fertilityWindowEnd)}'),
          
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: sageGreen),
              onPressed: _isLoading || _isFutureDate(_selectedCalendarDate) ? null : () => _showCycleEntryDialog(data, initialDate: _selectedCalendarDate),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('ΚΑΤΑΓΡΑΦΗ ΝΕΩΝ ΔΕΔΟΜΕΝΩΝ', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthHeader() {
    return Row(
      children: [
        IconButton(
          tooltip: 'Προηγούμενος μήνας',
          onPressed: () => setState(() => _currentCalendarMonth = DateTime(_currentCalendarMonth.year, _currentCalendarMonth.month - 1)),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            '${_monthNames[_currentCalendarMonth.month - 1]} ${_currentCalendarMonth.year}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          tooltip: 'Επόμενος μήνας',
          onPressed: () => setState(() => _currentCalendarMonth = DateTime(_currentCalendarMonth.year, _currentCalendarMonth.month + 1)),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildMonthCalendar({
    required Map<String, dynamic> profileData,
    required DateTime? lastPeriodStart,
    required DateTime nextPeriod,
    required DateTime? fertilityWindowStart,
    required DateTime? fertilityWindowEnd,
    required int cycleLength,
    required int periodDuration,
  }) {
    const weekdays = ['Κ', 'Δ', 'Τ', 'Τ', 'Π', 'Π', 'Σ'];
    final firstDay = DateTime(_currentCalendarMonth.year, _currentCalendarMonth.month);
    final daysInMonth = DateTime(_currentCalendarMonth.year, _currentCalendarMonth.month + 1, 0).day;
    final leadingEmptyCells = firstDay.weekday % 7;
    final totalCells = leadingEmptyCells + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF7F5FB), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: weekdays.map((day) => Expanded(child: Text(day, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF5D5792), fontWeight: FontWeight.bold, fontSize: 12)))).toList(),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rowCount * 7,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1.18),
            itemBuilder: (context, index) {
              final dayNumber = index - leadingEmptyCells + 1;
              if (dayNumber < 1 || dayNumber > daysInMonth) return Container(decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200)));
              
              final date = DateTime(_currentCalendarMonth.year, _currentCalendarMonth.month, dayNumber);
              return _buildCalendarDayCell(profileData: profileData, date: date, lastPeriodStart: lastPeriodStart, nextPeriod: nextPeriod, fertilityWindowStart: fertilityWindowStart, fertilityWindowEnd: fertilityWindowEnd, cycleLength: cycleLength, periodDuration: periodDuration);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarDayCell({
    required Map<String, dynamic> profileData,
    required DateTime date,
    required DateTime? lastPeriodStart,
    required DateTime nextPeriod,
    required DateTime? fertilityWindowStart,
    required DateTime? fertilityWindowEnd,
    required int cycleLength,
    required int periodDuration,
  }) {
    final isSelected = _isSameDay(date, _selectedCalendarDate);
    final isToday = _isSameDay(date, DateTime.now());
    final isFuture = _isFutureDate(date);
    
    final isActualPeriodDay = _isInDateRange(date, lastPeriodStart, periodDuration);
    final isPredictedPeriodDay = _isInDateRange(date, nextPeriod, periodDuration);
    
    final List<dynamic> pastPeriods = profileData['pastPeriods'] ?? [];
    bool isPastPeriodDay = false;
    for (var p in pastPeriods) {
      if (p['start'] != null && p['duration'] != null) {
        if (_isInDateRange(date, (p['start'] as Timestamp).toDate(), p['duration'] as int)) {
          isPastPeriodDay = true;
          break;
        }
      }
    }

    final isFertileDay = fertilityWindowStart != null && fertilityWindowEnd != null && !date.isBefore(_dateOnly(fertilityWindowStart)) && !date.isAfter(_dateOnly(fertilityWindowEnd));
    final isOvulationDay = _isSameDay(date, nextPeriod.subtract(const Duration(days: 14)));
    final cycleDay = _cycleDayForDate(date: date, lastPeriodStart: lastPeriodStart, cycleLength: cycleLength);

    Color backgroundColor = Colors.transparent;
    Color dayColor = Colors.black;
    Border? cellBorder;

    if (isActualPeriodDay) {
      backgroundColor = const Color(0xFFE97DA8); 
      dayColor = Colors.white;
    } else if (isPastPeriodDay) {
      backgroundColor = const Color(0xFFC7B1B9); 
      dayColor = Colors.white;
    } else if (isPredictedPeriodDay) {
      backgroundColor = const Color(0xFFFCE4EC); 
      dayColor = const Color(0xFFD81B60);        
      cellBorder = Border.all(color: const Color(0xFFF8BBD0), width: 1); 
    } else if (isFertileDay) {
      backgroundColor = const Color(0xFFF8E7F0); 
    }
    
    if (isSelected) {
      backgroundColor = const Color(0xFF332477); 
      dayColor = Colors.white;
      cellBorder = null; 
    }

    return InkWell(
      onTap: () {
        setState(() => _selectedCalendarDate = date);
        if (isFuture) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Δεν μπορείτε να κάνετε καταγραφή για μελλοντική ημερομηνία.'), backgroundColor: Colors.orange));
          return;
        }
        _showCycleEntryDialog(profileData, initialDate: date);
      },
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: backgroundColor, border: cellBorder ?? Border.all(color: Colors.grey.shade100), borderRadius: isSelected ? BorderRadius.circular(6) : null),
        child: Stack(
          children: [
            Align(alignment: Alignment.topLeft, child: Text('${date.day}', style: TextStyle(color: dayColor, fontSize: 15, fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w500))),
            if (cycleDay != null) Align(alignment: Alignment.topRight, child: Text('$cycleDay', style: TextStyle(color: isSelected || isActualPeriodDay || isPastPeriodDay ? Colors.white70 : Colors.grey.shade500, fontSize: 10))),
            if (isOvulationDay) Align(alignment: Alignment.center, child: Container(width: 12, height: 10, decoration: const BoxDecoration(color: Color(0xFF8E45D8), shape: BoxShape.circle)))
            else if (isFertileDay && !isActualPeriodDay && !isPredictedPeriodDay && !isPastPeriodDay) Align(alignment: Alignment.center, child: Icon(Icons.local_florist, size: 14, color: isSelected ? Colors.white : Colors.pink.shade400)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({required IconData icon, required String title, required String subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Icon(icon, color: sageGreen),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
      ),
    );
  }

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2023), lastDate: DateTime.now());
    if (picked != null) setState(() => _selectedLastPeriodDate = picked);
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
  bool _isSameDay(DateTime first, DateTime second) => first.year == second.year && first.month == second.month && first.day == second.day;
  bool _isFutureDate(DateTime date) => _dateOnly(date).isAfter(_dateOnly(DateTime.now()));

  bool _isInDateRange(DateTime date, DateTime? startDate, int duration) {
    if (startDate == null || duration <= 0) return false;
    final current = _dateOnly(date);
    final start = _dateOnly(startDate);
    final end = start.add(Duration(days: duration - 1));
    return !current.isBefore(start) && !current.isAfter(end);
  }

  int? _cycleDayForDate({required DateTime date, required DateTime? lastPeriodStart, required int cycleLength}) {
    if (lastPeriodStart == null || cycleLength <= 0) return null;
    final difference = _dateOnly(date).difference(_dateOnly(lastPeriodStart));
    if (difference.inDays < 0) return null;
    return (difference.inDays % cycleLength) + 1;
  }

  Future<void> _showCycleEntryDialog(Map<String, dynamic> profileData, {DateTime? initialDate}) async {
    final formKey = GlobalKey<FormState>();
    DateTime selectedDate = initialDate ?? DateTime.now();
    String selectedFlow = _flowIntensityOptions.first;
    String selectedMood = _moodOptions[1];
    final selectedLogSymptoms = <String>[];
    bool isPeriodStart = false; 

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Καταγραφή Κύκλου'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Ημερομηνία'),
                        subtitle: Text(_formatDate(selectedDate)),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2023), lastDate: DateTime.now());
                          if (picked != null) setDialogState(() => selectedDate = picked);
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
                            setDialogState(() {
                              isPeriodStart = val;
                              if (val && selectedFlow == 'Καμία ροή') selectedFlow = 'Κανονική';
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 15),
                      DropdownButtonFormField<String>(
                        initialValue: selectedFlow,
                        decoration: const InputDecoration(labelText: 'Ένταση Ροής'),
                        items: _flowIntensityOptions.map((flow) => DropdownMenuItem(value: flow, child: Text(flow))).toList(),
                        onChanged: (value) { if (value != null) setDialogState(() => selectedFlow = value); },
                      ),
                      const SizedBox(height: 16),
                      const Text('Συμπτώματα', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _cycleLogSymptoms.map((symptom) {
                          final isSelected = selectedLogSymptoms.contains(symptom);
                          return FilterChip(
                            label: Text(symptom),
                            selected: isSelected,
                            selectedColor: Colors.pink.shade100,
                            checkmarkColor: Colors.pink.shade400,
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) selectedLogSymptoms.add(symptom);
                                else selectedLogSymptoms.remove(symptom);
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedMood,
                        decoration: const InputDecoration(labelText: 'Διάθεση'),
                        items: _moodOptions.map((mood) => DropdownMenuItem(value: mood, child: Text(mood))).toList(),
                        onChanged: (value) { if (value != null) setDialogState(() => selectedMood = value); },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('ΑΚΥΡΩΣΗ')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: sageGreen),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.of(dialogContext).pop();
                    await _saveCycleEntry(
                      profileData: profileData,
                      entryDate: selectedDate,
                      flowIntensity: selectedFlow,
                      symptoms: selectedLogSymptoms,
                      mood: selectedMood,
                      isPeriodStart: isPeriodStart,
                    );
                  },
                  child: const Text('ΑΠΟΘΗΚΕΥΣΗ', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveCycleEntry({
    required Map<String, dynamic> profileData,
    required DateTime entryDate,
    required String flowIntensity,
    required List<String> symptoms,
    required String mood,
    required bool isPeriodStart, 
  }) async {
    setState(() => _isLoading = true);
    try {
      await _cycleService.logCycleEntry(
        entryDate: entryDate,
        flowIntensity: flowIntensity,
        symptoms: symptoms,
        mood: mood,
        isPeriodStart: isPeriodStart, 
        cycleLength: profileData['cycleLength'] as int? ?? _defaultCycleLength,
        periodDuration: profileData['periodDuration'] as int? ?? _defaultPeriodDuration,
        currentLastPeriodStart: (profileData['lastPeriodStart'] as Timestamp?)?.toDate(),
      );

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Η καταγραφή αποθηκεύτηκε επιτυχώς!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Σφάλμα: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _validateData() {
    bool isFormValid = _formKey.currentState!.validate();
    bool isDateSelected = _selectedLastPeriodDate != null;
    
    if (_usesUnknownCycleDetails) return isFormValid;

    if (_cycleLengthController.text.trim().isEmpty || _periodDurationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Παρακαλώ συμπληρώστε τη διάρκεια.'), backgroundColor: Colors.orange));
      return false;
    }

    if (!isFormValid || !isDateSelected) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Συμπληρώστε σωστά όλα τα πεδία.'), backgroundColor: Colors.orange));
      return false;
    }
    return true;
  }

  Future<void> _submitForm() async {
    if (!_validateData()) return;

    if (_usesUnknownCycleDetails) {
      await _saveDefaultCycleSettings();
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ολοκληρώθηκε επιτυχώς!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Σφάλμα: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveDefaultCycleSettings() async {
    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Χρήση προεπιλεγμένων τιμών;'),
        content: const Text('Θα χρησιμοποιηθούν προεπιλεγμένες τιμές: περίοδος 6 ημερών και κύκλος 30 ημερών.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('ΑΚΥΡΩΣΗ')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: sageGreen), onPressed: () => Navigator.of(context).pop(true), child: const Text('ΣΥΝΕΧΕΙΑ', style: TextStyle(color: Colors.white))),
        ],
      ),
    );

    if (!mounted || shouldContinue != true) return;

    setState(() => _isLoading = true);
    try {
      await _cycleService.saveInitialSettings(
        lastPeriodStart: _selectedLastPeriodDate ?? DateTime.now(),
        cycleLength: _defaultCycleLength,
        periodDuration: _defaultPeriodDuration,
        regularity: 'Δεν γνωρίζω',
        typicalSymptoms: _selectedSymptoms,
      );
      
      await _cycleService.markProfileAsUsingDefaultSettings();

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Αποθηκεύτηκαν προεπιλεγμένες τιμές κύκλου.'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Σφάλμα: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}