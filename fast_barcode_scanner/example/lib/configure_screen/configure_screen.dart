import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:flutter/material.dart';

import 'type_selector.dart';

class ConfigureScreen extends StatefulWidget {
  const ConfigureScreen({super.key});

  @override
  State<ConfigureScreen> createState() => _ConfigureScreenState();
}

class _ConfigureScreenState extends State<ConfigureScreen> {
  final CameraController cameraController = CameraController.shared;

  late List<BarcodeType> _types;
  late PerformanceMode _mode;
  late CameraPosition _position;
  late DetectionMode _detectionMode;

  @override
  void initState() {
    super.initState();
    final config = cameraController.state.value.scannerConfig!;
    _types = List<BarcodeType>.from(config.types);
    _mode = config.mode;
    _position = config.position;
    _detectionMode = config.detectionMode;
  }

  @override
  Widget build(BuildContext context) {
    final currentConfig = ScannerConfiguration(
      _types,
      _mode,
      _position,
      _detectionMode,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration'),
        actions: [
          TextButton(
            onPressed: _applyChanges,
            child: const Text('Apply'),
          ),
        ],
      ),
      body: ListView(
        children: ListTile.divideTiles(
          context: context,
          tiles: [
            ListTile(
              title: const Text('Active code types'),
              subtitle: Text(_types.map((e) => e.name).join(', ')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final updatedTypes = await Navigator.push<List<BarcodeType>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BarcodeTypeSelector(currentConfig),
                  ),
                );
                if (updatedTypes != null && updatedTypes.isNotEmpty) {
                  setState(() => _types = updatedTypes);
                }
              },
            ),
            ListTile(
              title: const Text('Performance Mode'),
              trailing: DropdownButton<PerformanceMode>(
                value: _mode,
                onChanged: (value) {
                  if (value != null) setState(() => _mode = value);
                },
                items: _buildDropdownItems(PerformanceMode.values),
              ),
            ),
            ListTile(
              title: const Text('Camera Position'),
              trailing: DropdownButton<CameraPosition>(
                value: _position,
                onChanged: (value) {
                  if (value != null) setState(() => _position = value);
                },
                items: _buildDropdownItems(CameraPosition.values),
              ),
            ),
            ListTile(
              title: const Text('Detection Mode'),
              trailing: DropdownButton<DetectionMode>(
                value: _detectionMode,
                onChanged: (value) {
                  if (value != null) setState(() => _detectionMode = value);
                },
                items: _buildDropdownItems(DetectionMode.values),
              ),
            ),
          ],
        ).toList(),
      ),
    );
  }

  List<DropdownMenuItem<E>> _buildDropdownItems<E extends Enum>(
    List<E> enumCases,
  ) =>
      enumCases
          .map((v) => DropdownMenuItem(value: v, child: Text(v.name)))
          .toList();

  Future<void> _applyChanges() async {
    try {
      await cameraController.configure(
        types: _types,
        mode: _mode,
        detectionMode: _detectionMode,
        position: _position,
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (error) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Configuration Error'),
          content: Text(error.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}
