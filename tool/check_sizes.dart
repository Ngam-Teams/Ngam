// ignore_for_file: avoid_print
import 'dart:io';
import 'package:image/image.dart' as img;
void main() {
  print('app.png: ${img.decodeImage(File('assets/app.png').readAsBytesSync())!.width}');
  print('app_splash.png: ${img.decodeImage(File('assets/app_splash.png').readAsBytesSync())!.width}');
}
