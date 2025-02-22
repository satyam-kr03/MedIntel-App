import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => ChatProvider(),
      child: MedIntelApp(),
    ),
  );
}

class MedIntelApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MedIntel',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text("MedIntel 🩺")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: chatProvider.messages.length,
              itemBuilder: (context, index) {
                final message = chatProvider.messages[index];
                return ListTile(
                  title: Text(message["content"]!),
                  subtitle: Text(message["role"]!),
                  tileColor: message["role"] == "user" ? Colors.blue[100] : Colors.green[100],
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(hintText: "What is up?"),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () {
                    String prompt = _controller.text.trim();
                    if (prompt.isNotEmpty) {
                      chatProvider.sendMessage(prompt);
                      _controller.clear();
                    }
                  },
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: chatProvider.uploadFile,
            child: Text("Upload File"),
          ),
        ],
      ),
    );
  }
}

class ChatProvider extends ChangeNotifier {
  final String baseUrl = "https://cool-starfish-suitable.ngrok-free.app";
  String clientId = Uuid().v4();
  List<Map<String, String>> messages = [];

  void sendMessage(String prompt) async {
    messages.add({"role": "user", "content": prompt});
    notifyListeners();

    String response = await _fetchResponse(prompt);
    messages.add({"role": "assistant", "content": response});
    notifyListeners();
  }

  Future<String> _fetchResponse(String prompt) async {
    final url = Uri.parse("$baseUrl/generate/$clientId?inp=$prompt");
    final response = await http.post(url);

    if (response.statusCode == 200) {
      return response.body;
    } else {
      return "Error generating response";
    }
  }

  Future<void> uploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      String endpoint = file.path.endsWith('.pdf') ? "upload_pdf" : "upload_img";

      var request = http.MultipartRequest(
        'POST',
        Uri.parse("$baseUrl/$endpoint/$clientId"),
      );
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      var response = await request.send();
      if (response.statusCode == 200) {
        messages.add({"role": "system", "content": "File uploaded successfully"});
      } else {
        messages.add({"role": "system", "content": "Error uploading file"});
      }
      notifyListeners();
    }
  }
}
