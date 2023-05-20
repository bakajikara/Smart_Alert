import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  }

  Future<void> _loadDevices() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? savedDevices = prefs.getStringList('devices');
    if (savedDevices != null) {
      setState(() {
        devices = savedDevices.map((deviceInfoJson) {
          Map<String, dynamic> deviceInfo = jsonDecode(deviceInfoJson) as Map<String, dynamic>;
          return {
            'name': deviceInfo['name'] as String? ?? '',
            'macAddress': deviceInfo['macAddress'] as String? ?? '',
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
      body: devices.isEmpty
          ? const Center(
              child: Text('デバイスがありません'),
            )
          : ReorderableListView.builder(
              key: _listKey,
              onReorder: _reorderDevices,
              shrinkWrap: true,
              itemCount: devices.length,
              itemBuilder: (context, index) {
                return ListTile(
                  key: ValueKey(devices[index]),
                  title: Text(devices[index]['name'] ?? ''),
                  subtitle: Text(devices[index]['macAddress'] ?? ''),
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
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.pushNamed(context, '/add');
          await _loadDevices();
        },
        tooltip: 'デバイスを追加',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
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
}