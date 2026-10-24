import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../models/chat_model.dart';
import '../../models/gig_model.dart';
import '../../services/chat_service.dart';
import '../../utils/app_theme.dart';
import '../typing_indicator.dart';

class ConversationSubTile extends StatefulWidget {
  final ConversationModel conversation;
  final GigModel? gigOverride;
  final String currentUserId;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const ConversationSubTile({
    super.key,
    required this.conversation,
    this.gigOverride,
    required this.currentUserId,
    required this.isDark,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<ConversationSubTile> createState() => _ConversationSubTileState();
}

class _ConversationSubTileState extends State<ConversationSubTile> {
  bool _isTyping = false;
  RealtimeChannel? _typingChannel;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _typingChannel = Supabase.instance.client
        .channel('public:chat:${widget.conversation.id}')
        .onBroadcast(
          event: 'typing',
          callback: (payload) {
            final userId = payload['user_id'] as String?;
            final isTyping = payload['is_typing'] as bool? ?? false;
            final otherUserId = widget.conversation.user1Id == widget.currentUserId 
                ? widget.conversation.user2Id 
                : widget.conversation.user1Id;
                
            if (userId == otherUserId && mounted) {
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
        )
        .subscribe();
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _typingChannel?.unsubscribe();
    super.dispose();
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

  Color _getColorForStatus(String status, bool isDark) {
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

  @override
  Widget build(BuildContext context) {
    final c = widget.conversation;
    String lastMsg;
    if (widget.gigOverride != null) {
      if (c.gigId == widget.gigOverride!.id) {
        lastMsg = c.lastMessage ?? 'Task: ${widget.gigOverride!.title}';
      } else {
        lastMsg = 'Task: ${widget.gigOverride!.title}';
        if (c.taskLastMessages != null) {
          final taskMsg = c.taskLastMessages![widget.gigOverride!.id];
          if (taskMsg != null && taskMsg.toString().isNotEmpty) {
            lastMsg = taskMsg.toString();
          }
        }
      }
    } else {
      lastMsg = c.lastMessage ?? 'No messages yet';
    }

    if (lastMsg.startsWith('__SYSTEM__:')) {
      lastMsg = lastMsg.replaceFirst('__SYSTEM__:', '');
    } else if (lastMsg.startsWith('__TASK_CARD__:')) {
      lastMsg = 'Sent a Task Card';
    } else if (lastMsg.startsWith('__QUOTE__:')) {
      lastMsg = 'Sent a Custom Quote';
    } else if (lastMsg.startsWith('__COUNTER__:')) {
      lastMsg = 'Sent a Counter-Offer';
    } else if (lastMsg == '__REQUEST_LOC__') {
      lastMsg = 'Requested your Location';
    }
    
    int unread = 0;
    if (c.lastMessageSenderId == widget.currentUserId) {
      unread = 0;
    } else if (widget.gigOverride != null) {
      unread = c.taskUnreadCounts?[widget.gigOverride!.id] ?? 0;
    } else {
      // Logik mesej tak baca: Total semua tolak dengan yang dalam task-task spesifik
      int specificUnreadSum = 0;
      if (c.taskUnreadCounts != null) {
        specificUnreadSum = c.taskUnreadCounts!.values.fold(0, (sum, val) => sum + val);
      }
      unread = (c.unreadCount - specificUnreadSum).clamp(0, 999);
    }
    
    bool isThisTaskUnread = unread > 0;

    final String time = widget.gigOverride == null ? c.formattedTime : '';
    final gigData = widget.gigOverride == null && c.gigId != null 
        ? ChatService.getCachedGigSync(c.gigId!) 
        : null;
    final gigTitle = widget.gigOverride?.title ?? gigData?['title'] ?? 'General Chat';
    final String? gigStatus = widget.gigOverride?.status ?? gigData?['status'];

    return InkWell(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (gigStatus != null) ...[
              Padding(
                padding: const EdgeInsets.only(right: 12.0, top: 2.0),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getColorForStatus(gigStatus, widget.isDark).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: HugeIcon(
                    icon: _getIconForStatus(gigStatus),
                    color: _getColorForStatus(gigStatus, widget.isDark),
                    size: 18,
                  ),
                ),
              ),
            ] else ...[
               // Ruang kosong nak bagi seimbang kalau takde ikon status
               const SizedBox(width: 46),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gigTitle,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isThisTaskUnread ? FontWeight.w800 : FontWeight.w600,
                      color: widget.isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (c.lastMessageSenderId == widget.currentUserId && !_isTyping)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: MessageStatusIndicator(
                            status: 'sent',
                            isRead: c.lastMessageIsRead,
                            isMe: true,
                            defaultColor: widget.isDark ? Colors.white70 : Colors.grey.shade600,
                          ),
                        ),
                      Expanded(
                        child: _isTyping
                            ? Row(
                                children: [
                                  Text(
                                    'Typing',
                                    style: TextStyle(
                                      color: AppTheme.primary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    maxLines: 1,
                                  ),
                                  const SizedBox(width: 4),
                                  const SizedBox(
                                    width: 20,
                                    height: 12,
                                    child: TypingIndicator(isDark: false),
                                  ),
                                ],
                              )
                            : Text(
                                lastMsg,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400,
                                  color: unread > 0
                                      ? (widget.isDark ? Colors.white70 : Colors.black87)
                                      : Colors.grey.shade500,
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (time.isNotEmpty)
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 11,
                      color: unread > 0 ? AppTheme.primary : Colors.grey.shade500,
                      fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                if (isThisTaskUnread && widget.gigOverride != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        unread > 99 ? '99+' : unread.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )
                else if (unread > 0 && widget.gigOverride == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        unread > 99 ? '99+' : unread.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
    required this.defaultColor,
  });

  @override
  Widget build(BuildContext context) {
    if (!isMe) return const SizedBox.shrink();

    if (isRead) {
      return const HugeIcon(icon: HugeIcons.strokeRoundedTick01, size: 14, color: AppTheme.primary);
    }
    
    switch (status) {
      case 'sending':
        return HugeIcon(icon: HugeIcons.strokeRoundedTime02, size: 12, color: defaultColor);
      case 'failed':
        return const HugeIcon(icon: HugeIcons.strokeRoundedAlert02, size: 14, color: Colors.red);
      default:
        return HugeIcon(icon: HugeIcons.strokeRoundedTick01, size: 14, color: defaultColor);
    }
  }
}
