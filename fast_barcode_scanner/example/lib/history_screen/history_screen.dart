import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../scan_history.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    history.addListener(onBarcodeListener);
  }

  void onBarcodeListener() {
    setState(() {});
  }

  @override
  void dispose() {
    history.removeListener(onBarcodeListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            onPressed: () => history.clear(),
            icon: const Icon(Icons.clear),
          )
        ],
      ),
      body: ListView.separated(
        itemBuilder: (ctx, idx) => ListTile(
          title: Text(history.scans[idx].value),
          subtitle: Text(
            describeEnum(history.scans[history.scans.length - idx - 1].type),
          ),
        ),
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemCount: history.scans.length,
      ),
    );
  }
}
