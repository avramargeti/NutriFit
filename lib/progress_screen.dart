import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'progress_manager.dart';
import 'progress_history_screen.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final Color sageGreen = const Color(0xFFA8B3A0);
  final Color slateGrey = const Color(0xFF8C9DA6);

  late ProgressManager _progressManager;
  Map<String, dynamic>? _reviewData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _progressManager = ProgressManager(userId: user.uid);
      _loadReview();
    }
  }

  Future<void> _loadReview() async {
    try {
      final data = await _progressManager.generateWeeklyReview();
      if (mounted) {
        setState(() {
          _reviewData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Σφάλμα: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _acceptAdjustment(int newTarget) async {
    setState(() => _isLoading = true);
    await _progressManager.updateGoals(newTarget);
    await _progressManager.saveReportToHistory(_reviewData!);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Το πλάνο σου προσαρμόστηκε επιτυχώς!'), backgroundColor: sageGreen),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _rejectAdjustmentAndKeepPlan() async {
    setState(() => _isLoading = true);
    await _progressManager.saveReportToHistory(_reviewData!);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Το πλάνο σου διατηρήθηκε ως είχε.')),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _finishReview() async {
    setState(() => _isLoading = true);
    await _progressManager.saveReportToHistory(_reviewData!);
    
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F8F5),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: sageGreen),
              const SizedBox(height: 16),
              Text('Υπολογισμός Εβδομαδιαίας Προόδου...', style: TextStyle(color: slateGrey)),
            ],
          ),
        ),
      );
    }

    if (_reviewData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Σφάλμα'), backgroundColor: Colors.white, foregroundColor: slateGrey),
        body: const Center(child: Text('Δεν βρέθηκαν δεδομένα.')),
      );
    }

    String status = _reviewData!['status'];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F5),
      appBar: AppBar(
        title: const Text('Ανασκόπηση Εβδομάδας'),
        backgroundColor: Colors.white,
        foregroundColor: slateGrey,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Πλήρες Ιστορικό',
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProgressHistoryScreen()),
              );
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDaysLoggedCard(_reviewData!['daysLogged']),
            const SizedBox(height: 20),

            if (status == 'insufficient_data')
              _buildInsufficientDataUI()
            else if (status == 'mid_week_review')
              _buildMidWeekUI()
            else if (status == 'goal_met')
              _buildGoalMetUI()
            else if (status == 'goal_not_met')
              _buildGoalNotMetUI(),
          ],
        ),
      ),
    );
  }

  Widget _buildDaysLoggedCard(int days) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: sageGreen.withValues(alpha: 0.15),
            child: Icon(Icons.calendar_month, color: sageGreen, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ημέρες Καταγραφής', style: TextStyle(color: slateGrey, fontSize: 14)),
                Text('$days / 7', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsufficientDataUI() {
    return Column(
      children: [
        Icon(Icons.data_usage, size: 80, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        Text('Χρειάζονται περισσότερα δεδομένα', 
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: slateGrey)),
        const SizedBox(height: 12),
        Text(_reviewData!['message'], 
          textAlign: TextAlign.center, 
          style: const TextStyle(fontSize: 16, height: 1.5)),
        const SizedBox(height: 30),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: slateGrey, minimumSize: const Size(double.infinity, 50)),
          onPressed: () => Navigator.pop(context),
          child: const Text('ΕΠΙΣΤΡΟΦΗ', style: TextStyle(color: Colors.white)),
        )
      ],
    );
  }

  Widget _buildMidWeekUI() {
    double ratio = _reviewData!['targetDailyCalories'] > 0 
        ? _reviewData!['avgDailyCalories'] / _reviewData!['targetDailyCalories'] 
        : 0;
    bool isOverTarget = ratio > 1.10;

    Color themeColor = isOverTarget ? Colors.orange.shade700 : Colors.blueAccent.shade400;
    Color bgColor = isOverTarget ? Colors.orange.withValues(alpha: 0.1) : Colors.blueAccent.withValues(alpha: 0.05);

    return Column(
      children: [
        _buildStatsRow(),
        const SizedBox(height: 20),
        
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Icon(
                isOverTarget ? Icons.trending_up : Icons.query_stats, 
                size: 60, 
                color: themeColor
              ),
              const SizedBox(height: 16),
              Text(
                'Ενδιάμεση Πορεία', 
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isOverTarget ? themeColor : slateGrey)
              ),
              const SizedBox(height: 12),
              Text(
                _reviewData!['message'], 
                textAlign: TextAlign.center, 
                style: const TextStyle(fontSize: 15, height: 1.5)
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: slateGrey, minimumSize: const Size(double.infinity, 50)),
          onPressed: () => Navigator.pop(context), 
          child: const Text('ΚΛΕΙΣΙΜΟ ΑΝΑΦΟΡΑΣ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ProgressHistoryScreen()));
          },
          icon: Icon(Icons.history, size: 18, color: slateGrey),
          label: Text('Πλήρες Ιστορικό', style: TextStyle(color: slateGrey, decoration: TextDecoration.underline)),
        )
      ],
    );
  }

  Widget _buildGoalMetUI() {
    return Column(
      children: [
        _buildStatsRow(),
        const SizedBox(height: 20),
        
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: sageGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Icon(Icons.emoji_events, size: 60, color: Colors.amber.shade600),
              const SizedBox(height: 12),
              Text('Τα πήγες περίφημα!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: sageGreen)),
              const SizedBox(height: 8),
              Text(_reviewData!['message'], textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.4)),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Text('ΝΕΟ ΕΠΙΤΕΥΓΜΑ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Chip(
                avatar: const Icon(Icons.star, color: Colors.white, size: 18),
                label: Text(_reviewData!['achievement'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                backgroundColor: Colors.amber.shade600,
              )
            ],
          ),
        ),
        const SizedBox(height: 30),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: sageGreen, minimumSize: const Size(double.infinity, 50)),
          onPressed: _finishReview,
          child: const Text('ΟΛΟΚΛΗΡΩΣΗ ΑΝΑΣΚΟΠΗΣΗΣ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ProgressHistoryScreen()));
          },
          icon: Icon(Icons.history, size: 18, color: slateGrey),
          label: Text('Πλήρες Ιστορικό', style: TextStyle(color: slateGrey, decoration: TextDecoration.underline)),
        )
      ],
    );
  }

  Widget _buildGoalNotMetUI() {
    int proposedCals = _reviewData!['proposedAdjustment'];

    return Column(
      children: [
        _buildStatsRow(),
        const SizedBox(height: 20),
        
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Icon(Icons.trending_up, size: 50, color: Colors.orange.shade700),
              const SizedBox(height: 12),
              Text('Ώρα για μια μικρή προσαρμογή', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
              const SizedBox(height: 8),
              Text(_reviewData!['message'], textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.4)),
              const SizedBox(height: 20),
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${_reviewData!['targetDailyCalories']}', style: const TextStyle(fontSize: 20, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Icon(Icons.arrow_forward, color: Colors.grey)),
                    Text('$proposedCals kcal', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: sageGreen)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: sageGreen, minimumSize: const Size(double.infinity, 50)),
          onPressed: () => _acceptAdjustment(proposedCals),
          child: const Text('ΑΠΟΔΟΧΗ ΠΡΟΤΑΣΗΣ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _rejectAdjustmentAndKeepPlan,
          child: Text('Διατήρηση τρέχοντος πλάνου', style: TextStyle(color: slateGrey, decoration: TextDecoration.underline)),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ProgressHistoryScreen()));
          },
          icon: Icon(Icons.history, size: 18, color: slateGrey),
          label: Text('Πλήρες Ιστορικό', style: TextStyle(color: slateGrey, decoration: TextDecoration.underline)),
        )
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Μέσος Όρος\nΗμέρας', '${_reviewData!['avgDailyCalories']}', Colors.blueAccent)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('Στόχος\nΗμέρας', '${_reviewData!['targetDailyCalories']}', sageGreen)),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: slateGrey)),
        ],
      ),
    );
  }
}