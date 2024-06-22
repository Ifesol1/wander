import 'package:flutter/material.dart';
import 'adventure_page.dart';
import 'plugin_store.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'adventureclass.dart';
import 'dart:convert';

class HomePage extends StatefulWidget {
  final List<CameraDescription> cameras;

  const HomePage({Key? key, required this.cameras}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Adventure> savedAdventures = [];

  @override
  void initState() {
    super.initState();
    _loadSavedAdventures();
  }

  Future<void> _loadSavedAdventures() async {
    final prefs = await SharedPreferences.getInstance();
    final adventuresJson = prefs.getStringList('savedAdventures') ?? [];
    setState(() {
      savedAdventures = adventuresJson.map((jsonStr) => Adventure.fromJson(jsonDecode(jsonStr))).toList();
    });
  }

  Future<void> _renameAdventure(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final adventures = prefs.getStringList('savedAdventures') ?? [];
    final newAdventureName = await _showRenameDialog(savedAdventures[index].details);
    if (newAdventureName != null) {
      savedAdventures[index].details = newAdventureName;
      adventures[index] = jsonEncode(savedAdventures[index].toJson());
      await prefs.setStringList('savedAdventures', adventures);
      setState(() {
        savedAdventures = savedAdventures; // Trigger UI update
      });
    }
  }

  Future<String?> _showRenameDialog(String currentName) async {
    TextEditingController controller = TextEditingController(text: currentName);
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Rename Adventure'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: "Enter new name"),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(context, controller.text);
              },
              child: Text('Save'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, null);
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAdventure(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final adventures = prefs.getStringList('savedAdventures') ?? [];
    adventures.removeAt(index);
    await prefs.setStringList('savedAdventures', adventures);
    setState(() {
      savedAdventures.removeAt(index);
    });
  }

  void _loadAdventure(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdventurePage(
          cameras: widget.cameras,
          savedAdventure: savedAdventures[index],
        ),
      ),
    ).then((_) {
      _loadSavedAdventures();
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
                'Welcome to the Adventure App!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Previous Adventures:',
                style: TextStyle(
                  fontSize: 22,
                  color: Colors.white70,
                ),
              ),
              SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: savedAdventures.length,
                  itemBuilder: (context, index) {
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: Icon(Icons.explore, color: Colors.teal),
                        title: Text(savedAdventures[index].details),
                        onTap: () {
                          _loadAdventure(index);
                        },
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'rename') {
                              _renameAdventure(index);
                            } else if (value == 'delete') {
                              _deleteAdventure(index);
                            }
                          },
                          itemBuilder: (BuildContext context) {
                            return [
                              PopupMenuItem(
                                value: 'rename',
                                child: Text('Rename'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ];
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AdventurePage(cameras: widget.cameras)),
                  ).then((_) {
                    _loadSavedAdventures();
                  });
                },
                icon: Icon(Icons.add, color: Colors.white),
                label: Text('Start a New Adventure', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PluginStore()),
                  );
                },
                icon: Icon(Icons.store, color: Colors.white),
                label: Text('Go to Plugin Store', style: TextStyle(color: Colors.white)),
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
