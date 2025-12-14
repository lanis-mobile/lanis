import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/sph/sph.dart';

typedef ImageBuilder =
    Widget Function(BuildContext context, ImageProvider imageProvider);

enum ImageType { png, jpg }

class CachedNetworkImage extends StatefulWidget {
  final Widget placeholder;
  final Uri imageUrl;
  final ImageBuilder builder;
  final ImageType imageType;

  const CachedNetworkImage({
    super.key,
    required this.placeholder,
    required this.imageUrl,
    required this.builder,
    this.imageType = ImageType.jpg,
  });

  @override
  State<CachedNetworkImage> createState() => _CachedNetworkImageState();
}

class _CachedNetworkImageState extends State<CachedNetworkImage> {
  bool loading = true;
  late ImageProvider imageProvider;

  Future<void> loadData() async {
    String? imagePath = await sph?.storage.downloadFile(
      widget.imageUrl.toString(),
      'image.${widget.imageType.toString().split('.').last}',
      followRedirects: true,
    );
    if (imagePath == null) {
      setState(() {
        loading = true;
      });
      return;
    }
    File imageFile = File(imagePath);
    imageProvider = FileImage(imageFile);
    setState(() {
      loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.imageUrl.scheme != 'data') {
      loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl.scheme == 'data') {
      try {
        String uriString = widget.imageUrl.toString();
        int commaIndex = uriString.indexOf(',');
        if (commaIndex != -1) {
          String base64Data = uriString
              .substring(commaIndex + 1)
              .replaceAll(RegExp(r'\s+'), '');
          Uint8List bytes = base64Decode(base64Data);

          return widget.builder(context, MemoryImage(bytes));
        }
      } catch (e) {
        return widget.placeholder;
      }
    }

    if (loading) {
      return widget.placeholder;
    } else {
      return widget.builder(context, imageProvider);
    }
  }
}
