enum AssistantVoiceGender { feminine, masculine }

extension AssistantVoiceGenderLabel on AssistantVoiceGender {
  String get faLabel {
    switch (this) {
      case AssistantVoiceGender.feminine:
        return 'صدای زن';
      case AssistantVoiceGender.masculine:
        return 'صدای مرد';
    }
  }
}
