String calculateNutriScore(double? calories, double? sugar, double? fat) {
  if (calories == null || sugar == null || fat == null) return 'N/A';
  int points = 0;
  if (calories > 400) {
    points += 3;
  } else if (calories > 200) {
    points += 2;
  } else if (calories > 100) {
    points += 1;
  }
  if (sugar > 20) {
    points += 3;
  } else if (sugar > 10) {
    points += 2;
  } else if (sugar > 5) {
    points += 1;
  }
  if (fat > 20) {
    points += 3;
  } else if (fat > 10) {
    points += 2;
  } else if (fat > 5) {
    points += 1;
  }
  if (points <= 2) return 'A';
  if (points <= 4) return 'B';
  if (points <= 6) return 'C';
  return 'D';
}
