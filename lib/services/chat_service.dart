import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_model.dart';
import '../models/user_model.dart';
import 'local_database_service.dart';

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

  /// Fetch all conversations for the current user
  static Stream<List<ConversationModel>> getConversationsStream(String currentUserId, {required bool isRunner}) async* {
    final localDb = LocalDatabaseService.instance;

    // Kasi keluar data local on-the-spot
    final localConversations = await localDb.getConversations();
    if (localConversations.isNotEmpty) {
      // Untuk chat local, kita penuhkan terus dengan user yang dah di-cache
      List<ConversationModel> populatedLocal = [];
      for (var conv in localConversations) {
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
          
          // Save dalam SQLite (Cache)
          await localDb.insertConversations(conversations);
          return conversations;
        });
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

    var query = _supabase
        .from('conversations')
        .select()
        .or('and(user1_id.eq.$currentUserId,user2_id.eq.$otherUserId),and(user1_id.eq.$otherUserId,user2_id.eq.$currentUserId)');

    if (gigId != null) {
      query = query.eq('gig_id', gigId);
    } else {
      query = query.isFilter('gig_id', null);
    }

    final existing = await query.maybeSingle();

    if (existing != null) {
      return ConversationModel.fromJson(existing, currentUserId);
    }

    final response = await _supabase.from('conversations').insert({
      'user1_id': currentUserId,
      'user2_id': otherUserId,
      'gig_id': gigId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).select().single();

    return ConversationModel.fromJson(response, currentUserId);
  }

  /// Send a message
  static Future<MessageModel> sendMessage(MessageModel message, {String? contextGigId}) async {
    try {
      // 1. Sumbat mesej baru masuk DB pastu ambil UUID betul dia
      final response = await _supabase.from('messages').insert(message.toSupabaseJson()).select().single();
      final actualMessage = MessageModel.fromJson(response);

      // 2. Update table perbualan
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

  /// Upload image and send an image message
  static Future<MessageModel> sendImageMessage(MessageModel pendingMessage, File imageFile, {String? contextGigId}) async {
    try {
      final fileExt = imageFile.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${pendingMessage.senderId}.$fileExt';
      final filePath = '${pendingMessage.conversationId}/$fileName';
      
      await _supabase.storage.from('chat_images').upload(filePath, imageFile);
      final imageUrl = _supabase.storage.from('chat_images').getPublicUrl(filePath);

      final newMsg = pendingMessage.copyWith(
        imageUrl: imageUrl, 
        fileName: fileName,
        fileSize: imageFile.lengthSync(),
      );

      final response = await _supabase.from('messages').insert(newMsg.toSupabaseJson()).select().single();
      final actualMessage = MessageModel.fromJson(response);

      if (contextGigId != null) {
        await _supabase.rpc('update_conversation_task_message', params: {
          'p_conversation_id': pendingMessage.conversationId,
          'p_sender_id': pendingMessage.senderId,
          'p_message_content': 'Photo',
          'p_gig_id': contextGigId,
        });
      } else {
        await _supabase.from('conversations').update({
          'last_message': 'Photo',
          'last_message_sender_id': pendingMessage.senderId,
          'last_message_is_read': false,
          'updated_at': actualMessage.createdAt.toUtc().toIso8601String(),
        }).eq('id', pendingMessage.conversationId);
      }
      
      final sentMsg = actualMessage.copyWith(status: 'sent');
      await LocalDatabaseService.instance.insertMessage(sentMsg);
      
      return actualMessage;
    } catch (e) {
      await LocalDatabaseService.instance.insertMessage(pendingMessage.copyWith(status: 'failed'));
      rethrow;
    }
  }

  /// Upload file and send a file message
  static Future<MessageModel> sendFileMessage(MessageModel pendingMessage, File file, String fileName, {String? contextGigId}) async {
    try {
      final filePath = '${pendingMessage.conversationId}/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      
      await _supabase.storage.from('chat_images').upload(filePath, file);
      final fileUrl = _supabase.storage.from('chat_images').getPublicUrl(filePath);

      final newMsg = pendingMessage.copyWith(
        imageUrl: fileUrl,
        fileName: fileName,
        fileSize: file.lengthSync(),
      );

      final response = await _supabase.from('messages').insert(newMsg.toSupabaseJson()).select().single();
      final actualMessage = MessageModel.fromJson(response);

      if (contextGigId != null) {
        await _supabase.rpc('update_conversation_task_message', params: {
          'p_conversation_id': pendingMessage.conversationId,
          'p_sender_id': pendingMessage.senderId,
          'p_message_content': 'File',
          'p_gig_id': contextGigId,
        });
      } else {
        await _supabase.from('conversations').update({
          'last_message': 'File',
          'last_message_sender_id': pendingMessage.senderId,
          'last_message_is_read': false,
          'updated_at': actualMessage.createdAt.toUtc().toIso8601String(),
        }).eq('id', pendingMessage.conversationId);
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
