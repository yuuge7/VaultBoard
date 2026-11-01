import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';

class TestFileSelector extends FileSelectorPlatform {
  XFile? selected;
  String? savePath;

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async => selected;

  @override
  Future<FileSaveLocation?> getSaveLocation({
    List<XTypeGroup>? acceptedTypeGroups,
    SaveDialogOptions options = const SaveDialogOptions(),
  }) async => savePath == null ? null : FileSaveLocation(savePath!);
}
