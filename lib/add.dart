import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreen();
}

class _AddDeviceScreen extends State<AddDeviceScreen> {
  final FlutterBluePlus _flutterBlue = FlutterBluePlus.instance;
  final List<ScanResult> _scanResults = [];

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    _stopScan();
    super.dispose();
  }

  void _startScan() async {
    PermissionStatus permissionStatus = await Permission.location.request();

    if (permissionStatus.isGranted) {
      _flutterBlue.startScan();
      _flutterBlue.scanResults.listen((scanResults) {
        for (ScanResult scanResult in scanResults) {
          if (!_scanResults.contains(scanResult)) {
            setState(() {
              _scanResults.add(scanResult);
            });
          }
        }
      });
    } else {
      // 位置情報の権限が拒否された場合はエラーメッセージを表示
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('権限エラー'),
            content: const Text('位置情報の権限が必要です。アプリ設定から有効にしてください。'),
            actions: [
              TextButton(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          );
        },
      );
    }
  }

  void _stopScan() {
    _flutterBlue.stopScan();
  }

  String getDeviceDisplayName(ScanResult scanResult) {
    final deviceName = scanResult.device.name.isEmpty ? 'Unknown Device' : scanResult.device.name;
    final deviceUUID = scanResult.advertisementData.serviceUuids.isNotEmpty
        ? scanResult.advertisementData.serviceUuids.first.toString()
        : '';
    final List<String> tileUUIDs = [
      '0000fd84-0000-1000-8000-00805f9b34fb',
      '0000feec-0000-1000-8000-00805f9b34fb',
      '0000feed-0000-1000-8000-00805f9b34fb',
      '0000067c-0000-1000-8000-00805f9b34fb'
    ];
    if (tileUUIDs.contains(deviceUUID)) {
      return 'Tile';
    } else {
      return deviceName;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add device"),
      ),
      body: ListView.builder(
        itemCount: _scanResults.length,
        itemBuilder: (context, index) {
          final device = _scanResults[index].device;
          return ListTile(
            title: Text(getDeviceDisplayName(_scanResults[index])),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Advertisement Data:'),
                Text(
                  _scanResults[index].advertisementData.toString().replaceAll(',', '\n'),
                  style: const TextStyle(fontFamily: 'Courier'),
                ),
                Text('MAC Address: ${device.id}'),
                Text('Type: ${device.type}'),
              ],
            ),
          );
        },
      ),
    );
  }
}