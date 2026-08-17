import 'dart:html' as html;

void signalRiderWebReady() {
  html.window.dispatchEvent(html.Event('circum-rider-ready'));
}
