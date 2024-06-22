import 'package:shared_preferences/shared_preferences.dart';

class ExtensionUtils {
  // Function to check if an extension is enabled
  static Future<bool> isExtensionEnabled(String key) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? false;
  }
}
