import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:fast_barcode_scanner_example/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'scanning_screen/scanning_screen.dart';

void main() {
  runApp(const MaterialApp(home: HomeScreen()));
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _disposeCheckboxValue = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fast Barcode Scanner')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              child: const Text('Open Scanner'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ScanningScreen(
                    dispose: _disposeCheckboxValue,
                  ),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final cam = CameraController();

                final dialog = SimpleDialog(
                  children: [
                    SimpleDialogOption(
                      child: const Text('Choose path'),
                      onPressed: () => Navigator.pop(context, 1),
                    ),
                    SimpleDialogOption(
                      child: const Text('Choose image'),
                      onPressed: () => Navigator.pop(context, 2),
                    ),
                    SimpleDialogOption(
                      child: const Text('Open Picker'),
                      onPressed: () => Navigator.pop(context, 3),
                    )
                  ],
                );

                final result = await showDialog<int>(
                    context: context, builder: (_) => dialog);
                final ImageSource source;

                switch (result) {
                  case 1:
                    source = ImageSource.path('fake/path/img.jpg');
                    break;
                  case 2:
                    final bytes = await rootBundle.load('assets/barcode.jpg');
                    source = ImageSource.binary(bytes);
                    break;
                  case 3:
                    source = ImageSource.picker();
                    break;
                  default:
                    return;
                }

                try {
                  final barcodes = await cam.scanImage(source);
                  showDialog(
                    context: context,
                    builder: (_) => SimpleDialog(
                        title: const Text('Results'),
                        children:
                            barcodes?.map((e) => Text(e.toString())).toList() ??
                                const [Center(child: Text('Aborted'))]),
                  );
                } catch (error, stack) {
                  presentErrorAlert(context, error, stack);
                }
              },
              child: const Text('Scan image'),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Dispose:'),
                Checkbox(
                  value: _disposeCheckboxValue,
                  onChanged: (newValue) => setState(
                    () => _disposeCheckboxValue = newValue!,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
