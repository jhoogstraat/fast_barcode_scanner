import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class BarcodeTypeSelector extends StatefulWidget {
  const BarcodeTypeSelector(this._config, {Key? key}) : super(key: key);

  final ScannerConfiguration _config;

  @override
  State<BarcodeTypeSelector> createState() => _BarcodeTypeSelectorState();
}

class _BarcodeTypeSelectorState extends State<BarcodeTypeSelector> {
  _BarcodeTypeSelectorState();

  @override
  void initState() {
    super.initState();
    _items = BarcodeType.values.map((e) => describeEnum(e)).toList();
    _selected = widget._config.types.toList();
  }

  late List<String> _items;
  late List<BarcodeType> _selected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Types'),
        leading: BackButton(
          onPressed: () => Navigator.pop(context, _selected),
        ),
      ),
      body: ListView.separated(
        itemBuilder: (ctx, idx) {
          final item = BarcodeType.values.elementAt(idx);
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
