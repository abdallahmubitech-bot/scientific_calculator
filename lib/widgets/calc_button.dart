import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// A single calculator key with haptic feedback, an optional icon and an
/// optional small hint (the alternate SHIFT function) in its top-right corner.
class CalcButton extends StatelessWidget {
  const CalcButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.onLongPress,
    this.hint,
    this.icon,
    this.background = AppColors.keySurface,
    this.foreground = AppColors.primaryText,
    this.hintColor = AppColors.secondaryText,
    this.fontSize = 20,
    this.fontWeight = FontWeight.w500,
  });

  final String label;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final String? hint;
  final IconData? icon;
  final Color background;
  final Color foreground;
  final Color hintColor;
  final double fontSize;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    final longPress = onLongPress;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: background,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: AppColors.dividerColor, width: 0.5),
        ),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onPressed();
          },
          onLongPress: longPress == null
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  longPress();
                },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final hintText = hint;
              final showHint = hintText != null && constraints.maxHeight >= 38;
              final iconData = icon;
              return Stack(
                fit: StackFit.expand,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(4, showHint ? 10 : 0, 4, 0),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: iconData != null
                            ? Icon(
                                iconData,
                                color: foreground,
                                size: fontSize + 2,
                                semanticLabel: label,
                              )
                            : Text(
                                label,
                                maxLines: 1,
                                style: TextStyle(
                                  color: foreground,
                                  fontSize: fontSize,
                                  fontWeight: fontWeight,
                                  height: 1.1,
                                ),
                              ),
                      ),
                    ),
                  ),
                  if (showHint && hintText != null)
                    Positioned(
                      top: 2,
                      right: 5,
                      child: Text(
                        hintText,
                        maxLines: 1,
                        style: TextStyle(
                          color: hintColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          height: 1.1,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
