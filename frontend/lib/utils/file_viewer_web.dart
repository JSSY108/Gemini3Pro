import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'file_viewer_impl_io.dart' if (dart.library.html) 'file_viewer_impl_web.dart' as impl;

Future<void> openFileImpl(BuildContext context, PlatformFile file) => impl.openFileImpl(context, file);
