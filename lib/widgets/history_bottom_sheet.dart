import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/calculation_history.dart';
import '../providers/calculator_controller.dart';
import '../theme/app_colors.dart';

/// Slide-up sheet listing timestamped calculations.
///
/// Tap an expression to load it into the display, tap a result to insert it
/// at the cursor, swipe an entry away to delete it.
class HistoryBottomSheet extends StatelessWidget {
  const HistoryBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.keySurface,
      builder: (_) => const HistoryBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CalculatorController>();
    final items = c.history;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              decoration: const BoxDecoration(
                color: AppColors.dividerColor,
                borderRadius: BorderRadius.all(Radius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
              child: Row(
                children: [
                  const Icon(Icons.history, color: AppColors.primaryColor),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'History',
                      style: TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: items.isEmpty
                        ? null
                        : () {
                            HapticFeedback.lightImpact();
                            c.clearHistory();
                          },
                    child: const Text('Clear all'),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: items.isEmpty
                  ? ListView(
                      controller: scrollController,
                      children: const [_EmptyHistory()],
                    )
                  : ListView.separated(
                      controller: scrollController,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Dismissible(
                          key: ObjectKey(item),
                          background: const ColoredBox(
                            color: AppColors.lightPrimaryColor,
                          ),
                          onDismissed: (_) => c.removeHistoryItem(item),
                          child: _HistoryTile(item: item),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Icon(Icons.calculate_outlined, size: 48, color: AppColors.dividerColor),
          SizedBox(height: 12),
          Text(
            'No calculations yet',
            style: TextStyle(color: AppColors.secondaryText, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item});

  final CalculationHistory item;

  @override
  Widget build(BuildContext context) {
    final c = Provider.of<CalculatorController>(context, listen: false);
    final result = item.result.replaceAll('E', '×10^').replaceAll('-', '−');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              item.formattedTimestamp,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 11,
              ),
            ),
          ),
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              c.useHistoryExpression(item);
              Navigator.of(context).pop();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                item.expression,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              c.useHistoryResult(item);
              Navigator.of(context).pop();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                '= $result',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
