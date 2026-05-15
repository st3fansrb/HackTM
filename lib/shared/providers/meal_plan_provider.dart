import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/meal_planner/domain/weekly_plan.dart';

String currentWeekId() {
  final now = DateTime.now();
  final thursday = now.add(Duration(days: 4 - now.weekday));
  final firstDayOfYear = DateTime(thursday.year, 1, 1);
  final weekNum =
      ((thursday.difference(firstDayOfYear).inDays) / 7).floor() + 1;
  return 'week_${thursday.year}_${weekNum.toString().padLeft(2, '0')}';
}

final weeklyPlanProvider = StreamProvider<WeeklyPlan?>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return const Stream.empty();
  final weekId = currentWeekId();
  return FirebaseFirestore.instance
      .doc('users/${user.uid}/weekly_plans/$weekId')
      .snapshots()
      .map((snap) => snap.exists && snap.data() != null
          ? WeeklyPlan.fromFirestore(snap.data()!)
          : null);
});
