import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/calculator_display.dart';
import '../widgets/history_bottom_sheet.dart';
import '../widgets/scientific_keypad.dart';

/// Main screen. Portrait stacks a collapsible scientific grid above the
/// numeric pad; landscape places both side by side.
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  bool _scientificCollapsed = false;

  void _openHistory() => HistoryBottomSheet.show(context);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayStyle,
      child: Scaffold(
        backgroundColor: AppColors.darkPrimaryColor,
        resizeToAvoidBottomInset: false,
        appBar: isLandscape
            ? null
            : AppBar(
                toolbarHeight: 46,
                title: const Text('Scientific Calculator'),
                actions: [
                  IconButton(
                    tooltip: 'History',
                    icon: const Icon(Icons.history),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _openHistory();
                    },
                  ),
                ],
              ),
        body: SafeArea(
          child: ColoredBox(
            color: AppColors.surface,
            child: isLandscape ? _buildLandscape(size) : _buildPortrait(),
          ),
        ),
      ),
    );
  }

  Widget _buildPortrait() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ModeBar(),
        const Expanded(flex: 26, child: CalculatorDisplay()),
        SizedBox(
          height: 40,
          child: MemoryBar(
            collapsed: _scientificCollapsed,
            onToggleCollapsed: () {
              setState(() => _scientificCollapsed = !_scientificCollapsed);
            },
          ),
        ),
        Expanded(
          flex: 74,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scientificHeight =
                  _scientificCollapsed ? 0.0 : constraints.maxHeight * 0.46;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRect(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      height: scientificHeight,
                      child: const ScientificKeypad(),
                    ),
                  ),
                  const Expanded(child: NumericKeypad()),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLandscape(Size size) {
    final displayHeight = (size.height * 0.28).clamp(72.0, 150.0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ModeBar(onHistory: _openHistory),
        SizedBox(height: displayHeight, child: const CalculatorDisplay()),
        const Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 34, child: MemoryBar()),
                    Expanded(child: ScientificKeypad()),
                  ],
                ),
              ),
              Expanded(flex: 5, child: NumericKeypad()),
            ],
          ),
        ),
      ],
    );
  }
}
