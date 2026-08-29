import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/collection.dart';
import '../../providers/auth_provider.dart';
import '../../services/collection_service.dart';
import '../../shared/layout/corvus_page.dart';
import '../../shared/widgets/corvus_button.dart';
import '../../shared/widgets/corvus_tag_input.dart';
import '../../shared/widgets/corvus_text_field.dart';

class CreateCollectionPage extends StatefulWidget {
  final String? collectionId;

  const CreateCollectionPage({super.key, this.collectionId});

  @override
  State<CreateCollectionPage> createState() => _CreateCollectionPageState();
}

class _CreateCollectionPageState extends State<CreateCollectionPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _coverController = TextEditingController();
  final _collectionService = CollectionService();

  List<String> _tags = [];
  String _collectionType = 'curated';
  bool _isPublic = true;
  bool _isSaving = false;
  bool _isLoading = false;
  Collection? _collection;

  bool get _isEditing => widget.collectionId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadCollection();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _coverController.dispose();
    super.dispose();
  }

  Future<void> _loadCollection() async {
    setState(() => _isLoading = true);
    try {
      final collection =
          await _collectionService.getCollectionById(widget.collectionId!);
      if (!mounted) return;
      _titleController.text = collection.title;
      _descController.text = collection.description;
      _coverController.text = collection.coverUrl ?? '';
      setState(() {
        _collection = collection;
        _tags = List<String>.from(collection.tags);
        _collectionType = collection.collectionType;
        _isPublic = collection.isPublic;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir la colección')),
      );
    }
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/collections');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final profile = context.read<AuthProvider>().profile;
    if (profile == null) return;

    if (_isEditing && _isPublic) {
      try {
        final items = await _collectionService.getCollectionItems(
          widget.collectionId!,
        );
        final hiddenWorks = items.where((item) {
          final work = item.work;
          return work == null || !work.isPublic || work.status != 'published';
        }).length;
        if (hiddenWorks > 0) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                hiddenWorks == 1
                    ? 'Publica la obra privada antes de abrir la colección.'
                    : 'Publica las $hiddenWorks obras privadas antes de abrir la colección.',
              ),
            ),
          );
          return;
        }
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo validar la visibilidad de las obras'),
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final Collection saved;
      if (_isEditing) {
        saved = await _collectionService.updateCollection(
          id: widget.collectionId!,
          title: _titleController.text,
          description: _descController.text,
          isPublic: _isPublic,
          collectionType: _collectionType,
          tags: _tags,
          coverUrl: _coverController.text,
        );
      } else {
        saved = await _collectionService.createCollection(
          profileId: profile.id,
          curatorName: profile.displayName,
          title: _titleController.text,
          description: _descController.text,
          isPublic: _isPublic,
          collectionType: _collectionType,
          tags: _tags,
          coverUrl: _coverController.text,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing ? 'Colección actualizada' : 'Colección creada',
          ),
        ),
      );
      if (_isEditing && context.canPop()) {
        context.pop(saved);
      } else {
        context.go('/collection/${saved.id}');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileId = context.watch<AuthProvider>().profile?.id;
    final canEdit = !_isEditing || _collection?.isOwnedBy(profileId) == true;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar colección' : 'Nueva colección'),
        leading: IconButton(
          tooltip: 'Cerrar',
          icon: const Icon(Icons.close_rounded, size: 20),
          onPressed: _leave,
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : CorvusFormPage(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  children: [
                    Text(
                      _isEditing
                          ? 'Actualiza la identidad y el criterio curatorial de esta sala.'
                          : 'Construye una sala para conservar, relacionar y presentar obras.',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    CorvusTextField(
                      controller: _titleController,
                      label: 'Título de la colección',
                      hint: 'El nombre de tu sala o archivo',
                      maxLength: 120,
                      readOnly: !canEdit,
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'El título es obligatorio';
                        if (text.length < 3) return 'Usa al menos 3 caracteres';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _collectionType,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de colección',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'curated',
                          child: Text('Curaduría'),
                        ),
                        DropdownMenuItem(
                          value: 'series',
                          child: Text('Serie temática'),
                        ),
                        DropdownMenuItem(
                          value: 'exhibition',
                          child: Text('Exposición'),
                        ),
                        DropdownMenuItem(
                          value: 'inspiration',
                          child: Text('Archivo de inspiración'),
                        ),
                        DropdownMenuItem(
                          value: 'personal',
                          child: Text('Archivo personal'),
                        ),
                      ],
                      onChanged: canEdit
                          ? (value) => setState(
                                () => _collectionType = value ?? 'curated',
                              )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    CorvusTextField(
                      controller: _descController,
                      label: 'Texto de sala',
                      hint: 'El hilo curatorial o la narrativa de la colección',
                      maxLines: 5,
                      maxLength: 1200,
                      readOnly: !canEdit,
                    ),
                    const SizedBox(height: 16),
                    CorvusTextField(
                      controller: _coverController,
                      label: 'Portada (URL)',
                      hint: 'https://...',
                      keyboardType: TextInputType.url,
                      prefixIcon: const Icon(Icons.image_outlined),
                      readOnly: !canEdit,
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return null;
                        final uri = Uri.tryParse(text);
                        if (uri == null ||
                            !uri.hasScheme ||
                            !uri.hasAuthority) {
                          return 'Escribe una URL válida';
                        }
                        return null;
                      },
                    ),
                    if (_coverController.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: AspectRatio(
                          aspectRatio: 16 / 7,
                          child: CachedNetworkImage(
                            imageUrl: _coverController.text.trim(),
                            fit: BoxFit.contain,
                            placeholder: (_, __) => Container(
                              color: AppColors.overlay,
                              alignment: Alignment.center,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: AppColors.overlay,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    CorvusTagInput(
                      label: 'Etiquetas',
                      hint: 'abstracción, archivo, ciudad',
                      values: _tags,
                      onChanged: canEdit
                          ? (value) => setState(() => _tags = value)
                          : (_) {},
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.overlay,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isPublic
                                ? Icons.public_outlined
                                : Icons.lock_outline_rounded,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isPublic ? 'Pública' : 'Privada',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  _isPublic
                                      ? 'Visible para la comunidad'
                                      : 'Solo tú puedes abrirla',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isPublic,
                            onChanged: canEdit
                                ? (value) => setState(() => _isPublic = value)
                                : null,
                            activeThumbColor: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    CorvusButton(
                      label: _isEditing ? 'Guardar cambios' : 'Crear colección',
                      icon:
                          _isEditing ? Icons.save_outlined : Icons.add_rounded,
                      isLoading: _isSaving,
                      onPressed: canEdit ? _save : null,
                      width: double.infinity,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
