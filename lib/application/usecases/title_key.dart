/// Returns [title] lowercased, with the accented vowels, ñ, ç and ý common in
/// romanized Japanese and Spanish titles folded to their base letter.
///
/// Lets romanized titles such as "Kōkaku" sort and match alongside their
/// unaccented spelling instead of by code point.
String titleKey(String title) {
  final StringBuffer buffer = StringBuffer();
  for (final int rune in title.toLowerCase().runes) {
    buffer.writeCharCode(_foldedDiacritics[rune] ?? rune);
  }
  return buffer.toString();
}

const Map<int, int> _foldedDiacritics = <int, int>{
  0xE0: 0x61, // à -> a
  0xE1: 0x61, // á -> a
  0xE2: 0x61, // â -> a
  0xE3: 0x61, // ã -> a
  0xE4: 0x61, // ä -> a
  0xE5: 0x61, // å -> a
  0x101: 0x61, // ā -> a
  0xE7: 0x63, // ç -> c
  0xE8: 0x65, // è -> e
  0xE9: 0x65, // é -> e
  0xEA: 0x65, // ê -> e
  0xEB: 0x65, // ë -> e
  0x113: 0x65, // ē -> e
  0xEC: 0x69, // ì -> i
  0xED: 0x69, // í -> i
  0xEE: 0x69, // î -> i
  0xEF: 0x69, // ï -> i
  0x12B: 0x69, // ī -> i
  0xF1: 0x6E, // ñ -> n
  0xF2: 0x6F, // ò -> o
  0xF3: 0x6F, // ó -> o
  0xF4: 0x6F, // ô -> o
  0xF5: 0x6F, // õ -> o
  0xF6: 0x6F, // ö -> o
  0x14D: 0x6F, // ō -> o
  0xF9: 0x75, // ù -> u
  0xFA: 0x75, // ú -> u
  0xFB: 0x75, // û -> u
  0xFC: 0x75, // ü -> u
  0x16B: 0x75, // ū -> u
  0xFD: 0x79, // ý -> y
  0xFF: 0x79, // ÿ -> y
};
