import 'package:flutter/material.dart';

import 'detector_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: DetectorScreen());
    // return MaterialApp(
    //   home: Scaffold(
    //     appBar: AppBar(title: const Text('Fast Barcode Scanner')),
    //     body: Center(
    //       child: RaisedButton(
    //         child: Text("Open Scanner"),
    //         onPressed: () => Navigator.push(
    //           context,
    //           MaterialPageRoute(builder: (context) => DetectorScreen()),
    //         ),
    //       ),
    //     ),
    //   ),
    // );
  }
}
