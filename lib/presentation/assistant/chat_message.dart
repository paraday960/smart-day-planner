/// یک پیام در چت دستیار.
class ChatMessage {
  ChatMessage({required this.text, required this.isUser, DateTime? time})
      : time = time ?? DateTime.now();

  final String text;
  final bool isUser;
  final DateTime time;
}
