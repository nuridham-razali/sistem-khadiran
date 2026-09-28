class VerificationChallenge {
  final String challengeId;
  final String nonce;
  final String livenessAction; // 'BLINK_TWICE', 'TURN_HEAD_RIGHT', 'TURN_HEAD_LEFT', 'SMILE_GENTLY'
  final String instruction;
  final int expiresInSeconds;
  final String expiresAt;

  VerificationChallenge({
    required this.challengeId,
    required this.nonce,
    required this.livenessAction,
    required this.instruction,
    required this.expiresInSeconds,
    required this.expiresAt,
  });

  factory VerificationChallenge.fromJson(Map<String, dynamic> json) {
    return VerificationChallenge(
      challengeId: json['challengeId'] ?? '',
      nonce: json['nonce'] ?? '',
      livenessAction: json['livenessAction'] ?? 'BLINK_TWICE',
      instruction: json['instruction'] ?? 'Look directly at camera and blink twice',
      expiresInSeconds: json['expiresInSeconds'] ?? 120,
      expiresAt: json['expiresAt'] ?? '',
    );
  }
}
