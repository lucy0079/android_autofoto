import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class ImageClassifier {
  Interpreter? _interpreter;
  List<String>? _labels;

  bool isModelLoaded() => _interpreter != null;

  /// 모델 이름(modelName)을 받아 해당 모델과 라벨을 로드하는 함수
  Future<void> initializeClassifier(String modelName) async {
    try {
      // 1. 앱 내부 문서 폴더 경로를 찾습니다.
      final appDir = await getApplicationDocumentsDirectory();
      
      // 2. 모델 이름으로 모델과 라벨 파일의 전체 경로를 만듭니다.
      //    (zip 파일 안의 파일 이름이 model.tflite, labels.txt 라고 가정)
      final modelPath = '${appDir.path}/models/$modelName/model.tflite';
      final labelPath = '${appDir.path}/models/$modelName/labels.txt';

      // 3. 해당 경로의 파일들로 모델과 라벨을 로드합니다.
      _interpreter = await Interpreter.fromFile(File(modelPath));
      final labelData = await File(labelPath).readAsString();
      _labels = labelData.split('\n').where((label) => label.isNotEmpty).toList();
      
      print('$modelName 모델과 라벨 로딩 성공');
    } catch (e) {
      print('$modelName 모델 로딩 실패: $e');
      _interpreter = null;
      _labels = null;
    }
  }

  /// 이미지를 분류하고 상위 3개의 결과를 반환하는 함수
  Future<List<Map<String, dynamic>>?> classifyImage(File imageFile) async {
    if (!isModelLoaded()) {
      print('모델이 로드되지 않았습니다.');
      return null;
    }

    final image = img.decodeImage(imageFile.readAsBytesSync())!;
    final resizedImage = img.copyResize(image, width: 224, height: 224);
    
    // 모델의 입력 형식에 맞게 이미지 데이터를 변환
    var input = List.generate(1, (i) => List.generate(224, (j) => List.generate(224, (k) => List.generate(3, (l) => 0.0))));
    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        var pixel = resizedImage.getPixel(x, y);
        input[0][y][x][0] = pixel.r / 255.0;
        input[0][y][x][1] = pixel.g / 255.0;
        input[0][y][x][2] = pixel.b / 255.0;
      }
    }

    // 모델의 출력 크기(_labels.length)에 맞게 결과 담을 공간 준비
    var output = List.filled(1 * _labels!.length, 0.0).reshape([1, _labels!.length]);
    _interpreter!.run(input, output);

    final result = output[0] as List<double>;

    final List<Map<String, dynamic>> allPredictions = [];
    for (int i = 0; i < result.length; i++) {
      allPredictions.add({
        'label': _labels![i],
        'confidence': result[i],
      });
    }

    allPredictions.sort((a, b) => (b['confidence'] as double).compareTo(a['confidence'] as double));
    return allPredictions.take(3).toList();
  }

  void dispose() {
    _interpreter?.close();
  }
}