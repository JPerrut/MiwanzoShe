import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../logging/app_logger.dart';
import '../../models/media_entry.dart';
import '../../state/shaumsi_state.dart';
import '../widgets/glass_panel.dart';
import '../widgets/section_title.dart';

class FilesScreen extends StatelessWidget {
  FilesScreen({required this.state, super.key});

  final ShauMsiState state;
  final ImagePicker _picker = ImagePicker();
  static final AppLogger _logger = AppLogger.instance;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final entries = state.mediaEntries;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            SectionTitle(
              title: 'Arquivos',
              subtitle: 'Guarde fotos e vídeos em uma galeria privada.',
              trailing: FilledButton.icon(
                onPressed: () => _openPicker(context),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Adicionar'),
              ),
            ),
            const SizedBox(height: 16),
            if (entries.isEmpty)
              const GlassPanel(child: Text('Nenhum arquivo adicionado ainda.'))
            else
              GridView.builder(
                itemCount: entries.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.9,
                ),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return _MediaTile(
                    entry: entry,
                    onTap: () => _openPreview(context, entry),
                    onDelete: () => _confirmDelete(context, entry),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final option = await showModalBottomSheet<MediaType>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Selecionar foto'),
                onTap: () => Navigator.pop(sheetContext, MediaType.image),
              ),
              ListTile(
                leading: const Icon(Icons.video_library_outlined),
                title: const Text('Selecionar vídeo'),
                onTap: () => Navigator.pop(sheetContext, MediaType.video),
              ),
            ],
          ),
        );
      },
    );

    if (option == null) return;

    try {
      XFile? selected;
      if (option == MediaType.image) {
        selected = await _picker.pickImage(source: ImageSource.gallery);
      } else {
        selected = await _picker.pickVideo(source: ImageSource.gallery);
      }

      if (selected == null) return;

      await state.addMediaEntry(path: selected.path, type: option);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Arquivo adicionado na galeria.')),
        );
      }
    } catch (error, stackTrace) {
      _logger.error(
        'FilesScreen',
        'Falha ao adicionar arquivo de mídia.',
        error: error,
        stackTrace: stackTrace,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível adicionar o arquivo agora.'),
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, MediaEntry entry) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Excluir arquivo?'),
          content: const Text('Deseja remover este item da galeria?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (shouldDelete ?? false) {
      await state.deleteMediaEntry(entry.id);
    }
  }

  Future<void> _openPreview(BuildContext context, MediaEntry entry) async {
    if (entry.isImage) {
      await showDialog<void>(
        context: context,
        builder: (_) => _ImagePreviewDialog(path: entry.path),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (_) => _VideoPreviewDialog(path: entry.path),
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  final MediaEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final file = File(entry.path);
    final exists = file.existsSync();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: exists ? onTap : null,
        child: GlassPanel(
          padding: const EdgeInsets.all(8),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _buildBody(file, exists),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: onDelete,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.delete_outline, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(File file, bool exists) {
    if (!exists) {
      return Container(
        color: Colors.black12,
        alignment: Alignment.center,
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Arquivo não encontrado', textAlign: TextAlign.center),
        ),
      );
    }

    if (entry.isImage) {
      return Image.file(file, fit: BoxFit.cover);
    }

    return Container(
      color: Colors.black.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.play_circle_fill, size: 52),
          SizedBox(height: 8),
          Text('Vídeo'),
        ],
      ),
    );
  }
}

class _ImagePreviewDialog extends StatelessWidget {
  const _ImagePreviewDialog({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final file = File(path);

    return Dialog(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: file.existsSync()
            ? InteractiveViewer(child: Image.file(file, fit: BoxFit.contain))
            : const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Arquivo não encontrado.'),
              ),
      ),
    );
  }
}

class _VideoPreviewDialog extends StatefulWidget {
  const _VideoPreviewDialog({required this.path});

  final String path;

  @override
  State<_VideoPreviewDialog> createState() => _VideoPreviewDialogState();
}

class _VideoPreviewDialogState extends State<_VideoPreviewDialog> {
  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;

  @override
  void initState() {
    super.initState();
    final file = File(widget.path);
    if (!file.existsSync()) return;
    _controller = VideoPlayerController.file(file);
    _initializeFuture = _controller!.initialize();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final initializeFuture = _initializeFuture;

    if (controller == null || initializeFuture == null) {
      return const AlertDialog(content: Text('Arquivo não encontrado.'));
    }

    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      content: FutureBuilder<void>(
        future: initializeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          return AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          );
        },
      ),
      actions: [
        IconButton(
          onPressed: () async {
            if (controller.value.isPlaying) {
              await controller.pause();
            } else {
              await controller.play();
            }
            if (mounted) setState(() {});
          },
          icon: Icon(
            controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}
