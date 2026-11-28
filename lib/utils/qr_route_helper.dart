import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../screens/customer/post_route_loader.dart';
import '../screens/explore/store_route_loader.dart';
import '../screens/receipt/ereceipt_screen.dart';
import '../screens/receipt/payment_result_screen.dart';
import '../screens/shared/my_queue_ticket_screen.dart';
import '../screens/shared/promo_claim_screen.dart';
import 'glass_toast.dart';

class NgamQrRouteHelper {
  NgamQrRouteHelper._();

  static void handleScannedQr(BuildContext context, String rawData) {
    final query = rawData.trim();
    if (query.isEmpty) return;

    // 1. WiFi QR format
    if (query.startsWith('WIFI:')) {
      String ssid = 'WiFi_Kedai';
      String pass = '';
      final parts = query.replaceFirst('WIFI:', '').split(';');
      for (final part in parts) {
        if (part.startsWith('S:')) ssid = part.substring(2).replaceAll(r'\:', ':').replaceAll(r'\;', ';');
        if (part.startsWith('P:')) pass = part.substring(2).replaceAll(r'\:', ':').replaceAll(r'\;', ';');
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF161622),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white12),
          ),
          title: Row(
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedWifi01,
                color: Color(0xFF42A5F5),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'qr_route.wifi_title'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'qr_route.wifi_detected'.tr(),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SSID: $ssid',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (pass.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'qr_route.wifi_password_label'.tr(args: [pass]),
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'common.close'.tr(),
                style: const TextStyle(color: Colors.white54),
              ),
            ),
            if (pass.isNotEmpty)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF42A5F5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: pass));
                  Navigator.pop(ctx);
                  showGlassToast(context, 'qr_route.wifi_copied_toast'.tr());
                },
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedCopy01,
                  color: Colors.white,
                  size: 16,
                ),
                label: Text('common.copy_password'.tr()),
              ),
          ],
        ),
      );
      return;
    }

    // 2. Smart Queue QR format
    if (query.startsWith('NGAM_QUEUE:') ||
        query.contains('/queue/') ||
        query.contains('/q/')) {
      String? bizId;
      if (query.startsWith('NGAM_QUEUE:')) {
        bizId = query.substring('NGAM_QUEUE:'.length).split('|').first.trim();
      } else {
        final qUri = Uri.tryParse(query);
        if (qUri != null && qUri.pathSegments.isNotEmpty) {
          final idx = qUri.pathSegments.indexWhere((s) => s == 'queue' || s == 'q');
          if (idx != -1 && idx + 1 < qUri.pathSegments.length) {
            bizId = qUri.pathSegments[idx + 1].replaceFirst('@', '').trim();
          } else {
            bizId = qUri.pathSegments.last.replaceFirst('@', '').trim();
          }
        }
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MyQueueTicketScreen(
            initialBusinessId: (bizId != null && bizId.isNotEmpty) ? bizId : null,
            allowDirectJoin: true,
          ),
        ),
      );
      showGlassToast(context, 'qr_route.opening_queue_toast'.tr());
      return;
    }

    // 2b. NGAM-ORDER:<orderId> QR format -> open Digital e-Receipt
    if (query.startsWith('NGAM-ORDER:')) {
      final orderId = query.substring('NGAM-ORDER:'.length).trim();
      if (orderId.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EreceiptScreen(orderId: orderId)),
        );
        showGlassToast(context, 'qr_route.opening_receipt_toast'.tr());
        return;
      }
    }

    final uri = Uri.tryParse(query);
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https' || uri.scheme == 'ngam')) {
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      final first = segments.isNotEmpty ? segments.first.toLowerCase() : '';
      final second = segments.length > 1 ? segments[1].toLowerCase() : '';

      // 3. Dedicated e-Receipt & Points QR
      final isGatewayResult =
          first == 'receipt' && (second == 'success' || second == 'failed' || second == 'cancel');
      if (first == 'e-resit' ||
          first == 'ereceipt' ||
          (first == 'receipt' && !isGatewayResult)) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EreceiptScreen(uri: uri)),
        );
        showGlassToast(context, 'qr_route.opening_receipt_toast'.tr());
        return;
      }

      if (isGatewayResult) {
        final orderId = uri.queryParameters['order_id'] ??
            uri.queryParameters['reference'] ??
            uri.queryParameters['id'] ??
            '';
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentResultScreen(
              status: second,
              orderId: orderId,
            ),
          ),
        );
        return;
      }

      // 4. Dedicated Promo / Voucher URL: /promo/:code or /voucher/:code
      if (first == 'promo' || first == 'voucher') {
        final code = segments.length > 1
            ? Uri.decodeComponent(segments[1])
            : (uri.queryParameters['code'] ?? '');
        final store = uri.queryParameters['store'] ?? uri.queryParameters['shop'] ?? '';
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PromoClaimScreen(
              promoCode: code,
              businessIdentifier: store,
              tableNumber: uri.queryParameters['table'],
            ),
          ),
        );
        showGlassToast(context, 'qr_route.opening_promo_toast'.tr());
        return;
      }

      // 5. Post link: /p/:id or /post/:id
      if (first == 'p' || first == 'post') {
        final postId = segments.length > 1 ? segments[1] : '';
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PostRouteLoader(postId: postId)),
        );
        return;
      }

      // 6. Storefront / Table / Store+Promo link
      String identifier = '';
      if (first == 'c' || first == 'store' || first == 'shop') {
        identifier = segments.length > 1 ? Uri.decodeComponent(segments[1]) : '';
      } else if (segments.isNotEmpty) {
        identifier = Uri.decodeComponent(segments.first);
      } else if (uri.host.isNotEmpty) {
        identifier = uri.host;
      }

      final tableParam = uri.queryParameters['table'];
      final promoParam = uri.queryParameters['promo'] ?? uri.queryParameters['voucher'];

      // If Promo QR with no table number -> open dedicated Promo Claim Page!
      if (promoParam != null &&
          promoParam.trim().isNotEmpty &&
          (tableParam == null || tableParam.trim().isEmpty)) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PromoClaimScreen(
              promoCode: promoParam.trim(),
              businessIdentifier: identifier,
            ),
          ),
        );
        showGlassToast(context, 'qr_route.opening_promo_toast'.tr());
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StoreRouteLoader(
            businessId: identifier,
            tableNumber: tableParam,
            promoCode: promoParam,
            autoShowPromoPopup: promoParam != null && promoParam.trim().isNotEmpty,
          ),
        ),
      );
      return;
    }

    // 7. Plain handle/ID fallback
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoreRouteLoader(businessId: query),
      ),
    );
  }
}
