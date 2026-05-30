import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'meal_selection_screen.dart';

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
      DateTime newDate = _selectedDate.add(Duration(days: days));
      DateTime now = DateTime.now();
      DateTime today = DateTime(now.year, now.month, now.day);
      DateTime targetDate = DateTime(newDate.year, newDate.month, newDate.day);

      if (!targetDate.isAfter(today)) {
        _selectedDate = newDate;
      }
    });
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(
          context,
        ).copyWith(colorScheme: ColorScheme.light(primary: sageGreen)),
        child: child!,
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

  void _openMealSelection(String category) {
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
                                await _deleteEntry(entry);
                                setSheetState(
                                  () => mealEntries.removeAt(index),
                                );
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
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MealSelectionScreen(
              category: title,
              dateString: _dateString,
              isExercise: isExercise,
            ),
          ),
        );
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
                          color: _isToday() ? Colors.grey.shade300 : slateGrey,
                        ),
                        onPressed: _isToday() ? null : () => _changeDate(1),
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
                            child: ListView(
                              padding: const EdgeInsets.only(bottom: 80),
                              children: _mealCategories.map((category) {
                                final categoryEntries = _entriesForCategory(
                                  entries,
                                  category,
                                );
                                return _buildCategorySection(
                                  category,
                                  categoryEntries,
                                );
                              }).toList(),
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
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'ΚΑΤΑΓΡΑΦΗ',
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
                    tooltip: 'Επεξεργασία γεύματος',
                    icon: Icon(Icons.edit_outlined, color: slateGrey),
                    onPressed: () => _showManageMealSheet(category, entries),
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
    String imageUrl = (entry['imageUrl'] ?? '').toString();
    final calories = _asInt(entry['calories']);

    return ListTile(
      key: ValueKey(_entryKey(entry, index)),
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
      subtitle: Text(_entrySubtitle(entry), style: TextStyle(color: slateGrey)),
      trailing: SizedBox(
        width: 58,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isEx ? '-' : '+'}$calories',
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
            '${isEx ? '-' : '+'}$calories kcal',
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
