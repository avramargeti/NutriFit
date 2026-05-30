import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'goals_screen.dart';
import 'auth_screen.dart';
import 'admin_add_ingredient_screen.dart';
import 'ingredients_list_screen.dart';
import 'add_recipe_screen.dart';
import 'recipes_list_screen.dart';
import 'cooking_book_screen.dart';
import 'fitness_programs_screen.dart';
import 'super_market_list_screen.dart';
import 'fitness_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String username = "User";
  bool isLoadingUsername = true;

  final Color sageGreen = const Color(0xFFA8B3A0);
  final Color slateGrey = const Color(0xFF8C9DA6);

  @override
  void initState() {
    super.initState();
    _fetchUsername();
  }

  void _showComingSoon(String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Η λειτουργία "$featureName" θα είναι σύντομα διαθέσιμη! 🚀'),
        backgroundColor: sageGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _fetchUsername() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (mounted) {
          setState(() {
            if (doc.exists && doc.data() != null) {
              username = (doc.data() as Map<String, dynamic>)['username'] ?? "User";
            }
            isLoadingUsername = false;
          });
        }
      } catch (e) {
        debugPrint("Σφάλμα: $e");
        if (mounted) setState(() => isLoadingUsername = false);
      }
    } else {
      if (mounted) setState(() => isLoadingUsername = false);
    }
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      debugPrint("Σφάλμα αποσύνδεσης: $e");
    }
  }

  // Λειτουργία για το μενού των συνταγών
  void _showRecipesModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Συνταγές',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: slateGrey,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: sageGreen,
                child: const Icon(Icons.search, color: Colors.white),
              ),
              title: const Text('Αναζήτηση Συνταγών'),
              onTap: () {
                Navigator.pop(context); 
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RecipesListScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: slateGrey,
                child: const Icon(Icons.add, color: Colors.white),
              ),
              title: const Text('Δημιουργία Νέας Συνταγής'),
              onTap: () {
                Navigator.pop(context); 
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddRecipeScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final List<String> adminEmails = [
      'avramargeti@gmail.com',
      'bokosdimitris@gmail.com',
      'adonopoulouifigeneia@icloud.com'
    ];
    final isAdmin =
        currentUser != null && adminEmails.contains(currentUser.email);

    return Scaffold(
      appBar: AppBar(
        title: const Text('NutriFit'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book),
            tooltip: 'My Cooking Book',
            onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CookingBookScreen()),
                );
              },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Αποσύνδεση',
            onPressed: _logout,
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(Icons.person, size: 60, color: sageGreen),
            ),
            const SizedBox(height: 15),
            isLoadingUsername
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: sageGreen,
                    ),
                  )
                : Text(
                    'Καλώς ήρθες, $username!',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: slateGrey,
                    ),
                  ),
            const Text(
              'Η υγεία σου σε πρώτο πλάνο',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 40),
            _buildDashboardButton(
              context,
              title: 'ΟΙ ΣΤΟΧΟΙ ΜΟΥ',
              icon: Icons.track_changes,
              color: sageGreen,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const GoalsScreen()),
                );
              },
            ),
            const SizedBox(height: 20),
            _buildDashboardButton(
              context,
              title: 'ΒΙΒΛΙΟΘΗΚΗ ΥΛΙΚΩΝ',
              icon: Icons.inventory_2_outlined,
              color: slateGrey,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const IngredientsListScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            _buildDashboardButton(
              context,
              title: 'ΟΙ ΣΥΝΤΑΓΕΣ ΜΟΥ',
              icon: Icons.auto_stories,
              color: sageGreen,
              onTap: () => _showRecipesModal(context),
            ),
            const SizedBox(height: 20),

            // --- ΝΕΟ ΚΟΥΜΠΙ: ΛΙΣΤΑ SUPER MARKET ---
            _buildDashboardButton(
              context,
              title: 'ΛΙΣΤΑ SUPER MARKET',
              icon: Icons.shopping_cart_outlined,
              color: slateGrey,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SuperMarketListScreen()),
                );
              },
            ),
            const SizedBox(height: 20),
            
            _buildDashboardButton(
              context,
              title: 'FITNESS',
              icon: Icons.fitness_center,
              color: sageGreen,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FitnessScreen()),
                );
              }
            ),
            
            const SizedBox(height: 20),
            _buildDashboardButton(
              context,
              title: 'ΤΟ ΠΛΑΝΟ ΜΟΥ',
              icon: Icons.calendar_today,
              color: slateGrey,
              isOutlined: true,
              onTap: () => _showComingSoon("Το Πλάνο Μου"),
            ),

            if (isAdmin) ...[
              const SizedBox(height: 50),
              const Divider(thickness: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.admin_panel_settings, color: slateGrey),
                  const SizedBox(width: 8),
                  Text(
                    'ADMIN AREA',
                    style: TextStyle(
                      color: slateGrey,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: slateGrey,
                  minimumSize: const Size(double.infinity, 50),
                  side: BorderSide(color: slateGrey.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminAddIngredientScreen(),
                    ),
                  );
                },
                child: const Text('ΠΡΟΣΘΗΚΗ ΝΕΟΥ ΥΛΙΚΟΥ'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: slateGrey,
                  minimumSize: const Size(double.infinity, 50),
                  side: BorderSide(color: slateGrey.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FitnessProgramsScreen(viewAll: true, isAdmin: true),
                    ),
                  );
                },
                child: const Text('ΔΙΑΧΕΙΡΙΣΗ ΠΡΟΓΡΑΜΜΑΤΩΝ FITNESS'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isOutlined = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: isOutlined
          ? OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              icon: Icon(icon),
              onPressed: onTap,
              label: Text(
                title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            )
          : ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              icon: Icon(icon, size: 26),
              onPressed: onTap,
              label: Text(
                title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
    );
  }
}