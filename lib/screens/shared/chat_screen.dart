import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:provider/provider.dart';
import '../../utils/app_theme.dart';
import '../../services/chat_service.dart';
import '../../widgets/chat/user_group_conversation_card.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../models/chat_model.dart';
import '../../providers/auth_provider.dart';
import '../../models/gig_model.dart';
import '../../services/gig_service.dart';
import '../../widgets/typing_indicator.dart';
import '../../services/review_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../../services/local_database_service.dart';

import '../../services/push_service.dart';

// ============================================================
// Ngam App — Skrin Chat
// Senarai chat ala glassmorphism dengan UI mesej
// ============================================================

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late Stream<List<ConversationModel>> _conversationsStream;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';
  List<String> _matchingConversationIds = [];
  Set<String> _onlineUserIds = {};

  void _onSearchChanged(String query) async {
    setState(() {
      _searchQuery = query.trim().toLowerCase();
    });

    if (_searchQuery.isNotEmpty) {
      final db = await LocalDatabaseService.instance.database;
      final maps = await db.query(
        'messages',
        columns: ['conversation_id'],
        where: 'content LIKE ?',
        whereArgs: ['%$_searchQuery%'],
        distinct: true,
      );
      if (mounted) {
        setState(() {
          _matchingConversationIds = maps.map((e) => e['conversation_id'] as String).toList();
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _matchingConversationIds = [];
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      if (mounted) setState(() {});
    });
    final currentUser = context.read<AuthProvider>().user;
    if (currentUser != null) {
      _conversationsStream = ChatService.getConversationsStream(currentUser.id, isRunner: currentUser.role == 'runner');
      ChatService.trackPresence(currentUser.id);
      ChatService.onlineUsers.addListener(_onPresenceUpdate);
    } else {
      _conversationsStream = const Stream.empty();
    }
  }

  void _onPresenceUpdate() {
    if (mounted) {
      setState(() {
        _onlineUserIds = ChatService.onlineUsers.value;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    ChatService.onlineUsers.removeListener(_onPresenceUpdate);
    ChatService.stopTrackingPresence();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = context.read<AuthProvider>().user;
    if (currentUser == null) return const Scaffold(body: Center(child: Text("Not logged in")));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
              children: [
                // ─── Header ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'chat.messages'.tr(),
                          style: GoogleFonts.outfit(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── Search Bar (Cari Chat) ──────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: GlassContainer(
                    useOwnLayer: true,
                    quality: GlassQuality.standard,
                    shape: LiquidRoundedSuperellipse(borderRadius: 24.0),
                    settings: _glassSettings(isDark),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.white.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedSearch01,
                              color: isDark ? Colors.white70 : Colors.grey.shade600,
                              size: 20,
                              strokeWidth: 2.0,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocus,
                              onChanged: _onSearchChanged,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                              decoration: InputDecoration(
                                hintText: 'chat.search_conversations'.tr(),
                                hintStyle: TextStyle(
                                  fontSize: 15,
                                  color: isDark ? Colors.white54 : Colors.grey.shade500,
                                  fontWeight: FontWeight.w400,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isDense: true,
                                filled: false,
                                fillColor: Colors.transparent,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                                _searchFocus.unfocus();
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white24 : Colors.black12,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close,
                                  color: isDark ? Colors.white : Colors.black87,
                                  size: 14,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ─── Label Seksyen ───────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'chat.recent'.tr(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                ),

                // ─── Senarai Chat/Perbualan ──────────────────────
                Expanded(
                  child: StreamBuilder<List<ConversationModel>>(
                    stream: _conversationsStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                         return _buildChatShimmer(isDark);
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                         return Center(child: Text("chat.no_conversations".tr()));
                      }
                      final allConversations = snapshot.data!;
                      final conversations = _searchQuery.isEmpty 
                          ? allConversations 
                          : allConversations.where((c) {
                              final nameMatch = (c.otherUser?.userName ?? '').toLowerCase().contains(_searchQuery);
                              final msgMatch = _matchingConversationIds.contains(c.id);
                              return nameMatch || msgMatch;
                            }).toList();
                      
                      final groupedConversations = <String, List<ConversationModel>>{};
                      for (var c in conversations) {
                        if (c.otherUser == null) continue;
                        groupedConversations.putIfAbsent(c.otherUser!.id, () => []).add(c);
                      }
                      
                      final groupedList = groupedConversations.values.toList();
                      
                      if (_searchQuery.isNotEmpty) {
                        groupedList.sort((aList, bList) {
                          final aName = (aList.first.otherUser?.userName ?? '').toLowerCase();
                          final bName = (bList.first.otherUser?.userName ?? '').toLowerCase();
                          final aMatchName = aName.contains(_searchQuery);
                          final bMatchName = bName.contains(_searchQuery);
                          
                          if (aMatchName && !bMatchName) return -1;
                          if (!aMatchName && bMatchName) return 1;
                          return 0; // Kekalkan turutan masa (latest message) kalau dua-dua sama level
                        });
                      }
                      if (groupedList.isEmpty) {
                         return Center(child: Text("chat.no_matching_conversations".tr()));
                      }
                      
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                        physics: const BouncingScrollPhysics(),
                        itemCount: groupedList.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final userConvs = groupedList[index];
                          final otherUser = userConvs.first.otherUser!;
                          final isOnline = _onlineUserIds.contains(otherUser.id);
                          return UserGroupConversationCard(
                            otherUser: otherUser,
                            conversations: userConvs,
                            currentUserId: currentUser.id,
                            isDark: isDark,
                            isOnline: isOnline,
                            onTap: (c, gigId) => _openChat(context, c, isDark, gigId),
                            onLongPress: (c) => _showDeleteDialog(context, c),
                          );
                        },
                      );
                    }
                  ),
                ),
              ],
            ),
          ),
        );
  }

  Widget _buildChatShimmer(bool isDark) {
    final baseColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05);
    final highlightColor = isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.15);

    Widget buildSkeletonBox(double height, [double? width, double borderRadius = 8]) {
      return Container(
        height: height,
        width: width ?? double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      );
    }

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        physics: const BouncingScrollPhysics(),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              buildSkeletonBox(44, 44, 22),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildSkeletonBox(18, 120),
                    const SizedBox(height: 8),
                    buildSkeletonBox(14),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  buildSkeletonBox(12, 40),
                  const SizedBox(height: 8),
                  buildSkeletonBox(24, 24, 12),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  void _openChat(BuildContext context, ConversationModel c, bool isDark, String? initialGigId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatThreadScreen(conversation: c, initialGigId: initialGigId),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, ConversationModel c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "chat.delete_chat".tr(),
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          "chat.delete_chat_desc".tr(),
          style: GoogleFonts.outfit(
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("wallet.cancel".tr(), style: TextStyle(color: Colors.grey.shade500)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ChatService.deleteConversation(c.id);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete chat: $e')),
                  );
                }
              }
            },
            child: Text("chat.delete".tr(), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  LiquidGlassSettings _glassSettings(bool isDark) => LiquidGlassSettings(
        thickness: 0.1,
        blur: 15,
        refractiveIndex: 1.0,
        glassColor: Colors.transparent,
        lightAngle: 45.0,
        lightIntensity: isDark ? 0.1 : 0.2,
        ambientStrength: 1.0,
        saturation: 1.0,
        chromaticAberration: 0.0,
      );
}



// ─── Skrin Thread Chat (Dalam Chat) ───────────────────────────
class ChatThreadScreen extends StatefulWidget {
  final ConversationModel conversation;
  final String? initialGigId;

  const ChatThreadScreen({super.key, required this.conversation, this.initialGigId});

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  
  bool _isUploadingImage = false;
  bool _isLoading = false;
  bool _hasMore = true;
  
  late String currentUserId;
  late String otherUserId;
  
  final List<MessageModel> _messages = [];
  RealtimeChannel? _subscription;
  Map<String, dynamic>? _otherUserProfile;

  bool _isOtherTyping = false;
  Timer? _typingTimer;
  MessageModel? _replyingToMessage;
  final Map<String, GlobalKey> _messageKeys = {};
  GigModel? _linkedGig;
  List<GigModel> _sharedGigs = [];

  String _formatDateDivider(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(date.year, date.month, date.day);

    if (msgDate == today) {
      return 'chat.today'.tr();
    } else if (msgDate == yesterday) {
      return 'chat.yesterday'.tr();
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      if (date.year == now.year) {
        return '${date.day} ${months[date.month - 1]}';
      }
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    }
  }

  dynamic _getIconForStatus(String status) {
    switch (status.toUpperCase()) {
      case 'OPEN':
        return HugeIcons.strokeRoundedAlert01;
      case 'LOCKED':
        return HugeIcons.strokeRoundedLockKey;
      case 'IN-PROGRESS':
        return HugeIcons.strokeRoundedWorkHistory;
      case 'COMPLETED':
        return HugeIcons.strokeRoundedTick01;
      case 'CANCELLED':
        return HugeIcons.strokeRoundedCancel01;
      default:
        return HugeIcons.strokeRoundedWorkHistory;
    }
  }

  Color _getColorForStatus(String status, bool isDark, bool isActive) {
    switch (status.toUpperCase()) {
      case 'OPEN':
        return AppTheme.primary;
      case 'LOCKED':
        return Colors.orange;
      case 'IN-PROGRESS':
        return Colors.blue;
      case 'COMPLETED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      default:
        return AppTheme.primary;
    }
  }
  
  List<MessageModel> get _filteredMessages {
    if (_linkedGig == null) {
      return _messages.where((msg) => !msg.content.startsWith('__SYSTEM__')).toList();
    }
    
    List<MessageModel> result = [];
    String? currentContextId;
    
    // Proses mesej dari yang paling lama sampai paling baru
    for (int i = _messages.length - 1; i >= 0; i--) {
      final msg = _messages[i];
      
      if (msg.content.startsWith('__SYSTEM__Context:')) {
        currentContextId = msg.content.replaceFirst('__SYSTEM__Context:', '');
        continue; // Sorok mesej sistem
      } else if (msg.content.startsWith('__SYSTEM__:')) {
        final title = msg.content.replaceFirst('__SYSTEM__:Topic changed to ', '');
        final matchedGigs = _sharedGigs.where((g) => g.title == title);
        if (matchedGigs.isNotEmpty) {
          currentContextId = matchedGigs.first.id;
        }
        continue; // Sorok mesej sistem
      } else if (msg.content.startsWith('__TASK_CARD__:')) {
        final parts = msg.content.replaceFirst('__TASK_CARD__:', '').split('|');
        if (parts.isNotEmpty) currentContextId = parts[0];
      }
      
      // Kalau tak ada context set lagi, default ambil gig yang pertama
      // supaya mesej lama task tu tak melimpah masuk tab task lain.
      if (currentContextId == null && _sharedGigs.isNotEmpty) {
        currentContextId = _sharedGigs.first.id;
      }
      
      if (currentContextId == _linkedGig!.id) {
        result.insert(0, msg);
      }
    }
    return result;
  }

  @override
  void initState() {
    super.initState();
    currentUserId = context.read<AuthProvider>().user!.id;
    otherUserId = widget.conversation.user1Id == currentUserId ? widget.conversation.user2Id : widget.conversation.user1Id;
    
    _loadOtherUserProfile();
    _loadMessages();
    _loadDraft();
    _loadGigDetails();
    
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        _loadMessages();
      }
    });

    _subscription = ChatService.subscribeToChatEvents(
      widget.conversation.id,
      onNewMessage: (newMsg) {
        if (mounted) {
          setState(() {
            final existingIndex = _messages.indexWhere((m) => m.id == newMsg.id || (m.status == 'sending' && m.content == newMsg.content));
            if (existingIndex != -1) {
              _messages[existingIndex] = newMsg;
            } else {
              _messages.insert(0, newMsg);
            }
          });
        }
      },
      onTypingStatus: (String userId, bool isTyping) {
        if (userId == otherUserId && mounted) {
          setState(() {
            _isOtherTyping = isTyping;
          });
        }
      },
    );

    // Listen supaya bila user reply dari notification, chat auto-refresh
    lastNotificationReplyConversationId.addListener(_onNotificationReply);

    // Dah buang markMessagesAsRead global dari initState
    // Sekarang dia handle waktu _loadGigDetails dengan onPageChanged je
  }

  void _onTextChanged(String text) {
    if (_typingTimer?.isActive ?? false) _typingTimer!.cancel();
    
    // Save draf chat
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('draft_${widget.conversation.id}', text);
    });

    _subscription?.sendBroadcastMessage(event: 'typing', payload: {'user_id': currentUserId, 'is_typing': true});
    
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _subscription?.sendBroadcastMessage(event: 'typing', payload: {'user_id': currentUserId, 'is_typing': false});
    });
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draft = prefs.getString('draft_${widget.conversation.id}');
    if (draft != null && draft.isNotEmpty && mounted) {
      _controller.text = draft;
    }
  }

  Future<void> _loadGigDetails() async {
    try {
      final shared = await GigService.fetchSharedGigs(currentUserId, otherUserId);
      if (mounted) {
        setState(() {
          _sharedGigs = shared;
          
          String? targetGigId = widget.initialGigId ?? widget.conversation.gigId;
          
          if (targetGigId != null) {
            final idx = _sharedGigs.indexWhere((g) => g.id == targetGigId);
            if (idx != -1) {
              _linkedGig = _sharedGigs[idx];
            } else {
              // Fallback kalau tak terjumpa dalam shared cache
              GigService.fetchGigById(targetGigId).then((g) {
                if (mounted) setState(() => _linkedGig = g);
              });
            }
          }
        });
        
        ChatService.markMessagesAsRead(widget.conversation.id, otherUserId, gigId: _linkedGig?.id);
      }
    } catch (e) {
      debugPrint('Error loading gig details: $e');
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _subscription?.unsubscribe();
    _controller.dispose();
    _scrollController.dispose();
    lastNotificationReplyConversationId.removeListener(_onNotificationReply);
    super.dispose();
  }

  void _onNotificationReply() {
    final convId = lastNotificationReplyConversationId.value;
    if (convId == widget.conversation.id && mounted) {
      // Reset hasMore dan reload mesej dari awal supaya mesej baru muncul
      _hasMore = true;
      _messages.clear();
      _loadMessages();
    }
  }

  Future<void> _loadOtherUserProfile() async {
    final profile = await ChatService.getUserProfile(otherUserId);
    if (mounted) {
      setState(() {
        _otherUserProfile = profile;
      });
    }
  }

  Future<void> _loadMessages() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    final currentOffset = _messages.length;

    // 1. Terus load dari cache local supaya laju
    final localMessages = await LocalDatabaseService.instance.getMessages(widget.conversation.id, offset: currentOffset, limit: 50);
    
    if (mounted) {
      setState(() {
        bool addedLocal = false;
        for (var msg in localMessages) {
          if (!_messages.any((m) => m.id == msg.id)) {
            _messages.add(msg);
            addedLocal = true;
          }
        }
        if (addedLocal) {
          _messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        }
        _isLoading = false; // Cepat-cepat sorok loading spinner tu
      });
    }

    // 2. Tarik dari database (background) untuk sync mesej baru
    try {
      final networkMessages = await ChatService.getMessages(widget.conversation.id, offset: currentOffset, limit: 50);
      if (mounted) {
        setState(() {
          bool addedNetwork = false;
          for (var msg in networkMessages) {
            final index = _messages.indexWhere((m) => m.id == msg.id);
            if (index != -1) {
              _messages[index] = msg; // Update status (contoh: blue tick read receipt)
            } else {
              _messages.add(msg);
              addedNetwork = true;
            }
          }
          if (addedNetwork) {
            _messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          }
          
          if (networkMessages.isEmpty && localMessages.isEmpty) {
            _hasMore = false;
          }
        });
      }
    } catch (_) {
      // Ignore je kalau tengah offline
    }
  }
  void _scrollToMessage(String messageId) async {
    final key = _messageKeys[messageId];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );
    } else {
      // Tak render lagi, cuba jump kasi dekat sikit
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        _scrollController.animateTo(
          index * 80.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _cancelReply() {
    setState(() => _replyingToMessage = null);
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    await _ensureContextIsSet();

    // Buang draf chat
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('draft_${widget.conversation.id}');
    });

    Map<String, dynamic>? replyPayload;
    if (_replyingToMessage != null) {
      final isReplyMe = _replyingToMessage!.senderId == currentUserId;
      replyPayload = {
        'id': _replyingToMessage!.id,
        'content': _replyingToMessage!.content,
        'sender_name': isReplyMe ? 'You' : (_otherUserProfile?['name'] ?? 'User'),
      };
    }
    
    _cancelReply();

    final pendingMsg = MessageModel(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: widget.conversation.id,
      senderId: currentUserId,
      content: text,
      isRead: false,
      createdAt: DateTime.now(),
      status: 'sending',
      replyToMessage: replyPayload,
    );

    setState(() {
      _messages.insert(0, pendingMsg);
    });

    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }

    try {
      final actualMsg = await ChatService.sendMessage(pendingMsg, contextGigId: _linkedGig?.id);
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == pendingMsg.id);
          if (index != -1) _messages[index] = actualMsg;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == pendingMsg.id);
          if (index != -1) _messages[index] = pendingMsg.copyWith(status: 'failed');
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _isUploadingImage = true);
      
      await _ensureContextIsSet();
      
      final pendingMsg = MessageModel(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        conversationId: widget.conversation.id,
        senderId: currentUserId,
        content: '📷 Photo',
        isRead: false,
        createdAt: DateTime.now(),
        messageType: 'image',
        status: 'sending',
      );

      setState(() {
        _messages.insert(0, pendingMsg);
      });

      try {
        final actualMsg = await ChatService.sendImageMessage(pendingMsg, File(pickedFile.path), contextGigId: _linkedGig?.id);
        if (mounted) {
          setState(() {
            final index = _messages.indexWhere((m) => m.id == pendingMsg.id);
            if (index != -1) _messages[index] = actualMsg;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            final index = _messages.indexWhere((m) => m.id == pendingMsg.id);
            if (index != -1) _messages[index] = pendingMsg.copyWith(status: 'failed');
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send image: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isUploadingImage = false);
      }
    }
  }

  void _showAttachmentOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: GlassContainer(
            useOwnLayer: true,
            quality: GlassQuality.standard,
            shape: LiquidRoundedSuperellipse(borderRadius: 24.0),
            settings: LiquidGlassSettings(
              thickness: 0.1,
              blur: 15.0,
              refractiveIndex: 1.0,
              glassColor: Colors.transparent,
              lightAngle: 45.0,
              lightIntensity: isDark ? 0.1 : 0.2,
              ambientStrength: 1.0,
              saturation: 1.0,
              chromaticAberration: 0.0,
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.4), width: 1.0),
              ),
              child: Wrap(
                children: [
              ListTile(
                leading: const HugeIcon(icon: HugeIcons.strokeRoundedCamera01, color: AppTheme.primary, size: 24),
                title: Text('chat.camera'.tr(), style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const HugeIcon(icon: HugeIcons.strokeRoundedImage01, color: AppTheme.primary, size: 24),
                title: Text('chat.gallery'.tr(), style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const HugeIcon(icon: HugeIcons.strokeRoundedFile01, color: AppTheme.primary, size: 24),
                title: Text('chat.file'.tr(), style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                onTap: () {
                  Navigator.pop(context);
                  _pickFile();
                },
              ),
              if (_sharedGigs.isNotEmpty)
                ListTile(
                  leading: const HugeIcon(icon: HugeIcons.strokeRoundedWorkHistory, color: AppTheme.primary, size: 24),
                  title: Text('chat.task_card'.tr(), style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  onTap: () {
                    Navigator.pop(context);
                    _showTaskSelectorBottomSheet(isAttachMode: true);
                  },
                ),
              if (context.read<AuthProvider>().isRunner) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Runner Tools', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 12)),
                ),
                ListTile(
                  leading: const HugeIcon(icon: HugeIcons.strokeRoundedInvoice01, color: AppTheme.primary, size: 24),
                  title: Text('chat.send_quote'.tr(), style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  onTap: () {
                    Navigator.pop(context);
                    _showCreateQuoteDialog();
                  },
                ),
                if (_sharedGigs.isNotEmpty)
                  ListTile(
                    leading: const HugeIcon(icon: HugeIcons.strokeRoundedMoney04, color: AppTheme.primary, size: 24),
                    title: Text('chat.counter_offer'.tr(), style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                    onTap: () {
                      Navigator.pop(context);
                      _showCounterOfferDialog();
                    },
                  ),
                ListTile(
                  leading: const HugeIcon(icon: HugeIcons.strokeRoundedLocation01, color: AppTheme.primary, size: 24),
                  title: Text('chat.request_location'.tr(), style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  onTap: () {
                    Navigator.pop(context);
                    _sendRequestLocation();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  ),
);
  }

  void _sendRequestLocation() async {
    final msgId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final newMsg = MessageModel(
      id: msgId,
      conversationId: widget.conversation.id,
      senderId: currentUserId,
      content: '__REQUEST_LOC__',
      isRead: false,
      createdAt: DateTime.now(),
      status: 'sending',
    );
    setState(() { _messages.insert(0, newMsg); });
    await ChatService.sendMessage(newMsg, contextGigId: _linkedGig?.id);
  }

  void _showCreateQuoteDialog() {
    final priceController = TextEditingController();
    final detailsController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('chat.send_quote'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Price (RM)', prefixText: 'RM '),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: detailsController,
                decoration: const InputDecoration(labelText: 'Description / Scope'),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('wallet.cancel'.tr())),
            ElevatedButton(
              onPressed: () async {
                if (priceController.text.isEmpty) return;
                Navigator.pop(context);
                final price = priceController.text.trim();
                final details = detailsController.text.trim();
                
                final msgId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
                final newMsg = MessageModel(
                  id: msgId,
                  conversationId: widget.conversation.id,
                  senderId: currentUserId,
                  content: '__QUOTE__:$price|$details',
                  isRead: false,
                  createdAt: DateTime.now(),
                  status: 'sending',
                );
                setState(() { _messages.insert(0, newMsg); });
                await ChatService.sendMessage(newMsg, contextGigId: _linkedGig?.id);
              },
              child: Text('chat.send_quote'.tr()),
            ),
          ],
        );
      },
    );
  }

  void _showCounterOfferDialog() {
    if (_linkedGig == null) return;
    final priceController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('chat.counter_offer'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Original Bounty: ${_linkedGig!.formattedBounty}'),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'New Price (RM)', prefixText: 'RM '),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('wallet.cancel'.tr())),
            ElevatedButton(
              onPressed: () async {
                if (priceController.text.isEmpty) return;
                Navigator.pop(context);
                final newPrice = priceController.text.trim();
                
                final msgId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
                final newMsg = MessageModel(
                  id: msgId,
                  conversationId: widget.conversation.id,
                  senderId: currentUserId,
                  content: '__COUNTER__:${_linkedGig!.formattedBounty}|$newPrice|${_linkedGig!.id}',
                  isRead: false,
                  createdAt: DateTime.now(),
                  status: 'sending',
                );
                setState(() { _messages.insert(0, newMsg); });
                await ChatService.sendMessage(newMsg, contextGigId: _linkedGig?.id);
              },
              child: Text('chat.counter_offer_btn'.tr()),
            ),
          ],
        );
      },
    );
  }

  void _showTaskSelectorBottomSheet({required bool isAttachMode}) {
    if (_sharedGigs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active tasks between you two.')));
      return;
    }
    
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: GlassContainer(
              useOwnLayer: true,
              quality: GlassQuality.standard,
              shape: LiquidRoundedSuperellipse(borderRadius: 24.0),
              settings: LiquidGlassSettings(
                thickness: 0.1,
                blur: 15.0,
                refractiveIndex: 1.0,
                glassColor: Colors.transparent,
                lightAngle: 45.0,
                lightIntensity: isDark ? 0.1 : 0.2,
                ambientStrength: 1.0,
                saturation: 1.0,
                chromaticAberration: 0.0,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.4), width: 1.0),
                ),
                child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isAttachMode ? 'Attach Task Card' : 'Switch Chat Context',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ..._sharedGigs.map((gig) {
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const HugeIcon(icon: HugeIcons.strokeRoundedWorkHistory, color: AppTheme.primary, size: 20),
                  ),
                  title: Text(gig.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${gig.formattedBounty} • ${gig.status}'),
                  onTap: () {
                    Navigator.pop(context);
                    if (isAttachMode) {
                      _sendTaskCard(gig);
                    } else {
                      setState(() {
                        _linkedGig = gig;
                      });
                      ChatService.markMessagesAsRead(widget.conversation.id, otherUserId, gigId: gig.id);
                    }
                  },
                );
              }),
            ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _ensureContextIsSet() async {
    if (_linkedGig == null) return;
    
    String? lastContextId;
    for (final msg in _messages) {
      if (msg.content.startsWith('__SYSTEM__Context:')) {
        lastContextId = msg.content.replaceFirst('__SYSTEM__Context:', '');
        break;
      } else if (msg.content.startsWith('__SYSTEM__:')) {
        final title = msg.content.replaceFirst('__SYSTEM__:Topic changed to ', '');
        final matchedGigs = _sharedGigs.where((g) => g.title == title);
        if (matchedGigs.isNotEmpty) lastContextId = matchedGigs.first.id;
        break;
      } else if (msg.content.startsWith('__TASK_CARD__:')) {
        final parts = msg.content.replaceFirst('__TASK_CARD__:', '').split('|');
        if (parts.isNotEmpty) lastContextId = parts[0];
        break;
      }
    }
    
    if (lastContextId != _linkedGig!.id) {
      final msgId = 'temp_${DateTime.now().millisecondsSinceEpoch}_sys';
      final newMsg = MessageModel(
        id: msgId,
        conversationId: widget.conversation.id,
        senderId: currentUserId,
        content: '__SYSTEM__Context:${_linkedGig!.id}',
        isRead: true, // Mesej sistem ni kira read secara auto la
        createdAt: DateTime.now().subtract(const Duration(milliseconds: 1)),
        status: 'sending',
      );
      setState(() { _messages.insert(0, newMsg); });
      await ChatService.sendSystemMessage(newMsg);
    }
  }

  Future<void> _sendTaskCard(GigModel gig) async {
    await _ensureContextIsSet();
    final msgId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final contentStr = '__TASK_CARD__:${gig.id}|${gig.title}|${gig.formattedBounty}|${gig.status}';
    final newMsg = MessageModel(
      id: msgId,
      conversationId: widget.conversation.id,
      senderId: currentUserId,
      content: contentStr,
      isRead: false,
      createdAt: DateTime.now(),
      status: 'sending',
    );
    setState(() { _messages.insert(0, newMsg); });
    await ChatService.sendMessage(newMsg, contextGigId: _linkedGig?.id);
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'csv'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() => _isUploadingImage = true);
        
        await _ensureContextIsSet();
        
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;

        final pendingMsg = MessageModel(
          id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
          conversationId: widget.conversation.id,
          senderId: currentUserId,
          content: '📎 File',
          isRead: false,
          createdAt: DateTime.now(),
          messageType: 'file',
          fileName: fileName,
          fileSize: file.lengthSync(),
          status: 'sending',
        );

        setState(() {
          _messages.insert(0, pendingMsg);
        });

        try {
          final actualMsg = await ChatService.sendFileMessage(pendingMsg, file, fileName, contextGigId: _linkedGig?.id);
          if (mounted) {
            setState(() {
              final index = _messages.indexWhere((m) => m.id == pendingMsg.id);
              if (index != -1) _messages[index] = actualMsg;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              final index = _messages.indexWhere((m) => m.id == pendingMsg.id);
              if (index != -1) _messages[index] = pendingMsg.copyWith(status: 'failed');
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to send file: $e')),
            );
          }
        } finally {
          if (mounted) setState(() => _isUploadingImage = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick file: $e')));
      }
    }
  }

  void _showProfileBrief(BuildContext context, Map<String, dynamic> userData, bool isDark) {
    final name = userData['name'] ?? 'User';
    final email = userData['email'] ?? '';
    final role = userData['role'] ?? 'Unknown';
    final avatarUrl = userData['avatar_url'];
    final userId = userData['id'] as String;
    final avatar = name.isNotEmpty ? name[0].toUpperCase() : '?';

    showDialog(
      context: context,
      builder: (_) => Center(
        child: Material(
          type: MaterialType.transparency,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: GlassContainer(
                useOwnLayer: true,
                quality: GlassQuality.standard,
                shape: LiquidRoundedSuperellipse(borderRadius: 24.0),
              settings: LiquidGlassSettings(
                thickness: 0.1,
                blur: 15,
                refractiveIndex: 1.0,
                glassColor: Colors.transparent,
                lightAngle: 45.0,
                lightIntensity: isDark ? 0.1 : 0.2,
                ambientStrength: 1.0,
                saturation: 1.0,
                chromaticAberration: 0.0,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(24.0),
                  border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.6), width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4), width: 2),
                        image: avatarUrl != null
                            ? DecorationImage(
                                image: CachedNetworkImageProvider(avatarUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: avatarUrl == null
                          ? Center(
                              child: Text(
                                avatar,
                                style: GoogleFonts.outfit(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primary,
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        role.toString().toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      email,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.grey,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    // Bahagian Statistik
                    FutureBuilder<List<dynamic>>(
                      future: Future.wait([
                        GigService.getPostedCount(userId),
                        GigService.getCompletedCount(userId),
                        ReviewService.getAverageRating(userId),
                      ]),
                      builder: (context, snapshot) {
                        int posted = 0;
                        int completed = 0;
                        double rating = 0.0;
                        
                        if (snapshot.hasData) {
                          posted = snapshot.data![0] as int;
                          completed = snapshot.data![1] as int;
                          rating = snapshot.data![2] as double;
                        }

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildGlassStat(isDark, 'Posted', '$posted', HugeIcons.strokeRoundedUpload01),
                            _buildGlassStat(isDark, 'Done', '$completed', HugeIcons.strokeRoundedTick01),
                            _buildGlassStat(isDark, 'Rating', rating > 0 ? rating.toStringAsFixed(1) : '-', HugeIcons.strokeRoundedStar),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    GlassContainer(
                      useOwnLayer: true,
                      quality: GlassQuality.standard,
                      shape: LiquidRoundedSuperellipse(borderRadius: 20.0),
                      settings: LiquidGlassSettings(
                        thickness: 0.1,
                        blur: 15,
                        refractiveIndex: 1.0,
                        glassColor: Colors.transparent,
                        lightAngle: 45.0,
                        lightIntensity: isDark ? 0.1 : 0.2,
                        ambientStrength: 1.0,
                        saturation: 1.0,
                        chromaticAberration: 0.0,
                      ),
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                          ),
                          child: const Center(
                            child: Text(
                              'Close',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildGlassStat(bool isDark, String label, String value, dynamic icon) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: GlassContainer(
          useOwnLayer: true,
          quality: GlassQuality.standard,
          shape: LiquidRoundedSuperellipse(borderRadius: 24.0),
          settings: LiquidGlassSettings(
            thickness: 0.1,
            blur: 15,
            refractiveIndex: 1.0,
            glassColor: Colors.transparent,
            lightAngle: 45.0,
            lightIntensity: isDark ? 0.1 : 0.2,
            ambientStrength: 1.0,
            saturation: 1.0,
            chromaticAberration: 0.0,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.6), width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                HugeIcon(icon: icon, size: 22, color: AppTheme.primary),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildQuickActionChip(String text, bool isDark) {
    return GestureDetector(
      onTap: () {
        _controller.text = text;
        _sendMessage();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.5),
                  width: 1.0,
                ),
              ),
              child: Center(
                child: Text(
                  text,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ─── Content Utama ──────────────────────────────────────────
          // ─── Ruangan Mesej ───────────────────────────────────
          Positioned.fill(
            child: Builder(
              builder: (context) {
                final displayMessages = _filteredMessages;
                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(16, _linkedGig != null ? 170 : 80, 16, 160), // Bagi padding extra kat atas untuk top bar & card, bawah untuk type chat
                  physics: const BouncingScrollPhysics(),
                  itemCount: displayMessages.length + (_isLoading ? 1 : 0) + (_isOtherTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_isOtherTyping) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const SizedBox(width: 8),
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: AppTheme.primary,
                                backgroundImage: _otherUserProfile?['avatar_url'] != null && _otherUserProfile!['avatar_url'].isNotEmpty 
                                    ? CachedNetworkImageProvider(_otherUserProfile!['avatar_url']) 
                                    : null,
                                child: _otherUserProfile?['avatar_url'] == null || _otherUserProfile!['avatar_url'].isEmpty
                                    ? Text(
                                        _otherUserProfile?['name'] != null && _otherUserProfile!['name'].isNotEmpty 
                                            ? _otherUserProfile!['name'][0].toUpperCase() 
                                            : '?',
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              TypingIndicator(isDark: isDark),
                            ],
                          ),
                        );
                      }
                      index--;
                    }
                    
                    if (index == displayMessages.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    
                    final msg = displayMessages[index];
                    
                    // Logic grouping: sorok avatar kalau mesej sebelah dari orang sama (selang masa bawah 1 minit)
                    bool showAvatar = true;
                    if (index < displayMessages.length - 1) {
                      final nextMsg = displayMessages[index + 1];
                      if (nextMsg.senderId == msg.senderId) {
                        final timeDiff = msg.createdAt.difference(nextMsg.createdAt).inSeconds.abs();
                        if (timeDiff < 60) {
                          showAvatar = false;
                        }
                      }
                    }
                      bool showDateDivider = false;
                      if (index == displayMessages.length - 1) {
                        showDateDivider = true;
                      } else {
                        final olderMsg = displayMessages[index + 1];
                        if (msg.createdAt.year != olderMsg.createdAt.year ||
                            msg.createdAt.month != olderMsg.createdAt.month ||
                            msg.createdAt.day != olderMsg.createdAt.day) {
                          showDateDivider = true;
                        }
                      }

                      Widget messageWidget = SwipeToReply(
                        isMe: msg.senderId == currentUserId,
                        onSwipe: () {
                          setState(() => _replyingToMessage = msg);
                          HapticFeedback.lightImpact();
                        },
                        child: Container(
                          key: _messageKeys.putIfAbsent(msg.id, () => GlobalKey()),
                          child: _MessageBubble(
                            message: msg, 
                            isDark: isDark, 
                            isMe: msg.senderId == currentUserId,
                            showAvatar: showAvatar,
                            otherAvatarUrl: _otherUserProfile?['avatar_url'],
                            otherName: _otherUserProfile?['name'],
                            onReplyTap: () {
                              if (msg.replyToMessage != null && msg.replyToMessage!['id'] != null) {
                                _scrollToMessage(msg.replyToMessage!['id']);
                              }
                            },
                            onImageTap: () {
                              if (!msg.isImage) return;
                              final imageMessages = _messages.where((m) => m.isImage).toList();
                              final initialIndex = imageMessages.indexWhere((m) => m.id == msg.id);
                              if (initialIndex != -1) {
                                showDialog(
                                  context: context,
                                  builder: (_) => _ImageViewerDialog(
                                    imageUrls: imageMessages.map((m) => m.imageUrl!).toList(),
                                    initialIndex: initialIndex,
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      );

                      if (showDateDivider) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _formatDateDivider(msg.createdAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                              ),
                            ),
                            messageWidget,
                          ],
                        );
                      }

                      return messageWidget;
              },
            );
          }),
        ),

          // ─── Tempat Taip Chat ────────────────────────────────
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom > 0
                ? 8
                : MediaQuery.of(context).padding.bottom + 8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      if (context.read<AuthProvider>().isRunner) ...[
                        _buildQuickActionChip('I am available', isDark),
                        _buildQuickActionChip('Please send a photo', isDark),
                        _buildQuickActionChip('Can you share your location?', isDark),
                        _buildQuickActionChip('I will arrive soon', isDark),
                        _buildQuickActionChip('Let me check my schedule', isDark),
                      ] else ...[
                        _buildQuickActionChip('Can you help me with this?', isDark),
                        _buildQuickActionChip('How much do you charge?', isDark),
                        _buildQuickActionChip('When can you start?', isDark),
                        _buildQuickActionChip('Here is a photo of the issue.', isDark),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_replyingToMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.reply_rounded, color: AppTheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _replyingToMessage!.senderId == currentUserId ? 'Replying to You' : 'Replying to ${_otherUserProfile?['name'] ?? 'User'}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 12),
                              ),
                              Text(
                                _replyingToMessage!.content,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _cancelReply,
                          child: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: GlassContainer(
                    useOwnLayer: true,
                    quality: GlassQuality.standard,
                    shape: LiquidRoundedSuperellipse(borderRadius: 32.0),
                    settings: LiquidGlassSettings(
                      thickness: 0.1,
                      blur: 2.0,
                      refractiveIndex: 1.0,
                      glassColor: Colors.transparent,
                      lightAngle: 45.0,
                      lightIntensity: isDark ? 0.1 : 0.2,
                      ambientStrength: 1.0,
                      saturation: 1.0,
                      chromaticAberration: 0.0,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.white.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.4),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _showAttachmentOptions,
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: HugeIcon(
                                icon: HugeIcons.strokeRoundedAttachment01,
                                color: Colors.grey.shade500,
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              onChanged: _onTextChanged,
                              onSubmitted: (_) {
                                _typingTimer?.cancel();
                                _subscription?.sendBroadcastMessage(event: 'typing', payload: {'user_id': currentUserId, 'is_typing': false});
                                _sendMessage();
                              },
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              decoration: InputDecoration(
                                filled: false,
                                hintText: 'Type a message...',
                                hintStyle: TextStyle(color: Colors.grey.shade500),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    _typingTimer?.cancel();
                    _subscription?.sendBroadcastMessage(event: 'typing', payload: {'user_id': currentUserId, 'is_typing': false});
                    _sendMessage();
                  },
                  child: GlassContainer(
                    useOwnLayer: true,
                    quality: GlassQuality.standard,
                    shape: LiquidRoundedSuperellipse(borderRadius: 24.0),
                    settings: LiquidGlassSettings(
                      thickness: 0.1,
                      blur: 15.0,
                      refractiveIndex: 1.0,
                      glassColor: Colors.transparent,
                      lightAngle: 45.0,
                      lightIntensity: isDark ? 0.1 : 0.2,
                      ambientStrength: 1.0,
                      saturation: 1.0,
                      chromaticAberration: 0.0,
                    ),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(24.0),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.5),
                          width: 1.0,
                        ),
                      ),
                      child: Center(
                        child: _isUploadingImage 
                        ? const SizedBox(
                            width: 24, height: 24, 
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          )
                        : const HugeIcon(
                            icon: HugeIcons.strokeRoundedSent02,
                            color: Colors.white,
                            size: 24,
                          ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      // ─── Top Bar Floating Custom ───────────────────────────────────────
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: GlassContainer(
                      useOwnLayer: true,
                      quality: GlassQuality.standard,
                      shape: LiquidRoundedSuperellipse(borderRadius: 30.0),
                      settings: LiquidGlassSettings(
                        thickness: 0.1,
                        blur: 2.0,
                        refractiveIndex: 1.0,
                        glassColor: Colors.transparent,
                        lightAngle: 45.0,
                        lightIntensity: isDark ? 0.1 : 0.2,
                        ambientStrength: 1.0,
                        saturation: 1.0,
                        chromaticAberration: 0.0,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.4), width: 1.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => Navigator.pop(context),
                              child: Padding(
                                padding: const EdgeInsets.only(right: 12.0),
                                child: HugeIcon(
                                  icon: HugeIcons.strokeRoundedArrowLeft01,
                                  color: isDark ? Colors.white : Colors.black87,
                                  size: 22,
                                ),
                              ),
                            ),
                            Expanded(
                              child: FutureBuilder<Map<String, dynamic>>(
                                future: ChatService.getUserProfile(otherUserId),
                                builder: (context, snapshot) {
                                  final name = snapshot.data?['name'] ?? '...';
                                  final avatarUrl = snapshot.data?['avatar_url'];
                                  final avatar = name.isNotEmpty ? name[0] : '?';
                                  final avatarColor = AppTheme.primary;
                                  return GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      if (snapshot.hasData) {
                                        _showProfileBrief(context, snapshot.data!, isDark);
                                      }
                                    },
                                    child: Row(
                                      children: [
                                        ValueListenableBuilder<Set<String>>(
                                          valueListenable: ChatService.onlineUsers,
                                          builder: (context, onlineUsers, child) {
                                            final isOnline = onlineUsers.contains(otherUserId);
                                            return Stack(
                                              clipBehavior: Clip.none,
                                              children: [
                                                Container(
                                                  width: 32,
                                                  height: 32,
                                                  decoration: BoxDecoration(
                                                    color: avatarColor.withValues(alpha: 0.15),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(color: avatarColor.withValues(alpha: 0.4), width: 1.5),
                                                    image: avatarUrl != null
                                                        ? DecorationImage(
                                                            image: CachedNetworkImageProvider(avatarUrl),
                                                            fit: BoxFit.cover,
                                                          )
                                                        : null,
                                                  ),
                                                  child: avatarUrl == null
                                                      ? Center(
                                                          child: Text(
                                                            avatar,
                                                            style: GoogleFonts.outfit(
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.w800,
                                                              color: avatarColor,
                                                            ),
                                                          ),
                                                        )
                                                      : null,
                                                ),
                                                if (isOnline)
                                                  Positioned(
                                                    bottom: 0,
                                                    right: 0,
                                                    child: Container(
                                                      width: 10,
                                                      height: 10,
                                                      decoration: BoxDecoration(
                                                        color: Colors.green,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, width: 2),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_otherUserProfile != null) ...(() {
                    final phone = _otherUserProfile!['phone'] ?? _otherUserProfile!['phone_number'];
                    if (phone != null && phone.toString().isNotEmpty) {
                      return <Widget>[
                        const SizedBox(width: 8),
                        GlassContainer(
                          useOwnLayer: true,
                          quality: GlassQuality.standard,
                          shape: LiquidRoundedSuperellipse(borderRadius: 30.0),
                          settings: LiquidGlassSettings(
                            thickness: 0.1,
                            blur: 2.0,
                            refractiveIndex: 1.0,
                            glassColor: Colors.transparent,
                            lightAngle: 45.0,
                            lightIntensity: isDark ? 0.1 : 0.2,
                            ambientStrength: 1.0,
                            saturation: 1.0,
                            chromaticAberration: 0.0,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.4), width: 1.0),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () async {
                                    final Uri url = Uri.parse('tel:$phone');
                                    try {
                                      if (!await launchUrl(url)) {
                                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch dialer')));
                                      }
                                    } catch (e) {
                                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch dialer')));
                                    }
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 6.0),
                                    child: HugeIcon(
                                      icon: HugeIcons.strokeRoundedCall02,
                                      color: AppTheme.primary,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () async {
                                    String cleanPhone = phone.toString().replaceAll(RegExp(r'\D'), '');
                                    if (cleanPhone.startsWith('0')) cleanPhone = '6$cleanPhone';
                                    try {
                                      final Uri appUrl = Uri.parse('whatsapp://send?phone=$cleanPhone');
                                      if (!await launchUrl(appUrl, mode: LaunchMode.externalApplication)) {
                                        final Uri webUrl = Uri.parse('https://wa.me/$cleanPhone');
                                        if (!await launchUrl(webUrl, mode: LaunchMode.externalApplication)) {
                                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch WhatsApp')));
                                        }
                                      }
                                    } catch (e) {
                                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch WhatsApp')));
                                    }
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 6.0),
                                    child: HugeIcon(
                                      icon: HugeIcons.strokeRoundedWhatsapp,
                                      color: Color(0xFF25D366),
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ];
                    }
                    return <Widget>[];
                  }()),
                ],
              ),
            ),
          ),
          if (_linkedGig != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SizedBox(
                height: 70,
                child: GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Gig details feature removed')),
                    );
                  },
                  child: GlassContainer(
                    useOwnLayer: true,
                    quality: GlassQuality.standard,
                    shape: LiquidRoundedSuperellipse(borderRadius: 16.0),
                    settings: LiquidGlassSettings(
                      thickness: 0.1,
                      blur: 15.0,
                      refractiveIndex: 1.0,
                      glassColor: Colors.transparent,
                      lightAngle: 45.0,
                      lightIntensity: isDark ? 0.1 : 0.2,
                      ambientStrength: 1.0,
                      saturation: 1.0,
                      chromaticAberration: 0.0,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.primary.withValues(alpha: 0.25) : AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.6), 
                          width: 1.5
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _getColorForStatus(_linkedGig!.status, isDark, true).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: HugeIcon(
                              icon: _getIconForStatus(_linkedGig!.status), 
                              color: _getColorForStatus(_linkedGig!.status, isDark, true), 
                              size: 18
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _linkedGig!.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold, 
                                    fontSize: 14,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${_linkedGig!.formattedBounty} • ${_linkedGig!.status}',
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : Colors.black54, 
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  ),
],
),
);
  }
}

// ─── Bubble Chat ──────────────────────────────────────────────
class _MessageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isDark;
  final bool isMe;
  final bool showAvatar;
  final VoidCallback? onImageTap;
  final VoidCallback? onReplyTap;
  final String? otherAvatarUrl;
  final String? otherName;

  const _MessageBubble({
    required this.message, 
    required this.isDark, 
    required this.isMe,
    this.showAvatar = true,
    this.onImageTap,
    this.onReplyTap,
    this.otherAvatarUrl,
    this.otherName,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _isDownloading = false;

  Future<void> _openFile() async {
    final url = widget.message.imageUrl;
    if (url == null || url.isEmpty) return;
    
    setState(() {
      _isDownloading = true;
    });

    try {
      final fileName = widget.message.displayFileName;
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/$fileName';
      final file = File(filePath);

      if (!await file.exists()) {
        final httpClient = HttpClient();
        final request = await httpClient.getUrl(Uri.parse(url));
        final response = await request.close();
        final bytes = await consolidateHttpClientResponseBytes(response);
        await file.writeAsBytes(bytes);
      }

      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open file: ${result.message}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isDark = widget.isDark;
    final isMe = widget.isMe;

    if (message.content.startsWith('__SYSTEM__:')) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.content.replaceFirst('__SYSTEM__:', ''),
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && widget.showAvatar) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 14,
              backgroundColor: AppTheme.primary,
              backgroundImage: widget.otherAvatarUrl != null && widget.otherAvatarUrl!.isNotEmpty ? CachedNetworkImageProvider(widget.otherAvatarUrl!) : null,
              child: widget.otherAvatarUrl == null || widget.otherAvatarUrl!.isEmpty
                  ? Text(
                      widget.otherName != null && widget.otherName!.isNotEmpty 
                          ? widget.otherName![0].toUpperCase() 
                          : '?',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ] else if (!isMe) ...[
            const SizedBox(width: 44),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF42A5F5) : (isDark ? const Color(0xFF2C2C2E) : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe || !widget.showAvatar ? 20 : 4),
                  bottomRight: Radius.circular(isMe && widget.showAvatar ? 4 : 20),
                ),
                boxShadow: isMe || isDark
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        )
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.replyToMessage != null)
                    GestureDetector(
                      onTap: widget.onReplyTap,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border(left: BorderSide(color: isMe ? Colors.white : AppTheme.primary, width: 4)),
                        ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.replyToMessage!['sender_name'] ?? 'User',
                            style: TextStyle(
                              color: isMe ? Colors.white : AppTheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            message.replyToMessage!['content'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isMe ? Colors.white70 : (isDark ? Colors.white70 : Colors.black54),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (message.imageUrl != null)
                    message.isFile
                    ? GestureDetector(
                        onTap: _isDownloading ? null : _openFile,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.white.withValues(alpha: 0.2) : (isDark ? Colors.white10 : Colors.grey.shade100),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _isDownloading 
                                  ? SizedBox(
                                      width: 24, height: 24, 
                                      child: CircularProgressIndicator(color: isMe ? Colors.white : AppTheme.primary, strokeWidth: 2,)
                                    )
                                  : HugeIcon(
                                      icon: HugeIcons.strokeRoundedFile01, 
                                      color: isMe ? Colors.white : AppTheme.primary, 
                                      size: 24
                                    ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  message.displayFileName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                                    decoration: TextDecoration.underline,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: GestureDetector(
                          onTap: () {
                            if (widget.onImageTap != null) {
                              widget.onImageTap!();
                            } else {
                              showDialog(
                                context: context,
                                builder: (_) => _ImageViewerDialog(
                                  imageUrls: [message.imageUrl!],
                                  initialIndex: 0,
                                ),
                              );
                            }
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: message.imageUrl!,
                              width: MediaQuery.of(context).size.width * 0.6,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                width: MediaQuery.of(context).size.width * 0.6,
                                height: 150,
                                color: isDark ? Colors.white10 : Colors.black12,
                                child: const Center(child: CircularProgressIndicator()),
                              ),
                              errorWidget: (context, url, error) => const Icon(Icons.error),
                            ),
                          ),
                        ),
                      )
                  else if (message.content.startsWith('__TASK_CARD__:'))
                    ...(() {
                      final parts = message.content.replaceFirst('__TASK_CARD__:', '').split('|');
                      if (parts.length >= 4) {
                        final status = parts[3];
                        final threadState = context.findAncestorStateOfType<_ChatThreadScreenState>();
                        final icon = threadState?._getIconForStatus(status) ?? HugeIcons.strokeRoundedWorkHistory;
                        final color = threadState?._getColorForStatus(status, isDark, true) ?? AppTheme.primary;

                        return [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isMe ? Colors.white.withValues(alpha: 0.2) : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.7)),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: isMe ? Colors.white.withValues(alpha: 0.3) : AppTheme.primary.withValues(alpha: 0.2)),
                                ),
                                  child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: isMe ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: HugeIcon(
                                      icon: icon, 
                                      color: color, 
                                      size: 20
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          parts[1],
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${parts[2]} • ${parts[3]}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isMe ? Colors.white70 : (isDark ? Colors.white70 : Colors.black54),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ];
                      }
                      return [const Text('Invalid Task Card')];
                    }())
                  else if (message.content.startsWith('__QUOTE__:'))
                    ...(() {
                      final parts = message.content.replaceFirst('__QUOTE__:', '').split('|');
                      if (parts.length >= 2) {
                        return [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                width: 240,
                                decoration: BoxDecoration(
                                  color: isMe ? Colors.white.withValues(alpha: 0.2) : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.7)),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: isMe ? Colors.white.withValues(alpha: 0.3) : AppTheme.primary.withValues(alpha: 0.2)),
                                ),
                                child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    HugeIcon(icon: HugeIcons.strokeRoundedInvoice01, color: isMe ? Colors.white : AppTheme.primary, size: 20),
                                    const SizedBox(width: 8),
                                    Text('chat.send_quote'.tr(), style: TextStyle(fontWeight: FontWeight.bold, color: isMe ? Colors.white : AppTheme.primary)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'RM ${parts[0]}',
                                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  parts[1],
                                  style: TextStyle(fontSize: 13, color: isMe ? Colors.white70 : (isDark ? Colors.white70 : Colors.black87)),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: () {},
                                    child: Text('chat.accept'.tr()),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ];
                      }
                      return [const Text('Invalid Quote')];
                    }())
                  else if (message.content.startsWith('__COUNTER__:'))
                    ...(() {
                      final parts = message.content.replaceFirst('__COUNTER__:', '').split('|');
                      if (parts.length >= 2) {
                        return [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                width: 240,
                                decoration: BoxDecoration(
                                  color: isMe ? Colors.white.withValues(alpha: 0.2) : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.7)),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: isMe ? Colors.white.withValues(alpha: 0.3) : AppTheme.primary.withValues(alpha: 0.2)),
                                ),
                                child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    HugeIcon(icon: HugeIcons.strokeRoundedMoney04, color: isMe ? Colors.white : AppTheme.primary, size: 20),
                                    const SizedBox(width: 8),
                                    Text('chat.counter_offer'.tr(), style: TextStyle(fontWeight: FontWeight.bold, color: isMe ? Colors.white : AppTheme.primary)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      parts[0],
                                      style: TextStyle(
                                        fontSize: 14, 
                                        fontWeight: FontWeight.bold, 
                                        color: isMe ? Colors.white54 : Colors.grey,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'RM ${parts[1]}',
                                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: () {},
                                    child: Text('chat.accept'.tr()),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ];
                      }
                      return [const Text('Invalid Counter')];
                    }())
                  else if (message.content == '__REQUEST_LOC__')
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            width: 240,
                            decoration: BoxDecoration(
                              color: isMe ? Colors.white.withValues(alpha: 0.2) : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.7)),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isMe ? Colors.white.withValues(alpha: 0.3) : AppTheme.primary.withValues(alpha: 0.2)),
                            ),
                            child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            HugeIcon(icon: HugeIcons.strokeRoundedLocation01, color: isMe ? Colors.white : AppTheme.primary, size: 32),
                            const SizedBox(height: 12),
                            Text(
                              'chat.location_requested'.tr(),
                              style: TextStyle(fontWeight: FontWeight.bold, color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'chat.share_location_desc'.tr(),
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: isMe ? Colors.white70 : (isDark ? Colors.white70 : Colors.black54)),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () {},
                                child: Text('chat.share_location'.tr()),
                              ),
                            ),
                          ],
                        ),
                      )
                    )
                  )
                  else
                    Text(
                      message.content,
                      style: TextStyle(
                        fontSize: 14,
                        color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                        height: 1.4,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.formattedTime,
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe ? Colors.white.withValues(alpha: 0.7) : Colors.grey.shade500,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        MessageStatusIndicator(
                          status: message.status,
                          isRead: message.isRead,
                          isMe: isMe,
                          defaultColor: Colors.white.withValues(alpha: 0.7),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ─── Indicator Status Mesej (Blue Tick) ───────────────────────
class MessageStatusIndicator extends StatelessWidget {
  final String status;
  final bool isRead;
  final bool isMe;
  final Color defaultColor;

  const MessageStatusIndicator({
    super.key,
    required this.status,
    required this.isRead,
    required this.isMe,
    this.defaultColor = Colors.grey,
  });

  @override
  Widget build(BuildContext context) {
    if (!isMe) return const SizedBox.shrink();

    if (status == 'failed') {
      return const Icon(
        Icons.error_outline,
        color: Colors.redAccent,
        size: 14,
      );
    }

    if (status == 'sending') {
      return Icon(
        Icons.access_time,
        color: defaultColor,
        size: 14,
      );
    }

    if (isRead) {
      return const Icon(
        Icons.done_all,
        color: Colors.blueAccent,
        size: 15,
      );
    }

    return Icon(
      Icons.check,
      color: defaultColor,
      size: 15,
    );
  }
}

class _ImageViewerDialog extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _ImageViewerDialog({required this.imageUrls, required this.initialIndex});

  @override
  State<_ImageViewerDialog> createState() => _ImageViewerDialogState();
}

class _ImageViewerDialogState extends State<_ImageViewerDialog> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentIndex < widget.imageUrls.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _prevPage() {
    if (_currentIndex > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              return InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: widget.imageUrls[index],
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          if (_currentIndex > 0)
            Positioned(
              left: 10,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.chevron_left, color: Colors.white, size: 40),
                    onPressed: _prevPage,
                  ),
                ),
              ),
            ),
          if (_currentIndex < widget.imageUrls.length - 1)
            Positioned(
              right: 10,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.chevron_right, color: Colors.white, size: 40),
                    onPressed: _nextPage,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onSwipe;
  final bool isMe;

  const SwipeToReply({
    super.key,
    required this.child,
    required this.onSwipe,
    required this.isMe,
  });

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply> with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  final double _maxDrag = 60.0;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animationController.addListener(() {
      setState(() {
        _dragOffset = _animation.value;
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _resetDrag() {
    _animation = Tween<double>(begin: _dragOffset, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (details) {
        setState(() {
          _dragOffset += details.delta.dx;
          if (widget.isMe) {
            _dragOffset = _dragOffset.clamp(-_maxDrag, 0.0);
          } else {
            _dragOffset = _dragOffset.clamp(0.0, _maxDrag);
          }
        });
      },
      onHorizontalDragEnd: (details) {
        if (_dragOffset.abs() >= _maxDrag * 0.8) {
          widget.onSwipe();
        }
        _resetDrag();
      },
      onHorizontalDragCancel: () {
        _resetDrag();
      },
      child: Stack(
        alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
        children: [
          if (_dragOffset.abs() > 10)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Icon(
                Icons.reply_rounded,
                color: Colors.grey.withValues(alpha: (_dragOffset.abs() / _maxDrag).clamp(0.0, 1.0)),
              ),
            ),
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
