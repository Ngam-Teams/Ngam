import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final srcFile = File('web/icons/Icon-512.png');
  final srcBytes = srcFile.readAsBytesSync();
  final srcImg = img.decodeImage(srcBytes)!;

  // 1. Cari bounding box kandungan (huruf "Ngam")
  int minX = srcImg.width, minY = srcImg.height, maxX = 0, maxY = 0;
  for (int y = 0; y < srcImg.height; y++) {
    for (int x = 0; x < srcImg.width; x++) {
      final p = srcImg.getPixel(x, y);
      if (p.r > 30 || p.g > 30 || p.b > 30) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }

  print('Original content box: ($minX, $minY) to ($maxX, $maxY)');
  final origW = maxX - minX + 1;
  final origH = maxY - minY + 1;

  // Potong kandungan teks sahaja
  final contentImg = img.copyCrop(srcImg, x: minX, y: minY, width: origW, height: origH);

  // 2. Skalakan teks supaya berada dalam "Safe Zone" 60% daripada lebar kanvas (307px daripada 512px)
  // Ini memberi 20% margin kiri dan 20% margin kanan supaya bila bulatan/cutout Android dipotong,
  // teks langsung tidak akan terkeluar atau menyentuh sempadan cutout!
  const targetCanvasSize = 512;
  const targetWidth = 310;
  final scaleRatio = targetWidth / origW;
  final targetHeight = (origH * scaleRatio).round();

  print('New content size: ${targetWidth}x$targetHeight (scaled by ${(scaleRatio * 100).toStringAsFixed(1)}%)');

  final resizedContent = img.copyResize(
    contentImg,
    width: targetWidth,
    height: targetHeight,
    interpolation: img.Interpolation.cubic,
  );

  // 3. Cipta kanvas 512x512 berlatar belakang hitam (#000000)
  final new512 = img.Image(width: targetCanvasSize, height: targetCanvasSize);
  // Isi warna hitam pekat
  img.fill(new512, color: img.ColorRgba8(0, 0, 0, 255));

  // Letak di tengah-tengah kanvas
  final destX = ((targetCanvasSize - targetWidth) / 2).round();
  final destY = ((targetCanvasSize - targetHeight) / 2).round();

  img.compositeImage(
    new512,
    resizedContent,
    dstX: destX,
    dstY: destY,
  );

  // 4. Jana saiz 192x192
  final new192 = img.copyResize(
    new512,
    width: 192,
    height: 192,
    interpolation: img.Interpolation.cubic,
  );

  // 5. Simpan ke kedua-dua projek (Ngam dan Ngam Business)
  final paths512 = [
    'web/icons/Icon-512.png',
    'web/icons/Icon-maskable-512.png',
    '../Ngam Business/web/icons/Icon-512.png',
    '../Ngam Business/web/icons/Icon-maskable-512.png',
  ];

  final paths192 = [
    'web/icons/Icon-192.png',
    'web/icons/Icon-maskable-192.png',
    '../Ngam Business/web/icons/Icon-192.png',
    '../Ngam Business/web/icons/Icon-maskable-192.png',
  ];

  final encoded512 = img.encodePng(new512);
  final encoded192 = img.encodePng(new192);

  for (final p in paths512) {
    File(p).writeAsBytesSync(encoded512);
    print('Saved: $p');
  }

  for (final p in paths192) {
    File(p).writeAsBytesSync(encoded192);
    print('Saved: $p');
  }

  print('\nSemua ikon PWA telah berjaya dikemaskini dengan padding zon selamat (Safe-Zone Padding)!');
}
