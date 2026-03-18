import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'database_service.dart';

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class DriveBackupService {
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  Future<void> backupDatabaseToDrive(BuildContext context) async {
    try {
      final scopes = [drive.DriveApi.driveFileScope];
      
      // Ensure initialized (usually called once at app start, but safe here)
      // await _googleSignIn.initialize(); 

      final account = await _googleSignIn.authenticate(scopeHint: scopes);
      
      final authHeaders = await account.authorizationClient.authorizationHeaders(scopes);
      if (authHeaders == null) {
        throw Exception('Failed to get authorization headers.');
      }

      final authenticateClient = GoogleAuthClient(authHeaders);
      final driveApi = drive.DriveApi(authenticateClient);

      final dbPath = await DatabaseService.instance.getDatabasePath();
      final file = File(dbPath);

      if (!await file.exists()) {
        throw Exception('Database file not found.');
      }

      final driveFile = drive.File();
      driveFile.name = 'crm_leads_backup.db';
      
      final media = drive.Media(file.openRead(), file.lengthSync());
      
      await driveApi.files.create(driveFile, uploadMedia: media);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup successful! Database uploaded to Google Drive.')),
        );
      }
    } catch (error) {
       if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $error')),
        );
      }
    }
  }
}
