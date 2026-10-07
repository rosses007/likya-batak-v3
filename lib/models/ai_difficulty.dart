/// Represents the artificial intelligence card-play difficulty levels.
enum AIDifficulty {
  easy,
  normal,
  hard;

  String get displayName {
    switch (this) {
      case AIDifficulty.easy:
        return "Kolay";
      case AIDifficulty.normal:
        return "Normal";
      case AIDifficulty.hard:
        return "Zor";
    }
  }

  static AIDifficulty fromString(String? value) {
    if (value == null) return AIDifficulty.normal;
    switch (value.toLowerCase().trim()) {
      case 'easy':
      case 'kolay':
        return AIDifficulty.easy;
      case 'hard':
      case 'zor':
        return AIDifficulty.hard;
      case 'normal':
      default:
        return AIDifficulty.normal;
    }
  }
}
