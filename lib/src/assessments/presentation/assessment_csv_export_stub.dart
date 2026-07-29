import 'package:flutter/services.dart';

Future<bool> exportAssessmentCsv(String fileName, String contents) async {
  await Clipboard.setData(ClipboardData(text: contents));
  return false;
}
