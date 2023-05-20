import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int searchInterval = 10; // 初期値
  int timeout = 1; // 初期値

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  Future<void> loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      searchInterval = prefs.getInt('searchInterval') ?? 10;
      timeout = prefs.getInt('timeout') ?? 1;
    });
  }

  Future<void> saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('searchInterval', searchInterval);
    await prefs.setInt('timeout', timeout);
  }

  Future<void> showEditDialog(String title, String settingKey, int initialValue) async {
    TextEditingController textEditingController = TextEditingController(text: initialValue.toString());

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: TextFormField(
            controller: textEditingController,
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  int newValue = int.tryParse(textEditingController.text) ?? initialValue;
                  if (settingKey == 'searchInterval') {
                    searchInterval = newValue;
                  } else if (settingKey == 'timeout') {
                    timeout = newValue;
                  }
                });
                saveSettings();
                Navigator.pop(context);
              },
              child: const Text('保存'),
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
        title: const Text('設定'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('検索時間間隔 (分)'),
            subtitle: Text('現在の値: $searchInterval'),
            onTap: () {
              showEditDialog('検索時間間隔', 'searchInterval', searchInterval);
            },
          ),
          ListTile(
            title: const Text('タイムアウト (分)'),
            subtitle: Text('現在の値: $timeout'),
            onTap: () {
              showEditDialog('タイムアウト', 'timeout', timeout);
            },
          ),
        ],
      ),
    );
  }
}
