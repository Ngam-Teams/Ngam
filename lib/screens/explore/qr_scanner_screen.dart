import '../../widgets/glass_nav_button.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../widgets/glass_toast.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController controller = MobileScannerController();
  bool _hasScanned = false;
  bool _torchEnabled = false;
  bool _isProcessingImage = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    if (_isProcessingImage || _hasScanned) return;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null || !mounted) return;

      setState(() => _isProcessingImage = true);

      final BarcodeCapture? capture = await controller.analyzeImage(image.path);
      if (capture != null && capture.barcodes.isNotEmpty) {
        for (final barcode in capture.barcodes) {
          if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
            _hasScanned = true;
            if (mounted) {
              Navigator.pop(context, barcode.rawValue);
            }
            return;
          }
        }
      }

      if (mounted) {
        showGlassToast(
          context,
          'Tiada kod QR dikesan dalam gambar ini. Sila pilih gambar yang lebih jelas.',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        showGlassToast(
          context,
          'Ralat memproses gambar: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingImage = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // The Camera Feed
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (_hasScanned) return;
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
                  _hasScanned = true;
                  Navigator.pop(context, barcode.rawValue);
                  break;
                }
              }
            },
          ),

          // --- FUTURISTIC OVERLAY ---
          _buildScannerOverlay(context),

          // Instructions Banner
          Positioned(
            bottom: 110,
            left: 32,
            right: 32,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HugeIcon(icon: HugeIcons.strokeRoundedQrCode, color: Colors.blueAccent, size: 20),
                  SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Halakan ke Kod QR kedai atau meja',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Gallery Picker Shortcut Button
          Positioned(
            bottom: 44,
            left: 32,
            right: 32,
            child: Center(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.black.withValues(alpha: 0.65),
                  side: const BorderSide(color: Colors.white30),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: _pickFromGallery,
                icon: const HugeIcon(icon: HugeIcons.strokeRoundedImage01, size: 18, color: Color(0xFF42A5F5)),
                label: const Text(
                  'Pilih dari Galeri Foto',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ),

          // Top Action Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GlassNavButton.close(
                    context: context,
                    isDark: true,
                    size: 42,
                    iconSize: 22,
                  ),
                  Row(
                    children: [
                      GlassNavButton(
                        icon: HugeIcons.strokeRoundedImage01,
                        tooltip: 'Pilih dari Galeri',
                        isDark: true,
                        size: 42,
                        iconSize: 20,
                        onTap: _pickFromGallery,
                      ),
                      const SizedBox(width: 8),
                      GlassNavButton(
                        icon: _torchEnabled ? HugeIcons.strokeRoundedFlash : HugeIcons.strokeRoundedFlashOff,
                        iconColor: _torchEnabled ? Colors.amber : Colors.white,
                        tooltip: 'Lampu Kilat',
                        isDark: true,
                        size: 42,
                        iconSize: 20,
                        onTap: () {
                          controller.toggleTorch();
                          setState(() => _torchEnabled = !_torchEnabled);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Loading Overlay when analyzing image from gallery
          if (_isProcessingImage)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF42A5F5)),
                    SizedBox(height: 16),
                    Text(
                      'Menganalisis kod QR dari gambar...',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay(BuildContext context) {
    return Stack(
      children: [
        // 1. THE DARK "PUNCH-HOLE" LAYER
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.5),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. THE FUTURISTIC BORDER (Neon Blue)
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue.withValues(alpha: 0.5), width: 2),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                )
              ],
            ),
          ),
        ),

        // 3. THE SCANNING LINE
        const _ScanningLine(),
      ],
    );
  }
} // <--- Added missing closing brace for _QRScannerScreenState

// --- MOVED OUTSIDE THE MAIN STATE CLASS ---

class _ScanningLine extends StatefulWidget {
  const _ScanningLine();

  @override
  State<_ScanningLine> createState() => _ScanningLineState();
}

class _ScanningLineState extends State<_ScanningLine> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Center(
          child: Container(
            width: 250,
            height: 250,
            alignment: Alignment(0, (_controller.value * 2) - 1),
            child: Container(
              height: 2,
              width: 220,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  )
                ],
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.withValues(alpha: 0),
                    Colors.blue,
                    Colors.blue.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}