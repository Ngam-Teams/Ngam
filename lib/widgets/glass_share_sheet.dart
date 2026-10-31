import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/saved_service.dart';
import 'glass_toast.dart';

/// Membuka TikTok-style Liquid Glass Share Sheet serba moden & estetik
void showGlassShareSheet(
  BuildContext context, {
  required Map<String, dynamic> post,
  VoidCallback? onPostHidden,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: Colors.black.withValues(alpha: 0.60),
    builder: (ctx) => _GlassShareSheetContent(
      post: post,
      onPostHidden: onPostHidden,
    ),
  );
}

class _GlassShareSheetContent extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback? onPostHidden;

  const _GlassShareSheetContent({
    required this.post,
    this.onPostHidden,
  });

  @override
  State<_GlassShareSheetContent> createState() => _GlassShareSheetContentState();
}

class _GlassShareSheetContentState extends State<_GlassShareSheetContent> {
  bool _copied = false;

  String get _postId => (widget.post['id'] ?? '').toString();
  String get _shopName => (widget.post['shopName'] ?? 'Kedai di Ngam').toString();
  String get _title => (widget.post['title'] ?? widget.post['caption'] ?? 'Hantaran menarik di Ngam').toString();
  String get _shareUrl => 'https://ngam.dev/p/$_postId';
  String get _shareText => 'Tengok video menarik dari $_shopName di Ngam!\n"$_title"\n\n$_shareUrl';

  Future<void> _launchExternalUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to in-app or browser
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      if (mounted) {
        showGlassToast(
          context,
          'Tidak dapat membuka aplikasi tersebut.',
          icon: HugeIcons.strokeRoundedAlert02,
        );
      }
    }
  }

  void _shareToWhatsApp() {
    Navigator.pop(context);
    final encoded = Uri.encodeComponent(_shareText);
    _launchExternalUrl('whatsapp://send?text=$encoded').catchError((_) {
      return _launchExternalUrl('https://wa.me/?text=$encoded');
    });
  }

  void _shareToTelegram() {
    Navigator.pop(context);
    final encodedText = Uri.encodeComponent(_shareText);
    final encodedUrl = Uri.encodeComponent(_shareUrl);
    _launchExternalUrl('tg://msg_url?url=$encodedUrl&text=$encodedText').catchError((_) {
      return _launchExternalUrl('https://t.me/share/url?url=$encodedUrl&text=$encodedText');
    });
  }

  void _shareToThreads() {
    Navigator.pop(context);
    final encodedText = Uri.encodeComponent(_shareText);
    _launchExternalUrl('https://www.threads.net/intent/post?text=$encodedText');
  }

  void _shareToX() {
    Navigator.pop(context);
    final tweet = Uri.encodeComponent('$_title via @ngam_app');
    final encodedUrl = Uri.encodeComponent(_shareUrl);
    _launchExternalUrl('https://twitter.com/intent/tweet?text=$tweet&url=$encodedUrl');
  }

  void _shareToFacebook() {
    Navigator.pop(context);
    final encodedUrl = Uri.encodeComponent(_shareUrl);
    _launchExternalUrl('https://www.facebook.com/sharer/sharer.php?u=$encodedUrl');
  }

  void _shareToInstagram() {
    Navigator.pop(context);
    _shareSystemNative();
  }

  void _shareToSms() {
    Navigator.pop(context);
    final encoded = Uri.encodeComponent(_shareText);
    _launchExternalUrl('sms:?body=$encoded');
  }

  void _shareSystemNative() async {
    Navigator.pop(context);
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: _shareText,
          subject: '$_title | Ngam',
        ),
      );
    } catch (e) {
      debugPrint('[GlassShareSheet] Native share error: $e');
    }
  }

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: _shareUrl));
    HapticFeedback.lightImpact();
    setState(() => _copied = true);
    showGlassToast(
      context,
      'Pautan disalin ke papan klip!',
      icon: HugeIcons.strokeRoundedCopy01,
    );
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  void _toggleSave() async {
    HapticFeedback.lightImpact();
    final nowSaved = await SavedService.toggleSavePost(widget.post);
    if (mounted) {
      setState(() {});
      showGlassToast(
        context,
        nowSaved
            ? 'Hantaran disimpan ke koleksi anda'
            : 'Hantaran dikeluarkan dari simpanan',
        icon: HugeIcons.strokeRoundedBookmark02,
      );
    }
  }

  void _showQrDialog() {
    Navigator.pop(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.70),
      builder: (dlgCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF161F30).withValues(alpha: 0.92),
                          const Color(0xFF0D131F).withValues(alpha: 0.95),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.95),
                          const Color(0xFFF1F5F9).withValues(alpha: 0.92),
                        ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.16)
                      : Colors.white.withValues(alpha: 0.8),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 36,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Imbas Kod QR',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(dlgCtx),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedCancel01,
                            color: isDark ? Colors.white70 : Colors.black87,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: _shareUrl,
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _shopName,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(dlgCtx);
                        _copyLink();
                      },
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedCopy01,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: const Text('Salin Pautan', style: TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showReportSheet() {
    Navigator.pop(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (sheetCtx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        const Color(0xEB131B2B),
                        const Color(0xF50B0F17),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.94),
                        const Color(0xFFF1F5F9).withValues(alpha: 0.96),
                      ],
              ),
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white.withValues(alpha: 0.16) : Colors.black.withValues(alpha: 0.08),
                  width: 1.2,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const HugeIcon(
                        icon: HugeIcons.strokeRoundedFlag01,
                        color: Color(0xFFEF4444),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Laporkan Kandungan',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Pilih sebab laporan untuk video atau hantaran ini:',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 16),
                ...[
                  'Spam, penipuan atau iklan palsu',
                  'Kandungan tidak sesuai / sensitif',
                  'Maklumat kedai mengelirukan',
                  'Hak cipta atau pelanggaran privasi',
                ].map(
                  (reason) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      dense: true,
                      leading: const HugeIcon(
                        icon: HugeIcons.strokeRoundedAlert02,
                        size: 18,
                        color: Color(0xFFEF4444),
                      ),
                      title: Text(reason, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                      trailing: HugeIcon(
                        icon: HugeIcons.strokeRoundedArrowRight01,
                        size: 16,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        showGlassToast(
                          context,
                          'Terima kasih. Laporan anda sedang disemak oleh pasukan Ngam.',
                          icon: HugeIcons.strokeRoundedTick01,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleNotInterested() {
    Navigator.pop(context);
    widget.onPostHidden?.call();
    showGlassToast(
      context,
      'Kami akan kurangkan cadangan seperti ini.',
      icon: HugeIcons.strokeRoundedThumbsDown,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSaved = SavedService.isPostSaved(_postId);

    final String mediaUrl = (widget.post['image'] ?? '').toString();
    final String coverUrl = (widget.post['thumbnail'] ?? widget.post['cover'] ?? '').toString();
    final String previewImg = coverUrl.isNotEmpty ? coverUrl : mediaUrl;
    final bool isVideo = (widget.post['mediaType'] == 'video') ||
        mediaUrl.toLowerCase().endsWith('.mp4');

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 32, sigmaY: 32),
        child: Container(
          padding: const EdgeInsets.only(top: 12, bottom: 26),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [
                      const Color(0xCC0D1424), // 80% opacity dark frosted glass
                      const Color(0xE8080C14), // 91% opacity deep acrylic refraction
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.88),
                      const Color(0xFFF1F5F9).withValues(alpha: 0.92),
                    ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.22) : Colors.white,
                width: 1.4,
              ),
              left: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                width: 1.0,
              ),
              right: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                width: 1.0,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 40,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top drag pill handle
                Center(
                  child: Container(
                    width: 42,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.28)
                          : Colors.black.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Header Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Kongsi ke',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                          ),
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedCancel01,
                            size: 16,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Mini Glass Card of the content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 48,
                            height: 48,
                            color: isDark ? Colors.white12 : Colors.black12,
                            child: previewImg.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: previewImg,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Center(
                                      child: HugeIcon(
                                        icon: isVideo ? HugeIcons.strokeRoundedVideo01 : HugeIcons.strokeRoundedImage01,
                                        color: isDark ? Colors.white38 : Colors.black38,
                                        size: 22,
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: HugeIcon(
                                      icon: isVideo ? HugeIcons.strokeRoundedVideo01 : HugeIcons.strokeRoundedImage01,
                                      color: isDark ? Colors.white38 : Colors.black38,
                                      size: 22,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _shopName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ─── ROW 1: SOCIAL & MESSAGING APPS (ORIGINAL BRAND LOGOS DENGAN HUGE ICONS) ───
                SizedBox(
                  height: 94,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    children: [
                      _buildSocialAppItem(
                        title: 'WhatsApp',
                        gradientColors: const [Color(0xFF25D366), Color(0xFF128C7E)],
                        hugeIcon: HugeIcons.strokeRoundedWhatsapp,
                        onTap: _shareToWhatsApp,
                        isDark: isDark,
                      ),
                      _buildSocialAppItem(
                        title: 'Telegram',
                        gradientColors: const [Color(0xFF2AABEE), Color(0xFF229ED9)],
                        hugeIcon: HugeIcons.strokeRoundedTelegram,
                        onTap: _shareToTelegram,
                        isDark: isDark,
                      ),
                      _buildSocialAppItem(
                        title: 'Threads',
                        gradientColors: isDark
                            ? const [Color(0xFF262626), Color(0xFF0D0D0D)]
                            : const [Color(0xFF1E293B), Color(0xFF0F172A)],
                        hugeIcon: HugeIcons.strokeRoundedThreads,
                        onTap: _shareToThreads,
                        isDark: isDark,
                      ),
                      _buildSocialAppItem(
                        title: 'X',
                        gradientColors: isDark
                            ? const [Color(0xFF222733), Color(0xFF0D111A)]
                            : const [Color(0xFF0F172A), Color(0xFF020617)],
                        hugeIcon: HugeIcons.strokeRoundedNewTwitter,
                        onTap: _shareToX,
                        isDark: isDark,
                      ),
                      _buildSocialAppItem(
                        title: 'Facebook',
                        gradientColors: const [Color(0xFF1877F2), Color(0xFF0C5EC9)],
                        hugeIcon: HugeIcons.strokeRoundedFacebook02,
                        onTap: _shareToFacebook,
                        isDark: isDark,
                      ),
                      _buildSocialAppItem(
                        title: 'Instagram',
                        gradientColors: const [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCB045)],
                        hugeIcon: HugeIcons.strokeRoundedInstagram,
                        onTap: _shareToInstagram,
                        isDark: isDark,
                      ),
                      _buildSocialAppItem(
                        title: 'Mesej',
                        gradientColors: const [Color(0xFF10B981), Color(0xFF059669)],
                        hugeIcon: HugeIcons.strokeRoundedMessage01,
                        onTap: _shareToSms,
                        isDark: isDark,
                      ),
                      _buildSocialAppItem(
                        title: 'Lain-lain',
                        gradientColors: const [Color(0xFF6366F1), Color(0xFF4F46E5)],
                        hugeIcon: HugeIcons.strokeRoundedShare01,
                        onTap: _shareSystemNative,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Divider(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                    height: 1,
                  ),
                ),

                const SizedBox(height: 8),

                // ─── ROW 2: ACTION BUTTONS (HUGE ICONS + LIQUID GLASS CAPSULES) ───
                SizedBox(
                  height: 94,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    children: [
                      _buildActionItem(
                        title: _copied ? 'Disalin!' : 'Salin Pautan',
                        hugeIcon: _copied ? HugeIcons.strokeRoundedTick01 : HugeIcons.strokeRoundedCopy01,
                        iconColor: _copied ? const Color(0xFF10B981) : (isDark ? Colors.white : Colors.black87),
                        bgColor: _copied
                            ? const Color(0xFF10B981).withValues(alpha: 0.2)
                            : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
                        onTap: _copyLink,
                        isDark: isDark,
                      ),
                      _buildActionItem(
                        title: isSaved ? 'Disimpan' : 'Simpan',
                        hugeIcon: HugeIcons.strokeRoundedBookmark02,
                        iconColor: isSaved ? const Color(0xFFFBBF24) : (isDark ? Colors.white : Colors.black87),
                        bgColor: isSaved
                            ? const Color(0xFFFBBF24).withValues(alpha: 0.2)
                            : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
                        onTap: _toggleSave,
                        isDark: isDark,
                      ),
                      _buildActionItem(
                        title: 'Kod QR',
                        hugeIcon: HugeIcons.strokeRoundedQrCode,
                        iconColor: isDark ? Colors.white : Colors.black87,
                        bgColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                        onTap: _showQrDialog,
                        isDark: isDark,
                      ),
                      _buildActionItem(
                        title: 'Laporkan',
                        hugeIcon: HugeIcons.strokeRoundedAlert02,
                        iconColor: const Color(0xFFEF4444),
                        bgColor: const Color(0xFFEF4444).withValues(alpha: 0.12),
                        onTap: _showReportSheet,
                        isDark: isDark,
                      ),
                      _buildActionItem(
                        title: 'Tak Minat',
                        hugeIcon: HugeIcons.strokeRoundedThumbsDown,
                        iconColor: isDark ? Colors.white70 : Colors.black54,
                        bgColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                        onTap: _handleNotInterested,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialAppItem({
    required String title,
    required List<Color> gradientColors,
    required dynamic hugeIcon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: gradientColors.first.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: HugeIcon(
                  icon: hugeIcon,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem({
    required String title,
    required dynamic hugeIcon,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bgColor,
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: Center(
                child: HugeIcon(
                  icon: hugeIcon,
                  color: iconColor,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
