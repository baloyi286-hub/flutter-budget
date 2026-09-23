import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'src/data/budget_repository.dart';
import 'src/domain/budget_service.dart';
import 'src/presentation/budget_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final repository = LocalBudgetRepository(prefs);
  final service = BudgetService(repository);
  await service.initialize();
  runApp(BudgetApp(service: service));
}

class BudgetApp extends StatelessWidget {
  const BudgetApp({super.key, required this.service});
  final BudgetService service;

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF1E1E1E);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Budget',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF007ACC),
          surface: Color(0xFF252526),
        ),
        cardTheme: const CardThemeData(color: Color(0xFF252526)),
        dividerColor: const Color(0xFF3C3C3C),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF2D2D30),
          border: OutlineInputBorder(),
        ),
      ),
      home: BudgetPage(service: service),
    );
  }
}
