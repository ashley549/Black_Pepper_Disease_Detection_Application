/// One saved scan (PRD Section 8).
class ScanRecord {
  final int? id;
  final String imagePath;
  final String label;
  final double confidence;
  final DateTime timestamp;

  const ScanRecord({
    this.id,
    required this.imagePath,
    required this.label,
    required this.confidence,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'imagePath': imagePath,
        'label': label,
        'confidence': confidence,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  factory ScanRecord.fromMap(Map<String, dynamic> map) => ScanRecord(
        id: map['id'] as int?,
        imagePath: map['imagePath'] as String,
        label: map['label'] as String,
        confidence: (map['confidence'] as num).toDouble(),
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      );
}
