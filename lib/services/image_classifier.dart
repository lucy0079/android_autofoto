import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart';

class ImageClassifier {
  Interpreter? _interpreter;
  List<String>? _labels;

  // 모델과 라벨 파일을 로드하는 함수
  Future<void> loadModel({required String modelPath, required String labelPath}) async {
    try {
      _interpreter = await Interpreter.fromFile(File(modelPath));
      _labels = await _loadLabels(labelPath);
      print('TFLite 모델과 라벨 로딩 성공');
    } catch (e) {
      print('모델 로딩 실패: $e');
    }
  }

  // 라벨 파일을 읽어 리스트로 반환 (수정된 부분)
  Future<List<String>> _loadLabels(String labelPath) async {
    // assets 폴더에서 실제 라벨 파일을 읽어옵니다.
    final labelData = await rootBundle.loadString(labelPath);
    // 줄바꿈을 기준으로 라벨을 분리하여 리스트로 만듭니다.
    return labelData.split('\n');
  }

  // 이미지를 분류하고 가장 확률이 높은 라벨을 반환하는 함수
  Future<String?> classifyImage(File imageFile) async {
    if (_interpreter == null || _labels == null) {
      print('모델이 로드되지 않았습니다.');
      return "모델 로딩 필요";
    }

    // 1. 이미지를 모델 입력 형식에 맞게 변환
    final image = img.decodeImage(imageFile.readAsBytesSync())!;
    // TODO: 실제 모델의 입력 사이즈에 맞게 조절해야 합니다. (예: 224x224)
    final resizedImage = img.copyResize(image, width: 224, height: 224);
    final input = _imageToByteList(resizedImage);

    // 2. 모델 추론 실행
    // TODO: 실제 모델의 출력 형태에 맞게 조절해야 합니다.
    var output = List.filled(1 * _labels!.length, 0.0).reshape([1, _labels!.length]);
    _interpreter!.run(input, output);

    // 3. 결과 해석
    final result = output[0] as List<double>;
    int maxIndex = result.indexOf(result.reduce((a, b) => a > b ? a : b));

    return _labels![maxIndex];
  }

  // 이미지를 Float32List로 변환 (정규화 포함)
  List<List<List<List<double>>>> _imageToByteList(img.Image image) {
    var convertedBytes = List.generate(
      224, (y) => List.generate(
        224, (x) {
          var pixel = image.getPixel(x, y);
          return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
        },
      ),
    );
    return [convertedBytes]; // 모델 입력 형태 [1, 224, 224, 3]
  }

  void dispose() {
    _interpreter?.close();
  }
}