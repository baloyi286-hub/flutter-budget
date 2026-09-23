import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'src/data/budget_repository.dart';
import 'src/domain/budget_service.dart';
import 'src/presentation/budget_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final service = BudgetService(LocalBudgetRepository(prefs));
  await service.initialize();
  runApp(BudgetApp(service: service));
}

class BudgetApp extends StatelessWidget {
  const BudgetApp({super.key, required this.service});
  final BudgetService service;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Budget',
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF4F7FA),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1976D2),
        primary: const Color(0xFF1976D2),
        secondary: const Color(0xFFFF654E),
        surface: Colors.white,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFF654E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF7F9FC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    home: BudgetPage(service: service),
  );
}
