class UserPreferences {
  final List<String> allergies;
  final List<String> dietaryRestrictions;
  final List<String> dislikedIngredients;
  final List<String> preferredCuisines;
  final bool completedOnboarding;

  const UserPreferences({
    this.allergies = const [],
    this.dietaryRestrictions = const [],
    this.dislikedIngredients = const [],
    this.preferredCuisines = const [],
    this.completedOnboarding = false,
  });

  const UserPreferences.empty()
      : allergies = const [],
        dietaryRestrictions = const [],
        dislikedIngredients = const [],
        preferredCuisines = const [],
        completedOnboarding = false;

  Map<String, dynamic> toJson() => {
        'allergies': allergies,
        'dietaryRestrictions': dietaryRestrictions,
        'dislikedIngredients': dislikedIngredients,
        'preferredCuisines': preferredCuisines,
        'completedOnboarding': completedOnboarding,
      };

  factory UserPreferences.fromJson(Map<String, dynamic> json) =>
      UserPreferences(
        allergies: _toList(json['allergies']),
        dietaryRestrictions: _toList(json['dietaryRestrictions']),
        dislikedIngredients: _toList(json['dislikedIngredients']),
        preferredCuisines: _toList(json['preferredCuisines']),
        completedOnboarding: json['completedOnboarding'] as bool? ?? false,
      );

  UserPreferences copyWith({
    List<String>? allergies,
    List<String>? dietaryRestrictions,
    List<String>? dislikedIngredients,
    List<String>? preferredCuisines,
    bool? completedOnboarding,
  }) =>
      UserPreferences(
        allergies: allergies ?? this.allergies,
        dietaryRestrictions: dietaryRestrictions ?? this.dietaryRestrictions,
        dislikedIngredients: dislikedIngredients ?? this.dislikedIngredients,
        preferredCuisines: preferredCuisines ?? this.preferredCuisines,
        completedOnboarding: completedOnboarding ?? this.completedOnboarding,
      );

  bool get isEmpty =>
      allergies.isEmpty &&
      dietaryRestrictions.isEmpty &&
      dislikedIngredients.isEmpty &&
      preferredCuisines.isEmpty;

  static List<String> _toList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.cast<String>();
    return [value.toString()];
  }
}
