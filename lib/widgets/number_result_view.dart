import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

/// Port of `NumberSystemUtils.setCopyableResults`.
///
/// Renders the four-line "Decimal / Binary / Octal / Hex" result where every
/// value is tappable and copied with a "Copied: <value>" toast, just like the
/// Java `ClickableSpan`s.
class NumberResultView extends StatefulWidget {
  final String text;
  final ValueChanged<String> onCopyValue;

  const NumberResultView({
    super.key,
    required this.text,
    required this.onCopyValue,
  });

  @override
  State<NumberResultView> createState() => _NumberResultViewState();
}

class _NumberResultViewState extends State<NumberResultView> {
  /// Stable recognizers, keyed by the value they copy. Recreating them inside
  /// [build] would dispose gestures that are currently in flight and churn
  /// objects on every rebuild.
  final Map<String, TapGestureRecognizer> _recognizers = {};

  @override
  void initState() {
    super.initState();
    _syncRecognizers();
  }

  @override
  void didUpdateWidget(covariant NumberResultView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _syncRecognizers();
    }
  }

  @override
  void dispose() {
    for (final recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    _recognizers.clear();
    super.dispose();
  }

  void _syncRecognizers() {
    final values = <String>{};
    for (final line in widget.text.split('\n')) {
      final value = _splitLine(line).value;
      if (value.isNotEmpty) values.add(value);
    }

    for (final key in _recognizers.keys.toList()) {
      if (!values.contains(key)) {
        _recognizers.remove(key)!.dispose();
      }
    }
    for (final value in values) {
      final recognizer = _recognizers.putIfAbsent(
        value,
        () => TapGestureRecognizer(),
      );
      recognizer.onTap = () => widget.onCopyValue(value);
    }
  }

  /// Splits "Label:   value" into its label (including the alignment spaces)
  /// and the value, matching the Java four-line layout.
  static ({String label, String value}) _splitLine(String line) {
    final colon = line.indexOf(':');
    if (colon < 0) return (label: line, value: '');

    final label = line.substring(0, colon + 1);
    final rest = line.substring(colon + 1);
    final trimmed = rest.trimLeft();
    return (
      label: label + rest.substring(0, rest.length - trimmed.length),
      value: trimmed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const baseStyle = TextStyle(fontFamily: 'monospace', fontSize: 14);
    final valueStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: colorScheme.primary,
      decoration: TextDecoration.none,
    );

    final spans = <TextSpan>[];
    final lines = widget.text.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final parts = _splitLine(lines[i]);
      spans.add(TextSpan(text: parts.label, style: baseStyle));

      if (parts.value.isNotEmpty) {
        spans.add(
          TextSpan(
            text: parts.value,
            style: valueStyle,
            recognizer: _recognizers[parts.value],
          ),
        );
      }
      if (i != lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return SelectableText.rich(
      TextSpan(children: spans),
      style: baseStyle,
    );
  }
}
