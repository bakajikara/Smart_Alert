import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Alert',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Bluetooth LE Devices'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  FlutterBluePlus _flutterBlue = FlutterBluePlus.instance;
  List<ScanResult> _scanResults = [];

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  void _startScan() async {
    PermissionStatus permissionStatus = await Permission.location.request();

    if (permissionStatus.isGranted) {
      _flutterBlue.scan().listen((scanResult) {
        if (!_scanResults.contains(scanResult.device)) {
          setState(() {
            _scanResults.add(scanResult);
          });
        }
      });
    } else {
      // 位置情報の権限が拒否された場合はエラーメッセージを表示
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('権限エラー'),
            content: Text('位置情報の権限が必要です。アプリ設定から有効にしてください。'),
            actions: [
              TextButton(
                child: Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          );
        },
      );
    }
  }

  String getDeviceDisplayName(ScanResult scanResult) {
    final deviceName = scanResult.device.name.isEmpty ? 'Unknown Device' : scanResult.device.name;
    final deviceUUID = scanResult.advertisementData.serviceUuids.isNotEmpty
        ? scanResult.advertisementData.serviceUuids.first.toString()
        : '';
    final List<String> TileUUIDs = [
      '0000fd84-0000-1000-8000-00805f9b34fb',
      '0000feec-0000-1000-8000-00805f9b34fb',
      '0000feed-0000-1000-8000-00805f9b34fb',
      '0000067c-0000-1000-8000-00805f9b34fb'
    ];
    if (TileUUIDs.contains(deviceUUID)) {
      return 'Tile';
    } else {
      return deviceName;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
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
                Text('Advertisement Data:'),
                Text(
                  _scanResults[index].advertisementData.toString().replaceAll(',', '\n'),
                  style: TextStyle(fontFamily: 'Courier'),
                ),
                Text('MAC Address: ' + device.id.toString()),
                Text('Type: ' + device.type.toString()),
              ],
            ),
          );
        },
      ),
    );
  }
}
