// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

String? readBrowserStorage(String key) => html.window.localStorage[key];

void writeBrowserStorage(String key, String value) {
  html.window.localStorage[key] = value;
}

void removeBrowserStorage(String key) {
  html.window.localStorage.remove(key);
}
