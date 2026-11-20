import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Port of the Android `PasswordManager`.
///
/// The original stores the password / private key inside Android
/// `EncryptedSharedPreferences` ("PrivatePrefs"). To stay cross-platform
/// (Android, iOS and Web) this port uses `SharedPreferences` with the same
/// logical keys. All user-facing strings and validation rules are kept intact.
class PasswordManager {
  PasswordManager._();

  static const String prefsName = 'PrivatePrefs';
  static const String passwordKey = 'password_key';
  static const String privateKeyKey = 'private_key';

  /// Bumped whenever the password or private key changes so open screens can
  /// refresh their state (the Java version calls `eventHandler.setupPreferences`).
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static SharedPreferences? _prefs;

  static Future<SharedPreferences> get _store async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Mirrors `PasswordManager.init(context)`.
  static Future<void> init() async {
    await _store;
  }

  static Future<bool> isPasswordSet() async {
    return (await _store).containsKey(passwordKey);
  }

  static Future<bool> isPrivateKeySet() async {
    return (await _store).containsKey(privateKeyKey);
  }

  static Future<String> getPrivateKey() async {
    return (await _store).getString(privateKeyKey) ?? '';
  }

  static Future<String> getPassword() async {
    return (await _store).getString(passwordKey) ?? '';
  }

  static Future<void> setPassword(String password) async {
    await (await _store).setString(passwordKey, password);
    changes.value++;
  }

  static Future<void> setPrivateKey(String key) async {
    await (await _store).setString(privateKeyKey, key);
    changes.value++;
  }

  /// Mirrors the "Reset" action in `showPasswordPrompt`.
  static Future<void> resetAll() async {
    final prefs = await _store;
    await prefs.remove(passwordKey);
    await prefs.remove(privateKeyKey);
    changes.value++;
  }

  /// Port of `showSetPasswordDialog`.
  ///
  /// Returns true when a password was saved (the caller then opens the
  /// private-key dialog).
  static Future<bool> showSetPasswordDialog(BuildContext context) async {
    final controller = TextEditingController();
    bool obscure = true;
    String? error;
    bool saved = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Set Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Set a password to protect your private key.'),
                  const SizedBox(height: 16),
                  _SecretField(
                    controller: controller,
                    hintText: 'Minimum 8 characters',
                    errorText: error,
                    obscure: obscure,
                    onVisibilityChanged: (visible) =>
                        setState(() => obscure = !visible),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (controller.text.trim().isEmpty) {
                      setState(() => error = "You can't leave it empty");
                      return;
                    }
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final password = controller.text;
                    String? validation;
                    if (password.length < 8) {
                      validation = 'Password must be at least 8 characters long.';
                    } else if (!RegExp(r'[A-Za-z]').hasMatch(password)) {
                      validation = 'Password must contain at least one letter.';
                    } else if (!RegExp(r'\d').hasMatch(password)) {
                      validation = 'Password must contain at least one number.';
                    }
                    if (validation != null) {
                      setState(() => error = validation);
                      return;
                    }
                    await setPassword(password);
                    saved = true;
                    if (context.mounted) Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    return saved;
  }

  /// Port of `showPasswordPrompt`. Returns true on a successful match.
  static Future<bool> showPasswordPrompt(BuildContext context) async {
    final controller = TextEditingController();
    bool obscure = true;
    String? error;
    bool matched = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Enter Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SecretField(
                    controller: controller,
                    hintText: 'Enter password',
                    errorText: error,
                    obscure: obscure,
                    onVisibilityChanged: (visible) =>
                        setState(() => obscure = !visible),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    await resetAll();
                    if (context.mounted) {
                      Navigator.of(dialogContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Password and private key reset'),
                        ),
                      );
                    }
                  },
                  child: const Text('Reset'),
                ),
                FilledButton(
                  onPressed: () async {
                    // Read at submit time so a password changed elsewhere
                    // while the dialog was open is not silently accepted.
                    final expected = await getPassword();
                    if (controller.text == expected) {
                      matched = true;
                      Navigator.of(dialogContext).pop();
                    } else {
                      setState(() => error = 'Incorrect password');
                    }
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    return matched;
  }

  /// Port of `showPrivateKeyDialog`.
  static Future<void> showPrivateKeyDialog(BuildContext context) async {
    final prefill = await getPrivateKey();
    final controller = TextEditingController(text: prefill);
    bool obscure = true;
    String? error;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Private Key'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SecretField(
                    controller: controller,
                    hintText: 'Enter private key',
                    errorText: error,
                    obscure: obscure,
                    onVisibilityChanged: (visible) =>
                        setState(() => obscure = !visible),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (controller.text.trim().isEmpty) {
                      setState(() => error = "You can't leave it empty");
                      return;
                    }
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    final key = controller.text;
                    if (key.isEmpty) {
                      setState(() =>
                          error = 'You must input at least a character.');
                      return;
                    }
                    await Clipboard.setData(ClipboardData(text: key));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Private key copied to clipboard'),
                        ),
                      );
                    }
                  },
                  child: const Text('Copy'),
                ),
                FilledButton(
                  onPressed: () async {
                    final key = controller.text;
                    if (key.isEmpty) {
                      setState(() =>
                          error = 'You must input at least a character.');
                      return;
                    }
                    await setPrivateKey(key);
                    if (context.mounted) {
                      Navigator.of(dialogContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Private key saved')),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
  }

  /// Port of `startBiometricAuth`.
  ///
  /// The Android version first tries BiometricPrompt when device security is
  /// set up, falling back to a password flow. This cross-platform port uses
  /// the password flow directly (no native biometric plugin dependency).
  static Future<void> startBiometricAuth(
    BuildContext context, {
    bool optionMenuItem = false,
  }) async {
    if (!optionMenuItem) {
      if (await showSetPasswordDialog(context)) {
        await showPrivateKeyDialog(context);
      }
      return;
    }

    if (await isPrivateKeySet()) {
      if (await showPasswordPrompt(context)) {
        await showPrivateKeyDialog(context);
      }
    } else {
      if (await showSetPasswordDialog(context)) {
        await showPrivateKeyDialog(context);
      }
    }
  }
}

/// The obscured text field plus its "Show Password" checkbox, shared by all
/// three password dialogs so their appearance and behaviour stay identical.
class _SecretField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final String? errorText;
  final bool obscure;
  final ValueChanged<bool> onVisibilityChanged;

  const _SecretField({
    required this.controller,
    required this.hintText,
    required this.errorText,
    required this.obscure,
    required this.onVisibilityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: hintText,
            errorText: errorText,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
              onPressed: () => onVisibilityChanged(obscure),
            ),
          ),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show Password'),
          value: !obscure,
          onChanged: (value) => onVisibilityChanged(value ?? false),
        ),
      ],
    );
  }
}
