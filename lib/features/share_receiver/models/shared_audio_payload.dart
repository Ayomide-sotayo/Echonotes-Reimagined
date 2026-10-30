import 'dart:convert';
import 'dart:io';

/// Encapsulates incoming shared audio metadata and validation.
class SharedAudioPayload {
  final String path;
  final String name;
  final String? mimeType;
  final int size;
  final DateTime receivedAt;
  final String id;

  SharedAudioPayload({
    required this.path,
    required this.name,
    this.mimeType,
    required this.size,
    DateTime? receivedAt,
    String? id,
  })  : receivedAt = receivedAt ?? DateTime.now(),
        id = id ?? '${name}_$size';

  bool get exists => File(path).existsSync();

  /// Supported formats for transcription and storage
  static const Set<String> supportedExtensions = {
    'mp3',
    'm4a',
    'wav',
    'aac',
    'ogg',
    'opus',
    'flac',
    'amr',
    'wma',
  };

  /// Extract clean extension from filename or mime type
  String get cleanExtension {
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex != -1 && dotIndex < name.length - 1) {
      return name.substring(dotIndex + 1).toLowerCase();
    }
    final pathDotIndex = path.lastIndexOf('.');
    if (pathDotIndex != -1 && pathDotIndex < path.length - 1) {
      return path.substring(pathDotIndex + 1).toLowerCase();
    }
    final mime = (mimeType ?? '').toLowerCase();
    if (mime.contains('opus')) return 'opus';
    if (mime.contains('ogg')) return 'ogg';
    if (mime.contains('mpeg') || mime.contains('mp3')) return 'mp3';
    if (mime.contains('wav')) return 'wav';
    if (mime.contains('aac')) return 'aac';
    if (mime.contains('m4a')) return 'm4a';
    if (mime.contains('flac')) return 'flac';
    return 'audio';
  }

  /// Format badge string (e.g. "OPUS AUDIO", "WHATSAPP VOICE NOTE", "MP3 AUDIO")
  String get formatBadge {
    final ext = cleanExtension.toUpperCase();
    final isVoiceNote = name.toLowerCase().contains('ptt') ||
        name.toLowerCase().contains('voice') ||
        ext == 'OPUS';
    if (isVoiceNote) {
      return '$ext • VOICE NOTE';
    }
    return '$ext AUDIO';
  }

  /// Whether the format is supported by AssemblyAI and the audio pipeline
  bool get isSupportedFormat {
    final ext = cleanExtension;
    if (supportedExtensions.contains(ext)) return true;
    final mime = (mimeType ?? '').toLowerCase();
    return mime.startsWith('audio/') ||
        mime == 'application/ogg' ||
        mime == 'application/opus';
  }

  /// Check whether the file is valid and readable
  bool get isValid {
    try {
      if (!exists) return false;
      final file = File(path);
      final len = file.lengthSync();
      // Must be between 1 byte and 100MB
      return len > 0 && len <= 100 * 1024 * 1024 && isSupportedFormat;
    } catch (_) {
      return false;
    }
  }

  /// Human-readable file size (e.g. "2.4 MB")
  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }
    return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'name': name,
      'mimeType': mimeType,
      'size': size,
      'receivedAt': receivedAt.millisecondsSinceEpoch,
      'id': id,
    };
  }

  factory SharedAudioPayload.fromMap(Map<String, dynamic> map) {
    return SharedAudioPayload(
      path: map['path'] as String? ?? '',
      name: map['name'] as String? ?? 'Shared Audio',
      mimeType: map['mimeType'] as String?,
      size: (map['size'] is int)
          ? map['size'] as int
          : int.tryParse(map['size']?.toString() ?? '0') ?? 0,
      receivedAt: map['receivedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['receivedAt'] as int)
          : null,
      id: map['id'] as String?,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory SharedAudioPayload.fromJson(String source) =>
      SharedAudioPayload.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
