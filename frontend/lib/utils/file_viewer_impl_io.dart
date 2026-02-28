import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openFileImpl(BuildContext context, PlatformFile file) async {
  if (file.bytes == null) return;

  final ext = file.name.split('.').last.toLowerCase();
  String mimeType = 'application/octet-stream';
  if (ext == 'pdf') mimeType = 'application/pdf';

  // Try to open as a data URI first
  try {
    final dataUri = Uri.dataFromBytes(file.bytes!, mimeType: mimeType);
    if (await canLaunchUrl(dataUri)) {
      await launchUrl(dataUri, mode: LaunchMode.externalApplication);
      return;
    }
  } catch (_) {}

  // Fallback: write to temp file and attempt to open with external app
  try {
    final tempDir = Directory.systemTemp;
    final safeName = file.name.replaceAll(RegExp(r'[\\/:]'), '_');
    final tempFile = File('${tempDir.path}${Platform.pathSeparator}$safeName');
    await tempFile.writeAsBytes(file.bytes!);
    final fileUri = Uri.file(tempFile.path);
    if (await canLaunchUrl(fileUri)) {
      await launchUrl(fileUri, mode: LaunchMode.externalApplication);
      return;
    }
  } catch (_) {}

  // Last resort: show a dialog with a save option
  if (!context.mounted) return;
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Open file', style: GoogleFonts.outfit()),
      content: Text(
          'Could not open ${file.name} directly. You can save it to the device instead.',
          style: GoogleFonts.outfit()),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Close', style: GoogleFonts.outfit()),
        ),
      ],
    ),
  );
}
