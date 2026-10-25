import '../../../application/map/map_image_intake_port.dart';

class MapImageIntakeAdapter implements MapImageIntakePort {
  const MapImageIntakeAdapter();

  @override
  Future<MapImageSource?> pick() async {
    throw const MapIntakeUnavailableException('Maps can only be created in the web app');
  }

  @override
  Future<NormalizedMapImage> normalize(
    MapImageSource source, {
    required int targetWidth,
    required int targetHeight,
  }) async {
    throw const MapIntakeUnavailableException('Maps can only be created in the web app');
  }
}
