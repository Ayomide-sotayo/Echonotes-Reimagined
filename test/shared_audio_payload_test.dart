import 'package:flutter_test/flutter_test.dart';
import 'package:echonotes/features/share_receiver/models/shared_audio_payload.dart';
import 'package:echonotes/features/share_receiver/services/share_receiver_service.dart';

void main() {
  group('SharedAudioPayload Unit Tests', () {
    test('Correctly identifies WhatsApp voice notes and Opus/OGG audio', () {
      final payload = SharedAudioPayload(
        path: '/cache/shared_audio/WhatsApp_Audio_2026.opus',
        name: 'WhatsApp_Audio_2026.opus',
        mimeType: 'audio/ogg; codecs=opus',
        size: 512000,
        receivedAt: DateTime(2026, 10, 28, 12, 0),
      );

      expect(payload.formatBadge, equals('OPUS • VOICE NOTE'));
      expect(payload.isSupportedFormat, isTrue);
      expect(payload.formattedSize, equals('500.0 KB'));
      expect(payload.id, equals('WhatsApp_Audio_2026.opus_512000'));
    });

    test('Correctly formats file sizes in bytes, KB and MB', () {
      final small = SharedAudioPayload(
        path: '/tmp/test.wav',
        name: 'test.wav',
        mimeType: 'audio/wav',
        size: 800,
        receivedAt: DateTime.now(),
      );
      expect(small.formattedSize, equals('800 B'));

      final large = SharedAudioPayload(
        path: '/tmp/large_lecture.mp3',
        name: 'large_lecture.mp3',
        mimeType: 'audio/mpeg',
        size: 15728640, // 15 MB
        receivedAt: DateTime.now(),
      );
      expect(large.formattedSize, equals('15.00 MB'));
      expect(large.formatBadge, equals('MP3 AUDIO'));
    });

    test('Flags unsupported or empty audio correctly', () {
      final empty = SharedAudioPayload(
        path: '/tmp/empty.mp3',
        name: 'empty.mp3',
        mimeType: 'audio/mpeg',
        size: 0,
        receivedAt: DateTime.now(),
      );
      expect(empty.isValid, isFalse);

      final unsupported = SharedAudioPayload(
        path: '/tmp/document.pdf',
        name: 'document.pdf',
        mimeType: 'application/pdf',
        size: 1024,
        receivedAt: DateTime.now(),
      );
      expect(unsupported.isSupportedFormat, isFalse);
    });

    test('Serializes to and from Map/JSON cleanly', () {
      final original = SharedAudioPayload(
        path: '/cache/sample.m4a',
        name: 'sample.m4a',
        mimeType: 'audio/mp4',
        size: 204800,
        receivedAt: DateTime(2026, 10, 28, 10, 30),
      );

      final jsonStr = original.toJson();
      final decoded = SharedAudioPayload.fromJson(jsonStr);

      expect(decoded.path, equals(original.path));
      expect(decoded.name, equals(original.name));
      expect(decoded.mimeType, equals(original.mimeType));
      expect(decoded.size, equals(original.size));
      expect(decoded.receivedAt.toIso8601String(), equals(original.receivedAt.toIso8601String()));
    });
    test('ShareReceiverService tracks isImportScreenActive and pendingAudioNotifier', () {
      final service = ShareReceiverService();
      expect(service.isImportScreenActive, isFalse);
      expect(service.hasPendingImport, isFalse);

      final payload = SharedAudioPayload(
        path: '/tmp/test.m4a',
        name: 'test.m4a',
        mimeType: 'audio/mp4',
        size: 1024,
        receivedAt: DateTime.now(),
      );

      service.pendingAudioNotifier.value = payload;
      expect(service.hasPendingImport, isTrue);
      expect(service.currentPending?.name, equals('test.m4a'));

      service.isImportScreenActive = true;
      expect(service.isImportScreenActive, isTrue);

      service.isImportScreenActive = false;
      service.pendingAudioNotifier.value = null;
      expect(service.hasPendingImport, isFalse);
    });
  });
}
