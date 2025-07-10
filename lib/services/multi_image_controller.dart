import 'package:multi_image_picker_view/multi_image_picker_view.dart';
import 'package:image_picker/image_picker.dart';

// XFile → ImageFile 변환 함수
ImageFile convertXFileToImageFile(XFile xfile) {
  return ImageFile(
    xfile.path, // key (필수)
    name: xfile.name,
    extension: xfile.path.split('.').last,
    path: xfile.path,
    bytes: null, // 필요시 await xfile.readAsBytes()
  );
}

// image_picker 기반 여러 장 선택 후 ImageFile로 변환
Future<List<ImageFile>> pickImagesUsingImagePicker(int pickCount) async {
  final ImagePicker picker = ImagePicker();
  final List<XFile> images = await picker.pickMultiImage();
  return images.map((xfile) => convertXFileToImageFile(xfile)).toList();
}

// multi_image_picker_view 패키지 컨트롤러 예시
class MyMultiImageController {
  final MultiImagePickerController controller = MultiImagePickerController(
    maxImages: 100,
    picker: (int pickCount, Object? params) async {
      return await pickImagesUsingImagePicker(pickCount);
    },
  );
}

// image_picker만 사용하는 간단 컨트롤러
class MultiImageController {
  final ImagePicker _picker = ImagePicker();

  /// 여러 장의 이미지를 XFile 리스트로 반환
  Future<List<XFile>> pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    return images;
  }
}
