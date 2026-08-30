import 'campaign_file_downloader_stub.dart'
    if (dart.library.html) 'campaign_file_downloader_web.dart'
    if (dart.library.js_interop) 'campaign_file_downloader_web.dart';

abstract class CampaignFileDownloader {
  /// Triggers a browser download on web platforms or platform-specific file handling.
  static Future<bool> downloadJsonFile(String jsonContent, String filename) async {
    return downloadJsonFileImpl(jsonContent, filename);
  }
}
