import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_model.dart';
import '../models/user_model.dart';
import 'local_database_service.dart';
import 'r2_storage_service.dart';

class ChatService {
  static final _supabase = Supabase.instance.client;
  static final Map<String, UserModel> _userCache = {};

  /// Caches and fetches User Profiles to solve the N+1 query problem
  static Future<UserModel?> getCachedUser(String userId) async {
    if (_userCache.containsKey(userId)) return _userCache[userId];
    try {
      final data = await _supabase.from('users').select().eq('id', userId).single();
      final user = UserModel.fromJson(data);
      _userCache[userId] = user;
      return user;
    } catch (e) {
      return null;
    }
  }
  static final Map<String, Map<String, dynamic>> _businessCache = {};

  static Future<Map<String, dynamic>?> getCachedBusiness(String businessId) async {
    if (_businessCache.containsKey(businessId)) return _businessCache[businessId];
    try {
      final data = await _supabase
          .from('businesses')
          .select('id, business_name, business_logo_url, business_phone, owner_user_id')
          .eq('id', businessId)
          .maybeSingle();
      if (data != null) {
        _businessCache[businessId] = Map<String, dynamic>.from(data);
      }
      return data;
    } catch (e) {
      return null;
    }
  }

  static UserModel _syntheticBusinessUser(
    String businessId,
    String? name,
    String? logoUrl,
    String? phone,
  ) {
    final now = DateTime.now();
    return UserModel(
      id: 'biz_$businessId',
      role: 'business',
      createdAt: now,
      updatedAt: now,
      userName: (name != null && name.isNotEmpty) ? name : 'Ngam Shop',
      userAvatarUrl: logoUrl,
      userPhone: phone,
      businessName: name,
      businessLogoUrl: logoUrl,
    );
  }

  static final Map<String, Map<String, dynamic>> _gigCache = {};
  
  static Map<String, dynamic>? getCachedGigSync(String gigId) => _gigCache[gigId];

  static Future<Map<String, dynamic>?> getCachedGig(String gigId) async {
    if (_gigCache.containsKey(gigId)) return _gigCache[gigId];
    try {
      final data = await _supabase.from('gigs').select('customer_id, gig_worker_id, title, status').eq('id', gigId).maybeSingle();
      if (data != null) {
        _gigCache[gigId] = data;
      }
      return data;
    } catch (e) {
      return null;
    }
  }

  static const String _convCachePrefix = 'cached_conversations_v1_';

  static Map<String, dynamic> _convToCacheMap(ConversationModel c) {
    return {
      'id': c.id,
      'user1_id': c.user1Id,
      'user2_id': c.user2Id,
      if (c.gigId != null) 'gig_id': c.gigId,
      if (c.lastMessage != null) 'last_message': c.lastMessage,
      if (c.lastMessageSenderId != null) 'last_message_sender_id': c.lastMessageSenderId,
      'last_message_is_read': c.lastMessageIsRead,
      'updated_at': c.updatedAt.toUtc().toIso8601String(),
      if (c.taskLastMessages != null) 'task_last_messages': c.taskLastMessages,
      if (c.taskUnreadCounts != null) 'task_unread_counts': c.taskUnreadCounts,
      'unread_count': c.unreadCount,
      if (c.businessId != null) 'business_id': c.businessId,
      if (c.businessName != null) 'business_name': c.businessName,
      if (c.businessLogoUrl != null) 'business_logo_url': c.businessLogoUrl,
      if (c.businessPhone != null) 'business_phone': c.businessPhone,
      if (c.contextType != null) 'context_type': c.contextType,
      if (c.contextId != null) 'context_id': c.contextId,
      'customer_unread_count': c.customerUnreadCount,
      'business_unread_count': c.businessUnreadCount,
      if (c.otherUser != null) 'users': c.otherUser!.toJson(),
    };
  }

  static Future<void> _saveConversationsPrefsCache(
    String userId,
    bool isRunner,
    List<ConversationModel> conversations,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_convCachePrefix${userId}_${isRunner ? 'r' : 'c'}';
      final encoded = jsonEncode(conversations.map(_convToCacheMap).toList());
      await prefs.setString(key, encoded);
    } catch (_) {}
  }

  static Future<List<ConversationModel>> _loadConversationsPrefsCache(
    String userId,
    bool isRunner,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_convCachePrefix${userId}_${isRunner ? 'r' : 'c'}';
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((m) => ConversationModel.fromJson(m, userId))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetch all conversations for the current user
  static Stream<List<ConversationModel>> getConversationsStream(String currentUserId, {required bool isRunner}) async* {
    final localDb = LocalDatabaseService.instance;

    // Kasi keluar data local on-the-spot (SQLite untuk mobile, SharedPreferences untuk Web/offline)
    final localConversations = await localDb.getConversations();
    if (localConversations.isNotEmpty) {
      // Untuk chat local, kita penuhkan terus dengan user yang dah di-cache
      List<ConversationModel> populatedLocal = [];
      for (var conv in localConversations) {
        if (conv.isBusinessChat) {
          if (isRunner) continue;
          final biz = _businessCache[conv.businessId!];
          final bName = conv.businessName ?? biz?['business_name']?.toString();
          final bLogo = conv.businessLogoUrl ?? biz?['business_logo_url']?.toString();
          final bPhone = conv.businessPhone ?? biz?['business_phone']?.toString();
          populatedLocal.add(conv.copyWith(
            businessName: bName,
            businessLogoUrl: bLogo,
            businessPhone: bPhone,
            unreadCount: conv.customerUnreadCount,
            otherUser: _syntheticBusinessUser(conv.businessId!, bName, bLogo, bPhone),
          ));
          continue;
        }

        if (conv.gigId != null) {
           final gigData = _gigCache[conv.gigId!];
           if (gigData != null) {
             final isCustomerInGig = gigData['customer_id'] == currentUserId;
             if (isRunner && isCustomerInGig) continue;
             if (!isRunner && !isCustomerInGig) continue;
           } else {
             // Lompat/skip kalau takde gig cache untuk elak chat role salah berkelip-kelip
             continue;
           }
        }

        final otherId = conv.user1Id == currentUserId ? conv.user2Id : conv.user1Id;
        final otherUser = _userCache[otherId];
        populatedLocal.add(conv.copyWith(otherUser: otherUser));
      }
      yield populatedLocal;
    } else {
      final prefsCached = await _loadConversationsPrefsCache(currentUserId, isRunner);
      if (prefsCached.isNotEmpty) {
        yield prefsCached;
      }
    }

    // Tarik data network berterusan (Stream)
    yield* _supabase
        .from('conversations')
        .stream(primaryKey: ['id'])
        .asyncMap((maps) async {
          final filtered = maps.where((m) => m['user1_id'] == currentUserId || m['user2_id'] == currentUserId).toList();
          filtered.sort((a, b) {
            final aTime = DateTime.tryParse(a['updated_at'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = DateTime.tryParse(b['updated_at'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });
          
          List<ConversationModel> conversations = [];
          for (var e in filtered) {
             final conv = ConversationModel.fromJson(e, currentUserId);

             if (conv.isBusinessChat) {
               // Business chats belong to customer inbox (when user1 is customer)
               if (isRunner || conv.user1Id != currentUserId) continue;
               final biz = await getCachedBusiness(conv.businessId!);
               final bName = biz?['business_name']?.toString();
               final bLogo = biz?['business_logo_url']?.toString();
               final bPhone = biz?['business_phone']?.toString();
               conversations.add(conv.copyWith(
                 businessName: bName,
                 businessLogoUrl: bLogo,
                 businessPhone: bPhone,
                 unreadCount: conv.customerUnreadCount,
                 otherUser: _syntheticBusinessUser(conv.businessId!, bName, bLogo, bPhone),
               ));
               continue;
             }

             if (conv.gigId != null) {
               final gigData = await getCachedGig(conv.gigId!);
               if (gigData != null) {
                 final isCustomerInGig = gigData['customer_id'] == currentUserId;
                 if (isRunner && isCustomerInGig) continue;
                 if (!isRunner && !isCustomerInGig) continue;
               }
             }

             final otherId = conv.user1Id == currentUserId ? conv.user2Id : conv.user1Id;
             final otherUser = await getCachedUser(otherId);
             conversations.add(conv.copyWith(otherUser: otherUser));
          }
          
          // Save dalam SQLite & SharedPreferences (Cache untuk offline/web)
          await localDb.insertConversations(conversations);
          await _saveConversationsPrefsCache(currentUserId, isRunner, conversations);
          return conversations;
        })
        .handleError((_) {});
  }

  /// Prefetch recent chats and messages in the background
  static Future<void> prefetchChats(String currentUserId) async {
    try {
      final response = await _supabase
          .from('conversations')
          .select()
          .or('user1_id.eq.$currentUserId,user2_id.eq.$currentUserId')
          .order('updated_at', ascending: false)
          .limit(20);
      
      final localDb = LocalDatabaseService.instance;
      List<ConversationModel> conversations = [];
      
      for (var e in response) {
         conversations.add(ConversationModel.fromJson(e, currentUserId));
      }
      
      if (conversations.isNotEmpty) {
        await localDb.insertConversations(conversations);
        
        // Fetch recent messages for these conversations
        for (var conv in conversations) {
          final msgs = await _supabase
              .from('messages')
              .select()
              .eq('conversation_id', conv.id)
              .order('created_at', ascending: false)
              .limit(50);
              
          final networkMessages = msgs.map((e) => MessageModel.fromJson(e)).toList();
          if (networkMessages.isNotEmpty) {
            await localDb.insertMessages(networkMessages);
          }
        }
      }
    } catch (e) {
      debugPrint('Prefetch failed: $e');
    }
  }

  /// Get paginated historical messages
  static Future<List<MessageModel>> getMessages(String conversationId, {int limit = 50, int offset = 0}) async {
    final localDb = LocalDatabaseService.instance;
    try {
      final response = await _supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
          
      final networkMessages = response.map((e) => MessageModel.fromJson(e)).toList();
      await localDb.insertMessages(networkMessages);
      return networkMessages;
    } catch (e) {
      // Pakai cache offline kalau network putus
      return await localDb.getMessages(conversationId, limit: limit, offset: offset);
    }
  }

  /// Subscribe to new messages and typing events via Supabase Realtime
  static RealtimeChannel subscribeToChatEvents(
    String conversationId, {
    required void Function(MessageModel) onNewMessage,
    required void Function(String userId, bool isTyping) onTypingStatus,
  }) {
    return _supabase.channel('public:chat:$conversationId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'conversation_id',
          value: conversationId,
        ),
        callback: (payload) {
          final newMsg = MessageModel.fromJson(payload.newRecord);
          LocalDatabaseService.instance.insertMessage(newMsg);
          onNewMessage(newMsg);
        },
      )
      .onBroadcast(
        event: 'typing',
        callback: (payload) {
          final userId = payload['user_id'] as String?;
          final isTyping = payload['is_typing'] as bool? ?? false;
          if (userId != null) onTypingStatus(userId, isTyping);
        },
      )
      .subscribe();
  }

  // --- Kehadiran / Presence ---
  static RealtimeChannel? _presenceChannel;
  static final ValueNotifier<Set<String>> onlineUsers = ValueNotifier({});

  /// Joins the global presence channel to mark the current user as online.
  static void trackPresence(String userId) {
    if (_presenceChannel != null) return; // Memang dah tengah track pun
    
    _presenceChannel = _supabase.channel('online_presence');
    _presenceChannel!
      .onPresenceSync((payload) {
        final state = _presenceChannel!.presenceState();
        final Set<String> onlineUserIds = {};
        for (dynamic presenceState in state) {
          final presences = presenceState.presences;
          if (presences != null) {
            for (dynamic p in presences) {
              if (p.payload != null && p.payload['user_id'] != null) {
                onlineUserIds.add(p.payload['user_id'] as String);
              }
            }
          }
        }
        onlineUsers.value = onlineUserIds;
      })
      .subscribe((status, [error]) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          await _presenceChannel!.track({'user_id': userId});
        }
      });
  }

  static void stopTrackingPresence() {
    _presenceChannel?.unsubscribe();
    _presenceChannel = null;
    onlineUsers.value = {};
  }

  /// Create or get a conversation between two users
  static Future<ConversationModel> createOrGetConversation(String currentUserId, String otherUserId, {String? gigId}) async {
    if (currentUserId == otherUserId) {
      throw Exception('You cannot chat with yourself.');
    }

    final existing = await _supabase
        .from('conversations')
        .select()
        .or('and(user1_id.eq.$currentUserId,user2_id.eq.$otherUserId),and(user1_id.eq.$otherUserId,user2_id.eq.$currentUserId)')
        .limit(1)
        .maybeSingle();

    if (existing != null) {
      return ConversationModel.fromJson(existing, currentUserId);
    }

    final response = await _supabase.from('conversations').insert({
      'user1_id': currentUserId,
      'user2_id': otherUserId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).select().single();

    return ConversationModel.fromJson(response, currentUserId);
  }

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static Future<void> _ensureCurrentUserInPublicUsers() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    if (_userCache.containsKey(user.id)) return;
    try {
      final existing = await _supabase
          .from('users')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();
      if (existing == null) {
        final fallbackName = user.userMetadata?['full_name']?.toString() ??
            user.userMetadata?['name']?.toString() ??
            user.email?.split('@').first ??
            'Pengguna Ngam';
        await _supabase.from('users').insert({
          'id': user.id,
          'role': 'customer',
          'user_name': fallbackName,
          if (user.email != null) 'user_email': user.email,
        });
      }
    } catch (_) {}
  }

  /// Create or get a customer <-> business conversation via SECURITY DEFINER RPC (with direct fallback)
  static Future<ConversationModel> getOrCreateBusinessConversation(
    String businessId, {
    String? contextType,
    String? contextId,
  }) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('Authentication required');
    }

    await _ensureCurrentUserInPublicUsers();

    final validContextId = (contextId != null && _uuidRegex.hasMatch(contextId.trim()))
        ? contextId.trim()
        : null;

    final biz = await getCachedBusiness(businessId);
    final bName = biz?['business_name']?.toString();
    final bLogo = biz?['business_logo_url']?.toString();
    final bPhone = biz?['business_phone']?.toString();
    final ownerId = biz?['owner_user_id']?.toString();

    Map<String, dynamic>? row;
    Object? lastError;

    try {
      final response = await _supabase.rpc(
        'get_or_create_business_conversation',
        params: {
          'p_business_id': businessId,
          if (contextType != null) 'p_context_type': contextType,
          if (validContextId != null) 'p_context_id': validContextId,
        },
      );
      if (response is Map) {
        row = Map<String, dynamic>.from(response);
      } else if (response is List && response.isNotEmpty && response.first is Map) {
        row = Map<String, dynamic>.from(response.first as Map);
      }
    } catch (rpcErr) {
      lastError = rpcErr;
      debugPrint('[ChatService] get_or_create_business_conversation RPC failed, trying direct fallback: $rpcErr');
    }

    // Fallback 1: Direct query/insert on conversations table with business_id
    if (row == null) {
      try {
        final existing = await _supabase
            .from('conversations')
            .select()
            .eq('user1_id', currentUserId)
            .eq('business_id', businessId)
            .limit(1)
            .maybeSingle();

        if (existing != null) {
          row = Map<String, dynamic>.from(existing);
          if (ownerId != null &&
              ownerId.isNotEmpty &&
              existing['user2_id']?.toString() != ownerId) {
            try {
              final healed = await _supabase
                  .from('conversations')
                  .update({'user2_id': ownerId})
                  .eq('id', existing['id'])
                  .select()
                  .maybeSingle();
              if (healed != null) {
                row = Map<String, dynamic>.from(healed);
              }
            } catch (_) {}
          }
        } else {
          final targetUser2 = (ownerId != null && ownerId.isNotEmpty) ? ownerId : currentUserId;
          try {
            final inserted = await _supabase
                .from('conversations')
                .insert({
                  'user1_id': currentUserId,
                  'user2_id': targetUser2,
                  'business_id': businessId,
                  'context_type': contextType ?? 'general',
                  if (validContextId != null) 'context_id': validContextId,
                  'updated_at': DateTime.now().toUtc().toIso8601String(),
                })
                .select()
                .single();
            row = Map<String, dynamic>.from(inserted);
          } catch (fkErr) {
            // Fallback 1B: If owner_user_id is not yet in public.users (FK 23503),
            // bind user2_id to currentUserId so the business_id conversation succeeds immediately.
            debugPrint('[ChatService] Owner FK fallback triggered: $fkErr');
            final insertedSelf = await _supabase
                .from('conversations')
                .insert({
                  'user1_id': currentUserId,
                  'user2_id': currentUserId,
                  'business_id': businessId,
                  'context_type': contextType ?? 'general',
                  if (validContextId != null) 'context_id': validContextId,
                  'updated_at': DateTime.now().toUtc().toIso8601String(),
                })
                .select()
                .single();
            row = Map<String, dynamic>.from(insertedSelf);
          }
        }
      } catch (directErr) {
        lastError = directErr;
        debugPrint('[ChatService] Direct business conversation fallback failed: $directErr');
      }
    }

    if (row == null) {
      throw Exception(
        lastError != null
            ? '$lastError'
            : 'Tidak dapat memulakan sembang dengan kedai buat masa ini.',
      );
    }

    return ConversationModel.fromJson(row, currentUserId).copyWith(
      businessName: bName,
      businessLogoUrl: bLogo,
      businessPhone: bPhone,
      otherUser: _syntheticBusinessUser(businessId, bName, bLogo, bPhone),
    );
  }

  /// Mark a business conversation as read via SECURITY DEFINER RPC
  static Future<void> markBusinessConversationRead(
    String conversationId, {
    String viewerRole = 'customer',
  }) async {
    try {
      await _supabase.rpc(
        'mark_business_conversation_read',
        params: {
          'p_conversation_id': conversationId,
          'p_viewer_role': viewerRole,
        },
      );
    } catch (e) {
      debugPrint('markBusinessConversationRead failed: $e');
    }
  }

  /// Send a message
  static Future<MessageModel> sendMessage(
    MessageModel message, {
    String? contextGigId,
    bool isBusinessChat = false,
  }) async {
    try {
      // 1. Sumbat mesej baru masuk DB pastu ambil UUID betul dia
      final response = await _supabase.from('messages').insert(message.toSupabaseJson()).select().single();
      final actualMessage = MessageModel.fromJson(response);

      // 2. Update table perbualan
      if (!isBusinessChat) {
        if (contextGigId != null) {
          await _supabase.rpc('update_conversation_task_message', params: {
            'p_conversation_id': message.conversationId,
            'p_sender_id': message.senderId,
            'p_message_content': message.content,
            'p_gig_id': contextGigId,
          });
        } else {
          await _supabase.from('conversations').update({
            'last_message': message.content,
            'last_message_sender_id': message.senderId,
            'last_message_is_read': false,
            'updated_at': message.createdAt.toUtc().toIso8601String(),
          }).eq('id', message.conversationId);
        }
      } else {
        try {
          await _supabase.from('conversations').update({
            'last_message': message.content,
            'last_message_sender_id': message.senderId,
            'last_message_is_read': false,
            'updated_at': actualMessage.createdAt.toUtc().toIso8601String(),
          }).eq('id', message.conversationId);
        } catch (_) {}
      }
      
      // Update local dengan REAL ID supaya tak ter-duplicate bila reload nanti
      final sentMsg = actualMessage.copyWith(status: 'sent');
      await LocalDatabaseService.instance.insertMessage(sentMsg);
      
      return actualMessage;
    } catch (e) {
      final failedMsg = message.copyWith(status: 'failed');
      await LocalDatabaseService.instance.insertMessage(failedMsg);
      rethrow;
    }
  }

  /// Send a system message (e.g., date dividers, context updates) without incrementing unread counts
  static Future<void> sendSystemMessage(MessageModel message) async {
    try {
      await _supabase.from('messages').insert(message.toSupabaseJson());
      
      final sentMsg = message.copyWith(status: 'sent', isRead: true);
      await LocalDatabaseService.instance.insertMessage(sentMsg);
    } catch (e) {
      final failedMsg = message.copyWith(status: 'failed');
      await LocalDatabaseService.instance.insertMessage(failedMsg);
      rethrow;
    }
  }

  /// Upload image and send an image message (Web/PWA & Mobile compatible via R2 / Storage uploadBinary)
  static Future<MessageModel> sendImageMessage(
    MessageModel pendingMessage,
    Uint8List imageBytes,
    String originalFileName, {
    String? contextGigId,
    bool isBusinessChat = false,
  }) async {
    try {
      final fileExt = originalFileName.contains('.')
          ? originalFileName.split('.').last.toLowerCase()
          : 'jpg';
      final mimeType = fileExt == 'png'
          ? 'image/png'
          : (fileExt == 'webp' ? 'image/webp' : 'image/jpeg');
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${pendingMessage.senderId}.$fileExt';

      final imageUrl = await R2StorageService().uploadMedia(
        bytes: imageBytes,
        fileName: fileName,
        folder: 'chat/${pendingMessage.conversationId}',
        mimeType: mimeType,
      );

      final newMsg = pendingMessage.copyWith(
        imageUrl: imageUrl,
        fileName: fileName,
        fileSize: imageBytes.lengthInBytes,
      );

      final response = await _supabase.from('messages').insert(newMsg.toSupabaseJson()).select().single();
      final actualMessage = MessageModel.fromJson(response);

      if (!isBusinessChat && contextGigId != null) {
        await _supabase.rpc('update_conversation_task_message', params: {
          'p_conversation_id': pendingMessage.conversationId,
          'p_sender_id': pendingMessage.senderId,
          'p_message_content': 'Photo',
          'p_gig_id': contextGigId,
        });
      } else {
        try {
          await _supabase.from('conversations').update({
            'last_message': '📷 Photo',
            'last_message_sender_id': pendingMessage.senderId,
            'last_message_is_read': false,
            'updated_at': actualMessage.createdAt.toUtc().toIso8601String(),
          }).eq('id', pendingMessage.conversationId);
        } catch (_) {}
      }

      final sentMsg = actualMessage.copyWith(status: 'sent');
      await LocalDatabaseService.instance.insertMessage(sentMsg);

      return actualMessage;
    } catch (e) {
      await LocalDatabaseService.instance.insertMessage(pendingMessage.copyWith(status: 'failed'));
      rethrow;
    }
  }

  /// Upload video and send a video message (Web/PWA & Mobile compatible via R2 / Storage uploadBinary)
  static Future<MessageModel> sendVideoMessage(
    MessageModel pendingMessage,
    Uint8List videoBytes,
    String originalFileName, {
    String? contextGigId,
    bool isBusinessChat = false,
  }) async {
    try {
      final fileExt = originalFileName.contains('.')
          ? originalFileName.split('.').last.toLowerCase()
          : 'mp4';
      final mimeType = fileExt == 'mov'
          ? 'video/quicktime'
          : (fileExt == 'webm' ? 'video/webm' : 'video/mp4');
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${pendingMessage.senderId}.$fileExt';

      final videoUrl = await R2StorageService().uploadMedia(
        bytes: videoBytes,
        fileName: fileName,
        folder: 'chat/${pendingMessage.conversationId}',
        mimeType: mimeType,
      );

      final newMsg = pendingMessage.copyWith(
        imageUrl: videoUrl,
        messageType: 'video',
        fileName: originalFileName,
        fileSize: videoBytes.lengthInBytes,
      );

      final response = await _supabase.from('messages').insert(newMsg.toSupabaseJson()).select().single();
      final actualMessage = MessageModel.fromJson(response);

      if (!isBusinessChat && contextGigId != null) {
        await _supabase.rpc('update_conversation_task_message', params: {
          'p_conversation_id': pendingMessage.conversationId,
          'p_sender_id': pendingMessage.senderId,
          'p_message_content': 'Video',
          'p_gig_id': contextGigId,
        });
      } else {
        try {
          await _supabase.from('conversations').update({
            'last_message': '🎬 Video',
            'last_message_sender_id': pendingMessage.senderId,
            'last_message_is_read': false,
            'updated_at': actualMessage.createdAt.toUtc().toIso8601String(),
          }).eq('id', pendingMessage.conversationId);
        } catch (_) {}
      }

      final sentMsg = actualMessage.copyWith(status: 'sent');
      await LocalDatabaseService.instance.insertMessage(sentMsg);

      return actualMessage;
    } catch (e) {
      await LocalDatabaseService.instance.insertMessage(pendingMessage.copyWith(status: 'failed'));
      rethrow;
    }
  }

  /// Upload file and send a file message (Web/PWA & Mobile compatible via R2 / Storage uploadBinary)
  static Future<MessageModel> sendFileMessage(
    MessageModel pendingMessage,
    Uint8List fileBytes,
    String fileName, {
    String? contextGigId,
    bool isBusinessChat = false,
  }) async {
    try {
      final lower = fileName.toLowerCase();
      final mimeType = lower.endsWith('.pdf')
          ? 'application/pdf'
          : (lower.endsWith('.csv')
              ? 'text/csv'
              : (lower.endsWith('.txt') ? 'text/plain' : 'application/octet-stream'));
      final safeName = '${DateTime.now().millisecondsSinceEpoch}_$fileName';

      final fileUrl = await R2StorageService().uploadMedia(
        bytes: fileBytes,
        fileName: safeName,
        folder: 'chat/${pendingMessage.conversationId}',
        mimeType: mimeType,
      );

      final newMsg = pendingMessage.copyWith(
        imageUrl: fileUrl,
        fileName: fileName,
        fileSize: fileBytes.lengthInBytes,
      );

      final response = await _supabase.from('messages').insert(newMsg.toSupabaseJson()).select().single();
      final actualMessage = MessageModel.fromJson(response);

      if (!isBusinessChat && contextGigId != null) {
        await _supabase.rpc('update_conversation_task_message', params: {
          'p_conversation_id': pendingMessage.conversationId,
          'p_sender_id': pendingMessage.senderId,
          'p_message_content': 'File',
          'p_gig_id': contextGigId,
        });
      } else {
        try {
          await _supabase.from('conversations').update({
            'last_message': '📎 $fileName',
            'last_message_sender_id': pendingMessage.senderId,
            'last_message_is_read': false,
            'updated_at': actualMessage.createdAt.toUtc().toIso8601String(),
          }).eq('id', pendingMessage.conversationId);
        } catch (_) {}
      }

      final sentMsg = actualMessage.copyWith(status: 'sent');
      await LocalDatabaseService.instance.insertMessage(sentMsg);

      return actualMessage;
    } catch (e) {
      await LocalDatabaseService.instance.insertMessage(pendingMessage.copyWith(status: 'failed'));
      rethrow;
    }
  }

  /// Mark all messages in a conversation as read (sent by the other user)
  static Future<void> markMessagesAsRead(String conversationId, String otherUserId, {String? gigId}) async {
    await _supabase.from('messages')
        .update({'is_read': true})
        .eq('conversation_id', conversationId)
        .eq('sender_id', otherUserId)
        .eq('is_read', false);

    if (gigId != null) {
      final response = await _supabase.from('conversations').select().eq('id', conversationId).maybeSingle();
      if (response != null && response['task_unread_counts'] != null) {
        Map<String, dynamic> counts = Map<String, dynamic>.from(response['task_unread_counts']);
        counts.remove(gigId);
        
        final updatePayload = <String, dynamic>{
          'task_unread_counts': counts,
        };
        
        // Mark chat tu read HANYA kalau mesej tu memang dihantar oleh pihak sana
        if (counts.isEmpty && response['last_message_sender_id'] == otherUserId) {
          updatePayload['last_message_is_read'] = true;
        }

        await _supabase.from('conversations')
            .update(updatePayload)
            .eq('id', conversationId);
            
        // Update database local terus
        final conv = ConversationModel.fromJson({
          ...response,
          ...updatePayload,
        }, '');
        await LocalDatabaseService.instance.insertConversation(conv);
      }
    } else {
      final response = await _supabase.from('conversations').select().eq('id', conversationId).maybeSingle();
      if (response != null) {
        final updatePayload = <String, dynamic>{
          'task_unread_counts': {},
        };
        if (response['last_message_sender_id'] == otherUserId) {
          updatePayload['last_message_is_read'] = true;
        }
        
        await _supabase.from('conversations')
            .update(updatePayload)
            .eq('id', conversationId);
            
        final conv = ConversationModel.fromJson({
          ...response,
          ...updatePayload,
        }, '');
        await LocalDatabaseService.instance.insertConversation(conv);
      }
    }
  }
  
  /// Fetch user profile helper
  static Future<Map<String, dynamic>> getUserProfile(String userId) async {
    return await _supabase.from('users').select().eq('id', userId).single();
  }

  /// Delete a conversation and all its messages and images
  static Future<void> deleteConversation(String conversationId) async {
    try {
      final files = await _supabase.storage.from('chat_images').list(path: conversationId);
      if (files.isNotEmpty) {
        final filePaths = files.map((f) => '$conversationId/${f.name}').toList();
        await _supabase.storage.from('chat_images').remove(filePaths);
      }
    } catch (e) {
      // Ignore je diam-diam kalau folder tu kosong atau tak wujud
    }

    await _supabase.from('messages').delete().eq('conversation_id', conversationId);
    await _supabase.from('conversations').delete().eq('id', conversationId);
  }
}
