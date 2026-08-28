import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_model.dart';
import '../../models/chat_model.dart';
import '../../models/gig_model.dart';
import '../../services/gig_service.dart';
import '../../utils/app_theme.dart';
import 'conversation_sub_tile.dart';
import '../typing_indicator.dart';

class UserGroupConversationCard extends StatefulWidget {
  final UserModel otherUser;
  final List<ConversationModel> conversations;
  final String currentUserId;
  final bool isDark;
  final bool isOnline;
  final void Function(ConversationModel, String?) onTap;
  final void Function(ConversationModel) onLongPress;

  const UserGroupConversationCard({
    super.key,
    required this.otherUser,
    required this.conversations,
    required this.currentUserId,
    required this.isDark,
    required this.isOnline,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<UserGroupConversationCard> createState() => _UserGroupConversationCardState();
}

class _UserGroupConversationCardState extends State<UserGroupConversationCard> {
  bool _isExpanded = false;
  bool _isTyping = false;
  final List<RealtimeChannel> _typingChannels = [];
  Timer? _typingTimer;
  List<GigModel>? _sharedGigs;

  @override
  void initState() {
    super.initState();
    _setupTypingListeners();
    _loadSharedGigs();
  }

  Future<void> _loadSharedGigs() async {
    try {
      final gigs = await GigService.fetchSharedGigs(widget.currentUserId, widget.otherUser.id);
      if (mounted) setState(() => _sharedGigs = gigs);
    } catch (e) {
      if (mounted) setState(() => _sharedGigs = []);
    }
  }

  void _setupTypingListeners() {
    for (var conversation in widget.conversations) {
      final channel = Supabase.instance.client
          .channel('public:chat:${conversation.id}')
          .onBroadcast(
            event: 'typing',
            callback: (payload) {
              final userId = payload['user_id'] as String?;
              final isTyping = payload['is_typing'] as bool? ?? false;
              
              if (userId == widget.otherUser.id && mounted) {
                setState(() {
                  _isTyping = isTyping;
                });
                
                if (isTyping) {
                  _typingTimer?.cancel();
                  _typingTimer = Timer(const Duration(seconds: 3), () {
                    if (mounted) setState(() => _isTyping = false);
                  });
                }
              }
            },
          );
      channel.subscribe();
      _typingChannels.add(channel);
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    for (var channel in _typingChannels) {
      channel.unsubscribe();
    }
    super.dispose();
  }

  Widget _buildBadge(dynamic icon, Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: icon, color: color, size: 18),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int openCount = 0;
    int inProgressCount = 0;
    int completedCount = 0;
    int lockedCount = 0;
    int unreadCount = 0;

    for (var c in widget.conversations) {
      if (c.lastMessageSenderId == widget.currentUserId) {
        continue; // Aku yang hantar chat tu tadi, so tak payah la tunjuk unread
      }

      int specificUnreads = 0;
      if (c.taskUnreadCounts != null) {
        specificUnreads = c.taskUnreadCounts!.values.fold(0, (sum, val) => sum + val);
      }

      if (specificUnreads > 0) {
        unreadCount += specificUnreads;
      } else if (!c.lastMessageIsRead && c.lastMessage != null) {
        unreadCount += 1;
      }
    }

    if (_sharedGigs != null) {
      for (var gig in _sharedGigs!) {
        final status = gig.status.toUpperCase();
        if (status == 'OPEN') {
          openCount++;
        } else if (status == 'IN-PROGRESS') inProgressCount++;
        else if (status == 'COMPLETED') completedCount++;
        else if (status == 'LOCKED') lockedCount++;
      }
    }

    final avatarColor = AppTheme.primary;
    final avatarUrl = widget.otherUser.userAvatarUrl;
    final name = widget.otherUser.userName;
    final avatar = (name?.isNotEmpty ?? false) ? name![0].toUpperCase() : '?';

    return GlassContainer(
      useOwnLayer: true,
      quality: GlassQuality.standard,
      shape: LiquidRoundedSuperellipse(borderRadius: 24.0),
      settings: LiquidGlassSettings(
        thickness: 0.1,
        blur: 15,
        refractiveIndex: 1.0,
        glassColor: Colors.transparent,
        lightAngle: 45.0,
        lightIntensity: widget.isDark ? 0.1 : 0.2,
        ambientStrength: 1.0,
        saturation: 1.0,
        chromaticAberration: 0.0,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: widget.isDark ? 0.12 : 0.7),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: widget.isDark ? 0.15 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header User
            InkWell(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: avatarColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: avatarColor.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
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
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: avatarColor,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        if (widget.isOnline)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name ?? '',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: widget.isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (openCount > 0) _buildBadge(HugeIcons.strokeRoundedWorkHistory, AppTheme.primary, '$openCount'),
                              if (inProgressCount > 0) _buildBadge(HugeIcons.strokeRoundedHourglass, Colors.blue, '$inProgressCount'),
                              if (completedCount > 0) _buildBadge(HugeIcons.strokeRoundedTick01, Colors.green, '$completedCount'),
                              if (lockedCount > 0) _buildBadge(HugeIcons.strokeRoundedLockKey, Colors.orange, '$lockedCount'),
                              if (unreadCount > 0) _buildBadge(HugeIcons.strokeRoundedMessageMultiple01, Colors.red, '$unreadCount'),
                              if (_isTyping)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Typing',
                                        style: TextStyle(
                                          color: AppTheme.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const SizedBox(
                                        width: 16,
                                        height: 10,
                                        child: TypingIndicator(isDark: false),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    HugeIcon(
                      icon: _isExpanded ? HugeIcons.strokeRoundedArrowUp01 : HugeIcons.strokeRoundedArrowDown01,
                      color: widget.isDark ? Colors.white54 : Colors.black54,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            
            // Isi Kandungan
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _isExpanded ? Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(
                      height: 1,
                      color: widget.isDark ? Colors.white12 : Colors.black12,
                    ),
                  ),
                  if (_sharedGigs == null)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else ...[
                    // Tunjuk General Chat kalau tak ada task spesifik
                    if (_sharedGigs!.isEmpty)
                      ConversationSubTile(
                        conversation: widget.conversations.first,
                        currentUserId: widget.currentUserId,
                        isDark: widget.isDark,
                        onTap: () => widget.onTap(widget.conversations.first, null),
                        onLongPress: () => widget.onLongPress(widget.conversations.first),
                      ),
                    // Gig / Task Tertentu
                    ..._sharedGigs!.map((gig) {
                      final conv = widget.conversations.firstWhere(
                        (c) => c.gigId == gig.id,
                        orElse: () => widget.conversations.first,
                      );
                      return ConversationSubTile(
                        conversation: conv,
                        gigOverride: gig,
                        currentUserId: widget.currentUserId,
                        isDark: widget.isDark,
                        onTap: () => widget.onTap(conv, gig.id),
                        onLongPress: () => widget.onLongPress(conv),
                      );
                    }),
                  ],
                  const SizedBox(height: 8),
                ],
              ) : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}
