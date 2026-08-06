import '../../utils/persian_format.dart';
import '../../services/security_service.dart';

class SecurityActionsController {
  const SecurityActionsController();

  Future<void> setPin(SecurityService service, String pin) async {
    await service.setPin(PersianFormat.englishDigits(pin));
  }

  Future<bool> disablePin(SecurityService service, String pin) async {
    final ok = await service.verifyPin(PersianFormat.englishDigits(pin));
    if (!ok) return false;
    await service.disablePin();
    return true;
  }
}
