import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/calculator_controller.dart';
import 'screens/calculator_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ScientificCalculatorApp());
}

class ScientificCalculatorApp extends StatelessWidget {
  const ScientificCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CalculatorController>(
      create: (_) => CalculatorController()..load(),
      child: MaterialApp(
        title: 'Scientific Calculator',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const CalculatorScreen(),
      ),
    );
  }
}
