Future<bool> downloadJsonFileImpl(String jsonContent, String filename) async {
  // On non-web platforms without direct file picker dialog, returns true indicating export string is ready.
  return true;
}
