import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/chat_model.dart';

class LocalDatabaseService {
  static final LocalDatabaseService instance = LocalDatabaseService._init();
  static Database? _database;

  LocalDatabaseService._init();

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError('SQLite cache tidak disokong di pelayar web.');
    }
    if (_database != null) return _database!;
    _database = await _initDB('chat_database.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE messages ADD COLUMN reply_to_message TEXT').catchError((e) => null);
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE conversations ADD COLUMN task_last_messages TEXT').catchError((e) => null);
        }
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE conversations ADD COLUMN task_unread_counts TEXT').catchError((e) => null);
        }
      },
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const textNullType = 'TEXT';
    const boolType = 'INTEGER NOT NULL'; // SQLite memang tak ada storage class khas untuk Boolean.
    const integerType = 'INTEGER NOT NULL';
    const integerNullType = 'INTEGER';

    await db.execute('''
CREATE TABLE messages (
  id $idType,
  conversation_id $textType,
  sender_id $textType,
  content $textType,
  image_url $textNullType,
  is_read $boolType,
  created_at $textType,
  message_type $textType,
  file_name $textNullType,
  file_size $integerNullType,
  status $textType,
  reply_to_message $textNullType
)
''');

    await db.execute('''
CREATE TABLE conversations (
  id $idType,
  user1_id $textType,
  user2_id $textType,
  gig_id $textNullType,
  last_message $textNullType,
  last_message_sender_id $textNullType,
  last_message_is_read $boolType,
  updated_at $textType,
  unread_count $integerType,
  task_last_messages $textNullType,
  task_unread_counts $textNullType
)
''');
  }

  // Urusan Mesej
  Future<void> insertMessage(MessageModel message) async {
    if (kIsWeb) return;
    final db = await instance.database;
    final json = message.toJson();
    json['is_read'] = message.isRead ? 1 : 0;
    if (json['reply_to_message'] != null && json['reply_to_message'] is Map) {
      json['reply_to_message'] = jsonEncode(json['reply_to_message']);
    }
    
    await db.insert(
      'messages',
      json,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertMessages(List<MessageModel> messages) async {
    if (kIsWeb) return;
    final db = await instance.database;
    final batch = db.batch();
    for (var message in messages) {
      final json = message.toJson();
      json['is_read'] = message.isRead ? 1 : 0;
      if (json['reply_to_message'] != null && json['reply_to_message'] is Map) {
        json['reply_to_message'] = jsonEncode(json['reply_to_message']);
      }
      batch.insert('messages', json, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<MessageModel>> getMessages(String conversationId, {int limit = 50, int offset = 0}) async {
    if (kIsWeb) return [];
    final db = await instance.database;
    final maps = await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );

    if (maps.isNotEmpty) {
      return maps.map((json) {
        final mutableJson = Map<String, dynamic>.from(json);
        mutableJson['is_read'] = mutableJson['is_read'] == 1;
        if (mutableJson['reply_to_message'] != null && mutableJson['reply_to_message'] is String) {
          try {
            mutableJson['reply_to_message'] = jsonDecode(mutableJson['reply_to_message']);
          } catch (_) {}
        }
        return MessageModel.fromJson(mutableJson);
      }).toList();
    } else {
      return [];
    }
  }

  Future<void> updateMessageStatus(String id, String status) async {
    if (kIsWeb) return;
    final db = await instance.database;
    await db.update(
      'messages',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteMessage(String id) async {
    if (kIsWeb) return;
    final db = await instance.database;
    await db.delete(
      'messages',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Urusan Chat/Perbualan
  Future<void> insertConversation(ConversationModel conversation) async {
    if (kIsWeb) return;
    final db = await instance.database;
    final json = conversation.toJson();
    json['last_message_is_read'] = conversation.lastMessageIsRead ? 1 : 0;
    if (json['task_last_messages'] != null && json['task_last_messages'] is Map) {
      json['task_last_messages'] = jsonEncode(json['task_last_messages']);
    }
    if (json['task_unread_counts'] != null && json['task_unread_counts'] is Map) {
      json['task_unread_counts'] = jsonEncode(json['task_unread_counts']);
    }
    await db.insert('conversations', json, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertConversations(List<ConversationModel> conversations) async {
    if (kIsWeb) return;
    final db = await instance.database;
    final batch = db.batch();
    for (var conv in conversations) {
      final json = conv.toJson();
      json['last_message_is_read'] = conv.lastMessageIsRead ? 1 : 0;
      if (json['task_last_messages'] != null && json['task_last_messages'] is Map) {
        json['task_last_messages'] = jsonEncode(json['task_last_messages']);
      }
      if (json['task_unread_counts'] != null && json['task_unread_counts'] is Map) {
        json['task_unread_counts'] = jsonEncode(json['task_unread_counts']);
      }
      batch.insert('conversations', json, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<ConversationModel>> getConversations() async {
    if (kIsWeb) return [];
    final db = await instance.database;
    final maps = await db.query(
      'conversations',
      orderBy: 'updated_at DESC',
    );

    if (maps.isNotEmpty) {
      return maps.map((json) {
        final mutableJson = Map<String, dynamic>.from(json);
        mutableJson['last_message_is_read'] = mutableJson['last_message_is_read'] == 1;
        if (mutableJson['task_last_messages'] != null && mutableJson['task_last_messages'] is String) {
          try {
            mutableJson['task_last_messages'] = jsonDecode(mutableJson['task_last_messages']);
          } catch (_) {}
        }
        if (mutableJson['task_unread_counts'] != null && mutableJson['task_unread_counts'] is String) {
          try {
            mutableJson['task_unread_counts'] = jsonDecode(mutableJson['task_unread_counts']);
          } catch (_) {}
        }
        return ConversationModel.fromJson(mutableJson, '');  
      }).toList();
    } else {
      return [];
    }
  }
}
