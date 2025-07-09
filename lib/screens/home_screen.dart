import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../api/model_downloader.dart';
import '../services/image_classifier.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImageClassifier _classifier = ImageClassifier();
  final ImagePicker _picker = ImagePicker();

  String _statusMessage = '앱이 준비되었습니다.';
  String? _classificationResult;
  File? _selectedImage;
  bool _isModelReady = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final isDownloaded = await ModelDownloader.isModelDownloaded();
    if (isDownloaded) {
      await _loadModel();
    } else {
      setState(() {
        _statusMessage = '분류를 위해 모델을 다운로드하세요.';
      });
    }
  }

  Future<void> _loadModel() async {
    setState(() => _statusMessage = '모델을 로딩 중입니다...');
    final modelPath = await ModelDownloader.getModelPath();
    // TODO: 실제 라벨 파일 경로를 지정해야 합니다.
    await _classifier.loadModel(modelPath: modelPath, labelPath: 'assets/labels.txt');
    setState(() {
      _isModelReady = true;
      _statusMessage = '모델 준비 완료! 사진을 선택하세요.';
    });
  }

  // Future<void> _downloadModel() async {
  //   setState(() => _statusMessage = '모델을 다운로드 중입니다...');
  //   final file = await ModelDownloader.downloadModel();
  //   if (file != null) {
  //     await _loadModel();
  //   } else {
  //     setState(() => _statusMessage = '모델 다운로드에 실패했습니다.');
  //   }
  // }

    Future<void> downloadAndUnzipModel() async {
    setState(() => _statusMessage = '모델을 다운로드 중입니다...');
    final file = await ModelDownloader.downloadAndUnzipModel();
    if (file != null) {
      await _loadModel();
    } else {
      setState(() => _statusMessage = '모델 다운로드에 실패했습니다.');
    }
  }

  Future<void> _pickAndClassifyImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() {
      _selectedImage = File(image.path);
      _statusMessage = '이미지를 분류 중입니다...';
      _classificationResult = null;
    });

    final result = await _classifier.classifyImage(_selectedImage!);
    setState(() {
      _classificationResult = result;
      _statusMessage = '분류 완료!';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AutoFoto 데모')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (_selectedImage != null)
              Container(
                height: 300,
                width: 300,
                margin: const EdgeInsets.only(bottom: 20),
                child: Image.file(_selectedImage!, fit: BoxFit.cover),
              ),
            Text(_statusMessage, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            if (_classificationResult != null)
              Text(
                '분류 결과: $_classificationResult',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.blue),
              ),
            const SizedBox(height: 30),
            if (!_isModelReady)
              ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('1. 모델 다운로드'),
                onPressed:downloadAndUnzipModel,
              ),
            if (_isModelReady)
              ElevatedButton.icon(
                icon: const Icon(Icons.photo_library),
                label: const Text('2. 사진 선택 및 분류'),
                onPressed: _pickAndClassifyImage,
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _classifier.dispose();
    super.dispose();
  }
}