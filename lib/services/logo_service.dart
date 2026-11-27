import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../data/database.dart';
import '../domain/business_profile.dart';

/// آماده‌سازی تصویر لوگو: خواندن (PNG/JPG/WebP/GIF/BMP)، کوچک‌کردن تا حداکثر ۲۵۶ پیکسل (با حفظ نسبت) و ذخیره به‌صورت PNG.
class LogoService {
  static const int maxSourceBytes = 10 * 1024 * 1024;
  static const int maxSide = 256;

  static Future<Uint8List> prepare(String path) async {
    final file = File(path);
    if (!file.existsSync()) throw DomainError('فایل تصویر پیدا نشد.');
    if (file.lengthSync() > maxSourceBytes) throw DomainError('حجم فایل تصویر زیاد است (حداکثر ۱۰ مگابایت).');
    final bytes = await file.readAsBytes();

    int w, h;
    try {
      final probe = await ui.instantiateImageCodec(bytes);
      final f = await probe.getNextFrame();
      w = f.image.width;
      h = f.image.height;
      f.image.dispose();
      probe.dispose();
    } catch (_) {
      throw DomainError('این فایل، تصویر معتبری نیست.');
    }

    final ui.Codec codec = w >= h
        ? await ui.instantiateImageCodec(bytes, targetWidth: math.min(w, maxSide))
        : await ui.instantiateImageCodec(bytes, targetHeight: math.min(h, maxSide));
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    codec.dispose();
    if (data == null) throw DomainError('تبدیل تصویر ممکن نشد.');
    final out = data.buffer.asUint8List();
    if (out.length > BusinessProfile.maxLogoBytes) throw DomainError('تصویر پس از کوچک‌سازی هنوز بزرگ است؛ تصویر ساده‌تری انتخاب کنید.');
    return out;
  }
}
