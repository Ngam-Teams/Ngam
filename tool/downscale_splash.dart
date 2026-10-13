// ignore_for_file: avoid_print
import 'dart:io';
import 'package:image/image.dart' as img;
void main() async {
  final file = File('assets/app_splash.png');
  final image = img.decodeImage(file.readAsBytesSync())!;
  
  // Resize to 512x512 to prevent OutOfMemory / Canvas crash on Android 12
  final resized = img.copyResize(image, width: 512, height: 512);
  await file.writeAsBytes(img.encodePng(resized));
  print('Successfully resized app_splash.png to 512x512');
}
