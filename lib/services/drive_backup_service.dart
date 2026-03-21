import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'database_service.dart';

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

class DriveBackupService {
  // Persistent instance — avoids re-creating on each call which can break the OAuth flow
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  /// Returns a signed-in [GoogleSignInAccount], trying silent sign-in first.
  Future<GoogleSignInAccount?> _getSignedInAccount() async {
    // Try silent sign-in first (uses cached credentials, avoids browser popup)
    try {
      final silentUser = await _googleSignIn.signInSilently();
      if (silentUser != null) return silentUser;
    } catch (_) {
      // Silent sign-in failed — fall through to interactive sign-in
    }

    // Interactive sign-in: shows the account picker + permission dialog
    try {
      return await _googleSignIn.signIn();
    } on PlatformException catch (e) {
      throw Exception('Google Sign-In failed: ${e.message ?? e.code}');
    }
  }

  Future<void> backupDatabaseToDrive(BuildContext? context, {bool silent = false}) async {
    try {
      final googleUser = await _getSignedInAccount();
      if (googleUser == null) return; // User cancelled

      final Map<String, String> authHeaders = await googleUser.authHeaders;
      final driveApi = drive.DriveApi(GoogleAuthClient(authHeaders));

      final dbPath = await DatabaseService.instance.getDatabasePath();
      final file = File(dbPath);

      final driveFile = drive.File();
      driveFile.name = 'crm_leads_backup.db';

      final media = drive.Media(file.openRead(), file.lengthSync());

      final fileList = await driveApi.files.list(
        q: "name = 'crm_leads_backup.db' and trashed = false",
        spaces: 'drive',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        final existingFileId = fileList.files!.first.id!;
        await driveApi.files.update(driveFile, existingFileId, uploadMedia: media);
      } else {
        await driveApi.files.create(driveFile, uploadMedia: media);
      }

      final ctx = context;
      if (!silent && ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Backup successful! Database synced to Google Drive.')),
        );
      }
    } catch (error) {
      final ctx = context;
      if (!silent && ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('Backup failed: $error'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> restoreDatabaseFromDrive(BuildContext? context) async {
    try {
      final googleUser = await _getSignedInAccount();
      if (googleUser == null) return; // User cancelled

      final Map<String, String> authHeaders = await googleUser.authHeaders;
      final driveApi = drive.DriveApi(GoogleAuthClient(authHeaders));

      final fileList = await driveApi.files.list(
        q: "name = 'crm_leads_backup.db' and trashed = false",
        spaces: 'drive',
      );

      if (fileList.files == null || fileList.files!.isEmpty) {
        throw Exception('No backup file found in Google Drive.');
      }

      final fileId = fileList.files!.first.id!;
      final drive.Media response = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final dbPath = await DatabaseService.instance.getDatabasePath();
      
      // Close the database to release the SQLite lock before overwriting
      await DatabaseService.instance.close();
      
      final localFile = File(dbPath);

      final IOSink sink = localFile.openWrite();
      await sink.addStream(response.stream);
      await sink.close();
      
      // Re-open/initialize the database so it's ready for immediate use
      await DatabaseService.instance.database;

      final ctx = context;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Restore successful! App will use the synced database.')),
        );
      }
    } catch (error) {
      final ctx = context;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('Restore failed: $error'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}
