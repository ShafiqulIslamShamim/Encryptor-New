/// Shared preference keys used by more than one screen.
///
/// Keeping them in one place prevents typos and makes it obvious which stored
/// values different features depend on.
class PreferenceKeys {
  const PreferenceKeys._();

  /// Selected conversion index (stored as a string, e.g. "27").
  static const converterSelect = 'converter_select';

  /// "1" enables the hex byte-array display mode, "0" disables it.
  static const converterHex = 'converter_hex';

  /// Converter used when nothing has been selected yet (AES-GCM encryption).
  static const defaultConverterValue = '27';
}
