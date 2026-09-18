typedef FinanceCsvDownloader =
    Future<bool> Function(String fileName, String contents);

Future<bool> exportFinanceCsv(String fileName, String contents) async => false;
