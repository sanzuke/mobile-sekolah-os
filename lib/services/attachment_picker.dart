import 'package:file_selector/file_selector.dart';

class PickedAttachment {
  const PickedAttachment({required this.name, required this.bytes});

  final String name;
  final List<int> bytes;

  int get size => bytes.length;
}

/// Chooses a leave attachment (photo of a doctor's note, a PDF). Behind an
/// interface so screens can be tested without the platform dialog.
abstract class AttachmentPicker {
  Future<PickedAttachment?> pick();
}

/// The system document picker (photos, Files, Drive). Android filters by MIME
/// type; the extensions are for desktop.
class FileAttachmentPicker implements AttachmentPicker {
  const FileAttachmentPicker();

  static const _types = XTypeGroup(
    label: 'Foto atau PDF',
    extensions: ['jpg', 'jpeg', 'png', 'pdf'],
    mimeTypes: ['image/jpeg', 'image/png', 'application/pdf'],
    uniformTypeIdentifiers: ['public.jpeg', 'public.png', 'com.adobe.pdf'],
  );

  @override
  Future<PickedAttachment?> pick() async {
    final file = await openFile(acceptedTypeGroups: const [_types]);
    if (file == null) return null;
    return PickedAttachment(name: file.name, bytes: await file.readAsBytes());
  }
}

/// Picks an RPP document (PDF or Word). Same interface, other file types.
class RppFilePicker implements AttachmentPicker {
  const RppFilePicker();

  static const _types = XTypeGroup(
    label: 'PDF atau Word',
    extensions: ['pdf', 'doc', 'docx'],
    mimeTypes: [
      'application/pdf',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    ],
    uniformTypeIdentifiers: [
      'com.adobe.pdf',
      'com.microsoft.word.doc',
      'org.openxmlformats.wordprocessingml.document',
    ],
  );

  @override
  Future<PickedAttachment?> pick() async {
    final file = await openFile(acceptedTypeGroups: const [_types]);
    if (file == null) return null;
    return PickedAttachment(name: file.name, bytes: await file.readAsBytes());
  }
}
