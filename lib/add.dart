import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final FlutterBluePlus _flutterBlue = FlutterBluePlus.instance;
  final List<ScanResult> _scanResults = [];
  StreamSubscription? scanSubscription;

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
      scanSubscription = _flutterBlue.scanResults.listen((scanResults) {
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
    scanSubscription?.cancel();
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

  Future<void> _showRegistrationDialog(ScanResult scanResult) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String initialName = getDeviceDisplayName(scanResult);
    TextEditingController nameController = TextEditingController(text: initialName);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('登録名を設定'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: '登録名'),
          ),
          actions: [
            TextButton(
              child: const Text('キャンセル'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                String name = nameController.text.trim();
                if (name.isEmpty) {
                  name = 'Unknown Device';
                }
                String macAddress = scanResult.device.id.toString();
                Map<String, String> deviceInfo = {'name': name, 'macAddress': macAddress};
                String deviceInfoJson = jsonEncode(deviceInfo);
                List<String> savedDevices = prefs.getStringList('devices') ?? [];
                savedDevices.add(deviceInfoJson);
                prefs.setStringList('devices', savedDevices);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('デバイスを追加'),
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
            onTap: () => _showRegistrationDialog(_scanResults[index]),
          );
        },
      ),
    );
  }
}