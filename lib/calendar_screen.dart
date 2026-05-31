import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'fitness_programs_screen.dart';
import 'meal_selection_screen.dart';
import 'progress_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  final Set<String> _expandedCategories = {};
  final Color sageGreen = const Color(0xFFA8B3A0);
  final Color slateGrey = const Color(0xFF8C9DA6);
  final List<String> _mealCategories = const [
    'Πρωινό',
    'Μεσημεριανό',
    'Βραδινό',
    'Σνακ',
    'Άσκηση',
  ];

  String get _dateString => DateFormat('yyyy-MM-dd').format(_selectedDate);
  String get _displayDate =>
      DateFormat('EEEE, d MMM', 'el').format(_selectedDate);

  DateTime get _selectedDay =>
      DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

  bool get _isFutureDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _selectedDay.isAfter(today);
  }

  int _asInt(dynamic value) {
    if (value is num) return value.round();
    return num.tryParse(value?.toString() ?? '')?.round() ?? 0;
  }

  List<Map<String, dynamic>> _entryList(dynamic entries) {
    if (entries is! List) return [];

    return entries
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  String _entrySubtitle(Map<String, dynamic> entry) {
    final category = (entry['category'] ?? '').toString();
    final quantity = _asInt(entry['quantity']);
    final unit = (entry['unit'] ?? '').toString();

    if (quantity <= 0 || unit.isEmpty) return category;
    return '$category • $quantity $unit';
  }

  String _entryKey(Map<String, dynamic> entry, int index) {
    final loggedAt = entry['loggedAt'];
    if (loggedAt is Timestamp) {
      return '${loggedAt.millisecondsSinceEpoch}-$index';
    }

    return '${entry['name'] ?? 'entry'}-${entry['category'] ?? ''}-$index';
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Πρωινό':
        return Icons.breakfast_dining;
      case 'Μεσημεριανό':
        return Icons.lunch_dining;
      case 'Βραδινό':
        return Icons.dinner_dining;
      case 'Σνακ':
        return Icons.apple;
      case 'Άσκηση':
        return Icons.fitness_center;
      default:
        return Icons.restaurant;
    }
  }

  List<Map<String, dynamic>> _entriesForCategory(
    List<Map<String, dynamic>> entries,
    String category,
  ) {
    if (category == 'Άσκηση') {
      return entries.where((entry) => entry['isExercise'] == true).toList();
    }

    return entries.where((entry) {
      return entry['isExercise'] != true && entry['category'] == category;
    }).toList();
  }

  int _categoryCalories(List<Map<String, dynamic>> entries) {
    return entries.fold(0, (total, entry) => total + _asInt(entry['calories']));
  }

  double _calorieProgress(int netCalories, int targetCalories) {
    if (targetCalories <= 0) return 0;
    return (netCalories / targetCalories).clamp(0.0, 1.25);
  }

  Color _goalColor(int netCalories, int targetCalories) {
    if (targetCalories <= 0) return slateGrey;
    final ratio = netCalories / targetCalories;
    if (ratio >= 1.05) return Colors.redAccent;
    if (ratio >= 0.85) return Colors.orangeAccent;
    return sageGreen;
  }

  String _goalStatus(int netCalories, int targetCalories) {
    if (targetCalories <= 0) return 'Δεν έχει οριστεί θερμιδικός στόχος';
    final remaining = targetCalories - netCalories;
    final ratio = netCalories / targetCalories;

    if (ratio >= 1.05) {
      return 'Ξεπέρασες τον στόχο κατά ${remaining.abs()} kcal';
    }
    if (remaining <= 0) return 'Έφτασες τον σημερινό στόχο';
    if (ratio >= 0.85) return 'Πλησιάζεις, απομένουν $remaining kcal';
    return 'Απομένουν $remaining kcal για τον στόχο';
  }

  String _goalMessage(int netCalories, int targetCalories) {
    if (targetCalories <= 0) {
      return 'Όρισε στόχους για να βλέπεις την καθημερινή σου πορεία.';
    }

    final ratio = netCalories / targetCalories;
    if (ratio >= 1.05) {
      return 'Μια μέρα δεν χαλάει την προσπάθεια. Συνέχισε με ηρεμία και επίγνωση.';
    }
    if (ratio >= 0.95) {
      return 'Είσαι ακριβώς εκεί που πρέπει. Πολύ δυνατή συνέπεια σήμερα.';
    }
    if (ratio >= 0.85) {
      return 'Είσαι πολύ κοντά. Μικρές σωστές επιλογές κάνουν τη διαφορά.';
    }
    if (ratio >= 0.5) {
      return 'Ωραία πορεία μέχρι τώρα. Κράτα ρυθμό και άκου το σώμα σου.';
    }
    return 'Η μέρα χτίζεται βήμα βήμα. Ξεκίνα απλά και με πρόθεση.';
  }

  bool _isToday() {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
  }

  Future<void> _pickDate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final DateTime? picked = await Navigator.push<DateTime>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => _CalendarOverviewScreen(
          userId: user.uid,
          initialDate: _selectedDate,
          sageGreen: sageGreen,
          slateGrey: slateGrey,
        ),
      ),
    );

    if (!mounted) return;

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _deleteEntry(Map<String, dynamic> entry) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('diary')
        .doc(_dateString)
        .update({
          'entries': FieldValue.arrayRemove([entry]),
        });
  }

  Future<void> _deletePlannedExercise(String planId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('my_plan')
        .doc(planId)
        .delete();
  }

  Future<bool> _confirmDeletePlannedExercise(Map<String, dynamic> entry) async {
    final planId = entry['planId']?.toString() ?? '';
    if (planId.isEmpty) return false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Διαγραφή από το πλάνο'),
        content: Text(
          'Θέλεις να διαγραφεί η άσκηση "${entry['name']}" από το πλάνο σου;',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ΑΚΥΡΩΣΗ'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ΔΙΑΓΡΑΦΗ'),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    await _deletePlannedExercise(planId);

    if (!mounted) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Η άσκηση διαγράφηκε από το πλάνο.'),
        backgroundColor: Colors.redAccent,
      ),
    );

    return true;
  }

  Future<void> _confirmPlannedExercise(Map<String, dynamic> entry) async {
    if (!_isToday()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Επιβεβαίωση άσκησης'),
        content: Text('Έγινε όντως η άσκηση "${entry['name']}" σήμερα;'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ΟΧΙ'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: sageGreen),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ΝΑΙ, ΚΑΤΑΓΡΑΦΗ'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('diary')
        .doc(_dateString)
        .set({
          'entries': FieldValue.arrayUnion([
            {
              'name': entry['name'],
              'category': 'Άσκηση',
              'isExercise': true,
              'calories': _asInt(entry['calories']),
              'quantity': _asInt(entry['quantity']),
              'unit': 'λεπτά',
              'loggedAt': Timestamp.now(),
              'imageUrl': entry['imageUrl'] ?? '',
              'sourcePlanId': entry['planId'],
            },
          ]),
        }, SetOptions(merge: true));

    final planId = entry['planId']?.toString() ?? '';
    if (planId.isNotEmpty) {
      final update = <String, dynamic>{
        'completedDates': FieldValue.arrayUnion([_dateString]),
      };
      if (entry['recurrenceType'] == 'once') {
        update['status'] = 'Ολοκληρώθηκε';
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('my_plan')
          .doc(planId)
          .update(update);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Η άσκηση επιβεβαιώθηκε και καταγράφηκε!'),
        backgroundColor: sageGreen,
      ),
    );
  }

  void _openMealSelection(String category) {
    if (category == 'Άσκηση') {
      _openFitnessPrograms();
      return;
    }

    if (_isFutureDate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Οι καταγραφές γίνονται μόνο για σήμερα ή παρελθόν.'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MealSelectionScreen(
          category: category,
          dateString: _dateString,
          isExercise: category == 'Άσκηση',
        ),
      ),
    );
  }

  void _openFitnessPrograms() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FitnessProgramsScreen(
          viewAll: false,
          calendarDateString: _dateString,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _plannedExerciseList(
    List<QueryDocumentSnapshot> docs,
  ) {
    return docs
        .where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final completedDates = List<String>.from(
            data['completedDates'] ?? [],
          );
          if (completedDates.contains(_dateString)) return false;

          final recurrenceType = data['recurrenceType'] ?? 'once';
          final plannedDateString = data['plannedDateString']?.toString();
          final plannedDate = DateTime.tryParse(plannedDateString ?? '');
          if (plannedDate == null) return false;

          final plannedDay = DateTime(
            plannedDate.year,
            plannedDate.month,
            plannedDate.day,
          );

          if (_selectedDay.isBefore(plannedDay)) return false;
          if (recurrenceType == 'daily') return true;
          if (recurrenceType == 'weekly') {
            return _selectedDay.weekday == _asInt(data['recurrenceWeekday']);
          }

          return plannedDateString == _dateString;
        })
        .map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'planId': doc.id,
            'name':
                data['programName'] ??
                data['name'] ??
                'Προγραμματισμένη άσκηση',
            'category': 'Άσκηση',
            'isExercise': true,
            'isPlannedExercise': true,
            'calories': data['expectedCalories'] ?? 0,
            'quantity': data['durationMinutes'] ?? 0,
            'unit': 'λεπτά',
            'status': data['status'] ?? 'Προγραμματισμένο',
            'recurrenceType': data['recurrenceType'] ?? 'once',
            'imageUrl': data['imageUrl'] ?? '',
          };
        })
        .toList();
  }

  void _toggleCategory(String category) {
    setState(() {
      if (_expandedCategories.contains(category)) {
        _expandedCategories.remove(category);
      } else {
        _expandedCategories.add(category);
      }
    });
  }

  Future<void> _showManageMealSheet(
    String category,
    List<Map<String, dynamic>> entries,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        final mealEntries = List<Map<String, dynamic>>.from(entries);

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Icon(_categoryIcon(category), color: sageGreen),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Επεξεργασία $category',
                            style: TextStyle(
                              color: slateGrey,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Προσθήκη',
                          icon: const Icon(Icons.add_circle_outline),
                          color: sageGreen,
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _openMealSelection(category);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (mealEntries.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Center(
                          child: Text(
                            category == 'Άσκηση'
                                ? 'Δεν έχει καταχωρηθεί άσκηση.'
                                : 'Δεν υπάρχουν καταγραφές σε αυτό το γεύμα.',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: mealEntries.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final entry = mealEntries[index];
                            return _buildManageEntryTile(
                              entry,
                              onDelete: () async {
                                var wasDeleted = true;
                                if (entry['isPlannedExercise'] == true) {
                                  wasDeleted =
                                      await _confirmDeletePlannedExercise(
                                        entry,
                                      );
                                } else {
                                  await _deleteEntry(entry);
                                }
                                if (wasDeleted) {
                                  setSheetState(
                                    () => mealEntries.removeAt(index),
                                  );
                                }
                              },
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: sageGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _openMealSelection(category);
                        },
                        icon: const Icon(Icons.add),
                        label: Text(
                          category == 'Άσκηση'
                              ? 'ΠΡΟΣΘΗΚΗ ΑΣΚΗΣΗΣ'
                              : 'ΠΡΟΣΘΗΚΗ ΚΑΤΑΓΡΑΦΗΣ',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCategorySelection() {
    if (_isFutureDate) {
      _openFitnessPrograms();
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Προσθήκη στο Ημερολόγιο',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: slateGrey,
              ),
            ),
            const SizedBox(height: 15),
            _buildCategoryTile(sheetContext, 'Πρωινό', Icons.breakfast_dining),
            _buildCategoryTile(sheetContext, 'Μεσημεριανό', Icons.lunch_dining),
            _buildCategoryTile(sheetContext, 'Βραδινό', Icons.dinner_dining),
            _buildCategoryTile(sheetContext, 'Σνακ', Icons.apple),
            const Divider(),
            _buildCategoryTile(
              sheetContext,
              'Άσκηση',
              Icons.fitness_center,
              isExercise: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTile(
    BuildContext sheetContext,
    String title,
    IconData icon, {
    bool isExercise = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: sageGreen),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      onTap: () {
        Navigator.pop(sheetContext);
        if (isExercise) {
          _openFitnessPrograms();
        } else {
          _openMealSelection(title);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Το Πλάνο Μου'),
        backgroundColor: Colors.white,
        foregroundColor: slateGrey,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Ανασκόπηση & Πρόοδος',
            icon: const Icon(Icons.analytics_outlined, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProgressScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Προβολή ημερολογίου',
            icon: const Icon(Icons.calendar_month),
            onPressed: _pickDate,
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('Παρακαλώ συνδεθείτε.'))
          : Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 12.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.chevron_left,
                          size: 30,
                          color: slateGrey,
                        ),
                        onPressed: () => _changeDate(-1),
                      ),
                      GestureDetector(
                        onTap: _pickDate,
                        child: Column(
                          children: [
                            Text(
                              _isToday() ? 'Σήμερα' : _displayDate,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: sageGreen,
                              ),
                            ),
                            if (!_isToday())
                              Text(
                                'Σήμερα είναι ${DateFormat('d/M').format(DateTime.now())}',
                                style: TextStyle(
                                  color: slateGrey,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.chevron_right,
                          size: 30,
                          color: slateGrey,
                        ),
                        onPressed: () => _changeDate(1),
                      ),
                    ],
                  ),
                ),

                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('diary')
                      .doc(_dateString)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Expanded(
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    Map<String, dynamic> data =
                        snapshot.data!.data() as Map<String, dynamic>? ?? {};
                    final entries = _entryList(data['entries']);

                    int consumedCals = 0;
                    int burnedCals = 0;
                    int totalProtein = 0;
                    int totalCarbs = 0;
                    int totalFats = 0;

                    for (final e in entries) {
                      if (e['isExercise'] == true) {
                        burnedCals += _asInt(e['calories']);
                      } else {
                        consumedCals += _asInt(e['calories']);
                        totalProtein += _asInt(e['protein']);
                        totalCarbs += _asInt(e['carbs']);
                        totalFats += _asInt(e['fats']);
                      }
                    }

                    int netCalories = consumedCals - burnedCals;

                    return Expanded(
                      child: Column(
                        children: [
                          // --- ΚΑΡΤΑ ΣΥΝΟΨΗΣ ---
                          Container(
                            margin: const EdgeInsets.all(16),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildMacroColumn(
                                      'Φαγητό',
                                      '$consumedCals',
                                      Colors.orange,
                                    ),
                                    const Text(
                                      '-',
                                      style: TextStyle(
                                        fontSize: 24,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    _buildMacroColumn(
                                      'Άσκηση',
                                      '$burnedCals',
                                      Colors.redAccent,
                                    ),
                                    const Text(
                                      '=',
                                      style: TextStyle(
                                        fontSize: 24,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    _buildMacroColumn(
                                      'Καθαρές',
                                      '$netCalories',
                                      sageGreen,
                                      isLarge: true,
                                    ),
                                  ],
                                ),
                                const Divider(height: 30),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildSmallMacro(
                                      'Πρωτεΐνη',
                                      '${totalProtein}g',
                                      Colors.red,
                                    ),
                                    _buildSmallMacro(
                                      'Υδατάνθ.',
                                      '${totalCarbs}g',
                                      Colors.blue,
                                    ),
                                    _buildSmallMacro(
                                      'Λιπαρά',
                                      '${totalFats}g',
                                      Colors.amber,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .snapshots(),
                            builder: (context, userSnapshot) {
                              final userData =
                                  userSnapshot.data?.data()
                                      as Map<String, dynamic>?;
                              final targetCalories = _asInt(
                                userData?['targetCalories'],
                              );

                              return _buildCalorieGoalCard(
                                netCalories,
                                targetCalories,
                              );
                            },
                          ),

                          Expanded(
                            child: StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .collection('my_plan')
                                  .snapshots(),
                              builder: (context, planSnapshot) {
                                final plannedExercises = planSnapshot.hasData
                                    ? _plannedExerciseList(
                                        planSnapshot.data!.docs,
                                      )
                                    : <Map<String, dynamic>>[];

                                return ListView(
                                  padding: const EdgeInsets.only(bottom: 80),
                                  children: _mealCategories.map((category) {
                                    final categoryEntries = _entriesForCategory(
                                      entries,
                                      category,
                                    );
                                    final displayEntries = category == 'Άσκηση'
                                        ? [
                                            ...categoryEntries,
                                            ...plannedExercises,
                                          ]
                                        : categoryEntries;

                                    return _buildCategorySection(
                                      category,
                                      displayEntries,
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        elevation: 4,
        backgroundColor: sageGreen,
        onPressed: _showCategorySelection,
        icon: Icon(
          _isFutureDate ? Icons.event_available : Icons.add,
          color: Colors.white,
        ),
        label: Text(
          _isFutureDate ? 'ΠΛΑΝΟ ΑΣΚΗΣΗΣ' : 'ΚΑΤΑΓΡΑΦΗ',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildMacroColumn(
    String title,
    String value,
    Color color, {
    bool isLarge = false,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: isLarge ? 26 : 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: slateGrey,
            fontWeight: isLarge ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildSmallMacro(String title, String value, Color color) {
    return Row(
      children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 4),
        Text(
          '$title: ',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildCalorieGoalCard(int netCalories, int targetCalories) {
    final color = _goalColor(netCalories, targetCalories);
    final progress = _calorieProgress(netCalories, targetCalories);
    final remaining = targetCalories - netCalories;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_circle_outlined, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Θερμιδικός στόχος',
                  style: TextStyle(
                    color: slateGrey,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                targetCalories > 0 ? '$targetCalories kcal' : '-',
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '$netCalories kcal καθαρές',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (targetCalories > 0)
                Text(
                  remaining >= 0
                      ? '$remaining kcal ακόμα'
                      : '+${remaining.abs()} kcal',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _goalStatus(netCalories, targetCalories),
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            _goalMessage(netCalories, targetCalories),
            style: TextStyle(color: Colors.grey.shade700, height: 1.25),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
    String category,
    List<Map<String, dynamic>> entries,
  ) {
    final isExercise = category == 'Άσκηση';
    final calories = _categoryCalories(entries);
    final color = isExercise ? Colors.redAccent : sageGreen;
    final isExpanded = _expandedCategories.contains(category);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _toggleCategory(category),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: color.withValues(alpha: 0.12),
                    child: Icon(
                      _categoryIcon(category),
                      color: color,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category,
                          style: TextStyle(
                            color: slateGrey,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entries.length == 1
                              ? '1 καταγραφή'
                              : '${entries.length} καταγραφές',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${isExercise ? '-' : '+'}$calories kcal',
                    style: TextStyle(
                      color: entries.isEmpty ? Colors.grey : color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    tooltip: _isFutureDate && category == 'Άσκηση'
                        ? 'Επεξεργασία πλάνου'
                        : 'Επεξεργασία γεύματος',
                    icon: Icon(
                      _isFutureDate && category == 'Άσκηση'
                          ? Icons.event_available
                          : Icons.edit_outlined,
                      color: _isFutureDate && category != 'Άσκηση'
                          ? Colors.grey.shade300
                          : slateGrey,
                    ),
                    onPressed: _isFutureDate && category != 'Άσκηση'
                        ? null
                        : () {
                            _showManageMealSheet(category, entries);
                          },
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: slateGrey,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded && entries.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  isExercise
                      ? 'Δεν έχει καταχωρηθεί άσκηση.'
                      : 'Δεν έχουν καταχωρηθεί φαγητά.',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            )
          else if (isExpanded)
            ...entries.asMap().entries.map((indexedEntry) {
              final entry = indexedEntry.value;
              return _buildEntryTile(entry, indexedEntry.key);
            }),
        ],
      ),
    );
  }

  Widget _buildEntryTile(Map<String, dynamic> entry, int index) {
    bool isEx = entry['isExercise'] == true;
    bool isPlanned = entry['isPlannedExercise'] == true;
    String imageUrl = (entry['imageUrl'] ?? '').toString();
    final calories = _asInt(entry['calories']);

    return ListTile(
      key: ValueKey(_entryKey(entry, index)),
      onTap: isPlanned && _isToday()
          ? () => _confirmPlannedExercise(entry)
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: imageUrl.isNotEmpty
          ? CircleAvatar(
              radius: 23,
              backgroundImage: NetworkImage(imageUrl),
              backgroundColor: Colors.transparent,
            )
          : CircleAvatar(
              radius: 23,
              backgroundColor: isEx
                  ? Colors.redAccent.withValues(alpha: 0.1)
                  : sageGreen.withValues(alpha: 0.2),
              child: Icon(
                isEx ? Icons.local_fire_department : Icons.restaurant,
                color: isEx ? Colors.redAccent : sageGreen,
              ),
            ),
      title: Text(
        (entry['name'] ?? 'Άγνωστη καταγραφή').toString(),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        isPlanned && _isToday()
            ? '${_entrySubtitle(entry)} • πάτησε για επιβεβαίωση'
            : _entrySubtitle(entry),
        style: TextStyle(color: slateGrey),
      ),
      trailing: SizedBox(
        width: isPlanned ? 104 : 58,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isPlanned ? '~$calories' : '${isEx ? '-' : '+'}$calories',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isEx ? Colors.redAccent : sageGreen,
                  ),
                ),
                const Text(
                  'kcal',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            if (isPlanned)
              IconButton(
                tooltip: 'Διαγραφή από το πλάνο',
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => _confirmDeletePlannedExercise(entry),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildManageEntryTile(
    Map<String, dynamic> entry, {
    required VoidCallback onDelete,
  }) {
    final isEx = entry['isExercise'] == true;
    final isPlanned = entry['isPlannedExercise'] == true;
    final imageUrl = (entry['imageUrl'] ?? '').toString();
    final calories = _asInt(entry['calories']);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: imageUrl.isNotEmpty
          ? CircleAvatar(
              radius: 22,
              backgroundImage: NetworkImage(imageUrl),
              backgroundColor: Colors.transparent,
            )
          : CircleAvatar(
              radius: 22,
              backgroundColor: isEx
                  ? Colors.redAccent.withValues(alpha: 0.1)
                  : sageGreen.withValues(alpha: 0.2),
              child: Icon(
                isEx ? Icons.local_fire_department : Icons.restaurant,
                color: isEx ? Colors.redAccent : sageGreen,
              ),
            ),
      title: Text(
        (entry['name'] ?? 'Άγνωστη καταγραφή').toString(),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(_entrySubtitle(entry), style: TextStyle(color: slateGrey)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isPlanned ? '~$calories kcal' : '${isEx ? '-' : '+'}$calories kcal',
            style: TextStyle(
              color: isEx ? Colors.redAccent : sageGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            tooltip: 'Διαγραφή',
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _CalendarOverviewScreen extends StatefulWidget {
  final String userId;
  final DateTime initialDate;
  final Color sageGreen;
  final Color slateGrey;

  const _CalendarOverviewScreen({
    required this.userId,
    required this.initialDate,
    required this.sageGreen,
    required this.slateGrey,
  });

  @override
  State<_CalendarOverviewScreen> createState() =>
      _CalendarOverviewScreenState();
}

class _CalendarOverviewScreenState extends State<_CalendarOverviewScreen> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(widget.initialDate.year, widget.initialDate.month);
  }

  String _dateString(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  int _asInt(dynamic value) {
    if (value is num) return value.round();
    return num.tryParse(value?.toString() ?? '')?.round() ?? 0;
  }

  bool _sameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  bool _hasPlannedExercise(DateTime date, List<QueryDocumentSnapshot> docs) {
    final selectedDay = DateTime(date.year, date.month, date.day);
    final dateString = _dateString(date);

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final completedDates = List<String>.from(data['completedDates'] ?? []);
      if (completedDates.contains(dateString)) continue;

      final plannedDateString = data['plannedDateString']?.toString();
      final plannedDate = DateTime.tryParse(plannedDateString ?? '');
      if (plannedDate == null) continue;

      final plannedDay = DateTime(
        plannedDate.year,
        plannedDate.month,
        plannedDate.day,
      );
      if (selectedDay.isBefore(plannedDay)) continue;

      final recurrenceType = data['recurrenceType'] ?? 'once';
      if (recurrenceType == 'daily') return true;
      if (recurrenceType == 'weekly' &&
          selectedDay.weekday == _asInt(data['recurrenceWeekday'])) {
        return true;
      }
      if (plannedDateString == dateString) return true;
    }

    return false;
  }

  Map<String, Set<String>> _diaryMarkers(List<QueryDocumentSnapshot> docs) {
    final markers = <String, Set<String>>{
      'Πρωινό': <String>{},
      'Μεσημεριανό': <String>{},
      'Βραδινό': <String>{},
      'Σνακ': <String>{},
      'Άσκηση': <String>{},
      'Άλλο': <String>{},
    };

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>?;
      final entries = data?['entries'];
      if (entries is! List) continue;

      for (final entry in entries.whereType<Map>()) {
        if (entry['isExercise'] == true) {
          markers['Άσκηση']!.add(doc.id);
        } else {
          final category = entry['category']?.toString() ?? '';
          final markerKey = markers.containsKey(category) ? category : 'Άλλο';
          markers[markerKey]!.add(doc.id);
        }
      }
    }

    return markers;
  }

  IconData _mealCategoryIcon(String category) {
    switch (category) {
      case 'Πρωινό':
        return Icons.breakfast_dining;
      case 'Μεσημεριανό':
        return Icons.lunch_dining;
      case 'Βραδινό':
        return Icons.dinner_dining;
      case 'Σνακ':
        return Icons.apple;
      default:
        return Icons.restaurant;
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + offset,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F5),
      appBar: AppBar(
        title: const Text('Ημερολόγιο'),
        backgroundColor: Colors.white,
        foregroundColor: widget.slateGrey,
        elevation: 0,
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .collection('diary')
              .snapshots(),
          builder: (context, diarySnapshot) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.userId)
                  .collection('my_plan')
                  .snapshots(),
              builder: (context, planSnapshot) {
                if (!diarySnapshot.hasData || !planSnapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(color: widget.sageGreen),
                  );
                }

                final diary = _diaryMarkers(diarySnapshot.data!.docs);
                final planDocs = planSnapshot.data!.docs;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Προηγούμενος μήνας',
                            onPressed: () => _changeMonth(-1),
                            icon: Icon(
                              Icons.chevron_left,
                              color: widget.slateGrey,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              DateFormat(
                                'MMMM yyyy',
                                'el',
                              ).format(_visibleMonth),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: widget.sageGreen,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Επόμενος μήνας',
                            onPressed: () => _changeMonth(1),
                            icon: Icon(
                              Icons.chevron_right,
                              color: widget.slateGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          _WeekdayLabel('Δ'),
                          _WeekdayLabel('Τ'),
                          _WeekdayLabel('Τ'),
                          _WeekdayLabel('Π'),
                          _WeekdayLabel('Π'),
                          _WeekdayLabel('Σ'),
                          _WeekdayLabel('Κ'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildMonthGrid(diary, planDocs),
                      ),
                    ),
                    _buildLegend(),
                    const SizedBox(height: 12),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildMonthGrid(
    Map<String, Set<String>> diaryMarkers,
    List<QueryDocumentSnapshot> planDocs,
  ) {
    final firstDay = DateTime(_visibleMonth.year, _visibleMonth.month);
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    final leadingBlanks = firstDay.weekday - 1;
    final itemCount = leadingBlanks + daysInMonth;

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.82,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index < leadingBlanks) return const SizedBox.shrink();

        final day = index - leadingBlanks + 1;
        final date = DateTime(_visibleMonth.year, _visibleMonth.month, day);
        final dateString = _dateString(date);
        final mealCategories = ['Πρωινό', 'Μεσημεριανό', 'Βραδινό', 'Σνακ']
            .where((category) {
              return diaryMarkers[category]?.contains(dateString) == true;
            })
            .toList();
        final hasOtherMeal = diaryMarkers['Άλλο']?.contains(dateString) == true;
        final hasLoggedExercise =
            diaryMarkers['Άσκηση']?.contains(dateString) == true;
        final hasPlan = _hasPlannedExercise(date, planDocs);
        final isSelected = _sameDay(date, widget.initialDate);
        final isToday = _sameDay(date, DateTime.now());

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.pop(context, date),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? widget.sageGreen.withValues(alpha: 0.24)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected || isToday
                    ? widget.sageGreen
                    : Colors.black.withValues(alpha: 0.05),
                width: isSelected || isToday ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? widget.sageGreen : widget.slateGrey,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 2,
                  runSpacing: 2,
                  alignment: WrapAlignment.center,
                  children: [
                    ...mealCategories.map(
                      (category) => _MarkerIcon(
                        icon: _mealCategoryIcon(category),
                        color: widget.sageGreen,
                      ),
                    ),
                    if (hasOtherMeal)
                      _MarkerIcon(
                        icon: Icons.restaurant,
                        color: widget.sageGreen,
                      ),
                    if (hasLoggedExercise)
                      const _MarkerIcon(
                        icon: Icons.local_fire_department,
                        color: Colors.redAccent,
                      ),
                    if (hasPlan)
                      const _MarkerIcon(
                        icon: Icons.event_available,
                        color: Colors.blueAccent,
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLegend() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          _LegendItem(
            icon: Icons.breakfast_dining,
            color: widget.sageGreen,
            label: 'Πρωινό',
          ),
          _LegendItem(
            icon: Icons.lunch_dining,
            color: widget.sageGreen,
            label: 'Μεσημ.',
          ),
          _LegendItem(
            icon: Icons.dinner_dining,
            color: widget.sageGreen,
            label: 'Βραδινό',
          ),
          _LegendItem(
            icon: Icons.apple,
            color: widget.sageGreen,
            label: 'Σνακ',
          ),
          const _LegendItem(
            icon: Icons.local_fire_department,
            color: Colors.redAccent,
            label: 'Άσκηση',
          ),
          const _LegendItem(
            icon: Icons.event_available,
            color: Colors.blueAccent,
            label: 'Πλάνο',
          ),
        ],
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String label;

  const _WeekdayLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.grey,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _MarkerIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _MarkerIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 12),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _LegendItem({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MarkerIcon(icon: icon, color: color),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
