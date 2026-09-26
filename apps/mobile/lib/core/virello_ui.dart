import 'dart:ui';
import 'package:flutter/material.dart';
import 'theme.dart';

/// Shared board-style components: gradient button, pill tabs, score ring,
/// shimmer placeholders, donut chart, stat tiles, search bar.
/// All screens in the approved 10-screen board build from these.
class VGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  const VGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.45 : 1,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            gradient: VirelloColors.brandGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: VirelloColors.violet.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
              if (icon != null) ...[
                const SizedBox(width: 8),
                Icon(icon, color: Colors.white, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal scrollable pill tabs — board style: violet filled active pill.
class VPillTabs extends StatelessWidget {
  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onTap;
  const VPillTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = i == selected;
          return Padding(
            padding: EdgeInsets.only(right: i == tabs.length - 1 ? 0 : 8),
            child: GestureDetector(
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: active ? VirelloColors.violet : VirelloColors.chipBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(tabs[i],
                    style: TextStyle(
                      color: active ? Colors.white : VirelloColors.mutedDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    )),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Circular score ring with center value.
class VScoreRing extends StatelessWidget {
  final double score; // 0..100
  final double size;
  const VScoreRing({super.key, required this.score, this.size = 140});

  @override
  Widget build(BuildContext context) {
    final s = score.clamp(0, 100);
    final color = s >= 70
        ? VirelloColors.success
        : s >= 45
            ? VirelloColors.amber
            : VirelloColors.violet;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: s / 100,
              strokeWidth: 13,
              backgroundColor: VirelloColors.chipBg,
              color: color,
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${s.round()}',
                style: TextStyle(
                    fontSize: size * 0.3, fontWeight: FontWeight.w900)),
            Text('/ 100',
                style: TextStyle(
                    color: VirelloColors.muted, fontSize: size * 0.1)),
          ]),
        ],
      ),
    );
  }
}

/// Loading placeholder with a soft pulse.
class VShimmerBox extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  const VShimmerBox(
      {super.key, this.width, required this.height, this.radius = 12});

  @override
  State<VShimmerBox> createState() => _VShimmerBoxState();
}

class _VShimmerBoxState extends State<VShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Opacity(
        opacity: 0.45 + 0.35 * _c.value,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: VirelloColors.chipBg,
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      ),
    );
  }
}

class VDonutSlice {
  final String label;
  final double value; // 0..1 share
  final Color color;
  const VDonutSlice(
      {required this.label, required this.value, required this.color});
}

/// Donut chart drawn with a CustomPainter — no extra dependencies.
class VDonutChart extends StatelessWidget {
  final List<VDonutSlice> slices;
  final double size;
  const VDonutChart({super.key, required this.slices, this.size = 150});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _DonutPainter(slices)),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: slices
              .map((sl) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              color: sl.color, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(sl.label,
                              style: const TextStyle(fontSize: 12))),
                      Text('${(sl.value * 100).round()}%',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                    ]),
                  ))
              .toList(),
        ),
      ),
    ]);
  }
}

class _DonutPainter extends CustomPainter {
  final List<VDonutSlice> slices;
  _DonutPainter(this.slices);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    var start = -90 * 3.1415926535 / 180;
    for (final sl in slices) {
      final sweep = sl.value * 2 * 3.1415926535;
      final paint = Paint()
        ..color = sl.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.42
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius * 0.75),
          start, sweep, false, paint);
      start += sweep;
    }
    // Center label: top slice share.
    if (slices.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(
            text: '${(slices.first.value * 100).round()}%',
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: VirelloColors.ink)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.slices != slices;
}

/// Small stat tile used on the Campaigns screen.
class VStatTile extends StatelessWidget {
  final String label;
  final String value;
  const VStatTile({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: VirelloColors.chipBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: [
          Text(value,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 11, color: VirelloColors.muted)),
        ]),
      ),
    );
  }
}

/// Board-style rounded search field.
class VSearchBar extends StatelessWidget {
  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool readOnly;
  const VSearchBar({
    super.key,
    required this.hint,
    this.controller,
    this.onSubmitted,
    this.onTap,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: VirelloColors.muted, fontSize: 14),
        prefixIcon:
            const Icon(Icons.search, color: VirelloColors.muted, size: 22),
        filled: true,
        fillColor: VirelloColors.chipBg,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    );
  }
}

/// Section title row with optional trailing action.
class VSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const VSectionHeader(
      {super.key, required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
          child: Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
      if (actionLabel != null)
        GestureDetector(
          onTap: onAction,
          child: Text(actionLabel!,
              style: const TextStyle(
                  fontSize: 13,
                  color: VirelloColors.violet,
                  fontWeight: FontWeight.w700)),
        ),
    ]);
  }
}

/// Soft white card with board shadow.
class VCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const VCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: VirelloColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: VirelloColors.cardShadow,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(20), child: card);
  }
}

/// Frosted-glass language badge — matches the approved mockup.
/// Translucent squircle with a violet border and soft glow, showing the
/// language's native-script glyph (اردو, ع, हिं, Ñ, Aa) in its color.
class VGlassLangBadge extends StatelessWidget {
  final String code;
  final double glyphSize;
  const VGlassLangBadge({super.key, required this.code, this.glyphSize = 15});

  /// Native-script glyph per language code (mockup-approved).
  static String scriptFor(String code) {
    switch (code.trim().toLowerCase()) {
      case 'en':
        return 'Aa';
      case 'ur':
        return 'اردو';
      case 'ar':
        return 'ع';
      case 'hi':
        return 'हिं';
      case 'es':
        return 'Ñ';
      case '':
        return '••';
      default:
        final c = code.trim();
        return c.substring(0, c.length > 2 ? 2 : c.length).toUpperCase();
    }
  }

  /// Glyph color per language (mockup-approved palette).
  static Color colorFor(String code) {
    switch (code.trim().toLowerCase()) {
      case 'en':
        return const Color(0xFF3B6FD4);
      case 'ur':
        return const Color(0xFF1FAE62);
      case 'ar':
        return const Color(0xFF8A5A2B);
      case 'hi':
        return const Color(0xFFE8930C);
      case 'es':
        return const Color(0xFFC0392B);
      default:
        return const Color(0xFF9A9AB0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: dark
                  ? [
                      const Color(0xB32A2B45),
                      const Color(0x80332E5C),
                    ]
                  : [
                      const Color(0xC4FFFFFF),
                      const Color(0xA6F0EEFF),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
                color: VirelloColors.violet.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: VirelloColors.violet.withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            scriptFor(code),
            style: TextStyle(
              fontSize: glyphSize,
              fontWeight: FontWeight.w800,
              color: colorFor(code),
            ),
          ),
        ),
      ),
    );
  }
}
