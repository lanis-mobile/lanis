import 'package:flutter/material.dart';

//widget.file.fileExtension
IconData getIconByFileExtension(String fileExtension) {
  switch (fileExtension) {
    case 'pdf':
      return Icons.picture_as_pdf;
    case 'doc':
    case 'docx':
      return Icons.description;
    case 'xls':
    case 'xlsx':
      return Icons.table_chart;
    case 'ppt':
    case 'pptx':
      return Icons.slideshow;
    case 'txt':
      return Icons.text_fields;
    case 'zip':
    case 'rar':
      return Icons.folder_zip;
    case 'jpg':
    case 'jpeg':
    case 'png':
    case 'gif':
      return Icons.image;
    case 'mp3':
    case 'wav':
    case 'flac':
      return Icons.audio_file;
    case 'mp4':
    case 'avi':
    case 'mkv':
      return Icons.movie;
    default:
      return Icons.insert_drive_file;
  }
}
