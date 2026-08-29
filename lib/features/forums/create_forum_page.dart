import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../models/fan_forum.dart';
import '../../models/work.dart';
import '../../services/fan_forum_service.dart';
import '../../shared/widgets/corvus_crow_animations.dart';
import '../../shared/widgets/corvus_text_field.dart';

class CreateForumPage extends StatefulWidget {
  final String? forumId;
  final FanForumService? service;

  const CreateForumPage({
    super.key,
    this.forumId,
    this.service,
  });

  @override
  State<CreateForumPage> createState() => _CreateForumPageState();
}

class _CreateForumPageState extends State<CreateForumPage> {
  static const _accents = [
    '#C92F35',
    '#6F5A91',
    '#3D7A68',
    '#B66A2C',
    '#3C6E9E',
    '#A84C76',
  ];

  late final FanForumService _service;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _guidelinesController = TextEditingController();
  List<Work> _works = const [];
  String? _linkedWorkId;
  String _joinPolicy = 'request';
  String _accentHex = _accents.first;
  bool _isDiscoverable = true;
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _error;

  bool get _editing => widget.forumId != null;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? FanForumService();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _guidelinesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final works = await _service.getAuthorWorks();
      FanForum? forum;
      if (widget.forumId != null) {
        forum = await _service.getForum(widget.forumId!);
      }
      if (!mounted) return;
      if (forum != null) {
        _nameController.text = forum.name;
        _descriptionController.text = forum.description;
        _guidelinesController.text = forum.guidelines;
      }
      setState(() {
        _works = works;
        _linkedWorkId = forum?.linkedWorkId;
        _joinPolicy = forum?.joinPolicy ?? 'request';
        _accentHex = forum?.accentHex ?? _accents.first;
        _isDiscoverable = forum?.isDiscoverable ?? true;
        _loading = false;
        _dirty = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  void _markDirty([String? _]) {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Salir sin guardar?'),
        content: const Text(
          'Los cambios de esta comunidad privada se perderán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Continuar editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _close() async {
    if (!await _confirmDiscard() || !mounted) return;
    setState(() => _dirty = false);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    context.canPop() ? context.pop() : context.go('/forums');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      String forumId;
      if (_editing) {
        forumId = widget.forumId!;
        await _service.updateForum(
          forumId: forumId,
          name: _nameController.text,
          description: _descriptionController.text,
          guidelines: _guidelinesController.text,
          joinPolicy: _joinPolicy,
          isDiscoverable: _isDiscoverable,
          linkedWorkId: _linkedWorkId,
          accentHex: _accentHex,
        );
      } else {
        final forum = await _service.createForum(
          name: _nameController.text,
          description: _descriptionController.text,
          guidelines: _guidelinesController.text,
          joinPolicy: _joinPolicy,
          isDiscoverable: _isDiscoverable,
          linkedWorkId: _linkedWorkId,
          accentHex: _accentHex,
        );
        forumId = forum.id;
      }
      if (!mounted) return;
      setState(() {
        _dirty = false;
        _saving = false;
      });
      context.go('/forums/$forumId');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el foro: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          leading: IconButton(
            tooltip: 'Volver',
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: _close,
          ),
          title: Text(_editing ? 'Editar foro privado' : 'Nuevo foro privado'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: Text(_saving ? 'Guardando' : 'Guardar'),
              ),
            ),
          ],
        ),
        body: _loading
            ? const Center(
                child: CorvusCrowLoader(label: 'Preparando el círculo...'),
              )
            : _error != null
                ? Center(
                    child: Text(
                      'No se pudo abrir el formulario.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.60),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      MediaQuery.sizeOf(context).width < 700 ? 16 : 28,
                      20,
                      MediaQuery.sizeOf(context).width < 700 ? 16 : 28,
                      64,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 920),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildIdentitySection(),
                              const SizedBox(height: 16),
                              _buildAccessSection(),
                              const SizedBox(height: 16),
                              _buildLinkSection(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildIdentitySection() {
    return _FormSection(
      icon: Icons.forum_outlined,
      title: 'Identidad de la comunidad',
      child: Column(
        children: [
          CorvusTextField(
            controller: _nameController,
            label: 'Nombre del foro',
            hint: 'Ej. Lectores del Códice',
            maxLength: 80,
            markdownPreview: false,
            onChanged: _markDirty,
            validator: (value) => (value?.trim().length ?? 0) < 3
                ? 'Escribe al menos 3 caracteres.'
                : null,
          ),
          const SizedBox(height: 14),
          CorvusTextField(
            controller: _descriptionController,
            label: 'Descripción',
            hint: 'Presenta el propósito y el tono de la comunidad.',
            maxLines: 4,
            maxLength: 1200,
            onChanged: _markDirty,
            validator: (value) => (value?.trim().length ?? 0) < 10
                ? 'Describe la comunidad con al menos 10 caracteres.'
                : null,
          ),
          const SizedBox(height: 14),
          CorvusTextField(
            controller: _guidelinesController,
            label: 'Acuerdos de convivencia',
            hint:
                '- Respeto entre lectores\n- Avisar spoilers\n- Cuidar la privacidad',
            maxLines: 6,
            maxLength: 5000,
            onChanged: _markDirty,
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final hex in _accents)
                  _ColorSwatch(
                    color: _colorFromHex(hex),
                    selected: _accentHex == hex,
                    onTap: () => setState(() {
                      _accentHex = hex;
                      _dirty = true;
                    }),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessSection() {
    return _FormSection(
      icon: Icons.lock_outline_rounded,
      title: 'Acceso privado',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: 'request',
                icon: Icon(Icons.how_to_reg_outlined),
                label: Text('Solicitudes'),
              ),
              ButtonSegment(
                value: 'invite_only',
                icon: Icon(Icons.mark_email_unread_outlined),
                label: Text('Solo invitación'),
              ),
            ],
            selected: {_joinPolicy},
            onSelectionChanged: (value) => setState(() {
              _joinPolicy = value.first;
              _dirty = true;
            }),
          ),
          const SizedBox(height: 14),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _isDiscoverable,
            onChanged: (value) => setState(() {
              _isDiscoverable = value;
              _dirty = true;
            }),
            title: const Text('Mostrar en el directorio'),
            subtitle: const Text(
              'El contenido seguirá siendo privado; solo se verá la ficha del foro.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkSection() {
    return _FormSection(
      icon: Icons.auto_stories_outlined,
      title: 'Obra anfitriona',
      child: DropdownButtonFormField<String?>(
        initialValue: _linkedWorkId,
        decoration: const InputDecoration(
          labelText: 'Vincular una obra publicada',
        ),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('Comunidad general del autor'),
          ),
          ..._works.map(
            (work) => DropdownMenuItem<String?>(
              value: work.id,
              child: Text(
                work.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
        onChanged: (value) => setState(() {
          _linkedWorkId = value;
          _dirty = true;
        }),
      ),
    );
  }

  Color _colorFromHex(String hex) {
    return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
  }
}

class _FormSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _FormSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primaryLight),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Color de la comunidad',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: selected ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
          child: selected
              ? const Icon(Icons.check_rounded, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}
