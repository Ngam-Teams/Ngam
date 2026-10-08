import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ngam/widgets/glass_box.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../providers/auth_provider.dart';

// Data dummy untuk cara pembayaran
class PaymentData {
  static final savedPaymentMethods = ValueNotifier<List<Map<String, dynamic>>>([]);

  static void addPaymentMethod(Map<String, dynamic> method) {
    savedPaymentMethods.value = [...savedPaymentMethods.value, method];
  }

  static void removePaymentMethod(String id) {
    savedPaymentMethods.value = savedPaymentMethods.value.where((m) => m["id"] != id).toList();
  }

  static void setPrimaryPaymentMethod(String id) {
    savedPaymentMethods.value = savedPaymentMethods.value.map((m) {
      final newM = Map<String, dynamic>.from(m);
      newM["isPrimary"] = (newM["id"] == id);
      return newM;
    }).toList();
  }
}

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  int _frontCardIndex = 0;

  final List<String> _malaysianBanks = [
    "Maybank", "CIMB Bank", "Public Bank", "RHB Bank", "Hong Leong Bank", "AmBank", "Bank Islam"
  ];

  LiquidGlassSettings _getGlassSettings(bool isDark, {double blur = 15.0}) {
    return LiquidGlassSettings(
      thickness: 0.1,
      blur: blur,
      refractiveIndex: 1.0,
      glassColor: Colors.transparent,
      lightAngle: 45.0,
      lightIntensity: isDark ? 0.1 : 0.2,
      ambientStrength: 1.0,
      saturation: 1.0,
      chromaticAberration: 0.0,
    );
  }
  // ==========================================
  // ðŸŸ¢ ENJIN CHIP & LOGO DOMPET PALING REALISTIK
  // ==========================================

  // ðŸ’Ž Lukis cip emas EMV biar nampak macam kad betul
  Widget _buildRealisticChip() {
    return SizedBox(
      width: 42, // Bagi kecil sikit supaya nampak detail cip yang gempak tu
      child: AspectRatio(
        aspectRatio: 1.586, // ðŸŸ¢ RATIO SAMA SEBIJIK MACAM KAD SEBENAR
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: const LinearGradient(
              colors: [Color(0xFFE5C058), Color(0xFFFDEB82), Color(0xFFE5C058)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.black.withValues(alpha: 0.4), width: 0.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 2, offset: const Offset(1, 1))],
          ),
          child: Stack(
            alignment: Alignment.center, // ðŸŸ¢ KONFEM NGAM-NGAM CENTER, TAK LARI
            children: [
              // Line garisan melintang
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(height: 0.5, color: Colors.black.withValues(alpha: 0.3)),
                  Container(height: 0.5, color: Colors.black.withValues(alpha: 0.3)),
                ],
              ),
              // Line garisan menegak
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(width: 0.5, color: Colors.black.withValues(alpha: 0.3)),
                  Container(width: 0.5, color: Colors.black.withValues(alpha: 0.3)),
                ],
              ),
              // Plat tengah (untuk cover line bersilang kat dalam)
              Container(
                width: 14, height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.4), width: 0.5),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFDEB82), Color(0xFFE5C058)],
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardLogo(String brand) {
    if (brand == 'VISA') {
      return const Text("VISA", style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: 1.0, shadows: [Shadow(color: Colors.black38, offset: Offset(1, 1), blurRadius: 2)]));
    } else if (brand == 'MASTERCARD') {
      return SizedBox(
        width: 44, height: 28,
        child: Stack(
          children: [
            Positioned(left: 0, child: Container(width: 28, height: 28, decoration: BoxDecoration(color: const Color(0xFFEB001B), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2)]))),
            Positioned(right: 0, child: Container(width: 28, height: 28, decoration: BoxDecoration(color: const Color(0xFFF79E1B).withValues(alpha: 0.9), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2)]))),
          ],
        ),
      );
    } else if (brand == 'AMEX') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(4), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)]),
        child: Text("AMEX", style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.w900, fontSize: 12)),
      );
    }
    return const HugeIcon(icon: HugeIcons.strokeRoundedCreditCard, color: Colors.white, size: 26);
  }

  Widget _buildBankLogo(String bankName, {double size = 42}) {
    Color bgColor; String initials; Color textColor = Colors.white;

    switch (bankName) {
      case "Maybank": bgColor = const Color(0xFFFFCC00); initials = "M"; textColor = Colors.black; break;
      case "CIMB Bank": bgColor = const Color(0xFF7A0010); initials = "CIMB"; break;
      case "Public Bank": bgColor = const Color(0xFFE3000F); initials = "PB"; break;
      case "RHB Bank": bgColor = const Color(0xFF0067B1); initials = "RHB"; break;
      case "Hong Leong Bank": bgColor = const Color(0xFF00387B); initials = "HLB"; break;
      case "AmBank": bgColor = const Color(0xFFED1A3B); initials = "Am"; break;
      case "Bank Islam": bgColor = const Color(0xFF4A2556); initials = "BI"; break;
      default: bgColor = Colors.blueGrey; initials = "B"; break;
    }

    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))]),
      child: Center(child: Text(initials, style: TextStyle(color: textColor, fontSize: size * 0.35, fontWeight: FontWeight.bold, letterSpacing: -0.5))),
    );
  }

  String _detectCardBrand(String rawDigits) {
    if (rawDigits.startsWith('4')) return 'VISA';
    if (rawDigits.startsWith('5')) return 'MASTERCARD';
    if (rawDigits.startsWith('34') || rawDigits.startsWith('37')) return 'AMEX';
    return 'CARD';
  }

  // ==========================================
  // BOTTOM SHEETS & MENUS
  // ==========================================

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
                          onTap: () {
                            if (formKey.currentState!.validate()) {
                              final rawDigits = numberController.text.replaceAll(' ', '');
                              final detectedBrand = _detectCardBrand(rawDigits);

                              PaymentData.addPaymentMethod({
                                "id": DateTime.now().millisecondsSinceEpoch.toString(),
                                "type": "card",
                                "name": detectedBrand,
                                "number": "â€¢â€¢â€¢â€¢ ${rawDigits.substring(rawDigits.length - 4)}",
                                "holder": nameController.text.toUpperCase(),
                                "expiry": expiryController.text,
                                "isPrimary": false,
                              });
                              Navigator.pop(context);
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
                                onTap: () {
                                  if (formKey.currentState!.validate()) {
                                    String accRaw = accountController.text;
                                    String masked = "â€¢â€¢â€¢â€¢ ${accRaw.substring(accRaw.length - 4)}";

                                    PaymentData.addPaymentMethod({
                                      "id": DateTime.now().millisecondsSinceEpoch.toString(),
                                      "type": "bank",
                                      "name": selectedBank,
                                      "number": masked,
                                      "holder": nameController.text.toUpperCase(),
                                      "expiry": null,
                                      "isPrimary": false,
                                    });
                                    Navigator.pop(context);
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

  // ─── DuitNow QR Sheet (Runner je boleh pakai) ────────────────
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
                          Text("wallet.your_qr_code".tr().toUpperCase(), style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
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
                            onTap: () {
                              if (pickedQr == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("wallet.upload_qr_first".tr())),
                                );
                                return;
                              }
                              PaymentData.addPaymentMethod({
                                "id": DateTime.now().millisecondsSinceEpoch.toString(),
                                "type": "duitnow_qr",
                                "name": "DuitNow QR",
                                "qrPath": pickedQr!.path,
                                "isPrimary": false,
                              });
                              Navigator.pop(context);
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

  // ==========================================
  // SUSUNAN FLOATING (PAKAI STACK)
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = screenWidth - 64;
    final cardHeight = cardWidth / 1.586;

    // Kita balut pakai ValueListenableBuilder sebab cardMethods tak wujud kat atas ni.

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text("wallet.title".tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(icon: const HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, color: Colors.grey, size: 24), onPressed: () => Navigator.pop(context)),
      ),
      body: Stack(
        children: [
          ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: PaymentData.savedPaymentMethods,
            builder: (context, methods, child) {

              final cardMethods = methods.where((m) => m["type"] == "card").toList();
              final bankMethods = methods.where((m) => m["type"] == "bank").toList();
              final duitnowMethods = methods.where((m) => m["type"] == "duitnow_qr").toList();

              // ðŸŸ¢ TAMBAH TINGGI (DYNAMIC HEIGHT) DEKAT SINI:
              double extraHeight = 10; // Padding untuk satu kad
              if (cardMethods.length == 2) extraHeight = 20; // Kasi sama offset macam kad nombor 2
              if (cardMethods.length >= 3) extraHeight = 30 ; // Kasi sama offset macam kad nombor 3
              final stackHeight = cardHeight + extraHeight;

              return Stack(
                children: [
                  Positioned.fill(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Credit & Debit Cards", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),

                          if (cardMethods.isEmpty)
                            _buildCardEmptyState(isDark: isDark, height: cardHeight, onTap: () => _showAddCardSheet(context, isDark))
                          else
                            _buildCardStack(cardMethods, isDark, cardHeight, stackHeight),

                          const SizedBox(height: 24),

                          Text("Linked Bank Accounts", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),

                          if (bankMethods.isEmpty)
                            _buildBankEmptyState(isDark: isDark, height: cardHeight, onTap: () => _showAddBankSheet(context, isDark))
                          else
                            Column(children: bankMethods.map((bank) => _buildBankTile(bank, isDark)).toList()),

                          // ─── Bahagian QR DuitNow ─────────────────────────────
                          if (duitnowMethods.isNotEmpty) ...[  
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                const HugeIcon(icon: HugeIcons.strokeRoundedQrCode, color: Color(0xFF00A86B), size: 18),
                                const SizedBox(width: 8),
                                Text("DuitNow QR", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Column(children: duitnowMethods.map((qr) => _buildDuitNowTile(qr, isDark)).toList()),
                          ],
                        ],
                      ),
                    ),
                  ),

                  Positioned(
                    bottom: 24, left: 16, right: 16,
                    child: SafeArea(top: false, child: _buildAddButton(context, isDark)),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // HELPER WIDGETS
  // ==========================================

  Widget _buildCardEmptyState({required bool isDark, required double height, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height, width: double.infinity,
        decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02), borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.1), width: 1.5)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)), child: HugeIcon(icon: HugeIcons.strokeRoundedCreditCard, color: isDark ? Colors.white54 : Colors.black54, size: 28)),
            const SizedBox(height: 12),
            Text("Add a Card", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildBankEmptyState({required bool isDark, required double height, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height, width: double.infinity,
        decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02), borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.1), width: 1.5)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)), child: HugeIcon(icon: HugeIcons.strokeRoundedBank, color: isDark ? Colors.white54 : Colors.black54, size: 28)),
            const SizedBox(height: 12),
            Text("Link Bank Account", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // ðŸ’Ž ENJIN KAD FOTOREALISTIK YANG TERPALING GEMPAK
  Widget _buildCardStack(List<Map<String, dynamic>> cardMethods, bool isDark, double cardHeight, double stackHeight) {
    int safeIndex = _frontCardIndex >= cardMethods.length ? 0 : _frontCardIndex;
    List<int> orderedIndices = List.generate(cardMethods.length, (i) => i);
    orderedIndices.sort((a, b) {
      int relA = (a - safeIndex + cardMethods.length) % cardMethods.length;
      int relB = (b - safeIndex + cardMethods.length) % cardMethods.length;
      return relB.compareTo(relA);
    });

    final currentMethod = cardMethods[safeIndex];
    final isPrimary = currentMethod["isPrimary"] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragEnd: (DragEndDetails details) {
            if (details.primaryVelocity == null) return;

            // ðŸŸ¢ Swipe BAWAH: Bawa kad belakang pergi depan
            if (details.primaryVelocity! > 300) {
              setState(() => _frontCardIndex = (safeIndex - 1 + cardMethods.length) % cardMethods.length);
            }
            // ðŸŸ¢ Swipe ATAS: Tolak kad depan pergi belakang
            else if (details.primaryVelocity! < -300) {
              setState(() => _frontCardIndex = (safeIndex + 1) % cardMethods.length);
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

                // Gradients Wallet Gelap (Tema Premium)
                List<Color> cardColors;
                if (method["name"] == "MASTERCARD") {
                  cardColors = [const Color(0xFF141E30), const Color(0xFF243B55)];
                } else if (method["name"] == "AMEX") {
                  cardColors = [const Color(0xFF004D40), const Color(0xFF00838F)];
                } else {
                  cardColors = [const Color(0xFF1A1F3B), const Color(0xFF2B3A67)]; // Default untuk Visa
                }

                return AnimatedPositioned(
                  key: ValueKey(method["id"]),
                  duration: const Duration(milliseconds: 500), curve: Curves.easeOutQuint,
                  top: top, left: 16, right: 16,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 500), curve: Curves.easeOutQuint,
                    scale: scale, alignment: Alignment.topCenter,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300), opacity: opacity,
                      child: GestureDetector(
                        onTap: () { if (relativePosition != 0) setState(() => _frontCardIndex = index); },
                        child: Container(
                          height: cardHeight,
                          decoration: BoxDecoration(
                              gradient: LinearGradient(colors: cardColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.0),
                              boxShadow: relativePosition == 0 ? [
                                BoxShadow(color: cardColors[0].withValues(alpha: 0.4), offset: const Offset(0, 8), blurRadius: 16, spreadRadius: -2),
                                BoxShadow(color: Colors.black.withValues(alpha: 0.15), offset: const Offset(0, 4), blurRadius: 8, spreadRadius: 0),
                              ] : []
                          ),
                          child: Stack(
                            children: [
                              // ðŸ’Ž 1. Overlay plastik kasi kilat sikit
                              Container(
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      gradient: LinearGradient(
                                        colors: [Colors.white.withValues(alpha: 0.15), Colors.transparent],
                                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                                      )
                                  )
                              ),
                              // ðŸ’Ž 2. Watermark bentuk bumi (jangan terang sangat)
                              Positioned(
                                right: -20, bottom: -20,
                                child: Icon(Icons.public, size: 160, color: Colors.white.withValues(alpha: 0.04)),
                              ),

                              // ðŸ’Ž 3. Isi dalam kad
                              // ðŸ’Ž 3. Isi dalam kad
                              Padding(
                                padding: const EdgeInsets.all(22),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  // ðŸŸ¢ DAH BUANG spaceBetween: Sekarang kita pakai Spacer() je biar cip ni center betul-betul!
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
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), // ðŸŸ¢ Kurangkan padding biar kemas
                                                decoration: BoxDecoration(
                                                    color: Colors.black.withValues(alpha: 0.3), // ðŸŸ¢ Pakaikan balik background hitam
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.5)
                                                ),
                                                child: Text("wallet.primary".tr(), style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5)), // ðŸŸ¢ Kecilkan tulisan
                                              )
                                          ]
                                      ),
                                    ),

                                    const Spacer(), // ðŸŸ¢ Tolak cip tepat kat center memanjang

                                    // TENGAH: Cip dengan simbol Contactless
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        _buildRealisticChip(),
                                        const SizedBox(width: 12),
                                        const Icon(Icons.contactless_outlined, color: Colors.white70, size: 28),
                                      ],
                                    ),

                                    const Spacer(), // ðŸŸ¢ Tolak detail bawah pergi ke bawah sekali

                                    // BARIS BAWAH 1: Nombor timbul (12 bintang + 4 nombor hujung)
                                    Text(
                                      // ðŸŸ¢ Paksa letak 12 bintang lepas tu ambil 4 nombor last je secara dinamik
                                        "**** **** **** ${method["number"].toString().length >= 4 ? method["number"].toString().substring(method["number"].toString().length - 4) : "0000"}",
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
                                                (method["holder"] ?? "USER").toString().toUpperCase(),
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
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // ðŸŸ¢ FIXED: Spacing pandai ubah sendiri ikut bilangan kad
        if (cardMethods.length > 1) ...[
          const SizedBox(height: 12),
          Center(child: Text("wallet.swipe_hint".tr(), style: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 11))),
          const SizedBox(height: 16),
        ] else ...[
          const SizedBox(height: 24), // ðŸŸ¢ Gap yang kemas kalau cuma ada sekeping kad
        ],

        SizedBox(
          height: 44,
          child: Row(
            children: [
              if (!isPrimary) ...[
                Expanded(
                  child: _AnimatedPressable(
                    onTap: () => PaymentData.setPrimaryPaymentMethod(currentMethod["id"]),
                    child: Container(decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), border: Border.all(color: Colors.blue.withValues(alpha: 0.5)), borderRadius: BorderRadius.circular(14)), child: Center(child: Text("wallet.set_primary".tr(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13)))),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: _AnimatedPressable(
                  onTap: () {
                    if (_frontCardIndex > 0) _frontCardIndex--;
                    PaymentData.removePaymentMethod(currentMethod["id"]);
                  },
                  child: Container(decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)), child: Center(child: Text("wallet.remove".tr(), maxLines: 1, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)))),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBankTile(Map<String, dynamic> bank, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05), width: 1.0)),
      child: Row(
        children: [
          _buildBankLogo(bank["name"], size: 42),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(bank["name"], style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)), const SizedBox(height: 2), Text(bank["number"], style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black54, letterSpacing: 1.5))])),
          IconButton(icon: Icon(Icons.delete_outline_rounded, color: Colors.redAccent.withValues(alpha: 0.8), size: 22), onPressed: () => PaymentData.removePaymentMethod(bank["id"]))
        ],
      ),
    );
  }

  Widget _buildDuitNowTile(Map<String, dynamic> qr, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00A86B).withValues(alpha: 0.3), width: 1.5),
        boxShadow: [BoxShadow(color: const Color(0xFF00A86B).withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // ─── Standard Header DuitNow (bersih, takde brand bank merepek)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00A86B), Color(0xFF009B5E)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                // Logo DuitNow tu
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                  child: const HugeIcon(icon: HugeIcons.strokeRoundedQrCode, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("DuitNow QR", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      Text("Registered Name in Image", style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
                if (qr["isPrimary"] == true)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                    child: Text("wallet.primary".tr(), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  ),
              ],
            ),
          ),

          // ─── Display QR Code yang bersih (standard je, tak payah brand bank)
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Kotak QR putih bersih — kita buang habis gaya dari bank lain
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(qr["qrPath"]),
                      width: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox(
                        height: 160,
                        child: Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 40)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Scan with any banking app to pay",
                  style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 12),
                ),
              ],
            ),
          ),

          // ─── Barisan action (butang)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => PaymentData.setPrimaryPaymentMethod(qr["id"]),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00A86B),
                      side: const BorderSide(color: Color(0xFF00A86B), width: 1.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text("Set Primary", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: Colors.redAccent.withValues(alpha: 0.8), size: 20),
                  onPressed: () => PaymentData.removePaymentMethod(qr["id"]),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.redAccent.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(BuildContext context, bool isDark) {
    return _AnimatedPressable(
      onTap: () => _showPaymentTypeSelector(context, isDark),
      child: GlassContainer(
        useOwnLayer: true, quality: GlassQuality.standard, shape: LiquidRoundedSuperellipse(borderRadius: 24.0), settings: _getGlassSettings(isDark, blur: 20),
        child: Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.2 : 0.6), width: 1.5), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, 8))]),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const HugeIcon(icon: HugeIcons.strokeRoundedAdd01, color: Colors.blue, size: 20), const SizedBox(width: 8), Text("wallet.add_payment_method".tr(), style: const TextStyle(color: Colors.blue, fontSize: 16, fontWeight: FontWeight.bold))]),
        ),
      ),
    );
  }
}

// ==========================================
// FORMATTERS & ANIMATIONS
// ==========================================

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
