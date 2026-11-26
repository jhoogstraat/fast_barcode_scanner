import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:fast_barcode_scanner_example/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'scanning_screen/scanning_screen.dart';

void main() {
  runApp(const MaterialApp(home: HomeScreen()));
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ScanningScreen(dispose: _disposeCheckboxValue),
                  ),
                );
              },
            ),
            ElevatedButton(
              onPressed: () async {
                final dialog = SimpleDialog(
                  children: [
                    SimpleDialogOption(
                      child: const Text('Scan sample image'),
                      onPressed: () => Navigator.pop(context, 'sample'),
                    ),
                    SimpleDialogOption(
                      child: const Text('Open Picker'),
                      onPressed: () => Navigator.pop(context, 'picker'),
                    )
                  ],
                );

                final result = await showDialog<String>(
                    context: context, builder: (_) => dialog);

                final ImageSource source;
                if (result == 'sample') {
                  final bytes = await rootBundle.load('assets/barcodes.png');
                  source = ImageSource.binary(bytes);
                } else if (result == 'picker') {
                  source = ImageSource.picker();
                } else {
                  return;
                }

                try {
                  final barcodes =
                      await CameraController.shared.scanImage(source);

                  if (!context.mounted) return;

                  showDialog(
                    context: context,
                    builder: (_) {
                      final List<Widget> children;

                      if (barcodes == null) {
                        children = const [Center(child: Text('User aborted'))];
                      } else if (barcodes.isEmpty) {
                        children = const [
                          Center(child: Text('No barcodes detected'))
                        ];
                      } else {
                        children =
                            barcodes.map((e) => Text(e.toString())).toList();
                      }

                      return SimpleDialog(
                        title: const Text('Result'),
                        children: [
                          Image.asset("assets/barcodes.png"),
                          ...children
                        ],
                      );
                    },
                  );
                } catch (error, stack) {
                  if (!context.mounted) return;
                  presentErrorAlert(context, error, stack);
                }
              },
              child: const Text('Scan image'),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Dispose CameraController with BarcodeCamera'),
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
