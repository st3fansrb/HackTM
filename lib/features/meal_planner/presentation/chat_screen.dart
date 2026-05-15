import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/providers/chat_provider.dart';
import '../../../shared/widgets/frigo_header.dart';
import 'parsed_message.dart';
import 'week_planner_sheet.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatProvider.notifier).initialize();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _confirmNewConversation() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Conversație nouă'),
        content: const Text(
            'Începi o conversație nouă? Istoricul va rămâne salvat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anulează'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(chatProvider.notifier).clearConversation();
              ref.read(chatProvider.notifier).initialize(forceNew: true);
            },
            child: const Text('Conversație nouă'),
          ),
        ],
      ),
    );
  }

  Future<void> _send({String? text}) async {
    final msg = text ?? _controller.text.trim();
    if (msg.isEmpty) return;
    if (text == null) _controller.clear();
    await ref.read(chatProvider.notifier).sendMessage(msg);
  }

  void _openWeekPlanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const WeekPlannerSheet(),
    );
  }

  Widget _buildQuickActions(ChatState chat) {
    const actions = [
      '🍳 Ce pot găti azi? ',
      '📅 Planifică săptămâna ',
    ];

    return Opacity(
      opacity: chat.isLoading ? 0.4 : 1.0,
      child: IgnorePointer(
        ignoring: chat.isLoading,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: actions
                  .map(
                    (label) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: label.trim() == '📅 Planifică săptămâna'
                            ? _openWeekPlanner
                            : () => _send(text: label),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ChatState>(chatProvider, (prev, next) {
      if ((prev?.messages.length ?? 0) != next.messages.length) {
        _scrollToBottom();
      }
    });

    final chat = ref.watch(chatProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: FrigoHeader(
        title: 'Frigo AI',
        subtitle: 'Asistent inteligent',
        actions: [
          if (chat.messages.length >= 4)
            IconButton(
              icon: const Icon(Icons.edit_note, color: Colors.white),
              tooltip: 'Conversație nouă',
              onPressed: () => _confirmNewConversation(),
            ),
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(Icons.auto_awesome, color: Colors.white, size: 22),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList(chat)),
          if (chat.error != null) _buildErrorBanner(chat.error!),
          _buildQuickActions(chat),
          _ChatInput(
            controller: _controller,
            isLoading: chat.isLoading,
            onSend: _send,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(ChatState chat) {
    if (chat.messages.isEmpty && chat.isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 14),
            Text(
              'Frigo AI analizează pantry-ul...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (chat.messages.isEmpty && chat.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined,
                  color: AppColors.expiredRed, size: 52),
              const SizedBox(height: 14),
              const Text(
                'Nu am putut conecta la Frigo AI',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                chat.error!,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () =>
                    ref.read(chatProvider.notifier).initialize(),
                icon: const Icon(Icons.refresh),
                label: const Text('Reîncearcă'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final itemCount = chat.messages.length + (chat.isLoading ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == chat.messages.length) {
          return const Padding(
            padding: EdgeInsets.only(top: 6, bottom: 6),
            child: Row(
              children: [
                _AiAvatar(),
                SizedBox(width: 8),
                _TypingIndicator(),
              ],
            ),
          );
        }

        final msg = chat.messages[index];
        final isUser = msg.role == 'user';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                const _AiAvatar(),
                const SizedBox(width: 8),
              ],
              ParsedMessage(content: msg.content, isUser: isUser),
              if (isUser) const SizedBox(width: 4),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorBanner(String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.expiredRed.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: AppColors.expiredRed, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(
                  color: AppColors.expiredRed, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared sub-widgets ───────────────────────────────────────────────────────

class _AiAvatar extends StatelessWidget {
  const _AiAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child:
          const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(delay: 0),
          const SizedBox(width: 4),
          _Dot(delay: 160),
          const SizedBox(width: 4),
          _Dot(delay: 320),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: AppColors.primary
              .withValues(alpha: 0.35 + 0.65 * _anim.value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final Future<void> Function({String? text}) onSend;

  const _ChatInput({
    required this.controller,
    required this.isLoading,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      padding: EdgeInsets.only(
          left: 16, right: 16, top: 10, bottom: 10 + bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !isLoading,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              maxLines: null,
              decoration: InputDecoration(
                hintText: 'Ce să gătesc azi?',
                hintStyle:
                    const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isLoading ? null : () => onSend(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isLoading
                    ? AppColors.textSecondary
                    : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isLoading ? Icons.hourglass_empty : Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
