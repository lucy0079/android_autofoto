import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../api/api_service.dart';
import '../services/image_classifier.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../services/multi_image_classifier.dart';
import '../services/multi_image_controller.dart';

Future<bool> requestGalleryPermission() async {
  final androidInfo = await DeviceInfoPlugin().androidInfo;
  int sdkInt = androidInfo.version.sdkInt;

  if (sdkInt >= 34) {
    var images = await Permission.photos.request();
    var videos = await Permission.videos.request();
    return images.isGranted && videos.isGranted;
  } else if (sdkInt >= 33) {
    var images = await Permission.photos.request();
    var videos = await Permission.videos.request();
    return images.isGranted && videos.isGranted;
  } else {
    var storage = await Permission.storage.request();
    return storage.isGranted;
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImageClassifier _classifier = ImageClassifier();
  final ImagePicker _picker = ImagePicker();
  final MultiImageController _multiImageController = MultiImageController();
  late final MultiImageClassifier _multiImageClassifier;

  String _statusMessage = '앱을 초기화 중입니다...';
  String? _currentModelName;
  bool _isModelReady = false;
  bool _isProcessing = false;

  List<File>? _selectedImages;
  List<List<Map<String, dynamic>>?> _classificationResults = [];

  @override
  void initState() {
    super.initState();
    _multiImageClassifier = MultiImageClassifier(_classifier, _multiImageController);
    _initialize();
  }

  /// 앱 시작 시 저장된 모델을 불러오는 초기화 함수
  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    String modelToLoad = prefs.getString('selected_model') ?? 'mobilenetv2';
    await _loadOrDownloadModel(modelToLoad);
  }

  /// 특정 모델을 로드하거나, 없으면 다운로드 후 로드하는 함수
  Future<void> _loadOrDownloadModel(String modelName) async {
    setState(() {
      _currentModelName = modelName;
      _isModelReady = false;
      _isProcessing = true;
      _statusMessage = '$modelName 모델을 준비 중입니다...';
      _selectedImages = null;
      _classificationResults = [];
    });

    final appDir = await getApplicationDocumentsDirectory();
    final modelFile = File('${appDir.path}/models/$modelName/model.tflite');

    if (!await modelFile.exists()) {
      setState(() => _statusMessage = '$modelName 모델을 다운로드 중입니다...');
      bool success = await ApiService.downloadAndUnzipModel(modelName);
      if (!success) {
        setState(() {
          _statusMessage = '모델 다운로드 실패';
          _isProcessing = false;
        });
        return;
      }
    }

    await _classifier.initializeClassifier(modelName);

    if (_classifier.isModelLoaded()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_model', modelName);
      setState(() {
        _isModelReady = true;
        _statusMessage = '준비 완료! 사진을 선택하세요.';
      });
    } else {
      setState(() => _statusMessage = '모델 로딩 실패');
    }
    setState(() => _isProcessing = false);
  }

  /// 모델 선택 다이얼로그를 보여주는 함수
  Future<void> _showModelSelectionDialog() async {
    List<String> models = await ApiService.getAvailableModels();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('모델 선택'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: models.length,
              itemBuilder: (context, index) {
                final modelName = models[index];
                return ListTile(
                  title: Text(modelName),
                  trailing: _currentModelName == modelName ? const Icon(Icons.check, color: Colors.blue) : null,
                  onTap: () {
                    Navigator.of(context).pop();
                    if (_currentModelName != modelName) {
                      _loadOrDownloadModel(modelName);
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
          ],
        );
      },
    );
  }

  /// 갤러리에서 여러 장의 사진을 선택하고 분류하는 함수
  Future<void> _pickAndClassifyImages() async {
    var status = await Permission.photos.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진 접근 권한이 필요합니다.')),
      );
      return;
    }

    final List<XFile>? pickedList = await _picker.pickMultiImage();
    if (pickedList == null || pickedList.isEmpty) {
      setState(() {
        _statusMessage = '이미지를 선택하지 않았습니다.';
        _isProcessing = false;
      });
      return;
    }

    setState(() {
      _statusMessage = '이미지를 분류 중입니다...';
      _selectedImages = pickedList.map((xfile) => File(xfile.path)).toList();
      _classificationResults = [];
      _isProcessing = true;
    });

    List<List<Map<String, dynamic>>?> results = [];
    for (final imageFile in _selectedImages!) {
      final result = await _classifier.classifyImage(imageFile);
      results.add(result);
    }

    setState(() {
      _classificationResults = results;
      _isProcessing = false;
      _statusMessage = results.isNotEmpty ? '분류 완료!' : '이미지를 선택하지 않았습니다.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AutoFoto${_currentModelName != null ? " ($_currentModelName)" : ""}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded),
            onPressed: _showModelSelectionDialog,
            tooltip: '모델 선택',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: _selectedImages != null && _selectedImages!.isNotEmpty
                    ? ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedImages!.length,
                        itemBuilder: (context, index) {
                          final imageFile = _selectedImages![index];
                          final result = (_classificationResults.length > index)
                              ? _classificationResults[index]
                              : null;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: Column(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: Image.file(
                                    imageFile,
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (result != null && result.isNotEmpty)
                                  Text(
                                    '${result[0]['label']} (${(result[0]['confidence'] * 100).toStringAsFixed(1)}%)',
                                    style: Theme.of(context).textTheme.bodyLarge,
                                  )
                                else
                                  const Text('분류 결과 없음'),
                              ],
                            ),
                          );
                        },
                      )
                    : const Center(child: Text('분류할 이미지를 선택하세요')),
              ),
              const SizedBox(height: 20),
              if (_isProcessing)
                Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 10),
                    Text(_statusMessage),
                  ],
                )
              else
                Text(_statusMessage),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('사진 여러 장 선택 및 분류'),
                onPressed: _isModelReady && !_isProcessing ? _pickAndClassifyImages : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
