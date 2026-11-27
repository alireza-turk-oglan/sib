/// ثابت‌های قرارداد API با پنل (غیرمحرمانه و ثابت بین محیط‌ها؛ بنابراین در کد هستند، نه env).
class ApiPaths {
  ApiPaths._();
  static const otpRequest = 'auth/otp/request';
  static const otpVerify = 'auth/otp/verify';
  static const check = 'auth/check';
  static const logout = 'auth/logout';
  static const smsSend = 'sms/send';
}

class ApiHeaders {
  ApiHeaders._();
  static const authorization = 'Authorization';
  static String bearer(String token) => 'Bearer $token';
}

/// مقدار فیلد `code` در پاسخ‌های خطای API
class ApiErrorCodes {
  ApiErrorCodes._();
  static const notRegistered = 'not_registered';
  static const blocked = 'blocked';
  static const badPhone = 'bad_phone';
  static const badCode = 'bad_code';
  static const otpFailed = 'otp_failed';
  static const rateLimited = 'rate_limited';
  static const subscriptionInactive = 'subscription_inactive';
  static const tokenInvalid = 'token_invalid';
  static const deviceMismatch = 'device_mismatch';
  static const deviceLimit = 'device_limit';
  static const dailyLimit = 'daily_limit';
  static const smsDisabled = 'sms_disabled';
  static const serverError = 'server_error';
}

/// طول و مدت اعتبار کد OTP (باید با سرور هماهنگ باشد)
class OtpRules {
  OtpRules._();
  static const length = 6;
  static const ttlSeconds = 120;
}
