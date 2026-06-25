// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:typed_data';

const _documentWindowName = 'sma_document_preview';

void prepareDocumentWindow() {
  html.window.open('about:blank', _documentWindowName);
}

Future<void> openDocumentUrl(String url) async {
  html.window.open(url, _documentWindowName);
}

Future<void> openDocumentBytes(
  List<int> bytes,
  String contentType,
  String fileName,
) async {
  final blob = html.Blob([Uint8List.fromList(bytes)], contentType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
}
