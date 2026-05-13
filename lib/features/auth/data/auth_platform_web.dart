// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

bool isIosPwaStandalone() {
  final ua = html.window.navigator.userAgent.toLowerCase();
  final isIos = ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod');
  if (!isIos) return false;
  // navigator.standalone is true only in iOS PWA standalone (home-screen) mode
  final standalone = (html.window.navigator as dynamic).standalone as bool? ?? false;
  // Fallback: CSS display-mode media query (also true in standalone)
  final mq = html.window.matchMedia('(display-mode: standalone)').matches;
  return standalone || mq;
}
