// lib/services/payment_service.dart
// ระบบชำระเงินผ่าน PromptPay QR:
// 1. โหลดการตั้งค่า (PromptPay ID, ราคา, QR สำรอง) จาก Firestore appConfig/payment (Admin ตั้งค่า)
// 2. สร้าง QR โค้ด PromptPay พร้อมยอดเงินที่ถูกต้อง (มาตรฐาน EMVCo) ฝั่ง client เอง
// 3. อัปโหลดสลิปการโอนไป R2 ผ่าน Admin API (same-origin กับเว็บ ไม่ติด CORS เพราะเรียกจาก native app)
// 4. สร้างคำขอชำระเงินใน Firestore ให้ Admin อนุมัติ/ปฏิเสธ
// เมื่อ Admin อนุมัติ (ที่ Admin Web) → users/{uid}.package จะถูกตั้งเป็น 'premium' ทันที
// ซึ่งทุกจุดในแอปที่เช็คสิทธิ์ premium จะปลดล็อกอัตโนมัติ

import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

// ── PromptPay QR payload generator (มาตรฐาน EMVCo) ─────────────
class PromptPayQr {
  static const _aid = 'A000000677010111';

  /// สร้าง payload string สำหรับแปลงเป็น QR code
  /// [id] = เบอร์โทร (10 หลัก) หรือเลขบัตรประชาชน/เลขนิติบุคคล (13 หลัก)
  /// [amount] = ยอดเงิน (ถ้าใส่ QR จะล็อกยอดไว้เลย)
  static String generatePayload(String id, {double? amount}) {
    final raw = id.replaceAll(RegExp(r'[^0-9]'), '');
    if (raw.isEmpty) return '';

    // 13 หลักขึ้นไป = เลขบัตรประชาชน/นิติบุคคล, น้อยกว่านั้น = เบอร์โทร
    final targetType   = raw.length >= 13 ? '02' : '01';
    final formattedId  = raw.length >= 13
        ? raw
        : '0066${raw.replaceFirst(RegExp(r'^0'), '')}';

    String f(String tag, String value) =>
        '$tag${value.length.toString().padLeft(2, '0')}$value';

    var data = ''
        '${f('00', '01')}'
        '${f('01', amount != null ? '12' : '11')}'
        '${f('29', '${f('00', _aid)}${f(targetType, formattedId)}')}'
        '${f('53', '764')}'
        '${amount != null ? f('54', amount.toStringAsFixed(2)) : ''}'
        '${f('58', 'TH')}';

    data += '6304';
    return data + _crc16(data);
  }

  static String _crc16(String data) {
    int crc = 0xFFFF;
    for (final b in data.codeUnits) {
      crc ^= (b << 8);
      for (int i = 0; i < 8; i++) {
        crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) & 0xFFFF : (crc << 1) & 0xFFFF;
      }
    }
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }
}

class PaymentConfig {
  final String promptpayId;
  final String accountName;
  final double priceMonthly;
  final double priceYearly;
  final String? qrImageUrl;

  const PaymentConfig({
    required this.promptpayId,
    required this.accountName,
    required this.priceMonthly,
    required this.priceYearly,
    this.qrImageUrl,
  });

  factory PaymentConfig.fromMap(Map<String, dynamic> m) => PaymentConfig(
    promptpayId:  m['promptpayId'] as String? ?? '',
    accountName:  m['accountName'] as String? ?? '',
    priceMonthly: (m['priceMonthly'] as num?)?.toDouble() ?? 199,
    priceYearly:  (m['priceYearly']  as num?)?.toDouble() ?? 1499,
    qrImageUrl:   m['qrImageUrl'] as String?,
  );

  static const defaults = PaymentConfig(
    promptpayId: '', accountName: '', priceMonthly: 199, priceYearly: 1499,
  );
}

// ── ต้องตั้งค่าให้ตรงกับ URL จริงของ Admin Web ────────────────
// (ใช้ endpoint /api/r2-upload ตัวเดียวกับที่ Admin Web อัปโหลดรูปอื่นๆ)
const String _adminApiBase = 'https://shadows-admin-web.vercel.app';

class PaymentService {
  static Future<PaymentConfig> loadConfig() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('appConfig').doc('payment').get();
      return snap.exists ? PaymentConfig.fromMap(snap.data()!) : PaymentConfig.defaults;
    } catch (_) {
      return PaymentConfig.defaults;
    }
  }

  /// อัปโหลดรูปสลิปผ่าน Admin API (same-origin กับเว็บ, native app ไม่ติด CORS)
  static Future<String> uploadSlip(File slip, String uid) async {
    final uri = Uri.parse('$_adminApiBase/api/r2-upload');
    final req = http.MultipartRequest('POST', uri)
      ..fields['path'] = 'payment_slips/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg'
      ..files.add(await http.MultipartFile.fromPath('file', slip.path));

    final streamed = await req.send().timeout(const Duration(seconds: 30));
    final resp     = await http.Response.fromStream(streamed);

    if (resp.statusCode != 200) {
      throw Exception('อัปโหลดสลิปไม่สำเร็จ (${resp.statusCode})');
    }
    final data = jsonDecode(resp.body);
    final url  = data['publicUrl'] as String?;
    if (url == null) throw Exception('ไม่พบ URL ของไฟล์ที่อัปโหลด');
    return url;
  }

  /// สร้างคำขอชำระเงินใหม่ใน Firestore ให้ Admin ตรวจสอบ
  static Future<void> submitRequest({
    required String uid,
    required String displayName,
    required String email,
    required String plan,
    required double amount,
    required String slipUrl,
  }) async {
    await FirebaseFirestore.instance.collection('paymentRequests').add({
      'userId': uid,
      'displayName': displayName,
      'email': email,
      'plan': plan,
      'amount': amount,
      'slipUrl': slipUrl,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// เช็คสถานะคำขอล่าสุดของ user (ไว้แสดงแบนเนอร์ "รอตรวจสอบ" ในหน้า Premium)
  static Future<Map<String, dynamic>?> latestRequest(String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection('paymentRequests')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return {...snap.docs.first.data(), 'id': snap.docs.first.id};
  }
}
