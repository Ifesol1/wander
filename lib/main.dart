import 'package:flutter/material.dart';
import 'home_page.dart';
import 'package:camera/camera.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));

}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({Key? key, required this.cameras}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Adventure App',
      theme: ThemeData(
        primarySwatch: Colors.teal,
      ),
      home: HomePage(cameras: cameras,),
    );
  }
}
