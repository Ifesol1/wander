import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'extensions.dart'; // Import the extensions list

class PluginStore extends StatefulWidget {
  @override
  _PluginStoreState createState() => _PluginStoreState();
}

class _PluginStoreState extends State<PluginStore> {
  Map<String, bool> enabledExtensions = {};

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      for (var extension in extensions) {
        String key = extension['file'];
        enabledExtensions[key] = prefs.getBool(key) ?? false;
      }
    });
  }

  Future<void> _setPreference(String key, bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    setState(() {
      enabledExtensions[key] = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade200, Colors.teal.shade800],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 25),
              Text(
                'Plugin Store',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.only(top: 8.0),
                  itemCount: extensions.length,
                  itemBuilder: (context, index) {
                    final extension = extensions[index];
                    String key = extension['file'];
                    bool isEnabled = enabledExtensions[key] ?? false;
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        title: Text(extension['name'], style: TextStyle(fontSize: 20)),
                        subtitle: Text(extension['description']),
                        trailing: Switch(
                          value: isEnabled,
                          onChanged: (bool value) {
                            _setPreference(key, value);
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: Icon(Icons.arrow_back, color: Colors.white),
                label: Text('Back', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}