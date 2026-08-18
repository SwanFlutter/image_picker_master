// example/lib/main.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:image_picker_master/image_picker_master.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Picker Master Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final ImagePickerMaster _picker = ImagePickerMaster.instance;
  List<PickedFile> _selectedFiles = [];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Image Picker Master Demo'),
        actions: [
          IconButton(
            icon: Icon(Icons.clear_all),
            onPressed: _clearFiles,
            tooltip: 'Clear all files',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildButtonGrid(),
            SizedBox(height: 20),
            if (_isLoading)
              Center(child: CircularProgressIndicator())
            else if (_selectedFiles.isNotEmpty)
              _buildFilesList(),
          ],
        ),
      ),
    );
  }

  Widget _buildButtonGrid() {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 3,
      children: [
        _buildPickButton(
          'Pick Single Image',
          Icons.image,
          () => _pickSingleImage(),
          Colors.green,
        ),
        _buildPickButton(
          'Pick Multiple Images',
          Icons.photo_library,
          () => _pickMultipleImages(),
          Colors.blue,
        ),
        _buildPickButton(
          'Pick Video',
          Icons.videocam,
          () => _pickVideo(),
          Colors.red,
        ),
        _buildPickButton(
          'Pick Multiple Videos',
          Icons.video_library,
          () => _pickMultipleVideos(),
          Colors.purple,
        ),
        _buildPickButton(
          'Pick Audio',
          Icons.audiotrack,
          () => _pickAudio(),
          Colors.orange,
        ),
        _buildPickButton(
          'Pick Documents',
          Icons.description,
          () => _pickDocuments(),
          Colors.teal,
        ),
        _buildPickButton(
          'Pick Any Files',
          Icons.folder,
          () => _pickAnyFiles(),
          Colors.grey,
        ),
        _buildPickButton(
          'Pick Custom Files',
          Icons.extension,
          () => _pickCustomFiles(),
          Colors.indigo,
        ),
        _buildPickButton(
          'Capture Photo',
          Icons.camera_alt,
          () => _capturePhoto(),
          Colors.deepOrange,
        ),
      ],
    );
  }

  Widget _buildPickButton(
    String title,
    IconData icon,
    VoidCallback onPressed,
    Color color,
  ) {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : onPressed,
      icon: Icon(icon, size: 16), // کاهش سایز آیکن
      label: Text(
        title,
        style: TextStyle(fontSize: 10), // کاهش سایز فونت متن
        textAlign: TextAlign.center,
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2), // کاهش پدینگ
        minimumSize: Size(double.infinity, 30), // کاهش ارتفاع دکمه
      ),
    );
  }

  Widget _buildFilesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selected Files (${_selectedFiles.length}):',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: _selectedFiles.length,
          itemBuilder: (context, index) {
            final file = _selectedFiles[index];
            return Card(
              margin: EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: _getFileIcon(file.mimeType),
                title: Text(
                  file.name,
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Size: ${_formatFileSize(file.size)}'),
                    if (file.mimeType != null) Text('Type: ${file.mimeType}'),
                    Text('Path: ${file.path}'),
                  ],
                ),
                trailing: IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeFile(index),
                ),
                isThreeLine: true,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _getFileIcon(String? mimeType) {
    if (mimeType == null) return Icon(Icons.insert_drive_file);
    if (mimeType.startsWith('image/')) {
      return Icon(Icons.image, color: Colors.green);
    } else if (mimeType.startsWith('video/')) {
      return Icon(Icons.videocam, color: Colors.red);
    } else if (mimeType.startsWith('audio/')) {
      return Icon(Icons.audiotrack, color: Colors.orange);
    } else if (mimeType.contains('pdf')) {
      return Icon(Icons.picture_as_pdf, color: Colors.red);
    } else if (mimeType.contains('word') || mimeType.contains('document')) {
      return Icon(Icons.description, color: Colors.blue);
    } else if (mimeType.contains('sheet') || mimeType.contains('excel')) {
      return Icon(Icons.table_chart, color: Colors.green);
    } else {
      return Icon(Icons.insert_drive_file, color: Colors.grey);
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  void _clearFiles() {
    setState(() {
      _selectedFiles.clear();
    });
    _picker.clearTemporaryFiles();
  }

  Future<void> _pickSingleImage() async {
    setState(() => _isLoading = true);
    try {
      final file = await _picker.pickImage(
        allowCompression: true,
        compressionQuality: 80,
      );
      if (file != null) {
        setState(() {
          _selectedFiles = [file];
        });
      }
    } catch (e) {
      _showError('Error picking image: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickMultipleImages() async {
    setState(() => _isLoading = true);
    try {
      final files = await _picker.pickImages(
        allowMultiple: true,
        allowCompression: true,
        compressionQuality: 70,
      );
      if (files != null && files.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(files);
        });
      }
    } catch (e) {
      _showError('Error picking images: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickVideo() async {
    setState(() => _isLoading = true);
    try {
      final file = await _picker.pickVideo();
      if (file != null) {
        setState(() {
          _selectedFiles.add(file);
        });
      }
    } catch (e) {
      _showError('Error picking video: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickMultipleVideos() async {
    setState(() => _isLoading = true);
    try {
      final files = await _picker.pickVideos(allowMultiple: true);
      if (files != null && files.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(files);
        });
      }
    } catch (e) {
      _showError('Error picking videos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAudio() async {
    setState(() => _isLoading = true);
    try {
      final files = await _picker.pickAudios(allowMultiple: true);
      if (files != null && files.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(files);
        });
      }
    } catch (e) {
      _showError('Error picking audio: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDocuments() async {
    setState(() => _isLoading = true);
    try {
      final files = await _picker.pickDocuments(
        allowMultiple: true,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
      );
      if (files != null && files.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(files);
        });
      }
    } catch (e) {
      _showError('Error picking documents: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAnyFiles() async {
    setState(() => _isLoading = true);
    try {
      final files = await _picker.pickFiles(
        type: FileType.all,
        allowMultiple: true,
      );
      if (files != null && files.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(files);
        });
      }
    } catch (e) {
      _showError('Error picking files: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickCustomFiles() async {
    setState(() => _isLoading = true);
    try {
      final files = await _picker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'rar', '7z', 'tar'],
        allowMultiple: true,
      );
      if (files != null && files.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(files);
        });
      }
    } catch (e) {
      _showError('Error picking custom files: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _capturePhoto() async {
    setState(() => _isLoading = true);

    try {
      final file = await _picker.capturePhoto(
        allowCompression: true,
        compressionQuality: 85,
        withData: true,
      );
      if (file != null) {
        setState(() {
          _selectedFiles.add(file);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Photo captured successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _showError('Camera capture was cancelled or failed');
      }
    } catch (e) {
      final userMessage = _getCameraErrorMessage(e.toString());
      _showError(userMessage);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getCameraErrorMessage(String error) {
    if (error.contains('NO_CAMERA_DEVICES_FOUND') ||
        error.contains('NO_CAMERA_FOUND')) {
      return 'No camera found on this device. Please connect a camera and try again.';
    } else if (error.contains('CAMERA_ACCESS_DENIED')) {
      return 'Camera access denied. Please enable camera permissions in your device settings.';
    } else if (error.contains('CAMERA_IN_USE_BY_ANOTHER_APP')) {
      return 'Camera is in use by another app. Please close other camera apps and try again.';
    } else if (error.contains('CAMERA_DEVICE_DISCONNECTED') ||
        error.contains('CAMERA_DEVICE_INVALIDATED')) {
      return 'Camera disconnected or unavailable. Please check the camera connection.';
    } else if (error.contains('MEDIA_FOUNDATION_ERROR')) {
      return 'Camera feature is not available. This device does not support camera capture.';
    } else if (error.contains('CAMERA_STREAMING_START_FAILED')) {
      return 'Failed to start camera stream. Please reconnect the camera and try again.';
    } else if (error.contains('FRAME_CAPTURE_FAILED') ||
        error.contains('CAMERA_NO_FRAME_AVAILABLE')) {
      return 'Photo capture failed. Please try again.';
    } else if (error.contains('CAMERA_CONFIGURATION_FAILED')) {
      return 'Camera configuration failed. The camera may not be compatible.';
    } else {
      return 'An unknown camera error occurred. Please try again.';
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
