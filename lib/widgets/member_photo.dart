import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/supabase_constants.dart';
import '../core/theme/app_colors.dart';

Future<Uint8List> compressMemberPhoto(Uint8List sourceBytes) async {
  var dimension = 1280;
  var quality = 84;
  Uint8List compressedBytes = sourceBytes;

  for (var attempt = 0; attempt < 7; attempt++) {
    compressedBytes = await FlutterImageCompress.compressWithList(
      sourceBytes,
      minWidth: dimension,
      minHeight: dimension,
      quality: quality,
      format: CompressFormat.jpeg,
      keepExif: false,
      autoCorrectionAngle: true,
    );
    if (compressedBytes.lengthInBytes <= 300 * 1024) break;
    dimension = (dimension * 0.85).round();
    quality = (quality - 7).clamp(48, 84).toInt();
  }

  return compressedBytes;
}

class MemberPhotoAvatar extends StatefulWidget {
  final String gymId;
  final String fullName;
  final String? photoPath;
  final Uint8List? photoBytes;
  final double radius;

  const MemberPhotoAvatar({
    super.key,
    required this.gymId,
    required this.fullName,
    this.photoPath,
    this.photoBytes,
    this.radius = 22,
  });

  @override
  State<MemberPhotoAvatar> createState() => _MemberPhotoAvatarState();
}

class _MemberPhotoAvatarState extends State<MemberPhotoAvatar> {
  Future<String>? _signedUrl;

  @override
  void initState() {
    super.initState();
    _loadSignedUrl();
  }

  @override
  void didUpdateWidget(covariant MemberPhotoAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoPath != widget.photoPath ||
        oldWidget.gymId != widget.gymId ||
        oldWidget.photoBytes != widget.photoBytes) {
      _loadSignedUrl();
    }
  }

  void _loadSignedUrl() {
    final path = widget.photoPath;
    if (path == null || widget.photoBytes != null) {
      _signedUrl = null;
      return;
    }
    if (!path.startsWith('${widget.gymId}/')) {
      _signedUrl = Future<String>.error(
        StateError('مسار الصورة لا يتبع صالة العضو.'),
      );
      return;
    }
    _signedUrl = Supabase.instance.client.storage
        .from(SupabaseConstants.bucketMemberPhotos)
        .createSignedUrl(path, 3600);
  }

  Widget _fallback(BuildContext context, {double? radius}) {
    final palette = context.appPalette;
    final effectiveRadius = radius ?? widget.radius;
    final name = widget.fullName.trim();
    return CircleAvatar(
      radius: effectiveRadius,
      backgroundColor: palette.primary.withValues(alpha: 0.15),
      child: Text(
        name.isEmpty ? '؟' : name.characters.first,
        style: TextStyle(
          color: palette.primary,
          fontWeight: FontWeight.bold,
          fontSize: effectiveRadius * 0.75,
        ),
      ),
    );
  }

  Widget _photo(BuildContext context, String? url, {double? radius}) {
    final effectiveRadius = radius ?? widget.radius;
    final image = widget.photoBytes != null
        ? Image.memory(
            widget.photoBytes!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallback(context, radius: radius),
          )
        : url == null
            ? _fallback(context, radius: radius)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _fallback(context, radius: radius),
              );

    return ClipOval(
      child: SizedBox.square(
        dimension: effectiveRadius * 2,
        child: image,
      ),
    );
  }

  Widget _previewImage(ImageProvider<Object> imageProvider) {
    return LayoutBuilder(
      builder: (context, constraints) => InteractiveViewer(
        child: SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Image(
            image: imageProvider,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _fallback(context, radius: 72),
          ),
        ),
      ),
    );
  }

  Future<void> _showPreview() async {
    final signedUrl = _signedUrl;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
            child: Center(
              child: widget.photoBytes != null
                  ? _previewImage(MemoryImage(widget.photoBytes!))
                  : signedUrl == null
                      ? _fallback(context, radius: 100)
                      : FutureBuilder<String>(
                          future: signedUrl,
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _fallback(context, radius: 72),
                                  const SizedBox(height: 12),
                                  const Text('تعذر تحميل الصورة.'),
                                ],
                              );
                            }
                            if (!snapshot.hasData) {
                              return const CircularProgressIndicator();
                            }
                            return _previewImage(NetworkImage(snapshot.data!));
                          },
                        ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final signedUrl = _signedUrl;
    return Semantics(
      button: true,
      label: 'عرض صورة ${widget.fullName}',
      child: GestureDetector(
        onTap: _showPreview,
        child: widget.photoBytes != null || signedUrl == null
            ? _photo(context, null)
            : FutureBuilder<String>(
                future: signedUrl,
                builder: (context, snapshot) => _photo(context, snapshot.data),
              ),
      ),
    );
  }
}

class MemberPhotoInput extends StatefulWidget {
  final String gymId;
  final String fullName;
  final String? existingPhotoPath;
  final Uint8List? selectedPhotoBytes;
  final ValueChanged<Uint8List> onPhotoSelected;
  final VoidCallback onPhotoRemoved;

  const MemberPhotoInput({
    super.key,
    required this.gymId,
    required this.fullName,
    required this.existingPhotoPath,
    required this.selectedPhotoBytes,
    required this.onPhotoSelected,
    required this.onPhotoRemoved,
  });

  @override
  State<MemberPhotoInput> createState() => _MemberPhotoInputState();
}

class _MemberPhotoInputState extends State<MemberPhotoInput> {
  final _picker = ImagePicker();
  bool _isPicking = false;
  String? _errorMessage;

  Future<void> _selectPhoto() async {
    setState(() {
      _isPicking = true;
      _errorMessage = null;
    });
    try {
      final image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;
      final compressed = await compressMemberPhoto(await image.readAsBytes());
      if (compressed.isEmpty) {
        throw StateError('تعذر تجهيز الصورة المحددة.');
      }
      widget.onPhotoSelected(compressed);
    } on StateError catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = 'تعذر تجهيز الصورة: $error');
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = 'تعذر اختيار الصورة: $error');
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto =
        widget.selectedPhotoBytes != null || widget.existingPhotoPath != null;

    return Column(
      children: [
        MemberPhotoAvatar(
          gymId: widget.gymId,
          fullName: widget.fullName,
          photoPath: widget.existingPhotoPath,
          photoBytes: widget.selectedPhotoBytes,
          radius: 42,
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _isPicking ? null : _selectPhoto,
              icon: _isPicking
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.photo_library_outlined),
              label: Text(_isPicking ? 'جارٍ تجهيز الصورة' : 'اختيار صورة'),
            ),
            if (hasPhoto)
              TextButton.icon(
                onPressed: _isPicking ? null : widget.onPhotoRemoved,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('إزالة الصورة'),
              ),
          ],
        ),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.appPalette.error, fontSize: 12),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}
