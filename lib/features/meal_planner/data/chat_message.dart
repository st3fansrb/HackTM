class ChatMessage {
  final String id;
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime createdAt;
  final String? sessionId;

  ChatMessage({
    String? id,
    required this.role,
    required this.content,
    DateTime? createdAt,
    this.sessionId,
  })  : id = id ?? '',
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        'timestamp': createdAt.millisecondsSinceEpoch,
        'sessionId': sessionId,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String? ?? '',
        role: json['role'] as String,
        content: json['content'] as String,
        createdAt: json['timestamp'] != null
            ? DateTime.fromMillisecondsSinceEpoch(
                (json['timestamp'] as num).toInt())
            : DateTime.now(),
        sessionId: json['sessionId'] as String?,
      );
}
