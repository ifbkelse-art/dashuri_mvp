import 'dart:async';
import 'dart:io';

import 'package:dashuri_core/dashuri_core.dart';

import '../../domain/entities/host_photo.dart';

/// Uploads photo bytes to a signed Supabase Storage URL with `dart:io`
/// [HttpClient] (the URL already carries its own short-lived token, so no
/// bearer token is sent). Never throws.
final class PhotoUploadDataSource {
  PhotoUploadDataSource({HttpClient Function()? httpClient})
    : _httpClient = httpClient ?? HttpClient.new;

  final HttpClient Function() _httpClient;

  Future<Result<void>> upload({
    required PhotoUploadTicket ticket,
    required PickedPhoto photo,
  }) async {
    final client = _httpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.putUrl(ticket.uploadUrl);
      request.headers
        ..contentType = ContentType.parse(photo.contentType)
        ..contentLength = photo.bytes.length;
      request.add(photo.bytes);
      final response = await request.close().timeout(
        const Duration(seconds: 60),
      );
      await response.drain<void>();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return const Success(null);
      }
      return Err(
        ServerFailure(
          code: 'photo_upload_failed',
          message: 'Upload returned HTTP ${response.statusCode}',
        ),
      );
    } on SocketException catch (e) {
      return Err(NetworkFailure(message: e.message));
    } on TimeoutException catch (e) {
      return Err(NetworkFailure(message: e.message));
    } on HttpException catch (e) {
      return Err(NetworkFailure(message: e.message));
    } on Object catch (e) {
      return Err(UnexpectedFailure(message: 'Photo upload failed: $e'));
    } finally {
      client.close(force: true);
    }
  }
}
