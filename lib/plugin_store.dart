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
    if (key == 'email_sender.dart' && value) {
      // If enabling the email sender, ask for the email address
      String? email = await _showEmailInputDialog();
      if (email != null && email.isNotEmpty) {
        await prefs.setString('user_email', email);
      }
    }
    await prefs.setBool(key, value);
    setState(() {
      enabledExtensions[key] = value;
    });
  }

  Future<String?> _showEmailInputDialog() async {
    TextEditingController emailController = TextEditingController();
    return await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Enter Email Address'),
          content: TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(hintText: 'Email Address'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(null);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(emailController.text);
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Number of tabs
      child: Scaffold(
        appBar: AppBar(

          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade200, Colors.teal.shade800],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          bottom: TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 4.0,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.teal.shade100,
            labelStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: 'Plugins'),
              Tab(text: 'Games'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Plugins Tab
            Container(
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
                      'Available Plugins',
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
                        itemCount: extensions
                            .where((extension) => extension['type'] != 'Game')
                            .length,
                        itemBuilder: (context, index) {
                          final pluginExtensions = extensions
                              .where((extension) => extension['type'] != 'Game')
                              .toList();
                          final extension = pluginExtensions[index];
                          String key = extension['file'];
                          bool isEnabled = enabledExtensions[key] ?? false;
                          return Card(
                            margin: EdgeInsets.symmetric(vertical: 8),
                            child: ListTile(
                              title: Text(extension['name'],
                                  style: TextStyle(fontSize: 20)),
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
                        padding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Games Tab
            Container(
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
                      'Available Games',
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
                        itemCount: extensions
                            .where((extension) => extension['type'] == 'Game')
                            .length,
                        itemBuilder: (context, index) {
                          final gameExtensions = extensions
                              .where((extension) => extension['type'] == 'Game')
                              .toList();
                          final extension = gameExtensions[index];
                          String key = extension['file'];
                          bool isEnabled = enabledExtensions[key] ?? false;
                          return Card(
                            margin: EdgeInsets.symmetric(vertical: 8),
                            child: ListTile(
                              title: Text(extension['name'],
                                  style: TextStyle(fontSize: 20)),
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
