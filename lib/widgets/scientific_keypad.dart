import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/calculator_controller.dart';
import '../services/math_engine.dart';
import '../theme/app_colors.dart';
import 'calc_button.dart';

/// Top status / modifier bar: SHIFT, HYP, DEG/RAD/GRAD and the memory flag.
class ModeBar extends StatelessWidget {
  const ModeBar({super.key, this.onHistory});

  /// When non-null a history button is shown at the end of the bar.
  final VoidCallback? onHistory;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CalculatorController>();
    return Material(
      color: AppColors.darkPrimaryColor,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: _buildContent(c),
      ),
    );
  }

  Widget _buildContent(CalculatorController c) {
    final onHistoryTap = onHistory;
    return Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ModeChip(
                    label: 'SHIFT',
                    active: c.isShift,
                    onTap: c.toggleShift,
                  ),
                  _ModeChip(label: 'HYP', active: c.isHyp, onTap: c.toggleHyp),
                  const SizedBox(width: 8),
                  for (final unit in AngleUnit.values)
                    _ModeChip(
                      label: unit.label,
                      active: c.angleUnit == unit,
                      onTap: () {
                        if (c.angleUnit == unit) {
                          c.cycleAngleUnit();
                        } else {
                          c.setAngleUnit(unit);
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
          if (c.hasMemory)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'M',
                style: TextStyle(
                  color: AppColors.textIcons,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (onHistoryTap != null)
            IconButton(
              tooltip: 'History',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.history, color: AppColors.textIcons),
              onPressed: () {
                HapticFeedback.lightImpact();
                onHistoryTap();
              },
            ),
        ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: active ? AppColors.accentColor : Colors.transparent,
        borderRadius: const BorderRadius.all(Radius.circular(6)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              label,
              style: TextStyle(
                color: active ? AppColors.textIcons : AppColors.lightPrimaryColor,
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Memory register row (MC, MR, M+, M-), the S<=>D toggle and, optionally,
/// the control that collapses the scientific grid in portrait.
class MemoryBar extends StatelessWidget {
  const MemoryBar({super.key, this.collapsed = false, this.onToggleCollapsed});

  final bool collapsed;
  final VoidCallback? onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CalculatorController>();
    final toggle = onToggleCollapsed;
    return Material(
      color: AppColors.lightPrimaryColor,
      shape: const Border(
        bottom: BorderSide(color: AppColors.dividerColor, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BarButton(label: 'MC', onTap: c.memoryClear),
          _BarButton(label: 'MR', onTap: c.memoryRecall),
          _BarButton(label: 'M+', onTap: c.memoryAdd),
          _BarButton(label: 'M−', onTap: c.memorySubtract),
          _BarButton(
            label: 'S⇔D',
            enabled: c.isFractionAvailable,
            onTap: c.toggleFraction,
          ),
          if (toggle != null)
            _BarButton(
              label: collapsed ? 'Show functions' : 'Hide functions',
              icon: collapsed
                  ? Icons.keyboard_arrow_down
                  : Icons.keyboard_arrow_up,
              onTap: toggle,
            ),
        ],
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.darkPrimaryColor : AppColors.secondaryText;
    final iconData = icon;
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Center(
          child: iconData != null
              ? Icon(iconData, color: color, size: 22, semanticLabel: label)
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _SciKey {
  const _SciKey(
    this.label, {
    this.tokens,
    this.action,
    this.hint,
    this.icon,
    this.highlighted = false,
  });

  final String label;
  final List<String>? tokens;
  final VoidCallback? action;
  final String? hint;
  final IconData? icon;
  final bool highlighted;
}

/// 6 x 4 grid of scientific keys. SHIFT swaps keys to their inverse / second
/// function and HYP turns the trigonometric keys into hyperbolic ones.
class ScientificKeypad extends StatelessWidget {
  const ScientificKeypad({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CalculatorController>();
    final shift = c.isShift;
    final hyp = c.isHyp;

    _SciKey trig(String fn) {
      final name = hyp ? '${fn}h' : fn;
      final inverse = '$name⁻¹';
      return shift
          ? _SciKey(inverse, tokens: ['$inverse('], hint: name, highlighted: true)
          : _SciKey(name, tokens: ['$name('], hint: inverse, highlighted: hyp);
    }

    _SciKey dual(
      String label,
      List<String> tokens,
      String shiftLabel,
      List<String> shiftTokens,
    ) {
      return shift
          ? _SciKey(shiftLabel, tokens: shiftTokens, hint: label, highlighted: true)
          : _SciKey(label, tokens: tokens, hint: shiftLabel);
    }

    final rows = <List<_SciKey>>[
      [
        trig('sin'),
        trig('cos'),
        trig('tan'),
        dual('ln', const ['ln('], 'eˣ', const ['e', '^', '(']),
        dual('log', const ['log('], '10ˣ', const ['1', '0', '^', '(']),
        const _SciKey('logₐb', tokens: ['logₐ(']),
      ],
      [
        dual('√', const ['√('], 'x²', const ['²']),
        const _SciKey('x²', tokens: ['²']),
        dual('xʸ', const ['^'], 'ʸ√x', const ['ʸ√']),
        dual('x³', const ['³'], '∛', const ['∛(']),
        const _SciKey('x⁻¹', tokens: ['^', '(', '−', '1', ')']),
        const _SciKey('n!', tokens: ['!']),
      ],
      [
        const _SciKey('nCr', tokens: ['C']),
        const _SciKey('nPr', tokens: ['P']),
        const _SciKey('π', tokens: ['π']),
        const _SciKey('e', tokens: ['e']),
        const _SciKey('mod', tokens: ['mod']),
        const _SciKey('%', tokens: ['%']),
      ],
      [
        const _SciKey('|x|', tokens: ['abs(']),
        const _SciKey('(', tokens: ['(']),
        const _SciKey(')', tokens: [')']),
        const _SciKey(',', tokens: [',']),
        _SciKey('Cursor left', icon: Icons.chevron_left, action: c.cursorLeft),
        _SciKey('Cursor right', icon: Icons.chevron_right, action: c.cursorRight),
      ],
    ];

    return Container(
      color: AppColors.lightPrimaryColor,
      padding: const EdgeInsets.all(3),
      child: Column(
        children: [
          for (final row in rows)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final key in row)
                    Expanded(
                      child: CalcButton(
                        label: key.label,
                        hint: key.hint,
                        icon: key.icon,
                        fontSize: 16,
                        background: key.highlighted
                            ? AppColors.primaryColor
                            : AppColors.lightPrimaryColor,
                        foreground: key.highlighted
                            ? AppColors.textIcons
                            : AppColors.darkPrimaryColor,
                        hintColor: key.highlighted
                            ? AppColors.lightPrimaryColor
                            : AppColors.secondaryText,
                        onPressed: () {
                          final action = key.action;
                          final tokens = key.tokens;
                          if (action != null) {
                            action();
                          } else if (tokens != null) {
                            c.insertAll(tokens);
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 5 x 4 numeric pad with digits, basic operators, DEL, AC, Ans and `=`.
class NumericKeypad extends StatelessWidget {
  const NumericKeypad({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Provider.of<CalculatorController>(context, listen: false);

    Widget digit(String d) => CalcButton(
          label: d,
          fontSize: 24,
          onPressed: () => c.insert(d),
        );

    Widget op(String symbol) => CalcButton(
          label: symbol,
          fontSize: 26,
          foreground: AppColors.primaryColor,
          onPressed: () => c.insert(symbol),
        );

    final rows = <List<Widget>>[
      [
        digit('7'),
        digit('8'),
        digit('9'),
        CalcButton(
          label: 'DEL',
          icon: Icons.backspace_outlined,
          background: AppColors.primaryColor,
          foreground: AppColors.textIcons,
          onPressed: c.delete,
          onLongPress: c.clearAll,
        ),
        CalcButton(
          label: 'AC',
          background: AppColors.primaryColor,
          foreground: AppColors.textIcons,
          onPressed: c.clearAll,
        ),
      ],
      [digit('4'), digit('5'), digit('6'), op('×'), op('÷')],
      [digit('1'), digit('2'), digit('3'), op('+'), op('−')],
      [
        digit('0'),
        digit('.'),
        CalcButton(
          label: '×10ˣ',
          fontSize: 17,
          onPressed: () => c.insert('E'),
        ),
        CalcButton(
          label: 'Ans',
          fontSize: 17,
          foreground: AppColors.primaryColor,
          onPressed: () => c.insert('Ans'),
        ),
        CalcButton(
          label: '=',
          fontSize: 28,
          background: AppColors.accentColor,
          foreground: AppColors.textIcons,
          onPressed: c.evaluate,
        ),
      ],
    ];

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(3),
      child: Column(
        children: [
          for (final row in rows)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final key in row) Expanded(child: key)],
              ),
            ),
        ],
      ),
    );
  }
}
