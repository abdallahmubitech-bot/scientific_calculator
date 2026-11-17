import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/calculator_controller.dart';
import '../theme/app_colors.dart';

/// Dual-line display: an editable, syntax-highlighted expression with a
/// blinking cursor on top and the live / committed result below.
class CalculatorDisplay extends StatefulWidget {
  const CalculatorDisplay({super.key});

  @override
  State<CalculatorDisplay> createState() => _CalculatorDisplayState();
}

class _CalculatorDisplayState extends State<CalculatorDisplay> {
  static const Set<String> _operators = {
    '+', '−', '×', '÷', '^', 'mod', 'C', 'P', '!', '%', '²', '³', 'ʸ√', 'E',
  };
  static const Set<String> _constants = {'π', 'e', 'Ans'};
  static const Set<String> _punctuation = {'(', ')', ','};

  final GlobalKey _cursorKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Scrolls the expression just enough to keep the cursor on screen.
  void _revealCursor() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cursorContext = _cursorKey.currentContext;
      if (cursorContext == null) return;
      Scrollable.ensureVisible(
        cursorContext,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
      Scrollable.ensureVisible(
        cursorContext,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    });
  }

  String _displayText(String token) => token == 'mod' ? ' mod ' : token;

  TextStyle _styleFor(String token, TextStyle base) {
    if (_operators.contains(token)) {
      return base.copyWith(
        color: AppColors.accentColor,
        fontWeight: FontWeight.w600,
      );
    }
    if (_constants.contains(token)) {
      return base.copyWith(
        color: AppColors.darkPrimaryColor,
        fontWeight: FontWeight.w600,
      );
    }
    if (_punctuation.contains(token)) return base;
    if (token.endsWith('(')) {
      return base.copyWith(color: AppColors.primaryColor);
    }
    return base; // Digits and the decimal point.
  }

  Widget _buildExpression(CalculatorController c) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fontSize = (constraints.maxHeight * 0.55).clamp(14.0, 28.0).toDouble();
        final base = TextStyle(
          color: AppColors.secondaryText,
          fontSize: fontSize,
          fontWeight: FontWeight.w400,
          height: 1.15,
        );
        final tokens = c.tokens;
        final children = <Widget>[];
        for (var i = 0; i <= tokens.length; i++) {
          final index = i;
          if (index == c.cursor) {
            children.add(_BlinkingCursor(key: _cursorKey, height: fontSize * 1.2));
          }
          if (index < tokens.length) {
            final token = tokens[index];
            children.add(
              _TokenView(
                text: _displayText(token),
                style: _styleFor(token, base),
                onTap: (after) {
                  HapticFeedback.selectionClick();
                  c.moveCursorTo(after ? index + 1 : index);
                },
              ),
            );
          }
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => c.moveCursorTo(tokens.length),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: children),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResult(CalculatorController c) {
    final isError = c.error != null;
    var text = c.resultText;
    if (!isError) {
      text = text.replaceAll('E', '×10^').replaceAll('-', '−');
    }
    final committed = c.isEvaluated || isError;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: c.isFractionAvailable
          ? () {
              HapticFeedback.lightImpact();
              c.toggleFraction();
            }
          : null,
      child: Align(
        alignment: Alignment.centerRight,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            text.isEmpty ? ' ' : text,
            maxLines: 1,
            style: TextStyle(
              color: isError ? AppColors.darkPrimaryColor : AppColors.primaryText,
              fontSize: committed ? 40 : 30,
              fontWeight: committed ? FontWeight.w600 : FontWeight.w400,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CalculatorController>();
    _revealCursor();
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.dividerColor, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 5, child: _buildExpression(c)),
          Expanded(flex: 6, child: _buildResult(c)),
        ],
      ),
    );
  }
}

/// One expression token. Tapping its left / right half places the cursor
/// before / after it.
class _TokenView extends StatelessWidget {
  const _TokenView({
    required this.text,
    required this.style,
    required this.onTap,
  });

  final String text;
  final TextStyle style;
  final ValueChanged<bool> onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) {
        final width = context.size?.width ?? 0;
        onTap(details.localPosition.dx > width / 2);
      },
      child: Text(text, style: style, maxLines: 1),
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor({super.key, required this.height});

  final double height;

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Opacity(
        opacity: _controller.value < 0.55 ? 1 : 0,
        child: child,
      ),
      child: Container(
        width: 2,
        height: widget.height,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        color: AppColors.accentColor,
      ),
    );
  }
}
