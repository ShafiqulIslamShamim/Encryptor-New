import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../controllers/theme_controller.dart';
import '../../services/conversion_labels.dart';
import '../../services/conversion_manager.dart';
import '../../services/converters/color_converters.dart';
import '../../services/password_manager.dart';
import '../../services/preference_keys.dart';
import '../../widgets/number_result_view.dart';
import '../settings/settings_screen.dart';
import 'color_picker_dialog.dart';
import 'text_editor_screen.dart';

/// Port of the Android `ConversionDetailActivity`, together with the wiring
/// from `UIInitializer` and `EventHandler`.
class ConversionDetailScreen extends StatefulWidget {
  final String title;
  final String entryValue;
  final ThemeController? themeController;

  const ConversionDetailScreen({
    super.key,
    required this.title,
    required this.entryValue,
    this.themeController,
  });

  @override
  State<ConversionDetailScreen> createState() => _ConversionDetailScreenState();
}

class _ConversionDetailScreenState extends State<ConversionDetailScreen> {
  late final int _index;
  late final TextEditingController _inputController;
  late final TextEditingController _resultController;
  late final FocusNode _inputFocus;
  late final FocusNode _resultFocus;

  bool _programmatic = false;
  bool _isInputFocused = true;
  bool _useHexFormat = false;
  bool _readOnlyResult = false;
  String? _error;
  bool _passwordPromptShown = false;

  /// Incremented for every conversion request so a slow result cannot
  /// overwrite the output of a newer one.
  int _conversionRequestId = 0;

  @override
  void initState() {
    super.initState();
    _index = int.tryParse(widget.entryValue) ?? 27;
    _inputController = TextEditingController();
    _resultController = TextEditingController();
    _inputFocus = FocusNode();
    _resultFocus = FocusNode();

    _inputFocus.addListener(() {
      setState(() {});
      _onFocusChanged(true);
    });
    _resultFocus.addListener(() {
      setState(() {});
      _onFocusChanged(false);
    });
    _inputController.addListener(() {
      setState(() {});
      _onTextChanged(true);
    });
    _resultController.addListener(() {
      setState(() {});
      _onTextChanged(false);
    });

    PasswordManager.init();
    _loadHexMode();
  }

  Future<void> _loadHexMode() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _useHexFormat = prefs.getString(PreferenceKeys.converterHex) == '1';
    });
    await _runConversion();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _resultController.dispose();
    _inputFocus.dispose();
    _resultFocus.dispose();
    super.dispose();
  }

  void _onFocusChanged(bool inputFocused) {
    if (!mounted) return;
    if (inputFocused && !_inputFocus.hasFocus) return;
    if (!inputFocused && !_resultFocus.hasFocus) return;
    _isInputFocused = inputFocused;
    _runConversion();
  }

  void _onTextChanged(bool isInput) {
    if (_programmatic) return;
    final controller = isInput ? _inputController : _resultController;

    if (controller.text.isEmpty) {
      _writeField(!isInput, '');
      setState(() => _error = null);
      return;
    }
    _runConversion();
  }

  void _writeField(bool input, String text) {
    final controller = input ? _inputController : _resultController;
    _programmatic = true;
    final selection = controller.selection;
    controller.value = controller.value.copyWith(
      text: text,
      selection: selection.copyWith(
        baseOffset: selection.baseOffset.clamp(0, text.length),
        extentOffset: selection.extentOffset.clamp(0, text.length),
      ),
    );
    _programmatic = false;
  }

  Future<void> _runConversion() async {
    final requestId = ++_conversionRequestId;
    final outcome = await ConversionManager.perform(
      entryValue: widget.entryValue,
      input: _inputController.text,
      result: _resultController.text,
      isInputFocused: _isInputFocused,
      useHexFormat: _useHexFormat,
    );
    if (!mounted || requestId != _conversionRequestId) return;

    setState(() {
      _error = outcome.error;
      _readOnlyResult = outcome.readOnlyResult;
      if (outcome.input != null) _writeField(true, outcome.input!);
      if (outcome.result != null) _writeField(false, outcome.result!);
    });

    await _maybePromptForPrivateKey(outcome.error);
  }

  /// Java cases 27/30 prompt for password setup when encryption fails because
  /// no private key has been configured. Prompt at most once per screen visit:
  /// cancelling the dialog used to trigger the same failure again forever.
  Future<void> _maybePromptForPrivateKey(String? error) async {
    if (error == null ||
        _passwordPromptShown ||
        !ConversionLabels.isEncryptionMode(_index) ||
        !mounted) {
      return;
    }
    final hasKey = await PasswordManager.isPrivateKeySet();
    final alias = await PasswordManager.getPrivateKey();
    if (hasKey || alias.isNotEmpty) return;

    _passwordPromptShown = true;
    await PasswordManager.startBiometricAuth(context, optionMenuItem: false);
    if (mounted) await _runConversion();
  }

  Future<void> _toggleHexMode() async {
    final prefs = await SharedPreferences.getInstance();
    final newValue = !_useHexFormat;
    await prefs.setString(PreferenceKeys.converterHex, newValue ? '1' : '0');
    setState(() => _useHexFormat = newValue);
    await _runConversion();
  }

  void _reset() {
    _writeField(true, '');
    _writeField(false, '');
    setState(() => _error = null);
    _inputFocus.requestFocus();
  }

  void _swapFields() {
    if (_readOnlyResult) return;
    final inText = _inputController.text;
    final resText = _resultController.text;
    _writeField(true, resText);
    _writeField(false, inText);
    _isInputFocused = !_isInputFocused;
    _runConversion();
  }

  Future<void> _copy(bool input) async {
    final text = (input ? _inputController : _resultController).text;
    if (text.isEmpty) {
      _toast('No text to copy');
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    _toast('Copied successfully');
  }

  Future<void> _copyValue(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    _toast('Copied: $value');
  }

  Future<void> _paste(bool input) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) {
      _toast('Clipboard is empty');
      return;
    }
    (input ? _inputController : _resultController).text = text;
    _isInputFocused = input;
    await _runConversion();
  }

  Future<void> _expand(bool input) async {
    final target = input ? 1 : 2;
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => TextEditorScreen(
          initialText: (input ? _inputController : _resultController).text,
          title: input
              ? ConversionLabels.inputLabel(_index)
              : ConversionLabels.outputLabel(_index),
          targetField: target,
        ),
      ),
    );
    if (result == null || !mounted) return;

    final text = result[TextEditorScreen.extraText] as String?;
    if (text == null) return;
    _writeField(input, text);
    _isInputFocused = input;
    await _runConversion();
  }

  Future<void> _import(bool input) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['txt'],
      );
      if (files.isEmpty) {
        _toast('Cancelled');
        return;
      }

      final bytes = await files.single.readAsBytes();
      final text = utf8.decode(bytes, allowMalformed: true);
      (input ? _inputController : _resultController).text = text;
      _isInputFocused = input;
      await _runConversion();
    } catch (e) {
      _toast('Failed to read file: $e');
    }
  }

  Future<void> _export(bool input) async {
    final text = (input ? _inputController : _resultController).text;
    if (text.isEmpty) {
      _toast('No text to export');
      return;
    }

    final now = DateTime.now();
    final name = 'Encryptor_Export_'
        '${_two(now.year)}${_two(now.month)}${_two(now.day)}_'
        '${_two(now.hour)}${_two(now.minute)}${_two(now.second)}.txt';
    final bytes = Uint8List.fromList(utf8.encode(text));

    try {
      final uri = await FilePicker.saveFile(
        dialogTitle: 'Save As',
        fileName: name,
        bytes: bytes,
        mimeType: 'text/plain',
      );
      if (uri == null) {
        _toast('Cancelled');
        return;
      }
      _toast('Saved: $name');
    } catch (e) {
      _toast('Error: $e');
    }
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  Future<void> _share(bool input) async {
    final text = (input ? _inputController : _resultController).text;
    if (text.isEmpty) {
      _toast('No text to share');
      return;
    }
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, subject: 'Encryptor'),
      );
    } catch (e) {
      _toast('Error: $e');
    }
  }

  /// Parses the current input as a packed ARGB color, or null when invalid.
  int? _inputColor() {
    return ColorConverters.parseColor(
      ColorConverters.normalizeHex(_inputController.text),
    );
  }

  Future<void> _pickColor() async {
    final initial = _inputColor() ?? 0xFFFF0000;
    final selected = await ColorPickerDialog.show(context, initialColor: initial);
    if (selected == null || !mounted) return;

    setState(() => _error = null);
    final hex = ColorConverters.formatArgbHex(selected, uppercase: true);
    _writeField(true, hex);
    _isInputFocused = true;
    await _runConversion();
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

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          themeController: widget.themeController ?? ThemeController(),
        ),
      ),
    );
  }

  TextInputType _getInputKeyboardType() {
    if (_index == 16) return TextInputType.number;
    if (_index >= 21 && _index <= 25) {
      return const TextInputType.numberWithOptions(decimal: true, signed: true);
    }
    return TextInputType.multiline;
  }

  bool get _canSwap =>
      !_readOnlyResult &&
      !ConversionLabels.isNumberSystem(_index) &&
      !(_index >= 3 && _index <= 8); // Not hashes

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final inputLabel = ConversionLabels.inputLabel(_index);
    final outputLabel = ConversionLabels.outputLabel(_index);
    final parsedColor =
        ConversionLabels.isColorMode(_index) ? _inputColor() : null;
    final highlight = parsedColor != null ? Color(parsedColor) : null;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (ConversionLabels.isColorMode(_index))
            IconButton(
              icon: const Icon(Icons.palette_outlined),
              tooltip: 'Pick color',
              onPressed: _pickColor,
            ),
          if (ConversionLabels.isEncryptionMode(_index))
            IconButton(
              icon: const Icon(Icons.key_rounded),
              tooltip: 'Private Key',
              onPressed: () =>
                  PasswordManager.startBiometricAuth(context, optionMenuItem: true),
            ),
          if (ConversionLabels.isByteArrayMode(_index))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: FilterChip(
                label: Text(
                  _useHexFormat ? 'HEX: ON' : 'HEX: OFF',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _useHexFormat
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                selected: _useHexFormat,
                onSelected: (_) => _toggleHexMode(),
                selectedColor: colorScheme.primary,
                checkmarkColor: colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Clear & Reset',
            onPressed: _reset,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Error Alert Banner
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colorScheme.error.withAlpha(80),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded,
                          color: colorScheme.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: colorScheme.onErrorContainer,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        color: colorScheme.onErrorContainer,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => setState(() => _error = null),
                      ),
                    ],
                  ),
                ),

              // Color Swatch Bar (for Color converters)
              if (ConversionLabels.isColorMode(_index))
                _ColorPreviewCard(
                  highlight: highlight,
                  hexText: _inputController.text,
                  onPickColor: _pickColor,
                ),

              // Input Card
              _ModernConversionCard(
                label: inputLabel,
                tag: 'INPUT',
                controller: _inputController,
                focusNode: _inputFocus,
                isFocused: _inputFocus.hasFocus,
                readOnly: false,
                keyboardType: _getInputKeyboardType(),
                onExpand: () => _expand(true),
                onCopy: () => _copy(true),
                onPaste: () => _paste(true),
                onClear: () {
                  _writeField(true, '');
                  _runConversion();
                },
                onShare: () => _share(true),
                onImport: () => _import(true),
                onExport: () => _export(true),
                showReload: false,
                highlightColor: highlight,
              ),

              // Interactive Swap Divider
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: colorScheme.outlineVariant.withAlpha(100),
                        thickness: 1,
                      ),
                    ),
                    if (_canSwap)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: IconButton.filledTonal(
                          onPressed: _swapFields,
                          tooltip: 'Swap Input & Result',
                          icon: const Icon(Icons.swap_vert_rounded, size: 20),
                          style: IconButton.styleFrom(
                            backgroundColor: colorScheme.secondaryContainer,
                            foregroundColor: colorScheme.onSecondaryContainer,
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(
                          Icons.arrow_downward_rounded,
                          size: 18,
                          color: colorScheme.onSurfaceVariant.withAlpha(100),
                        ),
                      ),
                    Expanded(
                      child: Divider(
                        color: colorScheme.outlineVariant.withAlpha(100),
                        thickness: 1,
                      ),
                    ),
                  ],
                ),
              ),

              // Result Card
              _ModernConversionCard(
                label: outputLabel,
                tag: 'RESULT',
                controller: _resultController,
                focusNode: _resultFocus,
                isFocused: _resultFocus.hasFocus,
                readOnly: _readOnlyResult,
                keyboardType: TextInputType.multiline,
                onExpand: () => _expand(false),
                onCopy: () => _copy(false),
                onPaste: () => _paste(false),
                onClear: () {
                  _writeField(false, '');
                  _runConversion();
                },
                onShare: () => _share(false),
                onImport: () => _import(false),
                onExport: () => _export(false),
                showReload: _index == 27,
                highlightColor: highlight,
                clickableValues: ConversionLabels.isNumberSystem(_index),
                onCopyValue: _copyValue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorPreviewCard extends StatelessWidget {
  final Color? highlight;
  final String hexText;
  final VoidCallback onPickColor;

  const _ColorPreviewCard({
    required this.highlight,
    required this.hexText,
    required this.onPickColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = highlight ?? Colors.transparent;

    return Container(
      height: 58,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: colorScheme.outline.withAlpha(120),
                width: 1.5,
              ),
              boxShadow: [
                if (highlight != null)
                  BoxShadow(
                    color: color.withAlpha(80),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              highlight != null ? 'Preview: $hexText' : 'Select or enter a color',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: onPickColor,
            icon: const Icon(Icons.colorize_rounded, size: 16),
            label: const Text('Picker'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernConversionCard extends StatelessWidget {
  final String label;
  final String tag;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isFocused;
  final bool readOnly;
  final TextInputType keyboardType;
  final VoidCallback onExpand;
  final VoidCallback onCopy;
  final VoidCallback onPaste;
  final VoidCallback onClear;
  final VoidCallback onShare;
  final VoidCallback onImport;
  final VoidCallback onExport;
  final bool showReload;
  final Color? highlightColor;
  final bool clickableValues;
  final ValueChanged<String>? onCopyValue;

  const _ModernConversionCard({
    required this.label,
    required this.tag,
    required this.controller,
    required this.focusNode,
    required this.isFocused,
    required this.readOnly,
    required this.keyboardType,
    required this.onExpand,
    required this.onCopy,
    required this.onPaste,
    required this.onClear,
    required this.onShare,
    required this.onImport,
    required this.onExport,
    required this.showReload,
    this.highlightColor,
    this.clickableValues = false,
    this.onCopyValue,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final text = controller.text;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isFocused
              ? colorScheme.primary
              : colorScheme.outlineVariant.withAlpha(150),
          width: isFocused ? 1.6 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isFocused
                ? colorScheme.primary.withAlpha(15)
                : Colors.black.withAlpha(6),
            blurRadius: isFocused ? 10 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: isFocused
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      color: isFocused
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isFocused ? colorScheme.primary : colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (text.isNotEmpty)
                  Text(
                    '${text.length} chars',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant.withAlpha(140),
                    ),
                  ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.open_in_full_rounded, size: 18),
                  tooltip: 'Fullscreen Editor',
                  onPressed: onExpand,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.secondaryContainer.withAlpha(120),
                    foregroundColor: colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),

          // Content Field
          if (clickableValues)
            Container(
              constraints: const BoxConstraints(minHeight: 140),
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: NumberResultView(
                text: text,
                onCopyValue: onCopyValue ?? (_) {},
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Stack(
                children: [
                  TextField(
                    controller: controller,
                    focusNode: focusNode,
                    readOnly: readOnly,
                    maxLines: null,
                    minLines: 5,
                    keyboardType: keyboardType,
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'monospace',
                      height: 1.4,
                    ),
                    decoration: InputDecoration(
                      hintText: readOnly
                          ? 'Converted result will appear here'
                          : 'Type or paste $label...',
                      hintStyle: TextStyle(
                        color: colorScheme.onSurfaceVariant.withAlpha(120),
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: colorScheme.outlineVariant.withAlpha(100),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: colorScheme.outlineVariant.withAlpha(100),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: colorScheme.primary,
                          width: 1.5,
                        ),
                      ),
                      filled: true,
                      fillColor: highlightColor != null
                          ? highlightColor!.withAlpha(30)
                          : colorScheme.surfaceContainerLow.withAlpha(120),
                      contentPadding: const EdgeInsets.fromLTRB(14, 12, 40, 12),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: text.isNotEmpty && !readOnly
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            tooltip: 'Clear',
                            color: colorScheme.onSurfaceVariant,
                            onPressed: onClear,
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(6),
                          )
                        : (text.isEmpty && !readOnly
                            ? IconButton(
                                icon: const Icon(Icons.content_paste_rounded,
                                    size: 18),
                                tooltip: 'Paste',
                                color: colorScheme.primary,
                                onPressed: onPaste,
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(6),
                              )
                            : const SizedBox.shrink()),
                  ),
                ],
              ),
            ),

          // Action Toolbar Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _CardActionButton(
                  icon: Icons.copy_rounded,
                  label: 'Copy',
                  colorScheme: colorScheme,
                  onPressed: onCopy,
                ),
                if (!readOnly)
                  _CardActionButton(
                    icon: Icons.content_paste_rounded,
                    label: 'Paste',
                    colorScheme: colorScheme,
                    onPressed: onPaste,
                  ),
                if (showReload)
                  _CardActionButton(
                    icon: Icons.refresh_rounded,
                    label: 'Reload',
                    colorScheme: colorScheme,
                    onPressed: () => focusNode.requestFocus(),
                  ),
                _CardActionButton(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  colorScheme: colorScheme,
                  onPressed: onShare,
                ),
                if (!readOnly)
                  _CardActionButton(
                    icon: Icons.file_upload_outlined,
                    label: 'Import',
                    colorScheme: colorScheme,
                    onPressed: onImport,
                  ),
                _CardActionButton(
                  icon: Icons.file_download_outlined,
                  label: 'Export',
                  colorScheme: colorScheme,
                  onPressed: onExport,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme colorScheme;
  final VoidCallback onPressed;

  const _CardActionButton({
    required this.icon,
    required this.label,
    required this.colorScheme,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh.withAlpha(160),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: colorScheme.outlineVariant.withAlpha(80),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
