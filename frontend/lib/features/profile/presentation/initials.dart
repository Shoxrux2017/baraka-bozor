/// The first letter of the first two words of [fullName], upper-cased;
/// `null` when there is no name.
String? initialsOf(String? fullName) {
  final List<String> words = (fullName ?? '')
      .split(RegExp(r'\s+'))
      .where((String word) => word.isNotEmpty)
      .take(2)
      .toList();
  if (words.isEmpty) {
    return null;
  }
  return words
      .map((String word) => String.fromCharCode(word.runes.first))
      .join()
      .toUpperCase();
}
