import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SIH OCR MVP',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const OCRHomePage(),
    );
  }
}

class OCRHomePage extends StatefulWidget {
  const OCRHomePage({super.key});

  @override
  State<OCRHomePage> createState() => _OCRHomePageState();
}

class _OCRHomePageState extends State<OCRHomePage> {
  // --- STATE VARIABLES ---
  File? _selectedImage;
  bool _isLoading = false;
  String _resultText = "No results yet.";
  
  // ⚠️ CRITICAL: REPLACE THIS WITH YOUR LAPTOP'S IP ADDRESS
  // Example: "http://192.168.1.5:8000/predict"
  final String _serverUrl = "http://192.168.0.193/predict"; 

  final ImagePicker _picker = ImagePicker();

  // --- LOGIC: PICK IMAGE ---
  Future<void> _pickImage() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    
    if (photo != null) {
      setState(() {
        _selectedImage = File(photo.path);
        _resultText = ""; // Clear previous results
      });
      
      // Automatically start processing after clicking
      _uploadImage(File(photo.path));
    }
  }

  // --- LOGIC: SEND TO PYTHON SERVER ---
  Future<void> _uploadImage(File imageFile) async {
    setState(() {
      _isLoading = true; // Show Loading Screen
    });

    try {
      // 1. Convert Image to Base64
      List<int> imageBytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      // 2. Prepare JSON Body (Matches your Python "ImageRequest" class)
      // Note: We add the header data:image... just in case, though your python cleans it
      String fullBase64 = "data:image/jpeg;base64,$base64Image";

      // 3. Send POST Request
      final response = await http.post(
        Uri.parse(_serverUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "image_base64": fullBase64
        }),
      );

      // 4. Handle Response
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        // Assuming your Python returns {"data": [{"text": "...", "box": ...}]}
        var items = data["data"] as List;
        
        // Combine all detected text into one string
        String combinedText = items.map((e) => e["text"]).join("\n");
        
        setState(() {
          _resultText = combinedText.isEmpty ? "No text found." : combinedText;
        });
      } else {
        setState(() {
          _resultText = "Server Error: ${response.statusCode}";
        });
      }

    } catch (e) {
      setState(() {
        _resultText = "Connection Failed: $e";
      });
    } finally {
      setState(() {
        _isLoading = false; // Hide Loading Screen
      });
    }
  }

  // --- UI BUILDER ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("KalkiForce OCR")),
      body: Stack(
        children: [
          // MAIN CONTENT
          Column(
            children: [
              // 1. Image Preview Area
              Expanded(
                flex: 2,
                child: Container(
                  width: double.infinity,
                  color: Colors.grey[200],
                  child: _selectedImage == null
                      ? const Center(child: Text("Tap Camera to Scan"))
                      : Image.file(_selectedImage!, fit: BoxFit.contain),
                ),
              ),
              
              // 2. Result Area
              Expanded(
                flex: 1,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  color: Colors.white,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("DETECTED TEXT:", 
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 10),
                        Text(_resultText, 
                          style: const TextStyle(fontSize: 18, color: Colors.black87)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // FLOATING ACTION BUTTON (CAMERA)
          Positioned(
            bottom: 30,
            right: 30,
            child: FloatingActionButton(
              onPressed: _isLoading ? null : _pickImage, // Disable if loading
              child: const Icon(Icons.camera_alt),
            ),
          ),

          // LOADING OVERLAY (The "Pop up" you asked for)
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 20),
                    Text(
                      "Processing with AI...",
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    )
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}