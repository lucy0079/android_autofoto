// lib/api/model_downloader.dart

import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart'; // ZIP 처리를 위해 임포트

class ModelDownloader {
  // ✅ 서버 코드에 맞게 포트 번호를 9000으로 수정
  static const String _modelUrl = 'http://172.30.48.18:9000/download-model';
  static const String _modelFileName = 'image_classifier.tflite';

  // 최종적으로 저장될 모델 파일의 경로
  static Future<String> getModelPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$_modelFileName';
  }

  // 모델이 이미 저장되었는지 확인
  static Future<bool> isModelDownloaded() async {
    final path = await getModelPath();
    return File(path).exists();
  }

  // ✨ 서버에서 ZIP 파일을 받아 압축을 풀고 모델만 저장하는 함수 (수정됨)
  static Future<File?> downloadAndUnzipModel() async {
    try {
      print('모델 다운로드를 시작합니다: $_modelUrl');
      final response = await http.get(Uri.parse(_modelUrl));

      if (response.statusCode == 200) {
        // 1. 서버로부터 받은 ZIP 데이터
        final zipBytes = response.bodyBytes;
        final archive = ZipDecoder().decodeBytes(zipBytes);

        // 2. ZIP 압축 내용 중에서 .tflite 파일을 찾기
        ArchiveFile? modelFile;
        for (final file in archive) {
          if (file.isFile && file.name.endsWith('.tflite')) {
            modelFile = file;
            break;
          }
        }

        if (modelFile != null) {
          // 3. 찾은 모델 파일의 압축을 풀어 기기에 저장
          final modelPath = await getModelPath();
          final file = File(modelPath);
          await file.writeAsBytes(modelFile.content as List<int>);
          print('모델 다운로드 및 압축 해제 완료: $modelPath');
          return file;
        } else {
          print('오류: 다운로드한 ZIP 파일 안에 .tflite 파일이 없습니다.');
          return null;
        }
      } else {
        print('모델 다운로드 실패: 서버 응답 코드 ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('모델 다운로드 중 오류 발생: $e');
      return null;
    }
  }
}