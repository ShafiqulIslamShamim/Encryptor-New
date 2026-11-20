import 'package:dynamic_color/dynamic_color.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'controllers/theme_controller.dart';
import 'screens/home_screen.dart';
import 'screens/settings/settings_screen.dart';

const MethodChannel _shortcutChannel =
    MethodChannel('com.shamim.encryptor/shortcut');

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
ThemeController? _rootThemeController;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // A shortcut tapped while the app is already running arrives here instead
  // of through the initial `getShortcutTarget` call.
  _shortcutChannel.setMethodCallHandler((call) async {
    if (call.method == 'shortcutTargetChanged' && call.arguments == 'settings') {
      final context = _rootNavigatorKey.currentContext;
      final controller = _rootThemeController;
      if (context != null && controller != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SettingsScreen(themeController: controller),
          ),
        );
      }
    }
  });

  runApp(const EncryptorApp());
}

class EncryptorApp extends StatefulWidget {
  const EncryptorApp({super.key});

  @override
  State<EncryptorApp> createState() => _EncryptorAppState();
}

class _EncryptorAppState extends State<EncryptorApp> {
  final ThemeController themeController = ThemeController();

  @override
  void initState() {
    super.initState();
    _rootThemeController = themeController;
    themeController.loadSettings();

    // The Flutter engine (and its MethodChannel handler) exists only after
    // the first frame, so read the shortcut target here, not in main().
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      String? target;
      try {
        target = await _shortcutChannel.invokeMethod<String>('getShortcutTarget');
      } catch (_) {}
      if (target == 'settings' && mounted) {
        final context = _rootNavigatorKey.currentContext;
        if (context != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SettingsScreen(themeController: themeController),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final hasDynamic = lightDynamic != null || darkDynamic != null;
        if (themeController.isDynamicSupported.value != hasDynamic) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            themeController.isDynamicSupported.value = hasDynamic;
          });
        }

        return ListenableBuilder(
          listenable: Listenable.merge([
            themeController.mode,
            themeController.color,
            themeController.isAmoled,
            themeController.isDynamicSupported,
          ]),
          builder: (context, _) {
            final selectedMode = themeController.mode.value;
            final selectedColor = themeController.color.value;
            final isAmoled = themeController.isAmoled.value;

            final lightScheme = createColorScheme(
              brightness: Brightness.light,
              selectedColor: selectedColor,
              dynamicScheme: lightDynamic,
            );

            final darkScheme = createColorScheme(
              brightness: Brightness.dark,
              selectedColor: selectedColor,
              dynamicScheme: darkDynamic,
            );

            final effectiveDarkScheme = isAmoled
                ? darkScheme.copyWith(
                    surface: Colors.black,
                    surfaceDim: Colors.black,
                    surfaceBright: Colors.black,
                    surfaceContainerLowest: Colors.black,
                    surfaceContainerLow: Colors.black,
                    surfaceContainer: Colors.black,
                    surfaceContainerHigh: Colors.black,
                    surfaceContainerHighest: Colors.black,
                  )
                : darkScheme;

            return MaterialApp(
              debugShowCheckedModeBanner: false,
              navigatorKey: _rootNavigatorKey,
              theme: ThemeData(
                colorScheme: lightScheme,
                useMaterial3: true,
                scaffoldBackgroundColor: lightScheme.surface,
                appBarTheme: AppBarTheme(backgroundColor: lightScheme.surface),
                navigationBarTheme: NavigationBarThemeData(
                  backgroundColor: lightScheme.surface,
                  indicatorColor: lightScheme.secondaryContainer,
                ),
              ),
              darkTheme: ThemeData(
                colorScheme: effectiveDarkScheme,
                useMaterial3: true,
                scaffoldBackgroundColor: isAmoled
                    ? Colors.black
                    : effectiveDarkScheme.surface,
                appBarTheme: AppBarTheme(
                  backgroundColor: isAmoled
                      ? Colors.black
                      : effectiveDarkScheme.surface,
                ),
                navigationBarTheme: NavigationBarThemeData(
                  backgroundColor: isAmoled
                      ? Colors.black
                      : effectiveDarkScheme.surface,
                  indicatorColor: effectiveDarkScheme.secondaryContainer,
                ),
              ),
              themeMode: switch (selectedMode) {
                AppThemeMode.system => ThemeMode.system,
                AppThemeMode.light => ThemeMode.light,
                AppThemeMode.dark => ThemeMode.dark,
              },
              home: HomeScreen(themeController: themeController),
              builder: (context, child) {
                final brightness = MediaQuery.platformBrightnessOf(context);

                final bool isDark = switch (selectedMode) {
                  AppThemeMode.system => brightness == Brightness.dark,
                  AppThemeMode.light => false,
                  AppThemeMode.dark => true,
                };

                final surfaceColor = isDark
                    ? (isAmoled ? Colors.black : effectiveDarkScheme.surface)
                    : lightScheme.surface;

                final systemUiStyle = SystemUiOverlayStyle(
                  systemNavigationBarColor: surfaceColor,
                  systemNavigationBarIconBrightness: isDark
                      ? Brightness.light
                      : Brightness.dark,
                  systemNavigationBarContrastEnforced: false,
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: isDark
                      ? Brightness.light
                      : Brightness.dark,
                  statusBarBrightness: isDark
                      ? Brightness.dark
                      : Brightness.light,
                );

                return AnnotatedRegion<SystemUiOverlayStyle>(
                  value: systemUiStyle,
                  child: child ?? const SizedBox.shrink(),
                );
              },
            );
          },
        );
      },
    );
  }

  ColorScheme createColorScheme({
    required Brightness brightness,
    required AppThemeColor selectedColor,
    required ColorScheme? dynamicScheme,
  }) {
    if (selectedColor == AppThemeColor.dynamic && dynamicScheme != null) {
      return dynamicScheme;
    }

    final seedColor = switch (selectedColor) {
      AppThemeColor.emerald => Colors.green,
      AppThemeColor.blossom => Colors.pink,
      AppThemeColor.ocean => Colors.blue,
      AppThemeColor.amber => Colors.amber,
      AppThemeColor.coral => Colors.deepOrange,
      AppThemeColor.dynamic => Colors.pink,
    };

    return ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);
  }
}