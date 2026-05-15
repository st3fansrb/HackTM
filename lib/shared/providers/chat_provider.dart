import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/domain/user_preferences.dart';
import '../../features/auth/domain/user_profile.dart';
import '../../features/meal_planner/data/chat_message.dart';
import '../../features/meal_planner/data/groq_service.dart';
import '../../features/meal_planner/data/preferences_extractor.dart';
import '../../features/pantry/domain/food_item.dart';
import '../../features/shopping_list/data/shopping_list_repository.dart';
import '../../features/shopping_list/domain/shopping_item.dart';
import 'pantry_provider.dart';
import 'preferences_provider.dart';
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
  String _sessionId;

  ChatNotifier(this._groq, this._shoppingRepo, this._prefsExtractor, this._ref)
      : _sessionId = DateTime.now().millisecondsSinceEpoch.toString(),
        super(const ChatState());

  List<FoodItem> get _pantryItems =>
      _ref.read(pantryProvider).valueOrNull ?? [];

  UserProfile? get _userProfile => _ref.read(profileProvider).valueOrNull;

  UserPreferences? get _userPreferences =>
      _ref.read(userPreferencesProvider).valueOrNull;

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

  Future<List<ChatMessage>> _loadHistoryFromFirestore(String userId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users/$userId/chat_history')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();
      return snap.docs
          .map((d) => ChatMessage.fromJson({...d.data(), 'id': d.id}))
          .toList()
          .reversed
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveMessage(String userId, ChatMessage msg) async {
    try {
      await FirebaseFirestore.instance
          .collection('users/$userId/chat_history')
          .add(msg.toJson());
    } catch (_) {}
  }

  Future<void> initialize({bool forceNew = false}) async {
    if (state.messages.isNotEmpty) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      final pantryItems = await _ref.read(pantryProvider.future);
      final prefs = userId != null
          ? await _loadPrefsFromFirestore(userId)
          : ExtractedPreferences.empty();

      if (!forceNew && userId != null) {
        final history = await _loadHistoryFromFirestore(userId);
        if (history.isNotEmpty) {
          state = state.copyWith(messages: history, isLoading: false);
          return;
        }
      }

      final welcome = await _groq.generateWelcome(
        pantryItems,
        profile: _userProfile,
        prefs: prefs,
        userPrefs: _userPreferences,
      );
      final welcomeMsg = ChatMessage(
        role: 'assistant',
        content: welcome,
        sessionId: _sessionId,
      );
      if (userId != null) await _saveMessage(userId, welcomeMsg);
      state = state.copyWith(
        messages: [welcomeMsg],
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

    final userId = FirebaseAuth.instance.currentUser?.uid;
    final userMsg = ChatMessage(
      role: 'user',
      content: text.trim(),
      sessionId: _sessionId,
    );

    if (userId != null) {
      _prefsExtractor.extract(text.trim()).then((prefs) {
        if (prefs.disliked.isNotEmpty ||
            prefs.liked.isNotEmpty ||
            prefs.dietary.isNotEmpty) {
          _prefsExtractor.saveToFirestore(userId, prefs);
        }
      }).catchError((_) {});
    }

    final withUser = [...state.messages, userMsg];
    state = state.copyWith(
        messages: withUser, isLoading: true, clearError: true);

    if (userId != null) await _saveMessage(userId, userMsg);

    try {
      final prefs = userId != null
          ? await _loadPrefsFromFirestore(userId)
          : ExtractedPreferences.empty();
      final reply = await _groq.sendMessage(
        withUser,
        _pantryItems,
        profile: _userProfile,
        prefs: prefs,
        userPrefs: _userPreferences,
      );
      final assistantMsg = ChatMessage(
        role: 'assistant',
        content: reply,
        sessionId: _sessionId,
      );
      if (userId != null) await _saveMessage(userId, assistantMsg);
      state = state.copyWith(
        messages: [...withUser, assistantMsg],
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
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final userMsg = ChatMessage(
      role: 'user',
      content: userText,
      sessionId: _sessionId,
    );
    final withUser = [...state.messages, userMsg];
    state =
        state.copyWith(messages: withUser, isLoading: true, clearError: true);
    if (userId != null) await _saveMessage(userId, userMsg);

    final prefs = userId != null
        ? await _loadPrefsFromFirestore(userId)
        : ExtractedPreferences.empty();

    try {
      final raw = await _groq.generateShoppingPlan(_pantryItems,
          profile: _userProfile, prefs: prefs);
      final trimmed = raw.trim();
      final parsed = jsonDecode(trimmed) as Map<String, dynamic>;
      if (parsed['retete'] == null) throw Exception('Missing retete key');
      final assistantMsg = ChatMessage(
        role: 'assistant',
        content: trimmed,
        sessionId: _sessionId,
      );
      if (userId != null) await _saveMessage(userId, assistantMsg);
      state = state.copyWith(
        messages: [...withUser, assistantMsg],
        isLoading: false,
      );
    } catch (_) {
      try {
        final reply = await _groq.sendMessage(withUser, _pantryItems,
            profile: _userProfile, prefs: prefs, userPrefs: _userPreferences);
        final assistantMsg = ChatMessage(
          role: 'assistant',
          content: reply,
          sessionId: _sessionId,
        );
        if (userId != null) await _saveMessage(userId, assistantMsg);
        state = state.copyWith(
          messages: [...withUser, assistantMsg],
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
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
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
