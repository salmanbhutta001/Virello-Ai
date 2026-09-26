import 'package:flutter/material.dart';

/// Brand glyphs drawn from SVG path data — no icon-font dependency.
///
/// Supports the path commands used below (M/L/H/V/C/S/Z, absolute +
/// relative). Not a general-purpose SVG parser.
Path _parseSvgPath(String d) {
  final path = Path();
  final tokens =
      RegExp(r'[MLHVCSZmlhvcs]|[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?')
          .allMatches(d)
          .map((m) => m.group(0)!)
          .toList();
  int i = 0;
  String cmd = '';
  double cx = 0, cy = 0, sx = 0, sy = 0;
  // Previous cubic's second control point (for smooth-curve reflection).
  double? pcx, pcy;
  double num() => double.parse(tokens[i++]);
  bool isCmd(String t) => RegExp(r'^[MLHVCSZmlhvcs]$').hasMatch(t);

  void cubic(double x1, double y1, double x2, double y2) {
    path.cubicTo(x1, y1, x2, y2, cx, cy);
    pcx = x2;
    pcy = y2;
  }

  void noCubic() {
    pcx = null;
    pcy = null;
  }

  while (i < tokens.length) {
    final t = tokens[i];
    if (isCmd(t)) {
      cmd = t;
      i++;
      continue;
    }
    switch (cmd) {
      case 'M':
        cx = num();
        cy = num();
        path.moveTo(cx, cy);
        sx = cx;
        sy = cy;
        noCubic();
        cmd = 'L';
        break;
      case 'm':
        cx += num();
        cy += num();
        path.moveTo(cx, cy);
        sx = cx;
        sy = cy;
        noCubic();
        cmd = 'l';
        break;
      case 'L':
        cx = num();
        cy = num();
        path.lineTo(cx, cy);
        noCubic();
        break;
      case 'l':
        cx += num();
        cy += num();
        path.lineTo(cx, cy);
        noCubic();
        break;
      case 'H':
        cx = num();
        path.lineTo(cx, cy);
        noCubic();
        break;
      case 'h':
        cx += num();
        path.lineTo(cx, cy);
        noCubic();
        break;
      case 'V':
        cy = num();
        path.lineTo(cx, cy);
        noCubic();
        break;
      case 'v':
        cy += num();
        path.lineTo(cx, cy);
        noCubic();
        break;
      case 'C':
        final x1 = num(), y1 = num(), x2 = num(), y2 = num();
        cx = num();
        cy = num();
        cubic(x1, y1, x2, y2);
        break;
      case 'c':
        final x1 = cx + num(), y1 = cy + num();
        final x2 = cx + num(), y2 = cy + num();
        cx += num();
        cy += num();
        cubic(x1, y1, x2, y2);
        break;
      case 'S':
        final x2 = num(), y2 = num();
        final x1 = 2 * cx - (pcx ?? cx), y1 = 2 * cy - (pcy ?? cy);
        cx = num();
        cy = num();
        cubic(x1, y1, x2, y2);
        break;
      case 's':
        final x2 = cx + num(), y2 = cy + num();
        final x1 = 2 * cx - (pcx ?? cx), y1 = 2 * cy - (pcy ?? cy);
        cx += num();
        cy += num();
        cubic(x1, y1, x2, y2);
        break;
      case 'Z':
      case 'z':
        path.close();
        cx = sx;
        cy = sy;
        noCubic();
        break;
      default:
        i++; // stray token — skip
        break;
    }
  }
  return path;
}

class _BrandPainter extends CustomPainter {
  final List<(Color, Path)> parts;
  const _BrandPainter(this.parts);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    for (final (color, p) in parts) {
      canvas.drawPath(
          p, Paint()..color = color..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Official 4-color Google "G" (24x24 viewBox).
class GoogleGIcon extends StatelessWidget {
  final double size;
  const GoogleGIcon({super.key, this.size = 18});

  static final _parts = <(int, String)>[
    (
      0xFF4285F4,
      'M23.5 12.27c0-.85-.08-1.66-.22-2.45H12v4.64h6.45c-.28 1.48-1.12 2.73-2.38 3.58v2.97h3.86c2.26-2.09 3.57-5.16 3.57-8.74z'
    ),
    (
      0xFF34A853,
      'M12 24c3.24 0 5.96-1.07 7.94-2.91l-3.86-2.97c-1.07.72-2.44 1.15-4.08 1.15-3.13 0-5.78-2.11-6.73-4.96H1.29v3.07C3.26 21.3 7.31 24 12 24z'
    ),
    (
      0xFFFBBC05,
      'M5.27 14.31c-.24-.72-.38-1.49-.38-2.31s.14-1.59.38-2.31V6.62H1.29C.47 8.24 0 10.06 0 12s.47 3.76 1.29 5.38l3.98-3.07z'
    ),
    (
      0xFFEA4335,
      'M12 4.73c1.76 0 3.35.61 4.6 1.8l3.42-3.42C17.95 1.19 15.24 0 12 0 7.31 0 3.26 2.7 1.29 6.62l3.98 3.07C6.22 6.84 8.87 4.73 12 4.73z'
    ),
  ].map((e) => (Color(e.$1), _parseSvgPath(e.$2))).toList();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _BrandPainter(_parts)));
  }
}

/// Apple logo silhouette (24x24 viewBox), drawn in the icon theme color.
class AppleIcon extends StatelessWidget {
  final double size;
  const AppleIcon({super.key, this.size = 19});

  static const _pathData =
      'M17.05 12.54c-.03-2.89 2.36-4.27 2.47-4.34-1.35-1.97-3.44-2.24-4.18-2.27-1.78-.18-3.47 1.05-4.37 1.05-.9 0-2.29-1.02-3.77-1-1.83.03-3.52 1.06-4.46 2.7-1.9 3.3-.49 8.19 1.37 10.87.9 1.31 1.98 2.78 3.4 2.73 1.36-.06 1.88-.88 3.53-.88s2.11.88 3.56.85c1.47-.03 2.4-1.33 3.3-2.65 1.04-1.52 1.47-2.99 1.49-3.07-.03-.01-2.86-1.1-2.89-4.34zM14.65 5.4c.8-.97 1.34-2.32 1.19-3.66-1.15.05-2.55.77-3.38 1.74-.74.86-1.39 2.23-1.22 3.55 1.29.1 2.6-.65 3.41-1.63z';

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color ?? Colors.black87;
    return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
            painter: _BrandPainter([(color, _parseSvgPath(_pathData))])));
  }
}
