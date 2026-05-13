import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/domain/user_profile.dart';
import '../../features/meal_planner/data/chat_message.dart';
import '../../features/meal_planner/data/groq_service.dart';
import '../../features/meal_planner/data/preferences_extractor.dart';
import '../../features/pantry/domain/food_item.dart';
import '../../features/shopping_list/data/shopping_list_repository.dart';
import '../../features/shopping_list/domain/shopping_item.dart';
import 'pantry_provider.dart';
import 'profile_provider.dart';

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class ChatNotifier extends StateNotifier<ChatState> {
  final GroqService _groq;
  final ShoppingListRepository _shoppingRepo;
  final PreferencesExtractor _prefsExtractor;
  final Ref _ref;

  ChatNotifier(this._groq, this._shoppingRepo, this._prefsExtractor, this._ref)
      : super(const ChatState());

  List<FoodItem> get _pantryItems =>
      _ref.read(pantryProvider).valueOrNull ?? [];

  UserProfile? get _userProfile => _ref.read(profileProvider).valueOrNull;

  Future<ExtractedPreferences> _loadPrefsFromFirestore(String userId) async {
    try {
      final doc = FirebaseFirestore.instance.doc('users/$userId');
      final snap = await doc.get();
      if (!snap.exists || snap.data() == null) return ExtractedPreferences.empty();
      final prefsData = snap.data()?['preferences'] as Map<String, dynamic>?;
      if (prefsData == null) return ExtractedPreferences.empty();
      return ExtractedPreferences.fromJson(prefsData);
    } catch (_) {
      return ExtractedPreferences.empty();
    }
  }

  Future<void> initialize() async {
    if (state.messages.isNotEmpty) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      final pantryItems = await _ref.read(pantryProvider.future);
      final prefs = userId != null
          ? await _loadPrefsFromFirestore(userId)
          : ExtractedPreferences.empty();
      final welcome = await _groq.generateWelcome(
        pantryItems,
        profile: _userProfile,
        prefs: prefs,
      );
      state = state.copyWith(
        messages: [ChatMessage(role: 'assistant', content: welcome)],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error:
            'Nu am putut contacta Frigo AI. Verifică conexiunea și încearcă din nou.',
      );
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMsg = ChatMessage(role: 'user', content: text.trim());

    final extractUserId = FirebaseAuth.instance.currentUser?.uid;
    if (extractUserId != null) {
      _prefsExtractor.extract(text.trim()).then((prefs) {
        if (prefs.disliked.isNotEmpty ||
            prefs.liked.isNotEmpty ||
            prefs.dietary.isNotEmpty) {
          _prefsExtractor.saveToFirestore(extractUserId, prefs);
        }
      }).catchError((_) {});
    }

    final withUser = [...state.messages, userMsg];
    state = state.copyWith(
        messages: withUser, isLoading: true, clearError: true);

    try {
      final prefs = extractUserId != null
          ? await _loadPrefsFromFirestore(extractUserId)
          : ExtractedPreferences.empty();
      final reply = await _groq.sendMessage(withUser, _pantryItems,
          profile: _userProfile, prefs: prefs);
      state = state.copyWith(
        messages: [
          ...withUser,
          ChatMessage(role: 'assistant', content: reply)
        ],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Eroare la trimiterea mesajului. Încearcă din nou.',
      );
    }
  }

  Future<void> sendShoppingPlan() async {
    const userText = '🛒 Completează coșul';
    final userMsg = ChatMessage(role: 'user', content: userText);
    final withUser = [...state.messages, userMsg];
    state = state.copyWith(messages: withUser, isLoading: true, clearError: true);

    final userId = FirebaseAuth.instance.currentUser?.uid;
    final prefs = userId != null
        ? await _loadPrefsFromFirestore(userId)
        : ExtractedPreferences.empty();

    try {
      final raw = await _groq.generateShoppingPlan(_pantryItems, profile: _userProfile, prefs: prefs);
      final trimmed = raw.trim();
      final parsed = jsonDecode(trimmed) as Map<String, dynamic>;
      if (parsed['retete'] == null) throw Exception('Missing retete key');
      state = state.copyWith(
        messages: [...withUser, ChatMessage(role: 'assistant', content: trimmed)],
        isLoading: false,
      );
    } catch (_) {
      try {
        final reply = await _groq.sendMessage(withUser, _pantryItems, profile: _userProfile, prefs: prefs);
        state = state.copyWith(
          messages: [...withUser, ChatMessage(role: 'assistant', content: reply)],
          isLoading: false,
        );
      } catch (e2) {
        state = state.copyWith(
          isLoading: false,
          error: 'Eroare la trimiterea mesajului. Încearcă din nou.',
        );
      }
    }
  }

  void clearConversation() {
    state = const ChatState();
  }

  Future<void> addMissingToShoppingList(List<String> itemNames) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    for (final name in itemNames) {
      try {
        await _shoppingRepo.addItem(
          user.uid,
          ShoppingItem(
            id: '',
            name: name.trim(),
            checked: false,
            source: 'ai',
            addedAt: DateTime.now(),
          ),
        );
      } catch (_) {}
    }
  }
}

final chatProvider =
    StateNotifierProvider.autoDispose<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(
    GroqService(),
    ShoppingListRepository(),
    ref.read(preferencesExtractorProvider),
    ref,
  );
});
