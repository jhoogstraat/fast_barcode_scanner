import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:fast_barcode_scanner_example/scanning_screen/scanning_overlay_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class OverlaySelector extends StatefulWidget {
  const OverlaySelector(this._config, {Key? key}) : super(key: key);

  final ScanningOverlayConfig _config;

  @override
  State<OverlaySelector> createState() => _OverlaySelectorState();
}

class _OverlaySelectorState extends State<OverlaySelector> {
  _OverlaySelectorState();

  @override
  void initState() {
    super.initState();
    _items = ScanningOverlayType.values.map((e) => describeEnum(e)).toList();
    _selected = widget._config.enabledOverlays.toList();
  }

  late List<String> _items;
  late List<ScanningOverlayType> _selected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Overlay Types'),
        leading: BackButton(
          onPressed: () => Navigator.pop(context, _selected),
        ),
      ),
      body: ListView.separated(
        itemBuilder: (ctx, idx) {
          final item = ScanningOverlayType.values.elementAt(idx);
          return CheckboxListTile(
            key: Key(_items[idx]),
            value: _selected.contains(item),
            title: Text(_items[idx]),
            onChanged: (newValue) {
              setState(() {
                if (newValue == true) {
                  _selected.add(item);
                } else {
                  _selected.remove(item);
                }
              });
            },
          );
        },
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemCount: BarcodeType.values.length,
      ),
    );
  }
}
