import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'package:flutter/services.dart';

class BackgroundTaskManager {
  static const platform = MethodChannel('background_upload');

  static Future<void> startBackgroundTask() async {
    if (Platform.isIOS) {
      try {
        await platform.invokeMethod('startBackgroundTask');
      } catch (e) {
        print('Error starting iOS background task: $e');
      }
    } else {
      // Android - usar workmanager
      Workmanager().cancelAll();
      Workmanager().registerOneOffTask(
        "message-task",
        "messageTask",
        initialDelay: Duration(seconds: 30),
        inputData: <String, dynamic>{
          "message": "Enviando mensagem...",
        },
      );
    }
  }

  static Future<void> startBackgroundUpload(String url, String filePath) async {
    if (Platform.isIOS) {
      try {
        await platform.invokeMethod('startBackgroundUpload', {
          'url': url,
          'filePath': filePath,
        });
      } catch (e) {
        print('Error starting iOS background upload: $e');
      }
    } else {
      // Android - implementar upload via workmanager
      Workmanager().registerOneOffTask(
        "upload-task",
        "uploadTask",
        inputData: <String, dynamic>{
          "url": url,
          "filePath": filePath,
        },
      );
    }
  }
}

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("=== WORKMANAGER TASK INICIADA ===");
    print("Task executada: $task");
    print("Input data: $inputData");

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Notificação simples: "Enviando mensagem..."
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'message_channel',
      'Envio de Mensagens',
      channelDescription: 'Notificações de envio de mensagens',
      importance: Importance.high,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      'Enviando mensagem...',
      '',
      notificationDetails,
    );

    try {
      final response = await http.get(
        Uri.parse('https://jsonplaceholder.typicode.com/posts/1'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("Requisição bem-sucedida: ${data['title']}");
        print("Body: ${data['body']}");
        print("Mensagem enviada com sucesso");
      } else {
        print("Erro na requisição: ${response.statusCode}");
        print("Erro ao enviar mensagem - Falha na conexão");
      }
    } catch (e) {
      print("Erro ao fazer requisição: $e");
      print("Erro ao enviar mensagem - Problema de conexão");
    }

    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Request permissions for Android
  await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();

  // Request permissions for iOS
  await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
    alert: true,
    badge: true,
    sound: true,
  );

  // Initialize workmanager only on Android
  if (Platform.isAndroid) {
    Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true,
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
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
  String _status = "Workmanager não iniciado";

  void _startMessageTask() async {
    await BackgroundTaskManager.startBackgroundTask();
    setState(() {
      if (Platform.isIOS) {
        _status = "Background task agendada para iOS! (BGTaskScheduler)";
      } else {
        _status = "Task de mensagem iniciada no Android!";
      }
    });
  }

  void _startUploadTask() async {
    // Exemplo de upload de arquivo - você precisará de um arquivo real
    const testUrl = "https://httpbin.org/post";
    const testFilePath = "/path/to/test/file.txt"; // Substituir por caminho real

    await BackgroundTaskManager.startBackgroundUpload(testUrl, testFilePath);
    setState(() {
      if (Platform.isIOS) {
        _status = "Background upload iniciado no iOS! (URLSession)";
      } else {
        _status = "Upload task iniciada no Android!";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Workmanager Test App'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Background Tasks Test',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text(
              'Status: $_status',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _startMessageTask,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 50),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Background Task'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _startUploadTask,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 50),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Background Upload'),
            ),
            const SizedBox(height: 40),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Como funciona:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('• Android: Workmanager'),
                    Text('• iOS: BGTaskScheduler + URLSession'),
                    Text('• Background Task: Executa notificação'),
                    Text('• Background Upload: Para arquivos reais'),
                    Text('• Funciona mesmo com app fechado'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
