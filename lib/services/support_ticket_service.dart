import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_update_service.dart';
import 'r2_storage_service.dart';

class SupportTicketModel {
  final String id;
  final String ticketCode;
  final String? userId;
  final String? businessId;
  final String sourceApp;
  final String reporterName;
  final String reporterEmail;
  final String? reporterPhone;
  final String category;
  final String priority;
  final String subject;
  final String description;
  final List<String> attachmentUrls;
  final String? appVersion;
  final String? platform;
  final String? deviceInfo;
  final String status;
  final String? adminReply;
  final DateTime? repliedAt;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SupportTicketModel({
    required this.id,
    required this.ticketCode,
    this.userId,
    this.businessId,
    required this.sourceApp,
    required this.reporterName,
    required this.reporterEmail,
    this.reporterPhone,
    required this.category,
    required this.priority,
    required this.subject,
    required this.description,
    required this.attachmentUrls,
    this.appVersion,
    this.platform,
    this.deviceInfo,
    required this.status,
    this.adminReply,
    this.repliedAt,
    this.resolvedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupportTicketModel.fromJson(Map<String, dynamic> json) {
    final rawAttachments = json['attachment_urls'];
    final List<String> parsedAttachments = [];
    if (rawAttachments is List) {
      for (final item in rawAttachments) {
        final s = item?.toString().trim() ?? '';
        if (s.isNotEmpty) parsedAttachments.add(s);
      }
    }

    DateTime? parseOptDate(dynamic val) {
      if (val == null) return null;
      return DateTime.tryParse(val.toString())?.toLocal();
    }

    return SupportTicketModel(
      id: json['id']?.toString() ?? '',
      ticketCode: json['ticket_code']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      businessId: json['business_id']?.toString(),
      sourceApp: json['source_app']?.toString() ?? 'ngam',
      reporterName: json['reporter_name']?.toString() ?? '',
      reporterEmail: json['reporter_email']?.toString() ?? '',
      reporterPhone: json['reporter_phone']?.toString(),
      category: json['category']?.toString() ?? 'bug',
      priority: json['priority']?.toString() ?? 'normal',
      subject: json['subject']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      attachmentUrls: parsedAttachments,
      appVersion: json['app_version']?.toString(),
      platform: json['platform']?.toString(),
      deviceInfo: json['device_info']?.toString(),
      status: json['status']?.toString() ?? 'open',
      adminReply: json['admin_reply']?.toString(),
      repliedAt: parseOptDate(json['replied_at']),
      resolvedAt: parseOptDate(json['resolved_at']),
      createdAt: parseOptDate(json['created_at']) ?? DateTime.now(),
      updatedAt: parseOptDate(json['updated_at']) ?? DateTime.now(),
    );
  }
}

class SupportTicketService {
  static final SupportTicketService _instance = SupportTicketService._internal();
  factory SupportTicketService() => _instance;
  SupportTicketService._internal();

  final SupabaseClient _client = Supabase.instance.client;
  final R2StorageService _r2 = R2StorageService();

  static String get detectedPlatform {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name.toLowerCase();
  }

  static String get detectedDeviceInfo {
    final platform = kIsWeb ? 'Web/PWA' : defaultTargetPlatform.name;
    return '$platform • v${AppUpdateService.currentVersion}';
  }

  String _generateTicketCode() {
    final now = DateTime.now();
    final yy = (now.year % 100).toString().padLeft(2, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    final suffix = List.generate(4, (_) => chars[rand.nextInt(chars.length)]).join();
    return 'NGM-$yy$mm$dd-$suffix';
  }

  String _inferMimeType(XFile file) {
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  Future<List<String>> uploadAttachments(List<XFile> files) async {
    final List<String> urls = [];
    for (final file in files) {
      final bytes = await file.readAsBytes();
      final url = await _r2.uploadMedia(
        bytes: bytes,
        fileName: file.name,
        folder: 'support-tickets',
        mimeType: _inferMimeType(file),
      );
      urls.add(url);
    }
    return urls;
  }

  Future<String> submitTicket({
    required String category,
    required String priority,
    required String subject,
    required String description,
    required String reporterName,
    required String reporterEmail,
    String? reporterPhone,
    List<XFile> attachments = const [],
  }) async {
    final currentUser = _client.auth.currentUser;
    final ticketCode = _generateTicketCode();
    final uploadedUrls = attachments.isNotEmpty ? await uploadAttachments(attachments) : <String>[];

    final payload = <String, dynamic>{
      'ticket_code': ticketCode,
      'user_id': currentUser?.id,
      'business_id': null,
      'source_app': 'ngam',
      'reporter_name': reporterName.trim(),
      'reporter_email': reporterEmail.trim(),
      'reporter_phone': (reporterPhone ?? '').trim().isEmpty ? null : reporterPhone!.trim(),
      'category': category,
      'priority': priority,
      'subject': subject.trim(),
      'description': description.trim(),
      'attachment_urls': uploadedUrls,
      'app_version': AppUpdateService.currentVersion,
      'platform': detectedPlatform,
      'device_info': detectedDeviceInfo,
      'status': 'open',
    };

    await _client.from('support_tickets').insert(payload);
    return ticketCode;
  }

  Stream<List<SupportTicketModel>> watchMyTickets() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      return Stream.value(const []);
    }
    return _client
        .from('support_tickets')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .map((rows) => rows.map((r) => SupportTicketModel.fromJson(r)).toList());
  }

  Future<List<SupportTicketModel>> fetchMyTickets() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];
    final res = await _client
        .from('support_tickets')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(50);
    return (res as List)
        .map((r) => SupportTicketModel.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }
}
