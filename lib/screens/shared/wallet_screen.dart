import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../services/payment_service.dart';
import '../../services/supabase_service.dart';


class WalletScreen extends StatefulWidget {
  final double? requiredAmountForPendingTask;
  const WalletScreen({super.key, this.requiredAmountForPendingTask});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with SingleTickerProviderStateMixin {
  int _frontCardIndex = 0;
  Timer? _autoScrollTimer;
  
  final ValueNotifier<List<Map<String, dynamic>>> _savedMethods = ValueNotifier([]);

  Future<void> _loadMethods() async {
    final methods = await PaymentService.fetchPaymentMethods();
    if (mounted) {
      _savedMethods.value = methods;
    }
  }

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
    _loadMethods();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTransactions();
    });
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() => _frontCardIndex++);
      }
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  double _tiltX = 0.0;
  double _tiltY = 0.0;

  final List<String> _malaysianBanks = [
    "Maybank", "CIMB Bank", "Public Bank", "RHB Bank", "Hong Leong Bank", 
    "AmBank", "Bank Islam", "Bank Rakyat", "UOB Malaysia", "OCBC Bank Malaysia", 
    "HSBC Bank Malaysia", "Standard Chartered Bank", "Affin Bank", "Alliance Bank", 
    "Bank Muamalat", "Agrobank", "MBSB Bank", "Al Rajhi Bank", "Kuwait Finance House", 
    "Citibank Malaysia", "GXBank", "AEON Bank", "Boost Bank"
  ];

  // Data Transaksi
  List<Map<String, dynamic>> _transactions = [];

  Future<void> _loadTransactions() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.user == null) return;
    
    try {
      final data = await SupabaseService.client
          .from('transactions')
          .select('*, gigs(title)')
          .eq('user_id', authProvider.user!.id)
          .order('created_at', ascending: false)
          .limit(20);
          
      final mapped = data.map((row) {
        final type = row['type'] as String;
        final amount = (row['amount'] as num).toDouble();
        final date = DateTime.parse(row['created_at']).toLocal();
        final gig = row['gigs'] as Map<String, dynamic>?;
        
        String title = '';
        String subtitle = '';
        bool isPositive = amount >= 0;
        
        switch (type) {
          case 'topup':
            title = 'Top Up';
            subtitle = 'Wallet Deposit';
            break;
          case 'withdrawal':
            title = 'Withdrawal';
            subtitle = 'Bank Transfer';
            break;
          case 'payment':
            title = 'Task Payment';
            subtitle = gig?['title'] ?? 'Service charge';
            break;
          case 'refund':
            title = 'Refund';
            subtitle = gig?['title'] ?? 'Task Cancelled';
            break;
          case 'earning':
            title = 'Earning';
            subtitle = gig?['title'] ?? 'Task Completed';
            break;
          default:
            title = 'Transaction';
            subtitle = 'Other';
        }
        
        return {
          'title': title,
          'subtitle': subtitle,
          'amount': amount.abs(),
          'isPositive': isPositive,
          'date': date,
        };
      }).toList();
      
      if (mounted) {
        setState(() {
          _transactions = mapped;
        });
      }
    } catch (e) {
      debugPrint('Error loading transactions: $e');
    }
  }

  LiquidGlassSettings _getGlassSettings(bool isDark, {double blur = 15.0}) {
    return LiquidGlassSettings(
      thickness: 0.1, blur: blur, refractiveIndex: 1.0, glassColor: Colors.transparent,
      lightAngle: 45.0, lightIntensity: isDark ? 0.1 : 0.2, ambientStrength: 1.0, saturation: 1.0, chromaticAberration: 0.02,
    );
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _tiltX -= details.delta.dy * 0.01;
      _tiltY += details.delta.dx * 0.01;
      _tiltX = _tiltX.clamp(-0.2, 0.2);
      _tiltY = _tiltY.clamp(-0.2, 0.2);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() { _tiltX = 0.0; _tiltY = 0.0; });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: _buildAddButton(context, isDark),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text("wallet.title".tr(), style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        leading: IconButton(icon: const HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, color: Colors.grey, size: 24), onPressed: () => Navigator.pop(context)),
      ),
      body: Stack(
        children: [
          // Orbs Bercahaya kat Background
          Positioned(top: 50, left: -100, child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [AppTheme.primary.withValues(alpha: 0.3), Colors.transparent])))),
          Positioned(top: 250, right: -150, child: Container(width: 350, height: 350, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [AppTheme.accent.withValues(alpha: 0.2), Colors.transparent])))),
          
          SafeArea(
            child: ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: _savedMethods,
              builder: (context, methods, child) {
                final savedCards = methods.where((m) => m["type"] == "card").toList();
                final bankMethods = methods.where((m) => m["type"] == "bank").toList();
                final duitnowMethods = methods.where((m) => m["type"] == "duitnow_qr").toList();

                final authProvider = context.watch<AuthProvider>();
                final realBalance = authProvider.user?.userBalance ?? 0.0;
                
                // Virtual list: Ngam Pay sentiasa duk kat index 0 (paling atas)
                final virtualCards = [ {"id": "ngam_pay", "type": "wallet", "name": "Ngam Pay", "balance": realBalance}, ...savedCards, ...bankMethods, ...duitnowMethods ];
                
                final cardWidth = MediaQuery.of(context).size.width - 32;
                final cardHeight = 220.0; 
                
                double extraHeight = 0;
                if (virtualCards.length == 2) extraHeight = 15;
                if (virtualCards.length >= 3) extraHeight = 25;
                final stackHeight = cardHeight + extraHeight;

                final currentMethod = virtualCards[_frontCardIndex % virtualCards.length];
                final isNgamPayActive = currentMethod["id"] == "ngam_pay";

                final safeHeight = MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom;
                final contentHeight = 20 + stackHeight + (virtualCards.length > 1 ? 44 : 24) + 60 + 70; // padding atas + stack + hint + butang-butang + gap kasi besar
                final drawerSize = (1.0 - (contentHeight / safeHeight)).clamp(0.2, 0.85);

                return Stack(
                  children: [
                    Column(
                      children: [
                        const SizedBox(height: 20),
                        // TIMBUNAN KAD (STACK)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 0),
                          child: _buildCardStack(virtualCards, isDark, cardHeight, stackHeight, cardWidth),
                        ),
                        
                        if (virtualCards.length > 1) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.swap_vert_rounded, size: 16, color: isDark ? Colors.white54 : Colors.black54),
                              const SizedBox(width: 8),
                              Text("wallet.swipe_hint".tr(), style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13, fontWeight: FontWeight.w500)),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ] else ...[
                          const SizedBox(height: 24),
                        ],
                        
                        // BUTANG ACTION DINAMIK
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: isNgamPayActive 
                              ? _buildNgamPayActions(isDark, currentMethod)
                              : _buildCreditCardActions(isDark, currentMethod),
                        ),
                      ],
                    ),

                    // LACI TRANSAKSI BOLEH DRAG
                    DraggableScrollableSheet(
                      initialChildSize: drawerSize,
                      minChildSize: drawerSize,
                      maxChildSize: 0.9,
                      snap: true,
                      builder: (context, scrollController) {
                        return _buildTransactionsDrawer(isDark, scrollController);
                      }
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TUKANG RENDER TIMBUNAN KAD
  // ==========================================
  Widget _buildCardStack(List<Map<String, dynamic>> cardMethods, bool isDark, double cardHeight, double stackHeight, double cardWidth) {
    int safeIndex = _frontCardIndex % cardMethods.length;
    List<int> orderedIndices = List.generate(cardMethods.length, (i) => i);
    orderedIndices.sort((a, b) {
      int relA = (a - safeIndex + cardMethods.length) % cardMethods.length;
      int relB = (b - safeIndex + cardMethods.length) % cardMethods.length;
      return relB.compareTo(relA);
    });

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragEnd: (DragEndDetails details) {
        if (details.primaryVelocity == null) return;
        if (details.primaryVelocity! > 300) {
          setState(() => _frontCardIndex = (safeIndex - 1 + cardMethods.length) % cardMethods.length);
          _startAutoScroll();
        } else if (details.primaryVelocity! < -300) {
          setState(() => _frontCardIndex = (safeIndex + 1) % cardMethods.length);
          _startAutoScroll();
        }
      },
      child: SizedBox(
        height: stackHeight,
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: orderedIndices.map((index) {
            int relativePosition = (index - safeIndex + cardMethods.length) % cardMethods.length;
            
            double top; double scale; double opacity;
            if (relativePosition == 0) { top = 0; scale = 1.0; opacity = 1.0; }
            else if (relativePosition == 1) { top = 35; scale = 0.90; opacity = 0.90; }
            else if (relativePosition == 2) { top = 65; scale = 0.80; opacity = 0.7; }
            else { top = 65; scale = 0.80; opacity = 0.00; }

            final method = cardMethods[index];
            final isNgamPay = method["id"] == "ngam_pay";

            return AnimatedPositioned(
              key: ValueKey(method["id"]),
              duration: const Duration(milliseconds: 500), curve: Curves.easeOutQuint,
              top: top, left: 24, right: 24,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 500), curve: Curves.easeOutQuint,
                scale: scale, alignment: Alignment.topCenter,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300), opacity: opacity,
                  child: GestureDetector(
                    onTap: () { 
                      if (relativePosition != 0) {
                        setState(() => _frontCardIndex = index);
                        _startAutoScroll();
                      } 
                    },
                    child: isNgamPay 
                      ? _buildNgamPayCard(isDark, method, cardHeight)
                      : (method["type"] == "bank"
                          ? _buildBankCardDesign(isDark, method, cardHeight, relativePosition == 0)
                          : (method["type"] == "duitnow_qr"
                              ? _buildDuitNowCardDesign(isDark, method, cardHeight, relativePosition == 0)
                              : _buildCreditCardDesign(isDark, method, cardHeight, relativePosition == 0))),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildNgamPayCard(bool isDark, Map<String, dynamic> method, double cardHeight) {
    final currencyFormatter = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ', decimalDigits: 2);
    
    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: TweenAnimationBuilder(
        tween: Tween<double>(begin: 0, end: _tiltX),
        duration: const Duration(milliseconds: 150),
        builder: (_, double valX, __) {
          return TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: _tiltY),
            duration: const Duration(milliseconds: 150),
            builder: (_, double valY, __) {
              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateX(valX)
                  ..rotateY(valY),
                alignment: FractionalOffset.center,
                child: GlassContainer(
                  quality: GlassQuality.standard,
                  shape: LiquidRoundedSuperellipse(borderRadius: 24.0),
                  settings: _getGlassSettings(isDark),
                  child: Container(
                    width: double.infinity,
                    height: cardHeight,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [
                          isDark ? Colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.6),
                          isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24.0),
                      border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.2 : 0.5), width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 30, offset: const Offset(0, 10))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("wallet.balance".tr(), style: TextStyle(fontSize: 16, color: isDark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w500)),
                            const Icon(Icons.wallet, color: AppTheme.primary, size: 28),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currencyFormatter.format(method["balance"]),
                          style: GoogleFonts.outfit(fontSize: 42, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87, letterSpacing: -1),
                        ),
                        const Spacer(),
                        Text("NGAM PAY", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, letterSpacing: 2, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCreditCardDesign(bool isDark, Map<String, dynamic> method, double cardHeight, bool isFront) {
    List<Color> cardColors;
    if (method["name"] == "MASTERCARD") {
      cardColors = [const Color(0xFF141E30), const Color(0xFF243B55)];
    } else if (method["name"] == "AMEX") cardColors = [const Color(0xFF004D40), const Color(0xFF00838F)];
    else cardColors = [const Color(0xFF1A1F3B), const Color(0xFF2B3A67)]; // Default untuk Visa

    return Container(
      height: cardHeight,
      decoration: BoxDecoration(
          gradient: LinearGradient(colors: cardColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24.0),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.0),
          boxShadow: isFront ? [
            BoxShadow(color: cardColors[0].withValues(alpha: 0.4), offset: const Offset(0, 8), blurRadius: 16, spreadRadius: -2),
            BoxShadow(color: Colors.black.withValues(alpha: 0.15), offset: const Offset(0, 4), blurRadius: 8, spreadRadius: 0),
          ] : []
      ),
      child: Stack(
        children: [
          // 1. Layer plastik yang berkilat
          Container(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24.0),
                  gradient: LinearGradient(
                    colors: [Colors.white.withValues(alpha: 0.15), Colors.transparent],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  )
              )
          ),
          // 2. Bayang-bayang watermark bumi
          Positioned(
            right: -20, bottom: -20,
            child: Icon(Icons.public, size: 160, color: Colors.white.withValues(alpha: 0.04)),
          ),

          // 3. Isi kandungan kad tu
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // BAHAGIAN ATAS: Nama dengan Primary Tag
                Align(
                  alignment: Alignment.topCenter,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("wallet.platinum".tr(), style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2.0)),
                        if (method["isPrimary"] == true)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.5)
                            ),
                            child: Text("wallet.primary".tr(), style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          )
                      ]
                  ),
                ),

                const Spacer(),

                // TENGAH: Cip dengan simbol Contactless
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildRealisticChip(),
                    const SizedBox(width: 12),
                    const Icon(Icons.contactless_outlined, color: Colors.white70, size: 28),
                  ],
                ),

                const Spacer(),

                // BARIS BAWAH 1: Nombor timbul (12 bintang + 4 nombor hujung)
                Text(
                    "**** **** **** ${method["last4"] ?? "0000"}",
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 3.0, shadows: [Shadow(color: Colors.black45, offset: Offset(1, 1), blurRadius: 2)])
                ),
                const SizedBox(height: 8),

                // BARIS BAWAH 2: Segala info dengan logo
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                            (method["holder"] ?? method["cardHolder"] ?? "NGAM USER").toString().toUpperCase(),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black45, offset: Offset(1, 1), blurRadius: 2)])
                        ),
                      ),
                      const SizedBox(width: 12),
                      Row(
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("wallet.valid".tr(), style: const TextStyle(color: Colors.white, fontSize: 5, fontWeight: FontWeight.bold)),
                              Text("wallet.thru".tr(), style: const TextStyle(color: Colors.white, fontSize: 5, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(width: 4),
                          Text(method["expiry"] ?? "12/28", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black45, offset: Offset(1, 1), blurRadius: 2)])),
                        ],
                      ),
                      const SizedBox(width: 16),
                      _buildCardLogo(method["name"]),
                    ]
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankCardDesign(bool isDark, Map<String, dynamic> method, double cardHeight, bool isFront) {
    return Container(
      height: cardHeight,
      decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.blueGrey.shade800, Colors.blueGrey.shade900], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24.0),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.0),
          boxShadow: isFront ? [
            BoxShadow(color: Colors.blueGrey.shade900.withValues(alpha: 0.4), offset: const Offset(0, 8), blurRadius: 16, spreadRadius: -2),
            BoxShadow(color: Colors.black.withValues(alpha: 0.15), offset: const Offset(0, 4), blurRadius: 8, spreadRadius: 0),
          ] : []
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.account_balance, color: Colors.white70, size: 32),
              Text("wallet.bank_account".tr(), style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ],
          ),
          const Spacer(),
          Text((method["name"] ?? method["bankName"] ?? "UNKNOWN BANK").toString().toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(method["accountNumber"]?.toString() ?? "**** 0000", style: const TextStyle(color: Colors.white70, fontSize: 16, letterSpacing: 2.0, fontFamily: 'monospace')),
              if (method["holder"] != null) 
                Expanded(child: Text(method["holder"].toString().toUpperCase(), textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDuitNowCardDesign(bool isDark, Map<String, dynamic> method, double cardHeight, bool isFront) {
    return Container(
      height: cardHeight,
      decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E242B) : Colors.white,
          borderRadius: BorderRadius.circular(24.0),
          border: Border.all(color: const Color(0xFF00A86B).withValues(alpha: 0.3), width: 2.0),
          boxShadow: isFront ? [
            BoxShadow(color: const Color(0xFF00A86B).withValues(alpha: 0.2), offset: const Offset(0, 8), blurRadius: 16, spreadRadius: -2),
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), offset: const Offset(0, 4), blurRadius: 8, spreadRadius: 0),
          ] : []
      ),
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("DuitNow QR", style: TextStyle(color: Color(0xFF00A86B), fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("wallet.show_to_receive".tr(), style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 14)),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFF00A86B), borderRadius: BorderRadius.circular(8)),
                  child: Text("wallet.primary".tr(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                )
              ],
            ),
          ),
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: method["qrPath"] != null 
                  ? Image.file(File(method["qrPath"]), fit: BoxFit.cover, errorBuilder: (_,__,___) => const Center(child: HugeIcon(icon: HugeIcons.strokeRoundedQrCode, color: Colors.black87, size: 60)))
                  : const Center(child: HugeIcon(icon: HugeIcons.strokeRoundedQrCode, color: Colors.black87, size: 60)),
            )
          )
        ],
      ),
    );
  }

  Widget _buildRealisticChip() {
    return SizedBox(
      width: 42,
      child: AspectRatio(
        aspectRatio: 1.586,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: const LinearGradient(colors: [Color(0xFFE5C058), Color(0xFFFDEB82), Color(0xFFE5C058)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            border: Border.all(color: Colors.black.withValues(alpha: 0.4), width: 0.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 2, offset: const Offset(1, 1))],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [Container(height: 0.5, color: Colors.black.withValues(alpha: 0.3)), Container(height: 0.5, color: Colors.black.withValues(alpha: 0.3))]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [Container(width: 0.5, color: Colors.black.withValues(alpha: 0.3)), Container(width: 0.5, color: Colors.black.withValues(alpha: 0.3))]),
              Container(width: 14, height: 10, decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), border: Border.all(color: Colors.black.withValues(alpha: 0.4), width: 0.5), gradient: const LinearGradient(colors: [Color(0xFFFDEB82), Color(0xFFE5C058)], begin: Alignment.topCenter, end: Alignment.bottomCenter)))
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardLogo(String brand) {
    if (brand == 'VISA') return const Text("VISA", style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: 1.0, shadows: [Shadow(color: Colors.black38, offset: Offset(1, 1), blurRadius: 2)]));
    if (brand == 'MASTERCARD') return SizedBox(width: 44, height: 28, child: Stack(children: [Positioned(left: 0, child: Container(width: 28, height: 28, decoration: const BoxDecoration(color: Color(0xFFEB001B), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2)]))), Positioned(right: 0, child: Container(width: 28, height: 28, decoration: BoxDecoration(color: const Color(0xFFF79E1B).withValues(alpha: 0.9), shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)])))]));
    return const HugeIcon(icon: HugeIcons.strokeRoundedCreditCard, color: Colors.white, size: 26);
  }

  // ==========================================
  // KANDUNGAN DINAMIK
  // ==========================================
  Future<double?> _showAmountDialog(BuildContext context, String title, String action, {bool isWithdrawal = false, List<Map<String, dynamic>>? cards}) async {
    final TextEditingController controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Map<String, dynamic>? selectedCard;
    if (cards != null && cards.isNotEmpty) {
      selectedCard = cards.firstWhere((c) => c['isPrimary'] == true, orElse: () => cards.first);
    }
    
    return showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E242B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isWithdrawal)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text('Withdrawal will be transferred directly to your primary bank account.', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54)),
                  ),
                if (!isWithdrawal && cards != null && cards.isNotEmpty) ...[
                  Text('Fund Source:', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Map<String, dynamic>>(
                        value: selectedCard,
                        isExpanded: true,
                        dropdownColor: isDark ? const Color(0xFF2C323A) : Colors.white,
                        items: cards.map((c) {
                          return DropdownMenuItem<Map<String, dynamic>>(
                            value: c,
                            child: Text('${c["name"] ?? "Card"} ending in ${c["last4"] ?? "****"}', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => selectedCard = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (!isWithdrawal && (cards == null || cards.isEmpty))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text('No credit card registered. Please add a card first.', style: TextStyle(fontSize: 12, color: Colors.redAccent)),
                  ),
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    prefixText: 'RM ',
                    hintText: '0.00',
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: (!isWithdrawal && (cards == null || cards.isEmpty)) ? null : () {
                  final val = double.tryParse(controller.text);
                  Navigator.pop(ctx, val);
                },
                child: Text(action, style: const TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildNgamPayActions(bool isDark, Map<String, dynamic> method) {
    return Padding(
      key: const ValueKey('ngam_pay_actions'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: _buildActionBtn(
              icon: HugeIcons.strokeRoundedAdd01, 
              label: "wallet.top_up".tr(), 
              isDark: isDark, 
              onTap: () async {
                final registeredCards = _savedMethods.value.where((m) => m['type'] == 'card').toList();
                final amount = await _showAmountDialog(context, 'Top Up Amount', 'Top Up', cards: registeredCards);
                if (amount != null && amount > 0) {
                  final authProvider = context.read<AuthProvider>();
                  try {
                    await SupabaseService.client.rpc('top_up_wallet', params: {
                      'p_user_id': authProvider.user!.id,
                      'p_amount': amount,
                    });
                    await authProvider.refreshBalance();
                    await _loadTransactions();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('RM ${amount.toStringAsFixed(2)} added to your wallet!')),
                      );
                      
                      if (widget.requiredAmountForPendingTask != null && authProvider.user!.userBalance >= widget.requiredAmountForPendingTask!) {
                        final isDark = Theme.of(context).brightness == Brightness.dark;
                        final proceed = await showDialog<bool>(
                          context: context,
                          builder: (context) {
                            return Dialog(
                              backgroundColor: Colors.transparent,
                              elevation: 0,
                              child: GlassContainer(
                                useOwnLayer: true,
                                quality: GlassQuality.standard,
                                shape: LiquidRoundedSuperellipse(borderRadius: 24.0),
                                settings: LiquidGlassSettings(
                                  blur: 16.0,
                                  lightIntensity: isDark ? 0.1 : 0.2,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(24.0),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.check_circle_rounded, size: 48, color: Colors.green),
                                      const SizedBox(height: 16),
                                      const Text('Baki Dah Cukup!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      const Text('Ingin teruskan pesanan yang tadi?', textAlign: TextAlign.center),
                                      const SizedBox(height: 24),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('Nanti Dulu', style: TextStyle(color: Colors.grey)),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                                            child: const Text('Teruskan'),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );

                        if (proceed == true && mounted) {
                          Navigator.pop(context, true);
                        }
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to top up')),
                      );
                    }
                  }
                }
              }
            )
          ),
          const SizedBox(width: 12),
          Expanded(child: _buildActionBtn(
            icon: HugeIcons.strokeRoundedArrowUp01, 
            label: "wallet.withdraw".tr(), 
            isDark: isDark, 
            onTap: () async {
              final bankMethods = _savedMethods.value.where((m) => m["type"] == "bank").toList();
              if (bankMethods.isEmpty) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sila tambah akaun bank terlebih dahulu.')),
                  );
                }
                return;
              }
              final amount = await _showAmountDialog(context, 'Withdraw Amount', 'Withdraw', isWithdrawal: true);
              if (amount != null && amount > 0) {
                final authProvider = context.read<AuthProvider>();
                final currentBalance = authProvider.user?.userBalance ?? 0.0;
                
                if (amount > currentBalance) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Insufficient balance')),
                    );
                  }
                  return;
                }

                try {
                  // Try panggil RPC withdrawal kalau wujud, kalau takde kita update dummy je untuk demo
                  try {
                    await SupabaseService.client.rpc('withdraw_wallet', params: {
                      'p_user_id': authProvider.user!.id,
                      'p_amount': amount,
                    });
                  } catch (e) {
                    // Lakonan (simulation) kalau RPC withdraw_wallet takde lagi kat DB
                    final newBalance = currentBalance - amount;
                    await SupabaseService.client.from('users').update({'user_balance': newBalance}).eq('id', authProvider.user!.id);
                    await SupabaseService.client.from('transactions').insert({
                      'user_id': authProvider.user!.id,
                      'type': 'withdrawal',
                      'amount': -amount,
                    });
                  }
                  
                  await authProvider.refreshBalance();
                  await _loadTransactions();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('RM ${amount.toStringAsFixed(2)} withdrawn to bank account successfully!')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to withdraw')),
                    );
                  }
                }
              }
            }
          )),
        ],
      ),
    );
  }

  Widget _buildCreditCardActions(bool isDark, Map<String, dynamic> method) {
    return Padding(
      key: ValueKey(method["id"]),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: _buildActionBtn(
              icon: HugeIcons.strokeRoundedStar,
              label: "wallet.set_primary".tr(),
              isDark: isDark,
              onTap: () async {
                await PaymentService.setPrimaryPaymentMethod(method["id"]);
                await _loadMethods();
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionBtn(
              icon: HugeIcons.strokeRoundedDelete02,
              label: "wallet.remove".tr(),
              isDark: isDark,
              color: Colors.redAccent,
              onTap: () async {
                await PaymentService.deletePaymentMethod(method["id"]);
                await _loadMethods();
                setState(() => _frontCardIndex = 0); // Kembali semula ke Ngam Pay
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsDrawer(bool isDark, ScrollController scrollController) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 30, offset: const Offset(0, -10))],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121212).withValues(alpha: 0.65) : Colors.white.withValues(alpha: 0.7),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.white, width: 1.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              physics: const BouncingScrollPhysics(),
            children: [
              Center(
                child: Container(
                  width: 40, height: 5,
                  decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10))
                )
              ),
              const SizedBox(height: 24),
              Text("wallet.recent_transactions".tr(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 16),
              ..._transactions.map((t) => _buildTransactionItem(t, isDark)),
              const SizedBox(height: 100), // Kasi ruang (padding) sikit untuk butang FAB
            ],
          ),
        ),
      ),
    ),
  );
  }

  // ==========================================
  // HELPERS
  // ==========================================
  Widget _buildActionBtn({required dynamic icon, required String label, required bool isDark, required VoidCallback onTap, Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        quality: GlassQuality.standard,
        shape: LiquidRoundedSuperellipse(borderRadius: 16.0),
        settings: _getGlassSettings(isDark, blur: 5.0),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.4),
            border: Border.all(color: color?.withValues(alpha: 0.3) ?? Colors.white.withValues(alpha: isDark ? 0.1 : 0.5)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon is IconData 
                  ? Icon(icon, size: 20, color: color ?? (isDark ? Colors.white : Colors.black87))
                  : HugeIcon(icon: icon, size: 20, color: color ?? (isDark ? Colors.white : Colors.black87)),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: color ?? (isDark ? Colors.white : Colors.black87))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> tx, bool isDark) {
    final currencyFormatter = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ', decimalDigits: 2);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tx['isPositive'] ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(tx['isPositive'] ? Icons.arrow_downward : Icons.arrow_upward,
                color: tx['isPositive'] ? Colors.green : Colors.red, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx['title'], style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
                Text(tx['subtitle'], style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black54)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${tx['isPositive'] ? '+' : ''}${currencyFormatter.format(tx['amount'])}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: tx['isPositive'] ? Colors.green : (isDark ? Colors.white : Colors.black87)),
              ),
              Text(DateFormat('MMM dd, hh:mm a').format(tx['date']), style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }



  String _detectCardBrand(String rawDigits) {
    if (rawDigits.startsWith('4')) return 'VISA';
    if (rawDigits.startsWith('5')) return 'MASTERCARD';
    if (rawDigits.startsWith('34') || rawDigits.startsWith('37')) return 'AMEX';
    return 'CARD';
  }






  void _showPaymentTypeSelector(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (dialogContext) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.4), width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 30, offset: const Offset(0, 10))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("wallet.add_payment_method".tr(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'Inter', color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 16),

                _buildTypeOption(isDark: isDark, icon: HugeIcons.strokeRoundedCreditCard, title: "Credit / Debit Card", subtitle: "Visa, Mastercard, Amex", color: Colors.blue, onTap: () { Navigator.pop(dialogContext); _showAddCardSheet(context, isDark); }),
                const SizedBox(height: 8),
                _buildTypeOption(isDark: isDark, icon: HugeIcons.strokeRoundedBank, title: "Link Bank Account", subtitle: "For quick payments & refunds", color: Colors.green, onTap: () { Navigator.pop(dialogContext); _showAddBankSheet(context, isDark); }),
                // DuitNow QR — Hanya untuk runner je
                if (context.read<AuthProvider>().isRunner) ...[  
                  const SizedBox(height: 8),
                  _buildTypeOption(isDark: isDark, icon: HugeIcons.strokeRoundedQrCode, title: "DuitNow QR", subtitle: "Upload your QR code for customers to pay", color: const Color(0xFF00A86B), onTap: () { Navigator.pop(dialogContext); _showAddDuitNowSheet(context, isDark); }),
                ],

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                    ),
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text("wallet.cancel".tr(), style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeOption({required bool isDark, required dynamic icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5)),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle), child: HugeIcon(icon: icon, color: color, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)), const SizedBox(height: 2), Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54))])),
            Icon(Icons.arrow_forward_ios_rounded, color: isDark ? Colors.white30 : Colors.black26, size: 14)
          ],
        ),
      ),
    );
  }

  void _showAddCardSheet(BuildContext context, bool isDark) {
    final nameController = TextEditingController();
    final numberController = TextEditingController();
    final expiryController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E242B).withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.8),
                  border: Border(top: BorderSide(color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.4), width: 1.5)),
                ),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)))),
                        const SizedBox(height: 16),
                        Text("wallet.add_credit_debit".tr(), style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),

                        _buildPremiumInput(isDark: isDark, label: "Card Number", hint: "0000 0000 0000 0000", icon: HugeIcons.strokeRoundedCreditCard, controller: numberController, keyboardType: TextInputType.number, formatters: [FilteringTextInputFormatter.digitsOnly, _CardNumberFormatter(), LengthLimitingTextInputFormatter(19)], validator: (value) {
                          if (value == null) return "Invalid";
                          if (value.replaceAll(' ', '').length != 16 && value.replaceAll(' ', '').length != 15) return "Invalid Length";
                          return null;
                        }),
                        const SizedBox(height: 12),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                flex: 3,
                                child: _buildPremiumInput(
                                    isDark: isDark, label: "Card Holder", hint: "NAME ON CARD", icon: HugeIcons.strokeRoundedUser, controller: nameController, keyboardType: TextInputType.name, textCapitalization: TextCapitalization.characters,
                                    formatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')), _UpperCaseTextFormatter(), LengthLimitingTextInputFormatter(26)],
                                    validator: (value) { if (value == null || value.trim().isEmpty) return "Cannot be empty"; return null; }
                                )
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                                flex: 2,
                                child: _buildPremiumInput(isDark: isDark, label: "Expiry", hint: "MM/YY", icon: HugeIcons.strokeRoundedCalendar01, controller: expiryController, keyboardType: TextInputType.number, formatters: [FilteringTextInputFormatter.digitsOnly, _ExpiryDateFormatter(), LengthLimitingTextInputFormatter(5)], validator: (value) {
                                  if (value == null || !RegExp(r'^(0[1-9]|1[0-2])\/([0-9]{2})$').hasMatch(value)) return "Invalid date";
                                  return null;
                                })
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        _AnimatedPressable(
                          onTap: () async {
                            if (formKey.currentState!.validate()) {
                              final rawDigits = numberController.text.replaceAll(' ', '');
                              final detectedBrand = _detectCardBrand(rawDigits);

                              await PaymentService.addPaymentMethod({
                                "id": DateTime.now().millisecondsSinceEpoch.toString(),
                                "type": "card",
                                "name": detectedBrand,
                                "holder": nameController.text,
                                "last4": rawDigits.substring(rawDigits.length - 4),
                                "expiry": expiryController.text,
                                "isPrimary": _savedMethods.value.where((m) => m['type'] == 'card').isEmpty,
                                "color": 0,
                              });
                              await _loadMethods();
                              if (mounted) Navigator.pop(context);
                            }
                          },
                          child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))]), child: Center(child: Text("wallet.save_card".tr(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)))),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAddBankSheet(BuildContext context, bool isDark) {
    final accountController = TextEditingController();
    final nameController = TextEditingController();
    String selectedBank = _malaysianBanks.first;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
            builder: (context, setSheetState) {
              return Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E242B).withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.8),
                        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.4), width: 1.5)),
                      ),
                      child: SingleChildScrollView(
                        child: Form(
                          key: formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)))),
                              const SizedBox(height: 16),
                              Text("wallet.link_bank_account".tr(), style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),

                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("wallet.select_bank".tr(), style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(14)),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: selectedBank,
                                        isExpanded: true,
                                        dropdownColor: isDark ? const Color(0xFF262626) : Colors.white,
                                        icon: Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? Colors.white54 : Colors.black54),
                                        items: _malaysianBanks.map((String bank) {
                                          return DropdownMenuItem<String>(
                                              value: bank,
                                              child: Row(children: [_buildBankLogo(bank, size: 28), const SizedBox(width: 12), Text(bank, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600, fontSize: 14))])
                                          );
                                        }).toList(),
                                        onChanged: (String? newValue) { setSheetState(() => selectedBank = newValue!); },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              _buildPremiumInput(isDark: isDark, label: "Account Number", hint: "Enter bank account number", icon: HugeIcons.strokeRoundedTaskEdit01, controller: accountController, keyboardType: TextInputType.number, formatters: [FilteringTextInputFormatter.digitsOnly], validator: (value) { if (value == null || value.length < 8) return "Invalid account number"; return null; }),
                              const SizedBox(height: 12),

                              _buildPremiumInput(isDark: isDark, label: "Account Holder Name", hint: "AS REGISTERED WITH BANK", icon: HugeIcons.strokeRoundedUser, controller: nameController, keyboardType: TextInputType.name, textCapitalization: TextCapitalization.characters, formatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')), _UpperCaseTextFormatter()], validator: (value) { if (value == null || value.trim().isEmpty) return "Cannot be empty"; return null; }),

                              const SizedBox(height: 24),

                              _AnimatedPressable(
                                onTap: () async {
                                  if (formKey.currentState!.validate()) {
                                    String accRaw = accountController.text;
                                    String masked = "•••• ${accRaw.substring(accRaw.length - 4)}";

                                    await PaymentService.addPaymentMethod({
                                      "id": DateTime.now().millisecondsSinceEpoch.toString(),
                                      "type": "bank",
                                      "name": selectedBank,
                                      "holder": nameController.text,
                                      "accountNumber": masked,
                                      "isPrimary": _savedMethods.value.where((m) => m['type'] == 'bank').isEmpty,
                                      "color": 0,
                                    });
                                    await _loadMethods();
                                    if (mounted) Navigator.pop(context);
                                  }
                                },
                                child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.green.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))]), child: Center(child: Text("wallet.link_account".tr(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)))),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
        );
      },
    );
  }

  void _showAddDuitNowSheet(BuildContext context, bool isDark) {
    File? pickedQr;
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E242B).withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.8),
                      border: Border(top: BorderSide(color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.4), width: 1.5)),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)))),
                          const SizedBox(height: 16),

                          // Header
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: const Color(0xFF00A86B).withValues(alpha: 0.15), shape: BoxShape.circle),
                                child: const HugeIcon(icon: HugeIcons.strokeRoundedQrCode, color: Color(0xFF00A86B), size: 22),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("DuitNow QR", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
                                  Text("wallet.customers_scan_qr".tr(), style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Label nama dibuang sebab QR DuitNow tu sendiri dah ada nama kat gambar.


                          // Kawasan upload QR
                          Text("YOUR QR CODE".toUpperCase(), style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () async {
                              final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
                              if (picked != null) {
                                setSheetState(() => pickedQr = File(picked.path));
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: double.infinity,
                              height: 180,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: pickedQr != null ? const Color(0xFF00A86B).withValues(alpha: 0.6) : Colors.grey.withValues(alpha: 0.3),
                                  width: pickedQr != null ? 2 : 1.5,
                                  style: pickedQr != null ? BorderStyle.solid : BorderStyle.solid,
                                ),
                              ),
                              child: pickedQr != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(15),
                                    child: Image.file(pickedQr!, fit: BoxFit.contain),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.upload_rounded, size: 36, color: Colors.grey.shade400),
                                      const SizedBox(height: 8),
                                      Text("wallet.tap_upload_qr".tr(), style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 4),
                                      Text("wallet.from_any_bank".tr(), style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                                    ],
                                  ),
                            ),
                          ),

                          // Kotak info
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00A86B).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF00A86B).withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.auto_fix_high_rounded, color: Color(0xFF00A86B), size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Your QR will be displayed in a clean, standardized format. Bank branding will be removed.",
                                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Butang Save
                          _AnimatedPressable(
                            onTap: () async {
                              if (pickedQr == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("wallet.upload_qr_first".tr())),
                                );
                                return;
                              }
                              await PaymentService.addPaymentMethod({
                                "id": DateTime.now().millisecondsSinceEpoch.toString(),
                                "type": "duitnow_qr",
                                "qrPath": pickedQr!.path,
                                "isPrimary": _savedMethods.value.where((m) => m['type'] == 'duitnow_qr').isEmpty,
                                "color": 0,
                              });
                              await _loadMethods();
                              if (mounted) Navigator.pop(context);
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00A86B),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: const Color(0xFF00A86B).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
                              ),
                              child: Center(child: Text("wallet.save_duitnow_qr".tr(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPremiumInput({required bool isDark, required String label, required String hint, required dynamic icon, required TextEditingController controller, TextInputType? keyboardType, List<TextInputFormatter>? formatters, TextCapitalization? textCapitalization, String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(14)),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: formatters,
            validator: validator,
            textCapitalization: textCapitalization ?? TextCapitalization.none,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint, hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black26, fontWeight: FontWeight.normal, fontSize: 13),
              prefixIcon: Padding(padding: const EdgeInsets.symmetric(horizontal: 14.0), child: HugeIcon(icon: icon, color: Colors.grey, size: 16)),
              prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddButton(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: _AnimatedPressable(
        onTap: () => _showPaymentTypeSelector(context, isDark),
        child: GlassContainer(
          useOwnLayer: true, quality: GlassQuality.standard, shape: LiquidRoundedSuperellipse(borderRadius: 24.0), settings: _getGlassSettings(isDark, blur: 20),
          child: Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.2 : 0.6), width: 1.5), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, 8))]),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const HugeIcon(icon: HugeIcons.strokeRoundedAdd01, color: Colors.blue, size: 20), const SizedBox(width: 8), Text("wallet.add_payment_method".tr(), style: const TextStyle(color: Colors.blue, fontSize: 16, fontWeight: FontWeight.bold))]),
          ),
        ),
      ),
    );
  }

  Widget _buildBankLogo(String bankName, {double size = 42}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Icon(
          Icons.account_balance, 
          size: size * 0.5, 
          color: isDark ? Colors.white70 : Colors.black87
        ),
      ),
    );
  }

}


class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(RegExp(r'\D'), '');
    String newString = '';
    for (int i = 0; i < text.length; i++) { if (i > 0 && i % 4 == 0) newString += ' '; newString += text[i]; }
    return TextEditingValue(text: newString, selection: TextSelection.collapsed(offset: newString.length));
  }
}

class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.isEmpty) return newValue.copyWith(text: '');
    String newString = '';
    for (int i = 0; i < text.length; i++) { if (i == 2) newString += '/'; newString += text[i]; }
    return TextEditingValue(text: newString, selection: TextSelection.collapsed(offset: newString.length));
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(text: newValue.text.toUpperCase(), selection: newValue.selection);
  }
}

class _AnimatedPressable extends StatefulWidget {
  final Widget child; final VoidCallback onTap;
  const _AnimatedPressable({required this.child, required this.onTap});
  @override
  State<_AnimatedPressable> createState() => _AnimatedPressableState();
}

class _AnimatedPressableState extends State<_AnimatedPressable> with SingleTickerProviderStateMixin {
  late AnimationController _c; late Animation<double> _s;
  @override
  void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 100)); _s = Tween<double>(begin: 1.0, end: 0.94).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut)); }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) { return GestureDetector(onTapDown: (_) => _c.forward(), onTapUp: (_) { _c.reverse(); widget.onTap(); }, onTapCancel: () => _c.reverse(), child: ScaleTransition(scale: _s, child: widget.child)); }
}
