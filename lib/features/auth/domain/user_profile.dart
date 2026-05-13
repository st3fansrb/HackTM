import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String displayName;
  final int householdSize;
  final String dietType;
  final List<String> allergies;
  final Map<String, bool> notifications;
  final DateTime? createdAt;
  final int activeDays;
  final double kgSaved;
  final double totalKgAdded;
  final double kgWasted;
  final List<String> ownedCondiments;

  const UserProfile({
    required this.uid,
    required this.displayName,
    this.householdSize = 2,
    this.dietType = 'omnivor',
    this.allergies = const [],
    this.notifications = const {
      'expiry_alerts': true,
      'daily_suggestions': true,
      'weekly_summary': false,
    },
    this.createdAt,
    this.activeDays = 1,
    this.kgSaved = 0.0,
    this.totalKgAdded = 0.0,
    this.kgWasted = 0.0,
    this.ownedCondiments = const [],
  });

  factory UserProfile.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawNotifs = data['notifications'];
    final Map<String, dynamic> notifMap =
        rawNotifs is Map ? rawNotifs.cast<String, dynamic>() : {};
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final totalKgAdded = (data['totalKgAdded'] as num?)?.toDouble() ?? 0.0;
    final kgWasted = (data['kgWasted'] as num?)?.toDouble() ?? 0.0;
    final kgSaved = (totalKgAdded * 0.30 - kgWasted).clamp(0.0, double.infinity);
    final activeDays = createdAt != null
        ? DateTime.now().difference(createdAt).inDays.clamp(1, 999999)
        : 1;
    return UserProfile(
      uid: doc.id,
      displayName: data['displayName'] as String? ?? '',
      householdSize: data['householdSize'] as int? ?? 2,
      dietType: data['dietType'] as String? ?? 'omnivor',
      allergies: List<String>.from((data['allergies'] as List?) ?? []),
      notifications: {
        'expiry_alerts': notifMap['expiry_alerts'] as bool? ?? true,
        'daily_suggestions': notifMap['daily_suggestions'] as bool? ?? true,
        'weekly_summary': notifMap['weekly_summary'] as bool? ?? false,
      },
      createdAt: createdAt,
      activeDays: activeDays,
      kgSaved: kgSaved,
      totalKgAdded: totalKgAdded,
      kgWasted: kgWasted,
      ownedCondiments: List<String>.from((data['ownedCondiments'] as List?) ?? []),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'displayName': displayName,
        'householdSize': householdSize,
        'dietType': dietType,
        'allergies': allergies,
        'notifications': notifications,
        'activeDays': activeDays,
        'kgSaved': kgSaved,
        'ownedCondiments': ownedCondiments,
      };

  UserProfile copyWith({
    String? uid,
    String? displayName,
    int? householdSize,
    String? dietType,
    List<String>? allergies,
    Map<String, bool>? notifications,
    DateTime? createdAt,
    int? activeDays,
    double? kgSaved,
    double? totalKgAdded,
    double? kgWasted,
    List<String>? ownedCondiments,
  }) =>
      UserProfile(
        uid: uid ?? this.uid,
        displayName: displayName ?? this.displayName,
        householdSize: householdSize ?? this.householdSize,
        dietType: dietType ?? this.dietType,
        allergies: allergies ?? this.allergies,
        notifications: notifications ?? this.notifications,
        createdAt: createdAt ?? this.createdAt,
        activeDays: activeDays ?? this.activeDays,
        kgSaved: kgSaved ?? this.kgSaved,
        totalKgAdded: totalKgAdded ?? this.totalKgAdded,
        kgWasted: kgWasted ?? this.kgWasted,
        ownedCondiments: ownedCondiments ?? this.ownedCondiments,
      );
}
