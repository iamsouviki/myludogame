import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ponytail: Clamps app content width between 360px and 1440px.
/// - Below 360px: clamps content width at 360px and provides scrollability.
/// - Between 360px and 1440px: fluid 100% width.
/// - Above 1440px: clamps max content width at 1440px and centers in viewport.
class ResponsiveWrapper extends StatelessWidget {
  final Widget child;

  const ResponsiveWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;

        if (screenWidth < 360) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                width: 360,
                height: math.max(screenHeight, 640),
                child: child,
              ),
            ),
          );
        }

        if (screenWidth > 1440) {
          return Center(
            child: SizedBox(
              width: 1440,
              child: child,
            ),
          );
        }

        return SizedBox(
          width: screenWidth,
          child: child,
        );
      },
    );
  }
}
