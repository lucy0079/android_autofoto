import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'image_classifier.dart';
import 'multi_image_controller.dart';

class MultiImageClassifier {
  final ImageClassifier classifier;
  final MultiImageController controller;

  MultiImageClassifier(this.classifier, this.controller);

  /// 여러 장의 이미지를 선택하고, 각 이미지를 분류한 결과 리스트를 반환합니다.
  Future<List<List<Map<String, dynamic>>?>> pickAndClassifyImages() async {
    final List<XFile> images = await controller.pickImages();
    if (images.isEmpty) return [];

    List<List<Map<String, dynamic>>?> results = [];
    for (final image in images) {
      final file = File(image.path);
      final result = await classifier.classifyImage(file);
      results.add(result);
    }
    return results;
  }
}
