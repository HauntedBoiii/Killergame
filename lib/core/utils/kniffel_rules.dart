/// Client-side score computation mirroring the server-side SQL function.
/// Used to show score suggestions in the scorecard before the user confirms.
int computeCategoryScore(String category, List<int> dice) {
  final counts = List.filled(7, 0); // index 1-6 = count of that face
  int sum = 0;
  for (final d in dice) {
    if (d >= 1 && d <= 6) {
      counts[d]++;
      sum += d;
    }
  }

  switch (category) {
    case 'ones':
      return counts[1];
    case 'twos':
      return counts[2] * 2;
    case 'threes':
      return counts[3] * 3;
    case 'fours':
      return counts[4] * 4;
    case 'fives':
      return counts[5] * 5;
    case 'sixes':
      return counts[6] * 6;
  }

  final isYahtzee = counts.any((c) => c == 5);
  final hasThree = counts.any((c) => c >= 3);
  final hasFour = counts.any((c) => c >= 4);
  final fullHouse = !isYahtzee &&
      counts.any((c) => c == 2) &&
      counts.any((c) => c == 3);
  final smallStr =
      (counts[1] > 0 && counts[2] > 0 && counts[3] > 0 && counts[4] > 0) ||
          (counts[2] > 0 && counts[3] > 0 && counts[4] > 0 && counts[5] > 0) ||
          (counts[3] > 0 && counts[4] > 0 && counts[5] > 0 && counts[6] > 0);
  final largeStr =
      (counts[1] > 0 &&
          counts[2] > 0 &&
          counts[3] > 0 &&
          counts[4] > 0 &&
          counts[5] > 0) ||
          (counts[2] > 0 &&
              counts[3] > 0 &&
              counts[4] > 0 &&
              counts[5] > 0 &&
              counts[6] > 0);

  switch (category) {
    case 'three_of_a_kind':
      return hasThree ? sum : 0;
    case 'four_of_a_kind':
      return hasFour ? sum : 0;
    case 'full_house':
      return fullHouse ? 25 : 0;
    case 'small_straight':
      return smallStr ? 30 : 0;
    case 'large_straight':
      return largeStr ? 40 : 0;
    case 'yahtzee':
      return isYahtzee ? 50 : 0;
    case 'chance':
      return sum;
    default:
      return 0;
  }
}
