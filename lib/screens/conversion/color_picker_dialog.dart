import 'package:material_ui/material_ui.dart';

import '../../services/converters/color_converters.dart';
import '../../widgets/custom_color_picker_view.dart';

/// Flutter port of Java `ColorPickerDialogFragment` + `dialog_color_picker.xml`.
///
/// Shows the HSV/alpha picker, old/new previews with a checkerboard background,
/// two-way synced HEX and smali (`0x/-0x`) text fields, and OK/Cancel actions.
/// Returns the packed ARGB color chosen by the user.
class ColorPickerDialog extends StatefulWidget {
  final int initialColor;

  const ColorPickerDialog({super.key, required this.initialColor});

  static Future<int?> show(BuildContext context, {required int initialColor}) {
    return showDialog<int>(
      context: context,
      builder: (_) => ColorPickerDialog(initialColor: initialColor),
    );
  }

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  final GlobalKey<CustomColorPickerViewState> _pickerKey =
      GlobalKey<CustomColorPickerViewState>();
  final TextEditingController _hexController = TextEditingController();
  final TextEditingController _smaliController = TextEditingController();

  late int _initial;
  late int _selected;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _initial = widget.initialColor & 0xFFFFFFFF;
    _selected = _initial;
    _hexController.text = _formatHex(_initial);
    _smaliController.text = ColorConverters.colorToSmaliHex(_hexController.text);
    _hexController.addListener(_onHexChanged);
    _smaliController.addListener(_onSmaliChanged);
  }

  @override
  void dispose() {
    _hexController.dispose();
    _smaliController.dispose();
    super.dispose();
  }

  static String _formatHex(int color) =>
      ColorConverters.formatArgbHex(color, uppercase: true);

  void _onPickerChanged(int color) {
    if (_syncing) return;
    setState(() => _selected = color);

    _syncing = true;
    final hex = _formatHex(color);
    if (_hexController.text.toUpperCase() != hex) {
      _hexController.text = hex;
    }
    final smali = ColorConverters.colorToSmaliHex(hex);
    if (_smaliController.text.toLowerCase() != smali.toLowerCase()) {
      _smaliController.text = smali;
    }
    _syncing = false;
  }

  void _onHexChanged() {
    if (_syncing) return;
    final parsed = ColorConverters.parseColor(_hexController.text);
    if (parsed == null) return;

    final color = parsed & 0xFFFFFFFF;
    setState(() => _selected = color);
    _pickerKey.currentState?.setColor(color);

    _syncing = true;
    final smali = ColorConverters.colorToSmaliHex(_formatHex(color));
    if (_smaliController.text.toLowerCase() != smali.toLowerCase()) {
      _smaliController.text = smali;
    }
    _syncing = false;
  }

  void _onSmaliChanged() {
    if (_syncing) return;
    final hex = ColorConverters.hexNumberToArgbHex(_smaliController.text);
    if (hex == null) return;
    final parsed = ColorConverters.parseColor(hex);
    if (parsed == null) return;

    final color = parsed & 0xFFFFFFFF;
    setState(() => _selected = color);
    _pickerKey.currentState?.setColor(color);

    _syncing = true;
    if (_hexController.text.toUpperCase() != hex.toUpperCase()) {
      _hexController.text = hex.toUpperCase();
    }
    _syncing = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return AlertDialog(
      title: Text(
        'Select a color',
        style: textTheme.titleLarge?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomColorPickerView(
              key: _pickerKey,
              color: _initial,
              onColorChanged: _onPickerChanged,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Expanded(child: _ColorSwatch(color: _initial)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('→', style: TextStyle(fontSize: 18)),
                  ),
                  Expanded(child: _ColorSwatch(color: _selected)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _hexController,
              decoration: const InputDecoration(
                hintText: '#RRGGBBAA',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _smaliController,
              decoration: const InputDecoration(
                hintText: '#RRGGBBAA',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

/// Checkerboard-backed color preview (Java `ColorPreviewDrawable`).
class _ColorSwatch extends StatelessWidget {
  final int color;

  const _ColorSwatch({required this.color});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 30,
      child: CustomPaint(
        painter: _CheckerPainter(
          light: colorScheme.surfaceContainerHighest,
          dark: colorScheme.outline,
          overlay: Color(color),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _CheckerPainter extends CustomPainter {
  final Color light;
  final Color dark;
  final Color overlay;

  const _CheckerPainter({
    required this.light,
    required this.dark,
    required this.overlay,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const tile = 6.0;
    for (int row = 0; row * tile < size.height; row++) {
      for (int column = 0; column * tile < size.width; column++) {
        canvas.drawRect(
          Rect.fromLTWH(column * tile, row * tile, tile, tile),
          Paint()..color = (row + column).isEven ? light : dark,
        );
      }
    }
    canvas.drawRect(Offset.zero & size, Paint()..color = overlay);

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..color = dark;
    canvas.drawRect(Offset.zero & size, border);
  }

  @override
  bool shouldRepaint(covariant _CheckerPainter old) =>
      old.light != light || old.dark != dark || old.overlay != overlay;
}
