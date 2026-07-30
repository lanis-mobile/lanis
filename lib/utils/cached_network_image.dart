import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';

typedef ImageBuilder =
    Widget Function(BuildContext context, ImageProvider imageProvider);

enum ImageType { png, jpg }

class CachedNetworkImage extends ConsumerStatefulWidget {
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
  ConsumerState<CachedNetworkImage> createState() => _CachedNetworkImageState();
}

class _CachedNetworkImageState extends ConsumerState<CachedNetworkImage> {
  bool loading = true;
  late ImageProvider imageProvider;

  Future<void> loadData() async {
    final storage = ref.read(storageManagerProvider);
    if (storage == null) {
      setState(() {
        loading = true;
      });
      return;
    }
    try {
      final imagePath = await storage.downloadFile(
        widget.imageUrl.toString(),
        'image.${widget.imageType.toString().split('.').last}',
        followRedirects: true,
      );
      File imageFile = File(imagePath);
      imageProvider = FileImage(imageFile);
      setState(() {
        loading = false;
      });
    } catch (_) {
      setState(() {
        loading = true;
      });
    }
  }

  void _loadBase64Data() {
    try {
      String uriString = widget.imageUrl.toString();
      int commaIndex = uriString.indexOf(',');
      if (commaIndex != -1) {
        String base64Data = uriString
            .substring(commaIndex + 1)
            .replaceAll(RegExp(r'\s+'), '');
        Uint8List bytes = base64Decode(base64Data);

        imageProvider = MemoryImage(bytes);
        setState(() {
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        loading = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.imageUrl.scheme == 'data') {
      _loadBase64Data();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => loadData());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return widget.placeholder;
    } else {
      return widget.builder(context, imageProvider);
    }
  }
}
