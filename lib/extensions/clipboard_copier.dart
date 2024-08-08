import 'package:flutter/services.dart';

class ClipboardCopier {
  Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    print('Text copied to clipboard: $text');
  }
}
