import '../../models/assistant_voice_gender.dart';

abstract class VoiceResponsePort {
  bool get enabled;
  AssistantVoiceGender get gender;

  Future<void> initialize();
  Future<void> setEnabled(bool value);
  Future<void> setGender(AssistantVoiceGender gender);
  Future<void> speak(String text, {bool force = false});
  Future<void> stop();
  Future<String> testVoice();
}
