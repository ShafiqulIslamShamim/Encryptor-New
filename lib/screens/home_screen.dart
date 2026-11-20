import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/theme_controller.dart';
import '../models/conversion_data.dart';
import '../services/preference_keys.dart';
import 'conversion/conversion_detail_screen.dart';
import 'settings/settings_screen.dart';

/// Shared left/right inset for the search field and the category cards so
/// their edges line up vertically.
const double _horizontalInset = 13;

/// Port of the Android `MainActivity`.
///
/// Shows a searchable, collapsible list of all conversion categories and
/// navigates to [ConversionDetailScreen] when an option is tapped.
class HomeScreen extends StatefulWidget {
  final ThemeController? themeController;

  const HomeScreen({super.key, this.themeController});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  late List<ConversionCategory> _categories;
  String _selectedValue = PreferenceKeys.defaultConverterValue;
  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
    _categories = ConversionData.getCategories();
    _selectedValue = PreferenceKeys.defaultConverterValue;
    _loadSelectedValue();
  }

  Future<void> _loadSelectedValue() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _selectedValue = prefs.getString(PreferenceKeys.converterSelect) ?? PreferenceKeys.defaultConverterValue;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Mirrors `ConversionAdapter.filter`: matches title, subtitle or category
  /// name (case-insensitive) and forces every matching category to expand.
  List<ConversionCategory> _filteredCategories(String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return _categories;

    return _categories
        .map((category) {
          final matchingItems = category.items.where((item) {
            return item.title.toLowerCase().contains(query) ||
                item.subtitle.toLowerCase().contains(query) ||
                category.name.toLowerCase().contains(query);
          }).toList();

          return ConversionCategory(
            name: category.name,
            description: category.description,
            icon: category.icon,
            items: matchingItems,
            isExpanded: true,
          );
        })
        .where((category) => category.items.isNotEmpty)
        .toList();
  }

  void _toggleCategory(ConversionCategory category) {
    setState(() {
      // Categories from the filtered list are temporary clones, so toggle the
      // original entry that shares the same name.
      final original = _categories.firstWhere(
        (c) => c.name == category.name,
        orElse: () => category,
      );
      original.isExpanded = !original.isExpanded;
    });
  }

  Future<void> _openConversion(ConversionItem item) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PreferenceKeys.converterSelect, item.entryValue);
    if (!mounted) return;

    setState(() => _selectedValue = item.entryValue);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConversionDetailScreen(
          title: item.title,
          entryValue: item.entryValue,
          themeController: widget.themeController,
        ),
      ),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          themeController: widget.themeController ?? ThemeController(),
        ),
      ),
    );
  }

  Future<void> _resetDashboard() async {
    _searchController.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(PreferenceKeys.converterSelect);
    if (!mounted) return;
    setState(() {
      _selectedValue = PreferenceKeys.defaultConverterValue;
      _categories = ConversionData.getCategories();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('App data refreshed'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  /// Double-back-to-exit behaviour from `MainActivity`.
  ///
  /// `canPop` is false, so the framework never pops the route for us. On the
  /// second press we must dismiss the home route explicitly.
  void _onPopInvoked(bool didPop) {
    if (didPop) return;
    final now = DateTime.now();
    if (_lastBackPress == null ||
        now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final visibleCategories = _filteredCategories(_searchController.text);

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _onPopInvoked(didPop),
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          backgroundColor: colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Encryptor',
            style: TextStyle(
              color: colorScheme.primary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset App',
              color: colorScheme.primary,
              onPressed: _resetDashboard,
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              color: colorScheme.primary,
              onPressed: _openSettings,
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  _horizontalInset,
                  4,
                  _horizontalInset,
                  10,
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Search conversions (e.g. Base64, SHA, Hex)...',
                    hintStyle: TextStyle(
                      fontSize: 15,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerLowest,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: colorScheme.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: colorScheme.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: colorScheme.primary, width: 2),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: visibleCategories.isEmpty
                    ? Center(
                        child: Opacity(
                          opacity: 0.75,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 40,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No conversion options found',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: visibleCategories.length,
                        itemBuilder: (context, index) {
                          final category = visibleCategories[index];
                          return _CategoryCard(
                            category: category,
                            selectedValue: _selectedValue,
                            onToggle: () => _toggleCategory(category),
                            onItemTap: _openConversion,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Expandable category header card (item_conversion_category.xml).
class _CategoryCard extends StatelessWidget {
  final ConversionCategory category;
  final String selectedValue;
  final VoidCallback onToggle;
  final ValueChanged<ConversionItem> onItemTap;

  const _CategoryCard({
    required this.category,
    required this.selectedValue,
    required this.onToggle,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasSelection = category.hasSelectedValue(selectedValue);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _horizontalInset,
        6,
        _horizontalInset,
        4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onToggle,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colorScheme.primary,
                    width: hasSelection ? 2 : 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        category.icon,
                        size: 20,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.name,
                            style: TextStyle(
                              color: colorScheme.onPrimaryContainer,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            category.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colorScheme.onPrimaryContainer,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${category.items.length}',
                        style: TextStyle(
                          color: colorScheme.onPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      category.isExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 20,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (category.isExpanded)
            for (final item in category.items)
              _OptionCard(item: item, onTap: () => onItemTap(item)),
        ],
      ),
    );
  }
}

/// Single conversion option card (item_conversion_option.xml).
class _OptionCard extends StatelessWidget {
  final ConversionItem item;
  final VoidCallback onTap;

  const _OptionCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 3, bottom: 3),
      child: Material(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant, width: 1),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item.icon,
                    size: 18,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
