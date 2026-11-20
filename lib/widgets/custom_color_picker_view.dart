import 'package:material_ui/material_ui.dart';

/// Flutter port of the Android `CustomColorPickerView`.
///
/// Draws the same three interactive regions:
///  1. Saturation / Value square (white -> pure hue, overlaid with black)
///  2. Vertical hue spectrum bar
///  3. Horizontal alpha bar over a checkerboard pattern
///
/// Dragging any region updates HSV/alpha and reports the packed ARGB color.
class CustomColorPickerView extends StatefulWidget {
  static const double viewHeight = 350;

  final int color;
  final ValueChanged<int> onColorChanged;

  const CustomColorPickerView({
    super.key,
    required this.color,
    required this.onColorChanged,
  });

  @override
  CustomColorPickerViewState createState() => CustomColorPickerViewState();
}

class CustomColorPickerViewState extends State<CustomColorPickerView> {
  static const double _padding = 12;
  static const double _hueBarWidth = 20;
  static const double _alphaBarHeight = 20;
  static const double _pointerRadius = 10;

  double _hue = 0;
  double _sat = 1;
  double _val = 1;
  int _alpha = 255;

  @override
  void initState() {
    super.initState();
    _setFromColor(widget.color);
  }

  @override
  void didUpdateWidget(covariant CustomColorPickerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.color != widget.color && widget.color != _currentColor()) {
      _setFromColor(widget.color);
    }
  }

  /// Programmatically applies a packed ARGB color (used by the hex/smali
  /// fields). Does not fire [onColorChanged], mirroring Java `setColor`.
  void setColor(int color) {
    if (color == _currentColor()) return;
    setState(() => _setFromColor(color));
  }

  void _setFromColor(int color) {
    final hsv = HSVColor.fromColor(Color(color));
    _hue = hsv.hue;
    _sat = hsv.saturation;
    _val = hsv.value;
    _alpha = Color(color).alpha;
  }

  int _currentColor() {
    return HSVColor.fromAHSV(_alpha / 255, _hue, _sat, _val).toColor().value;
  }

  void _handleDrag(Offset local, Size size) {
    final g = _geometry(size);
    final x = local.dx;
    final y = local.dy;

    if (y >= g.square.top && y <= g.square.bottom) {
      if (x >= g.square.left && x <= g.square.right) {
        _sat = _clamp((x - g.square.left) / g.square.width);
        _val = 1 - _clamp((y - g.square.top) / g.square.height);
      } else if (x >= g.hueBar.left && x <= g.hueBar.right) {
        _hue = 360 * _clamp((y - g.hueBar.top) / g.hueBar.height);
      }
    } else if (y >= g.alphaBar.top && y <= g.alphaBar.bottom) {
      _alpha = (_clamp((x - g.alphaBar.left) / g.alphaBar.width) * 255).round();
    }

    final color = _currentColor();
    setState(() {});
    widget.onColorChanged(color);
  }

  static double _clamp(double value) => value.clamp(0.0, 1.0).toDouble();

  static _PickerGeometry _geometry(Size size) {
    final squareHeight = size.height - _alphaBarHeight - 2 * _padding;
    final squareWidth = size.width - _hueBarWidth - 2 * _padding;
    final square = Rect.fromLTWH(_padding, _padding, squareWidth, squareHeight);
    final hueBar = Rect.fromLTWH(
      _padding + squareWidth + _padding,
      _padding,
      _hueBarWidth,
      squareHeight,
    );
    final alphaBar = Rect.fromLTWH(
      _padding,
      _padding + squareHeight + _padding,
      squareWidth + _hueBarWidth + _padding,
      _alphaBarHeight,
    );
    return _PickerGeometry(square, hueBar, alphaBar);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, CustomColorPickerView.viewHeight);
        return SizedBox(
          width: double.infinity,
          height: CustomColorPickerView.viewHeight,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: (details) => _handleDrag(details.localPosition, size),
            onPanUpdate: (details) => _handleDrag(details.localPosition, size),
            child: CustomPaint(
              size: size,
              painter: _ColorPickerPainter(
                hue: _hue,
                sat: _sat,
                val: _val,
                alpha: _alpha,
                outline: theme.colorScheme.outline,
                surfaceVariant: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PickerGeometry {
  final Rect square;
  final Rect hueBar;
  final Rect alphaBar;

  const _PickerGeometry(this.square, this.hueBar, this.alphaBar);
}

class _ColorPickerPainter extends CustomPainter {
  final double hue;
  final double sat;
  final double val;
  final int alpha;
  final Color outline;
  final Color surfaceVariant;

  const _ColorPickerPainter({
    required this.hue,
    required this.sat,
    required this.val,
    required this.alpha,
    required this.outline,
    required this.surfaceVariant,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final g = CustomColorPickerViewState._geometry(size);
    final square = g.square;
    final hueBar = g.hueBar;
    final alphaBar = g.alphaBar;
    if (square.width <= 0 || square.height <= 0) return;

    // 1. Saturation / Value square.
    final pureHue = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
    canvas.drawRect(
      square,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.white, pureHue],
        ).createShader(square),
    );
    canvas.drawRect(
      square,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(square),
    );

    // 2. Hue spectrum bar (red -> yellow -> green -> cyan -> blue -> magenta).
    canvas.drawRect(
      hueBar,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0xFFFF0000),
            Color(0xFFFFFF00),
            Color(0xFF00FF00),
            Color(0xFF00FFFF),
            Color(0xFF0000FF),
            Color(0xFFFF00FF),
            Color(0xFFFF0000),
          ],
        ).createShader(hueBar),
    );

    // 3. Alpha bar over a checkerboard pattern.
    const tile = 6.0;
    for (double y = alphaBar.top; y < alphaBar.bottom; y += tile) {
      for (double x = alphaBar.left; x < alphaBar.right; x += tile) {
        final isLight = (((x - alphaBar.left) / tile).round() +
                ((y - alphaBar.top) / tile).round())
            .isEven;
        canvas.drawRect(
          Rect.fromLTWH(x, y, tile, tile),
          Paint()..color = isLight ? surfaceVariant : outline,
        );
      }
    }
    final opaque = HSVColor.fromAHSV(1, hue, sat, val).toColor();
    canvas.drawRect(
      alphaBar,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [opaque.withAlpha(0), opaque],
        ).createShader(alphaBar),
    );

    // 4. Borders.
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = outline;
    canvas.drawRect(square, border);
    canvas.drawRect(hueBar, border);
    canvas.drawRect(alphaBar, border);

    // 5. Draggable pointers.
    void pointer(double x, double y) {
      final center = Offset(x, y);
      canvas.drawCircle(center, 10, Paint()..color = Colors.white);
      canvas.drawCircle(
        center,
        10,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.black,
      );
    }

    pointer(
      square.left + sat * square.width,
      square.top + (1 - val) * square.height,
    );
    pointer(hueBar.center.dx, square.top + (hue / 360) * square.height);
    pointer(
      square.left + (alpha / 255) * alphaBar.width,
      alphaBar.center.dy,
    );
  }

  @override
  bool shouldRepaint(covariant _ColorPickerPainter old) {
    return old.hue != hue ||
        old.sat != sat ||
        old.val != val ||
        old.alpha != alpha ||
        old.outline != outline ||
        old.surfaceVariant != surfaceVariant;
  }
}
