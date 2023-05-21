import 'dart:async';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:smart_alert/main.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final Key _listKey = UniqueKey();
  List<Map<String, String>> devices = [];

  @override
  void initState() {
    super.initState();
    _loadDevices();
    requestPermission();
    scanBluetoothDevices();
    FlutterBackgroundService().on('update').listen((event) {
      _loadDevices();
    });
  }

  void requestPermission() async {
    PermissionStatus permissionStatus = await Permission.locationAlways.request();
    if (!permissionStatus.isGranted) {
      // 位置情報の権限が拒否された場合はエラーメッセージを表示
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('権限エラー'),
            content: const Text('アプリ設定から位置情報へのアクセスを常に許可にしてください。'),
            actions: [
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  Permission.locationAlways.request();
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _loadDevices() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    List<String>? savedDevices = prefs.getStringList('devices');
    if (savedDevices != null) {
      setState(() {
        devices = savedDevices.map((deviceInfoJson) {
          Map<String, dynamic> deviceInfo = jsonDecode(deviceInfoJson) as Map<String, dynamic>;
          return {
            'name': deviceInfo['name'] as String? ?? '',
            'macAddress': deviceInfo['macAddress'] as String? ?? '',
            'lastDetected': deviceInfo['lastDetected'] as String? ?? '',
            'latitude': deviceInfo['latitude'] as String? ?? '',
            'longitude': deviceInfo['longitude'] as String? ?? '',
          };
        }).toList();
      });
    }
  }

  Future<void> _showChangeNameDialog(BuildContext context, int index) async {
    TextEditingController nameController = TextEditingController();
    nameController.text = devices[index]['name'] ?? '';

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('登録名を変更'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: '登録名'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('キャンセル'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('保存'),
              onPressed: () {
                String newName = nameController.text.trim();
                if (newName.isNotEmpty) {
                  setState(() {
                    devices[index]['name'] = newName;
                  });
                  _saveDevices();
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _deleteDevice(int index) {
    final deviceName = devices[index]['name'] ?? 'Unknown Device';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('デバイスを削除'),
          content: Text('デバイス $deviceName を削除しますか？'),
          actions: <Widget>[
            TextButton(
              child: const Text('キャンセル'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('削除'),
              onPressed: () {
                setState(() {
                  devices.removeAt(index);
                });
                _saveDevices();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveDevices() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> deviceInfoJsonList = devices.map((deviceInfo) {
      return jsonEncode(deviceInfo);
    }).toList();
    await prefs.setStringList('devices', deviceInfoJsonList);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.pushNamed(context, '/settings');
              }
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDevices,
        child: devices.isEmpty
            ? const Center(
                child: Text('デバイスがありません'),
              )
            : ReorderableListView.builder(
                key: _listKey,
                onReorder: _reorderDevices,
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  String name = devices[index]['name'] ?? '';
                  String macAddress = devices[index]['macAddress'] ?? '';
                  String lastDetected = devices[index]['lastDetected'] ?? '';
                  String latitude = devices[index]['latitude'] ?? '';
                  String longitude = devices[index]['longitude'] ?? '';
                  DateTime dateTime = DateTime.parse(lastDetected);
                  String formattedDateTime = DateFormat('yyyy/MM/dd HH:mm:ss').format(dateTime);
                  return ListTile(
                    key: ValueKey(devices[index]),
                    title: Text(name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('MAC アドレス: $macAddress'),
                        Text(
                          '最終検出時刻: $formattedDateTime',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '位置情報: ($latitude, $longitude)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    trailing: PopupMenuButton(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showChangeNameDialog(context, index);
                        } else if (value == 'delete') {
                          _deleteDevice(index);
                        }
                      },
                      itemBuilder: (BuildContext context) {
                        return <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: Text('登録名を変更'),
                          ),
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('デバイスを削除'),
                          ),
                        ];
                      },
                    ),
                    onTap: () {
                      launchMap(devices[index]['latitude'], devices[index]['longitude']);
                    },
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.pushNamed(context, '/add');
          await _loadDevices();
        },
        tooltip: 'デバイスを追加',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _reorderDevices(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final device = devices.removeAt(oldIndex);
      devices.insert(newIndex, device);
      _saveDevices();
    });
  }

  void launchMap(String? latitude, String? longitude) async {
    final url = Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude');
    await launchUrl(url);
  }
}