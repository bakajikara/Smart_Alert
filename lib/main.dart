import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:smart_alert/home.dart';
import 'package:smart_alert/add.dart';
import 'package:smart_alert/settings.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();

  runApp(const MyApp());
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      // this will be executed when app is in foreground or background in separated isolate
      onStart: onStart,

      // auto start service
      autoStart: true,
      autoStartOnBoot: true,
      isForegroundMode: true,
    ),
    iosConfiguration: IosConfiguration(
      // auto start service
      autoStart: true,
    ),
  );

  service.startService();
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Only available for flutter 3.0.0 and later
  DartPluginRegistrant.ensureInitialized();

  SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
  final searchInterval = sharedPreferences.getInt('searchInterval') ?? 10;

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  Timer.periodic(Duration(seconds: searchInterval), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        scanBluetoothDevices();
        service.invoke('update');
      }
    }
  });
}

void scanBluetoothDevices() async {
  FlutterBluePlus flutterBlue = FlutterBluePlus.instance;
  StreamSubscription? scanSubscription;

  SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
  final timeout = sharedPreferences.getInt('timeout') ?? 1 * 9;

  List<Map<String, String>> allDevices = [], searchingDevices = [];
  SharedPreferences prefs = await SharedPreferences.getInstance();
  List<String>? savedDevices = prefs.getStringList('devices');

  if (savedDevices != null) {
    allDevices = savedDevices.map((deviceInfoJson) {
      Map<String, dynamic> deviceInfo = jsonDecode(deviceInfoJson) as Map<String, dynamic>;
      return {
        'name': deviceInfo['name'] as String? ?? '',
        'macAddress': deviceInfo['macAddress'] as String? ?? '',
        'lastDetected': deviceInfo['lastDetected'] as String? ?? '',
        'latitude': deviceInfo['latitude'] as String? ?? '',
        'longitude': deviceInfo['longitude'] as String? ?? '',
      };
    }).toList();
    searchingDevices = savedDevices.map((deviceInfoJson) {
      Map<String, dynamic> deviceInfo = jsonDecode(deviceInfoJson) as Map<String, dynamic>;
      return {
        'name': deviceInfo['name'] as String? ?? '',
        'macAddress': deviceInfo['macAddress'] as String? ?? '',
        'lastDetected': deviceInfo['lastDetected'] as String? ?? '',
        'latitude': deviceInfo['latitude'] as String? ?? '',
        'longitude': deviceInfo['longitude'] as String? ?? '',
      };
    }).toList();
  }

  scanSubscription = flutterBlue.scan(timeout: Duration(seconds: timeout)).listen((scanResult) async {
    print('Device found: ${scanResult.device.name}');
    if (searchingDevices.any((device) => device["macAddress"] == scanResult.device.id.toString())) {
      searchingDevices.removeWhere((device) => device["macAddress"] == scanResult.device.id.toString());
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      int deviceIndex = allDevices.indexWhere((device) => device["macAddress"] == scanResult.device.id.toString());
      if (deviceIndex != -1) {
        allDevices[deviceIndex]['lastDetected'] = DateTime.now().toString();
        allDevices[deviceIndex]['latitude'] = position.latitude.toString();
        allDevices[deviceIndex]['longitude'] = position.longitude.toString();
        List<String> deviceInfoJsonList = allDevices.map((deviceInfo) {
          return jsonEncode(deviceInfo);
        }).toList();
        await prefs.setStringList('devices', deviceInfoJsonList);
      }
    }
    if (searchingDevices.isEmpty) {
      scanSubscription?.cancel();
      flutterBlue.stopScan();
      return;
    }
  }, onDone: () {
    if (searchingDevices.isNotEmpty) {
      print("見つからなかったデバイスがあるよ");
    }
  });
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
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja', 'JP'),
      ],
      initialRoute: '/',
      routes: {
        '/': (context) => const MyHomePage(title: '登録済みデバイス'),
        '/add': (context) => const AddDeviceScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}