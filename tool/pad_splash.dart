// ignore_for_file: avoid_print
import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  final file = File('assets/app.png');
  if (!file.existsSync()) {
    print('assets/app.png not found!');
    return;
  }

  // Load the image
  final originalBytes = await file.readAsBytes();
  final originalImage = img.decodeImage(originalBytes);
  if (originalImage == null) {
    print('Failed to decode image');
    return;
  }

  final width = originalImage.width;
  final height = originalImage.height;

  // Make it smaller for the splash screen (45% of original)
  final newContentWidth = (width * 0.45).round();
  final newContentHeight = (height * 0.45).round();

  // Resize the original image
  final resizedContent = img.copyResize(originalImage, width: newContentWidth, height: newContentHeight);

  // Create a new empty (transparent) image with the original dimensions
  final paddedImage = img.Image(width: width, height: height, format: originalImage.format);

  // Calculate position to center the resized content
  final xOffset = ((width - newContentWidth) / 2).round();
  final yOffset = ((height - newContentHeight) / 2).round();

  // Composite the resized content into the center of the padded image
  img.compositeImage(paddedImage, resizedContent, dstX: xOffset, dstY: yOffset);

  // Save the result
  final resultBytes = img.encodePng(paddedImage);
  await File('assets/app_splash.png').writeAsBytes(resultBytes);
  print('Successfully padded image to assets/app_splash.png!');
}
