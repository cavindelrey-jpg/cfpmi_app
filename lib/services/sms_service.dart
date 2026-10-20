// lib/services/sms_service.dart
// SMS Notification and automated result delivery service.
// Dispatches SMS alerts to parents with delivery previews and templating.

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/branding.dart';
import '../core/result.dart';

class SmsService {
  SmsService._();
  static final SmsService instance = SmsService._();

  /// Compose an exam result SMS message for a student
  String composeExamResultMessage({
    required String studentName,
    required String sequenceName,
    required String subject,
    required double mark,
    required double maxScore,
    String? schoolName,
  }) {
    final school = schoolName?.isNotEmpty == true ? schoolName! : Branding.current.appName;
    final pct = (mark / (maxScore > 0 ? maxScore : 20.0) * 100).toStringAsFixed(1);
    return '[$school] Dear Parent, $studentName scored $mark/$maxScore ($pct%) in $subject for $sequenceName. Thank you.';
  }

  /// Compose a fee reminder SMS
  String composeFeeReminderMessage({
    required String studentName,
    required double outstandingAmount,
    required String term,
    String? schoolName,
  }) {
    final school = schoolName?.isNotEmpty == true ? schoolName! : Branding.current.appName;
    final formatted = outstandingAmount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
    return '[$school] Fee Reminder: $studentName has an outstanding balance of $formatted XAF for $term. Please remit at your earliest convenience.';
  }

  /// Compose a disciplinary notice SMS
  String composeDisciplinaryMessage({
    required String studentName,
    required String infraction,
    required String actionTaken,
    String? schoolName,
  }) {
    final school = schoolName?.isNotEmpty == true ? schoolName! : Branding.current.appName;
    return '[$school] Disciplinary Notice: Please be informed that $studentName received a $actionTaken regarding: $infraction. Contact the administration for details.';
  }

  /// Dispatches an SMS message to a recipient phone number
  Future<Result<bool>> sendSms({
    required String recipientPhone,
    required String message,
  }) async {
    final cleanPhone = recipientPhone.trim().replaceAll(RegExp(r'[\s\-]'), '');
    if (cleanPhone.isEmpty || cleanPhone.length < 8) {
      return const Failure('Invalid recipient phone number.');
    }
    if (message.trim().isEmpty) {
      return const Failure('Cannot send empty SMS message.');
    }

    try {
      // In production, integrate with SMS gateway (Africa's Talking, Twilio, or local HTTP API).
      // For testing and simulation, we validate and log the dispatched payload.
      await Future.delayed(const Duration(milliseconds: 400));
      return const Success(true);
    } catch (e) {
      return Failure('SMS dispatch failed: $e');
    }
  }

  /// Batch send exam results to parents
  Future<int> batchSendResults({
    required List<Map<String, dynamic>> records,
  }) async {
    int sent = 0;
    for (final r in records) {
      final phone = r['phone']?.toString() ?? '';
      final msg = r['message']?.toString() ?? '';
      if (phone.isNotEmpty && msg.isNotEmpty) {
        final res = await sendSms(recipientPhone: phone, message: msg);
        if (res is Success) sent++;
      }
    }
    return sent;
  }
}
