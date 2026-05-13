class NutritionalData {
  final String? name;
  final String? brand;
  final double? calories;
  final double? protein;
  final double? fat;
  final double? carbs;
  final double? sugar;
  final double? salt;

  const NutritionalData({
    this.name,
    this.brand,
    this.calories,
    this.protein,
    this.fat,
    this.carbs,
    this.sugar,
    this.salt,
  });
}

// Returns 'A','B','C','D','E' or 'N/A' when no nutritional data available.
String calculateNutriScore(NutritionalData data) {
  if (data.calories == null &&
      data.sugar == null &&
      data.fat == null &&
      data.salt == null) {
    return 'N/A';
  }

  int negPoints = 0;

  // Calories: 0pts (<335 kJ) → 10pts (>3350 kJ), step = 335 kJ
  if (data.calories != null) {
    final kj = data.calories! * 4.184;
    negPoints += _steps(kj, 335, 335, 10);
  }

  // Sugar: 0pts (<4.5g) → 10pts (>45g), step = 4.5g
  if (data.sugar != null) {
    negPoints += _steps(data.sugar!, 4.5, 4.5, 10);
  }

  // Saturated fat (estimated = fat × 0.4): 0pts (<1g) → 10pts (>10g), step = 1g
  if (data.fat != null) {
    negPoints += _steps(data.fat! * 0.4, 1.0, 1.0, 10);
  }

  // Salt: 0pts (<0.2g) → 10pts (>2g), step = 0.2g
  if (data.salt != null) {
    negPoints += _steps(data.salt!, 0.2, 0.2, 10);
  }

  // Protein: 0pts (<1.6g) → 5pts (>8g), step = 1.6g
  int posPoints = 0;
  if (data.protein != null) {
    posPoints += _steps(data.protein!, 1.6, 1.6, 5);
  }

  final score = negPoints - posPoints;
  if (score <= -1) return 'A';
  if (score <= 2) return 'B';
  if (score <= 10) return 'C';
  if (score <= 18) return 'D';
  return 'E';
}

int _steps(double value, double first, double step, int max) {
  if (value < first) return 0;
  final pts = ((value - first) / step).floor() + 1;
  return pts.clamp(0, max);
}
