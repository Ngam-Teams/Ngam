import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'r2_storage_service.dart';
import '../utils/ngam_ref.dart';

// =============================================================================
// Ngam App — Dispute & 3-Way Mediation Service ("Pemerhati & Penentu")
// Handles opening disputes for Orders & Bookings, uploading R2 evidence,
// real-time 3-way mediation chat (Customer + Store + Ngam Mediator), & Admin escalation.
// =============================================================================

class DisputeCase {
  final String id;
  final String caseNumber;
  final String targetType; // 'order' | 'booking'
  final String? orderId;
  final String? bookingId;
  final String? bookingRef;
  final String businessId;
  final String customerId;
  final String? conversationId;
  final String customerName;
  final String businessName;
  final String itemSummary;
  final String reasonCode;
  final String reasonText;
  final double totalAmount;
  final double requestedRefundAmount;
  final double? approvedRefundAmount;
  final double? merchantReleaseAmount;
  final List<String> customerEvidenceUrls;
  final List<String> businessEvidenceUrls;
  final String? businessResponseText;
  final DateTime? businessRespondedAt;
  final String status;
  final String? resolutionType;
  final String? escalatedBy;
  final DateTime? escalatedAt;
  final String? moderatorId;
  final String? moderatorNote;
  final DateTime? responseDeadlineAt;
  final DateTime? resolvedAt;
  final DateTime createdAt;

  DisputeCase({
    required this.id,
    required this.caseNumber,
    required this.targetType,
    this.orderId,
    this.bookingId,
    this.bookingRef,
    required this.businessId,
    required this.customerId,
    this.conversationId,
    required this.customerName,
    required this.businessName,
    required this.itemSummary,
    required this.reasonCode,
    required this.reasonText,
    required this.totalAmount,
    required this.requestedRefundAmount,
    this.approvedRefundAmount,
    this.merchantReleaseAmount,
    required this.customerEvidenceUrls,
    required this.businessEvidenceUrls,
    this.businessResponseText,
    this.businessRespondedAt,
    required this.status,
    this.resolutionType,
    this.escalatedBy,
    this.escalatedAt,
    this.moderatorId,
    this.moderatorNote,
    this.responseDeadlineAt,
    this.resolvedAt,
    required this.createdAt,
  });

  bool get isResolved =>
      status == 'resolved_refund_full' ||
      status == 'resolved_refund_partial' ||
      status == 'resolved_release_business' ||
      status == 'withdrawn';

  bool get isEscalated =>
      status == 'escalated' || status == 'under_review';

  /// `NR` — Ngam Refund reference (cth: `NR2611233D9E4B`)
  String get refundReference =>
      NgamRef.refund(id, createdAt: resolvedAt ?? createdAt);

  factory DisputeCase.fromJson(Map<String, dynamic> json) {
    List<String> parseUrls(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
      }
      return const [];
    }

    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString())?.toLocal();
    }

    final parsedId = (json['id'] ?? '').toString();
    final parsedCreated = parseDt(json['created_at']) ?? DateTime.now();
    final rawCaseNo = (json['case_number'] ?? '').toString().trim();
    final formattedCaseNo =
        (rawCaseNo.isNotEmpty && !rawCaseNo.contains('-'))
            ? rawCaseNo.toUpperCase()
            : NgamRef.dispute(parsedId, createdAt: parsedCreated);

    return DisputeCase(
      id: parsedId,
      caseNumber: formattedCaseNo,
      targetType: (json['target_type'] ?? 'order').toString(),
      orderId: json['order_id']?.toString(),
      bookingId: json['booking_id']?.toString(),
      bookingRef: json['booking_ref']?.toString(),
      businessId: (json['business_id'] ?? '').toString(),
      customerId: (json['customer_id'] ?? '').toString(),
      conversationId: json['conversation_id']?.toString(),
      customerName: (json['customer_name'] ?? 'Pelanggan Ngam').toString(),
      businessName: (json['business_name'] ?? 'Kedai Ngam').toString(),
      itemSummary: (json['item_summary'] ?? '').toString(),
      reasonCode: (json['reason_code'] ?? 'other').toString(),
      reasonText: (json['reason_text'] ?? '').toString(),
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      requestedRefundAmount: (json['requested_refund_amount'] as num?)?.toDouble() ?? 0.0,
      approvedRefundAmount: (json['approved_refund_amount'] as num?)?.toDouble(),
      merchantReleaseAmount: (json['merchant_release_amount'] as num?)?.toDouble(),
      customerEvidenceUrls: parseUrls(json['customer_evidence_urls']),
      businessEvidenceUrls: parseUrls(json['business_evidence_urls']),
      businessResponseText: json['business_response_text']?.toString(),
      businessRespondedAt: parseDt(json['business_responded_at']),
      status: (json['status'] ?? 'open').toString(),
      resolutionType: json['resolution_type']?.toString(),
      escalatedBy: json['escalated_by']?.toString(),
      escalatedAt: parseDt(json['escalated_at']),
      moderatorId: json['moderator_id']?.toString(),
      moderatorNote: json['moderator_note']?.toString(),
      responseDeadlineAt: parseDt(json['response_deadline_at']),
      resolvedAt: parseDt(json['resolved_at']),
      createdAt: parseDt(json['created_at']) ?? DateTime.now(),
    );
  }
}

class DisputeMessage {
  final String id;
  final String disputeId;
  final String? senderId;
  final String senderRole; // 'customer' | 'business' | 'moderator' | 'system'
  final String senderName;
  final String message;
  final List<String> attachments;
  final DateTime createdAt;

  DisputeMessage({
    required this.id,
    required this.disputeId,
    this.senderId,
    required this.senderRole,
    required this.senderName,
    required this.message,
    required this.attachments,
    required this.createdAt,
  });

  factory DisputeMessage.fromJson(Map<String, dynamic> json) {
    final rawAtt = json['attachments'];
    final atts = (rawAtt is List)
        ? rawAtt.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList()
        : const <String>[];
    return DisputeMessage(
      id: (json['id'] ?? '').toString(),
      disputeId: (json['dispute_id'] ?? '').toString(),
      senderId: json['sender_id']?.toString(),
      senderRole: (json['sender_role'] ?? 'customer').toString(),
      senderName: (json['sender_name'] ?? 'Pengguna').toString(),
      message: (json['message'] ?? '').toString(),
      attachments: atts,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString())?.toLocal() ??
          DateTime.now(),
    );
  }
}

class DisputeService {
  static final _supabase = Supabase.instance.client;

  static Future<String> uploadEvidenceImage(
    Uint8List bytes,
    String fileName,
  ) async {
    return R2StorageService().uploadMedia(
      bytes: bytes,
      fileName: fileName,
      folder: 'disputes',
      mimeType: fileName.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg',
    );
  }

  static Future<DisputeCase> openDispute({
    required String targetType, // 'order' | 'booking'
    String? orderId,
    String? bookingId,
    String? bookingRef,
    required String businessId,
    required String reasonCode,
    required String reasonText,
    double? requestedRefundAmount,
    List<String> evidenceUrls = const [],
    String? itemSummary,
  }) async {
    final res = await _supabase.rpc('open_dispute_case', params: {
      'p_target_type': targetType,
      if (orderId != null && orderId.isNotEmpty) 'p_order_id': orderId,
      if (bookingId != null && bookingId.isNotEmpty) 'p_booking_id': bookingId,
      if (bookingRef != null && bookingRef.isNotEmpty) 'p_booking_ref': bookingRef,
      'p_business_id': businessId,
      'p_reason_code': reasonCode,
      'p_reason_text': reasonText,
      if (requestedRefundAmount != null) 'p_requested_refund_amount': requestedRefundAmount,
      'p_evidence_urls': evidenceUrls,
      if (itemSummary != null) 'p_item_summary': itemSummary,
    });
    return DisputeCase.fromJson(Map<String, dynamic>.from(res as Map));
  }

  static Future<DisputeCase?> fetchDisputeByOrder(String orderId) async {
    try {
      final res = await _supabase
          .from('disputes')
          .select()
          .eq('order_id', orderId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (res == null) return null;
      return DisputeCase.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      debugPrint('[DisputeService] fetchDisputeByOrder error: $e');
      return null;
    }
  }

  static Future<DisputeCase?> fetchDisputeByBooking({
    String? bookingId,
    String? bookingRef,
  }) async {
    try {
      if (bookingId != null && bookingId.isNotEmpty) {
        final res = await _supabase
            .from('disputes')
            .select()
            .eq('booking_id', bookingId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        if (res != null) return DisputeCase.fromJson(Map<String, dynamic>.from(res));
      }
      if (bookingRef != null && bookingRef.isNotEmpty) {
        final res = await _supabase
            .from('disputes')
            .select()
            .eq('booking_ref', bookingRef)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        if (res != null) return DisputeCase.fromJson(Map<String, dynamic>.from(res));
      }
    } catch (e) {
      debugPrint('[DisputeService] fetchDisputeByBooking error: $e');
    }
    return null;
  }

  static Stream<DisputeCase> watchDispute(String disputeId) {
    return _supabase
        .from('disputes')
        .stream(primaryKey: ['id'])
        .eq('id', disputeId)
        .map((rows) => DisputeCase.fromJson(Map<String, dynamic>.from(rows.first)));
  }

  static Stream<List<DisputeMessage>> watchMessages(String disputeId) {
    return _supabase
        .from('dispute_messages')
        .stream(primaryKey: ['id'])
        .eq('dispute_id', disputeId)
        .order('created_at', ascending: true)
        .map((rows) => rows
            .map((e) => DisputeMessage.fromJson(Map<String, dynamic>.from(e)))
            .toList());
  }

  static Future<void> sendMessage({
    required String disputeId,
    required String message,
    required String senderName,
    List<String> attachments = const [],
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    await _supabase.from('dispute_messages').insert({
      'dispute_id': disputeId,
      'sender_id': uid,
      'sender_role': 'customer',
      'sender_name': senderName,
      'message': message.trim(),
      'attachments': attachments,
    });
  }

  static Future<DisputeCase> escalateToAdmin(String disputeId, {String note = ''}) async {
    final res = await _supabase.rpc('escalate_dispute_case', params: {
      'p_dispute_id': disputeId,
      'p_note': note,
    });
    return DisputeCase.fromJson(Map<String, dynamic>.from(res as Map));
  }

  static Future<void> withdrawDispute(String disputeId, String senderName) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    await _supabase.rpc('withdraw_dispute_case', params: {
      'p_dispute_id': disputeId,
    });
  }
}
