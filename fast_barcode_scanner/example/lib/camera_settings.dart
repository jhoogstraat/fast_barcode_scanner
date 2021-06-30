import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'type_selector.dart';

class CameraSettings extends StatefulWidget {
  const CameraSettings(this._currentConfiguration, {Key? key})
      : super(key: key);

  final CameraConfiguration _currentConfiguration;

  @override
  State<CameraSettings> createState() => _CameraSettingsState();
}

class _CameraSettingsState extends State<CameraSettings> {
  late CameraConfiguration _config;

  @override
  void initState() {
    _config = widget._currentConfiguration;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration'),
        actions: [
          TextButton(
            child: const Text(
              'Apply',
              style: TextStyle(color: Colors.white),
            ),
            onPressed: () async {
              try {
                await CameraController.instance.changeConfiguration(
                  types: _config.types,
                  framerate: _config.framerate,
                  resolution: _config.resolution,
                  detectionMode: _config.detectionMode,
                  position: _config.position,
                );
              } catch (error) {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text('Fehler'),
                    content: Text(error.toString()),
                  ),
                );

                return;
              }

              Navigator.pop(context, _config);
            },
          )
        ],
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Active code types'),
            subtitle:
                Text(_config.types.map((e) => describeEnum(e)).join(', ')),
            onTap: () async {
              final types = await Navigator.push<List<BarcodeType>>(context,
                  MaterialPageRoute(builder: (_) {
                return BarcodeTypeSelector(_config);
              }));
              setState(() {
                _config = _config.copyWith(types: types);
              });
            },
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('Resolution'),
            trailing: DropdownButton<Resolution>(
                value: _config.resolution,
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(resolution: value);
                  });
                },
                items: buildDropdownItems(Resolution.values)),
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('Framerate'),
            trailing: DropdownButton<Framerate>(
                value: _config.framerate,
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(framerate: value);
                  });
                },
                items: buildDropdownItems(Framerate.values)),
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('Position'),
            trailing: DropdownButton<CameraPosition>(
                value: _config.position,
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(position: value);
                  });
                },
                items: buildDropdownItems(CameraPosition.values)),
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('Detection Mode'),
            trailing: DropdownButton<DetectionMode>(
                value: _config.detectionMode,
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(detectionMode: value);
                  });
                },
                items: buildDropdownItems(DetectionMode.values)),
          ),
        ],
      ),
    );
  }

  List<DropdownMenuItem<E>> buildDropdownItems<E extends Object>(
          List<E> enumCases) =>
      enumCases
          .map((v) => DropdownMenuItem(value: v, child: Text(describeEnum(v))))
          .toList();
}
