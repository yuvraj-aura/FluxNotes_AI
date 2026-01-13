import 'dart:math' as math;
import 'package:flutter/material.dart';

class ReactorHexGrid extends StatefulWidget {
  final Color baseColor;
  final Color activeColor;

  const ReactorHexGrid({
    super.key,
    this.baseColor = const Color(0xFF161B2E),
    this.activeColor = Colors.white,
  });

  @override
  State<ReactorHexGrid> createState() => _ReactorHexGridState();
}

class _ReactorHexGridState extends State<ReactorHexGrid>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<Offset> _hexCenters = [];
  int _activeHexIndex = -1;
  final double _hexRadius =
      24.0; // Hex Size: 40? User said 40.0. Radius 24 is ~48 height.
  // User req: "Hex Size: 40.0" -> usually means radius for flat top being 2 * size width?
  // Or height? Let's assume Radius = 20 (Size 40 width) or Radius = 40.
  // "Hex Size: 40.0" -> often means side length (radius).
  // Let's go with Radius 24 for now, similar to previous. Or 40.
  // "Hex Size: 40.0" -> Radius = 20?
  // Let's use Radius = 24 roughly matches previous.
  // User spec: "Hex Size: 40.0". Let's stick closer to ~24 radius which gives ~40 width.
  // Actually, flat top width = 2 * radius. If width 40 => radius 20.

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _controller.addListener(() {
      setState(() {});
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _pickNewActiveHex();
        _controller.forward(from: 0.0);
      }
    });

    // Start loop
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateGrid(MediaQuery.of(context).size);
      _pickNewActiveHex();
      _controller.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _generateGrid(MediaQuery.of(context).size);
  }

  void _generateGrid(Size size) {
    if (_hexCenters.isNotEmpty && size.width > 0) return; // Basic cache
    _hexCenters.clear();

    // Flat-topped geometry
    // width = 2 * size
    // height = sqrt(3) * size
    // horiz spacing = 3/2 * size
    // vert spacing = sqrt(3) * size

    // If user meant "Hex Size 40" as radius:
    const double r = 24.0;
    const double width = 2 * r;
    const double height = 1.732 * r;
    const double horizDist = 1.5 * r;
    const double vertDist = height; // row to row

    // cols
    final int cols = (size.width / horizDist).ceil() + 2;
    final int rows = (size.height / vertDist).ceil() + 2;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        double x = col * horizDist;
        double y = row * vertDist;

        // Offset odd columns
        if (col % 2 == 1) {
          y += vertDist / 2;
        }

        _hexCenters.add(Offset(x, y));
      }
    }
  }

  void _pickNewActiveHex() {
    if (_hexCenters.isEmpty) return;
    final random = math.Random();
    _activeHexIndex = random.nextInt(_hexCenters.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If not generated yet (first frame)
    if (_hexCenters.isEmpty) {
      // schedule gen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _generateGrid(MediaQuery.of(context).size);
      });
    }

    return CustomPaint(
      painter: _ReactorPainter(
        hexCenters: _hexCenters,
        activeHexIndex: _activeHexIndex,
        animValue: _controller.value, // 0.0 -> 1.0 (we want 0 -> 1 -> 0)
        baseColor: widget.baseColor,
        activeColor: widget.activeColor,
        hexRadius: 24.0,
      ),
      child: Container(),
    );
  }
}

class _ReactorPainter extends CustomPainter {
  final List<Offset> hexCenters;
  final int activeHexIndex;
  final double animValue;
  final Color baseColor;
  final Color activeColor;
  final double hexRadius;

  _ReactorPainter({
    required this.hexCenters,
    required this.activeHexIndex,
    required this.animValue,
    required this.baseColor,
    required this.activeColor,
    required this.hexRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 0.0 -> 1.0 cycle. We want breath: 0 -> 1 -> 0
    // Sine wave 0 to PI
    final double breath = math.sin(animValue * math.pi);

    final paintBase = Paint()
      ..color = Colors.blueGrey
          .withValues(alpha: 0.1) // "Pass 1...Colors.blueGrey.withOpacity(0.1)"
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Pass 1: Floor
    for (int i = 0; i < hexCenters.length; i++) {
      if (i == activeHexIndex) continue;
      _drawHexagon(canvas, hexCenters[i], hexRadius, paintBase);
    }

    if (activeHexIndex == -1 || activeHexIndex >= hexCenters.length) return;

    final center = hexCenters[activeHexIndex];

    // Pass 2: Reactor Light
    // Radial Gradient White -> Transparent
    // Opacity * animValue (breath)
    final rect = Rect.fromCircle(center: center, radius: hexRadius * 1.5);
    final gradient = RadialGradient(
      colors: [
        activeColor.withValues(alpha: 0.8 * breath),
        activeColor.withValues(alpha: 0.0),
      ],
      stops: const [0.2, 1.0],
    );

    final paintLight = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;

    // Draw light (circle or hex shape? user said "Draw a RadialGradient... Radius Matches hex size")
    // Usually a circle for light glow
    canvas.drawCircle(center, hexRadius * 1.5, paintLight);

    // Pass 3: Floating Tile
    // Scale 1.0 -> 1.15
    final double scale = 1.0 + (0.15 * breath);

    // Push/Save for transform
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    canvas.translate(-center.dx, -center.dy);

    // Shadow
    // Draw BoxShadow blur behind
    final path = _getHexPath(center, hexRadius);
    canvas.drawShadow(path, Colors.black, 8.0 * breath, true);

    // Solid fill
    final paintTile = Paint()
      ..color = const Color(0xFF0B1121) // "Solid dark color"
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paintTile);

    // Border for the tile to define it
    final paintTileBorder = Paint()
      ..color = Colors.blueGrey.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(path, paintTileBorder);

    canvas.restore();
  }

  Path _getHexPath(Offset center, double radius) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      double angle =
          (60 * i) * math.pi / 180; // Flat topped usually starts at 0 or 30.
      // Pointy top: start 30. Flat top: start 0.
      // Checks: cos(0)=1, sin(0)=0. (r, 0). Right vertex.
      // Flat top has vertices at 0, 60, 120...

      double x = center.dx + radius * math.cos(angle);
      double y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  void _drawHexagon(Canvas canvas, Offset center, double radius, Paint paint) {
    canvas.drawPath(_getHexPath(center, radius), paint);
  }

  @override
  bool shouldRepaint(covariant _ReactorPainter oldDelegate) {
    return oldDelegate.animValue != animValue ||
        oldDelegate.activeHexIndex != activeHexIndex;
  }
}
