// ─── Bookur Assistant AI Models ──────────────────────────────────────────

enum ChatSender {
  user,
  assistant,
  system,
}

enum QuickActionType {
  ourServices,
  howBookingWorks,
  serviceCharges,
  cancellationPolicy,
  refundPolicy,
  paymentInfo,
  technicianInfo,
  termsConditions,
  privacyPolicy,
  contactSupport,
  exploreServices,
  bookService,
  viewCancellationPolicy,
  viewRefundPolicy,
  readTerms,
  readPrivacy,
  trackActiveBooking,
}

class ChatQuickAction {
  final String label;
  final QuickActionType actionType;
  final String queryText;

  const ChatQuickAction({
    required this.label,
    required this.actionType,
    required this.queryText,
  });
}

class ChatActionCard {
  final String title;
  final String subtitle;
  final String buttonLabel;
  final String routeName;
  final dynamic routeArguments;
  final String? secondaryButtonLabel;
  final String? secondaryRouteName;

  const ChatActionCard({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.routeName,
    this.routeArguments,
    this.secondaryButtonLabel,
    this.secondaryRouteName,
  });
}

class ChatMessage {
  final String id;
  final String text;
  final ChatSender sender;
  final DateTime timestamp;
  final List<ChatQuickAction>? quickActions;
  final ChatActionCard? actionCard;
  final bool isTyping;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.quickActions,
    this.actionCard,
    this.isTyping = false,
  });

  ChatMessage copyWith({
    String? id,
    String? text,
    ChatSender? sender,
    DateTime? timestamp,
    List<ChatQuickAction>? quickActions,
    ChatActionCard? actionCard,
    bool? isTyping,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      sender: sender ?? this.sender,
      timestamp: timestamp ?? this.timestamp,
      quickActions: quickActions ?? this.quickActions,
      actionCard: actionCard ?? this.actionCard,
      isTyping: isTyping ?? this.isTyping,
    );
  }
}

class AiKnowledgeDocument {
  final String id;
  final String category;
  final String title;
  final String content;
  final String version;
  final String effectiveDate;
  final bool isPublished;
  final String updatedBy;
  final DateTime updatedAt;

  const AiKnowledgeDocument({
    required this.id,
    required this.category,
    required this.title,
    required this.content,
    required this.version,
    required this.effectiveDate,
    required this.isPublished,
    required this.updatedBy,
    required this.updatedAt,
  });
}
