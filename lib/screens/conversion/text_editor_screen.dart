import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

/// Port of the Android `TextEditorActivity`.
///
/// A generic full-screen editor. Returns the edited text together with the
/// unchanged [targetField] (1 = input field, 2 = result field) so the caller
/// can recompute the conversion in the correct direction.
class TextEditorScreen extends StatefulWidget {
  static const String extraText = 'extra_text';
  static const String extraTitle = 'extra_title';
  static const String extraTargetField = 'extra_target_field';

  final String? initialText;
  final String? title;
  final int targetField;

  const TextEditorScreen({
    super.key,
    this.initialText,
    this.title,
    this.targetField = 1,
  });

  @override
  State<TextEditorScreen> createState() => _TextEditorScreenState();
}

class _TextEditorScreenState extends State<TextEditorScreen> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  double _fontSize = 14.0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText ?? '');
    _focusNode = FocusNode();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  int get _charCount => _controller.text.length;

  int get _wordCount {
    final trimmed = _controller.text.trim();
    return trimmed.isEmpty ? 0 : trimmed.split(RegExp(r'\s+')).length;
  }

  int get _lineCount {
    if (_controller.text.isEmpty) return 0;
    return '\n'.allMatches(_controller.text).length + 1;
  }

  Future<void> _copy() async {
    if (_controller.text.isEmpty) {
      _toast('No text to copy');
      return;
    }
    await Clipboard.setData(ClipboardData(text: _controller.text));
    _toast('Copied successfully');
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) {
      _toast('Clipboard is empty');
      return;
    }
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
    _toast('Pasted from clipboard');
  }

  void _selectAll() {
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
    _focusNode.requestFocus();
  }

  void _clear() {
    if (_controller.text.isEmpty) return;
    _controller.clear();
    _toast('Cleared text');
  }

  void _toggleCase() {
    final text = _controller.text;
    if (text.isEmpty) return;
    final selection = _controller.selection;

    // Check if current text is uppercase
    final isUpper = text == text.toUpperCase() && text != text.toLowerCase();
    final newText = isUpper ? text.toLowerCase() : text.toUpperCase();

    _controller.value = _controller.value.copyWith(
      text: newText,
      selection: selection,
    );
    _toast(isUpper ? 'Converted to lowercase' : 'Converted to UPPERCASE');
  }

  void _zoomIn() {
    if (_fontSize < 24.0) {
      setState(() => _fontSize += 2.0);
    }
  }

  void _zoomOut() {
    if (_fontSize > 10.0) {
      setState(() => _fontSize -= 2.0);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _submit() {
    Navigator.of(context).pop(<String, dynamic>{
      TextEditorScreen.extraText: _controller.text,
      TextEditorScreen.extraTargetField: widget.targetField,
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = (widget.title != null && widget.title!.isNotEmpty)
        ? widget.title!
        : 'Text Editor';

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit $title',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${_charCount} chars • ${_wordCount} words • ${_lineCount} lines',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_decrease_rounded, size: 20),
            tooltip: 'Decrease font size',
            onPressed: _zoomOut,
          ),
          Center(
            child: Text(
              '${_fontSize.toInt()}pt',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.text_increase_rounded, size: 20),
            tooltip: 'Increase font size',
            onPressed: _zoomIn,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Quick Toolbar Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLowest,
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.outlineVariant.withAlpha(120),
                  ),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _ToolbarChip(
                      icon: Icons.select_all_rounded,
                      label: 'Select All',
                      onPressed: _selectAll,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(width: 6),
                    _ToolbarChip(
                      icon: Icons.transform_rounded,
                      label: 'Aa / aA',
                      onPressed: _toggleCase,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(width: 6),
                    _ToolbarChip(
                      icon: Icons.copy_rounded,
                      label: 'Copy',
                      onPressed: _copy,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(width: 6),
                    _ToolbarChip(
                      icon: Icons.content_paste_rounded,
                      label: 'Paste',
                      onPressed: _paste,
                      colorScheme: colorScheme,
                    ),
                    if (_controller.text.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _ToolbarChip(
                        icon: Icons.clear_all_rounded,
                        label: 'Clear',
                        onPressed: _clear,
                        colorScheme: colorScheme,
                        isDestructive: true,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Text Editor Area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _focusNode.hasFocus
                          ? colorScheme.primary.withAlpha(200)
                          : colorScheme.outlineVariant,
                      width: _focusNode.hasFocus ? 1.5 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: _fontSize,
                        height: 1.45,
                        letterSpacing: 0.2,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type, paste, or edit full text here...',
                        hintStyle: TextStyle(
                          color: colorScheme.onSurfaceVariant.withAlpha(140),
                          fontFamily: 'monospace',
                          fontSize: _fontSize,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Sticky Action Bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outlineVariant.withAlpha(120),
                  ),
                ),
              ),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.check_rounded, size: 20),
                      label: const Text(
                        'Apply & Submit',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final ColorScheme colorScheme;
  final bool isDestructive;

  const _ToolbarChip({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.colorScheme,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isDestructive
        ? colorScheme.error
        : colorScheme.onSurfaceVariant;
    final bg = isDestructive
        ? colorScheme.errorContainer.withAlpha(100)
        : colorScheme.surfaceContainerHigh;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDestructive
                  ? colorScheme.error.withAlpha(80)
                  : colorScheme.outlineVariant.withAlpha(120),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
