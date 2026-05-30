import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'cycle_service.dart';
import 'setup_screen.dart';
import 'dailylog_screen.dart';

class CycleScreen extends StatefulWidget {
  const CycleScreen({super.key});

  @override
  State<CycleScreen> createState() => _CycleScreenState();
}

class _CycleScreenState extends State<CycleScreen> {
  final CycleService _cycleService = CycleService();
  final Color sageGreen = const Color(0xFFA8B3A0);
  
  DateTime _currentCalendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedCalendarDate = DateTime.now();
  final List<String> _monthNames = ['Ιανουάριος', 'Φεβρουάριος', 'Μάρτιος', 'Απρίλιος', 'Μάιος', 'Ιούνιος', 'Ιούλιος', 'Αύγουστος', 'Σεπτέμβριος', 'Οκτώβριος', 'Νοέμβριος', 'Δεκέμβριος'];

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
                  return const SetupScreen(); // Καλεί το 2ο αρχείο
                } else {
                  return _buildCalendarView(snapshot.data!.data() as Map<String, dynamic>);
                }
              },
            ),
    );
  }

  Widget _buildCalendarView(Map<String, dynamic> data) {
    DateTime nextPeriod = (data['nextPeriodPredicted'] as Timestamp).toDate();
    final DateTime? lastPeriodStart = (data['lastPeriodStart'] as Timestamp?)?.toDate();
    final DateTime? fertilityWindowStart = (data['fertilityWindowStart'] as Timestamp?)?.toDate();
    final DateTime? fertilityWindowEnd = (data['fertilityWindowEnd'] as Timestamp?)?.toDate();
    final recommendation = data['lastRecommendation'] as String?;
    final cycleLength = data['cycleLength'] as int? ?? 30;
    final periodDuration = data['periodDuration'] as int? ?? 6;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMonthHeader(),
          const SizedBox(height: 8),
          _buildMonthCalendar(
            profileData: data, lastPeriodStart: lastPeriodStart, nextPeriod: nextPeriod,
            fertilityWindowStart: fertilityWindowStart, fertilityWindowEnd: fertilityWindowEnd,
            cycleLength: cycleLength, periodDuration: periodDuration,
          ),
          const SizedBox(height: 16),
          
          if (recommendation != null && recommendation.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.pink.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.pink.shade100)),
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
          if (lastPeriodStart != null) _buildInfoTile(icon: Icons.event, title: 'Τελευταία Περίοδος', subtitle: '${lastPeriodStart.day}/${lastPeriodStart.month}/${lastPeriodStart.year}'),
          _buildInfoTile(icon: Icons.calendar_today, title: 'Πρόβλεψη Επόμενης Περιόδου', subtitle: '${nextPeriod.day}/${nextPeriod.month}/${nextPeriod.year}'),
          if (fertilityWindowStart != null && fertilityWindowEnd != null)
            _buildInfoTile(icon: Icons.spa, title: 'Παράθυρο Γονιμότητας', subtitle: '${fertilityWindowStart.day}/${fertilityWindowStart.month}/${fertilityWindowStart.year} - ${fertilityWindowEnd.day}/${fertilityWindowEnd.month}/${fertilityWindowEnd.year}'),
          
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: sageGreen),
              onPressed: _isFutureDate(_selectedCalendarDate) ? null : () => _openDailyLogScreen(data),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('ΚΑΤΑΓΡΑΦΗ ΝΕΩΝ ΔΕΔΟΜΕΝΩΝ', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  void _openDailyLogScreen(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (_) => DailyLogScreen(initialDate: _selectedCalendarDate, profileData: data), // Καλεί το 3ο αρχείο
    );
  }

  Widget _buildMonthHeader() {
    return Row(
      children: [
        IconButton(
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
          onPressed: () => setState(() => _currentCalendarMonth = DateTime(_currentCalendarMonth.year, _currentCalendarMonth.month + 1)),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildMonthCalendar({
    required Map<String, dynamic> profileData, required DateTime? lastPeriodStart, required DateTime nextPeriod,
    required DateTime? fertilityWindowStart, required DateTime? fertilityWindowEnd, required int cycleLength, required int periodDuration,
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
            child: Row(children: weekdays.map((day) => Expanded(child: Text(day, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF5D5792), fontWeight: FontWeight.bold, fontSize: 12)))).toList()),
          ),
          GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: rowCount * 7,
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
    required Map<String, dynamic> profileData, required DateTime date, required DateTime? lastPeriodStart,
    required DateTime nextPeriod, required DateTime? fertilityWindowStart, required DateTime? fertilityWindowEnd,
    required int cycleLength, required int periodDuration,
  }) {
    final isSelected = _isSameDay(date, _selectedCalendarDate);
    final isToday = _isSameDay(date, DateTime.now());
    
    final isActualPeriodDay = _isInDateRange(date, lastPeriodStart, periodDuration);
    final isPredictedPeriodDay = _isInDateRange(date, nextPeriod, periodDuration);
    
    final List<dynamic> pastPeriods = profileData['pastPeriods'] ?? [];
    bool isPastPeriodDay = pastPeriods.any((p) => p['start'] != null && p['duration'] != null && _isInDateRange(date, (p['start'] as Timestamp).toDate(), p['duration'] as int));

    final isFertileDay = fertilityWindowStart != null && fertilityWindowEnd != null && !date.isBefore(_dateOnly(fertilityWindowStart)) && !date.isAfter(_dateOnly(fertilityWindowEnd));
    final isOvulationDay = _isSameDay(date, nextPeriod.subtract(const Duration(days: 14)));
    
    int? cycleDay;
    if (lastPeriodStart != null && cycleLength > 0) {
      final difference = _dateOnly(date).difference(_dateOnly(lastPeriodStart)).inDays;
      if (difference >= 0) cycleDay = (difference % cycleLength) + 1;
    }

    Color backgroundColor = Colors.transparent;
    Color dayColor = Colors.black;
    Border? cellBorder;

    if (isActualPeriodDay) { backgroundColor = const Color(0xFFE97DA8); dayColor = Colors.white; } 
    else if (isPastPeriodDay) { backgroundColor = const Color(0xFFC7B1B9); dayColor = Colors.white; } 
    else if (isPredictedPeriodDay) { backgroundColor = const Color(0xFFFCE4EC); dayColor = const Color(0xFFD81B60); cellBorder = Border.all(color: const Color(0xFFF8BBD0), width: 1); } 
    else if (isFertileDay) { backgroundColor = const Color(0xFFF8E7F0); }
    
    if (isSelected) { backgroundColor = const Color(0xFF332477); dayColor = Colors.white; cellBorder = null; }

    return InkWell(
      onTap: () {
        setState(() => _selectedCalendarDate = date);
        if (_isFutureDate(date)) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Δεν μπορείτε να κάνετε καταγραφή για μελλοντική ημερομηνία.'), backgroundColor: Colors.orange));
        else _openDailyLogScreen(profileData);
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
}