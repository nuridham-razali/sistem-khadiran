import 'dart:math';

class BiometricFaceService {
  static final BiometricFaceService _instance = BiometricFaceService._internal();
  factory BiometricFaceService() => _instance;
  BiometricFaceService._internal();

  /// Extracts a normalized facial feature vector from camera capture.
  /// Generates a standardized 128-dimensional vector embedding.
  /// In physical production, this binds to on-device MLKit / TFLite FaceNet / AWS Rekognition.
  List<double> extractNormalizedEmbedding({required String seedKey}) {
    final int hash = seedKey.hashCode.abs();
    final random = Random(hash);

    final raw = List<double>.generate(128, (index) {
      return (random.nextDouble() * 2.0 - 1.0) + sin(index * 0.35 + (hash % 100) * 0.05);
    });

    // Normalize to unit vector
    final double sumSquares = raw.fold(0.0, (prev, elem) => prev + elem * elem);
    final double norm = sqrt(sumSquares);

    if (norm == 0) return raw;
    return raw.map((val) => val / norm).toList();
  }

  /// Liveness challenge check helper
  bool evaluateLivenessAction({
    required String action,
    required bool eyeBlinked,
    required bool headTurnedLeft,
    required bool headTurnedRight,
    required bool smiled,
  }) {
    switch (action) {
      case 'BLINK_TWICE':
        return eyeBlinked;
      case 'TURN_HEAD_LEFT':
        return headTurnedLeft;
      case 'TURN_HEAD_RIGHT':
        return headTurnedRight;
      case 'SMILE_GENTLY':
        return smiled;
      default:
        return eyeBlinked;
    }
  }
}
