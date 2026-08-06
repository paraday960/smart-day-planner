class AssistantResponse {
  const AssistantResponse({
    required this.text,
    this.shouldSpeak = true,
    this.needsConfirmation = false,
    this.confidence,
  });

  final String text;
  final bool shouldSpeak;
  final bool needsConfirmation;
  final double? confidence;
}
