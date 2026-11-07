// Shared look for AttendTrack: "Premium and bold" (blue).
// Colors, theme, and small animation helpers (all under 300 ms).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  static const Color primary = Color(0xFF2447D6);
  static const Color primarySoft = Color(0xFF4766E0);
  static const Color navy = Color(0xFF0F1B4D);
  static const Color ink = Color(0xFF12214A);
  static const Color muted = Color(0xFF4A5A80);
  static const Color bg = Color(0xFFF5F7FB);
  static const Color tint = Color(0xFFE8EEFF);
  static const Color line = Color(0xFFE3E8F2);
  static const Color good = Color(0xFF17703A);
  static const Color goodSoft = Color(0xFFE3F5EA);
  static const Color bad = Color(0xFFB3261E);
  static const Color badSoft = Color(0xFFFDE7E4);
}

const Duration kFast = Duration(milliseconds: 160);
const Duration kMed = Duration(milliseconds: 260);

bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      }),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.line),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.tint,
        side: BorderSide.none,
        labelStyle: const TextStyle(fontSize: 13, color: AppColors.ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// Fade + small slide up. [index] staggers the start (each item moves 260 ms).
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int index;
  const FadeSlideIn({super.key, required this.child, this.index = 0});

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
    final step = index.clamp(0, 8);
    final total = 260 + step * 50;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      builder: (context, t, child) {
        final p = Interval(step * 50 / total, 1, curve: Curves.easeOutCubic)
            .transform(t);
        return Opacity(
          opacity: p,
          child: Transform.translate(offset: Offset(0, 16 * (1 - p)), child: child),
        );
      },
      child: child,
    );
  }
}

/// Shrinks slightly while a finger is down. Does not take the tap itself.
class PressScale extends StatefulWidget {
  final Widget child;
  const PressScale({super.key, required this.child});

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Number that counts to its value.
class CountUp extends StatelessWidget {
  final num value;
  final int decimals;
  final String suffix;
  final TextStyle? style;
  const CountUp({
    super.key,
    required this.value,
    this.decimals = 0,
    this.suffix = '',
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) {
      return Text('${value.toStringAsFixed(decimals)}$suffix', style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: value.toDouble()),
      duration: kMed,
      curve: Curves.easeOutCubic,
      builder: (_, v, __) =>
          Text('${v.toStringAsFixed(decimals)}$suffix', style: style),
    );
  }
}

/// Round percentage ring that fills smoothly.
class PctRing extends StatelessWidget {
  final double pct;
  final double size;
  final double stroke;
  final Color color;
  final Color track;
  final TextStyle? textStyle;
  const PctRing({
    super.key,
    required this.pct,
    this.size = 112,
    this.stroke = 10,
    this.color = Colors.white,
    this.track = AppColors.primarySoft,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final target = (pct / 100).clamp(0.0, 1.0);
    final instant = reduceMotion(context);
    return Semantics(
      label: '${pct.toStringAsFixed(0)} percent attendance',
      child: SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: target),
          duration: instant ? Duration.zero : const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => CustomPaint(
            painter: _RingPainter(v, stroke, color, track),
            child: Center(
              child: Text('${(v * 100).toStringAsFixed(0)}%', style: textStyle),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double v;
  final double stroke;
  final Color color;
  final Color track;
  _RingPainter(this.v, this.stroke, this.color, this.track);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track
      ..isAntiAlias = true;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color
      ..isAntiAlias = true;
    canvas.drawArc(r, 0, 6.2831853, false, base);
    canvas.drawArc(r, -1.5707963, 6.2831853 * v, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.v != v || old.color != color || old.track != track;
}

/// Thin progress bar that animates.
class AnimatedBar extends StatelessWidget {
  final double value;
  final Color color;
  final Color track;
  final double height;
  const AnimatedBar({
    super.key,
    required this.value,
    required this.color,
    this.track = AppColors.line,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: value.clamp(0.0, 1.0)),
        duration: reduceMotion(context) ? Duration.zero : kMed,
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => LinearProgressIndicator(
          value: v,
          minHeight: height,
          backgroundColor: track,
          color: color,
        ),
      ),
    );
  }
}

/// White rounded block used for most content.
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: kMed,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}

/// Small selectable pill (day picker, course picker).
class AppPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const AppPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: PressScale(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: kFast,
          curve: Curves.easeOut,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : AppColors.tint,
            borderRadius: BorderRadius.circular(14),
          ),
          child: AnimatedDefaultTextStyle(
            duration: kFast,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? Colors.white : AppColors.ink,
            ),
            child: Text(label),
          ),
        ),
      ),
        ),
      ),
    );
  }
}

/// Tab content switch: fade plus a small slide.
Widget tabTransition(Widget child, Animation<double> anim) {
  return FadeTransition(
    opacity: anim,
    child: SlideTransition(
      position: Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero)
          .animate(anim),
      child: child,
    ),
  );
}

/// Dark bottom bar with an animated active pill.
class AppNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const AppNavBar({super.key, required this.index, required this.onTap});

  static const _items = [
    (Icons.home_rounded, 'Home'),
    (Icons.calendar_month_rounded, 'History'),
    (Icons.qr_code_2_rounded, 'QR'),
    (Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.navy,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: List.generate(_items.length, (i) {
              final selected = i == index;
              return Expanded(
                child: PressScale(
                  child: InkWell(
                    onTap: () => onTap(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: kFast,
                          curve: Curves.easeOut,
                          width: selected ? 56 : 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primarySoft
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            _items[i].$1,
                            size: 24,
                            color: selected
                                ? Colors.white
                                : const Color(0xFFAEB9E3),
                          ),
                        ),
                        const SizedBox(height: 2),
                        AnimatedDefaultTextStyle(
                          duration: kFast,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w400,
                            color: selected
                                ? Colors.white
                                : const Color(0xFFAEB9E3),
                          ),
                          child: Text(_items[i].$2),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Blue top area with a rounded sheet over it. Scrolls as one page.
class BoldPage extends StatelessWidget {
  final Widget header;
  final List<Widget> children;
  const BoldPage({super.key, required this.header, required this.children});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    16, MediaQuery.of(context).padding.top + 16, 16, 24),
                child: header,
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
