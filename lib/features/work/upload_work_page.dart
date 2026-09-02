import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/aeternum_ficha.dart';
import '../../models/picked_image.dart';
import '../../models/work.dart';
import '../../providers/auth_provider.dart';
import '../../services/storage_service.dart';
import '../../services/work_service.dart';
import '../../shared/widgets/corvus_button.dart';
import '../../shared/widgets/corvus_crow_animations.dart';
import '../../shared/widgets/corvus_tag_input.dart';
import '../../shared/widgets/corvus_text_field.dart';
import 'work_reading_utils.dart';

// ─── Constantes de disciplina ─────────────────────────────────────────────────

const _disciplines = [
  'Pintura',
  'Fotografía',
  'Escultura',
  'Ilustración',
  'Arte Digital',
  'Música',
  'Literatura',
  'Poesía',
  'Cine',
  'Diseño',
  'Grabado',
  'Cerámica',
  'Performance',
];

enum _DisciplineCategory {
  painting,
  sculpture,
  craft,
  photography,
  digital,
  literary,
  audio,
  audiovisual,
  performance,
}

// ─── Opciones por disciplina ───────────────────────────────────────────────────

const _paintingStyles = [
  'Realismo',
  'Impresionismo',
  'Abstracto',
  'Surrealismo',
  'Expresionismo',
  'Contemporáneo',
  'Figurativo',
  'Minimalismo'
];
const _paintingSupports = [
  'Lienzo',
  'Papel',
  'Madera',
  'Tabla',
  'Mural',
  'Mixto'
];

const _sculptureMaterials = [
  'Bronce',
  'Mármol',
  'Cerámica',
  'Madera',
  'Metal',
  'Resina',
  'Piedra',
  'Yeso'
];
const _sculptureSupports = [
  'Pedestal',
  'Instalación',
  'Mural',
  'Relieve',
  'Bulto redondo'
];

const _craftTechniques = [
  'Aguafuerte',
  'Litografía',
  'Serigrafía',
  'Xilografía',
  'Torno',
  'Modelado',
  'Vidriado',
  'Esmalte'
];

const _photoCaptures = ['Analógica', 'Digital'];

const _digitalStyles = [
  'Pixel art',
  '3D render',
  'Vectorial',
  'Concept art',
  'Motion',
  'UI/UX',
  'Character design'
];

const _literaryGenres = [
  'Fantasía',
  'Ciencia ficción',
  'Terror',
  'Romance',
  'Drama',
  'Thriller',
  'Misterio',
  'Histórico',
  'Experimental'
];
const _literaryCorrientes = [
  'Contemporánea',
  'Clásica',
  'Experimental',
  'Vanguardista'
];

const _musicGenres = [
  'Ambient',
  'Rock',
  'Jazz',
  'Electrónica',
  'Clásica',
  'Folk',
  'Hip-Hop',
  'Experimental',
  'Pop',
  'Metal'
];
const _musicInstrumentation = ['Analógica', 'Digital', 'Mixta', 'Acústica'];
const _musicSubgenreMap = <String, List<String>>{
  'Electrónica': [
    'Ambient',
    'Synthwave',
    'House',
    'Minimal',
    'Techno',
    'Experimental'
  ],
  'Clásica': [
    'Barroco',
    'Romántico',
    'Contemporáneo',
    'Minimalismo',
    'Neoclásico'
  ],
  'Jazz': ['Bebop', 'Fusion', 'Swing', 'Free Jazz', 'Latin Jazz'],
  'Rock / Metal': ['Alternative', 'Progressive', 'Heavy', 'Post-rock', 'Indie'],
  'Ambient': [
    'Dark Ambient',
    'New Age',
    'Drone',
    'Field Recordings',
    'Ethereal'
  ],
  'Experimental': ['Noise', 'Glitch', 'Acusmática', 'Electroacústica'],
};

const _cinemaTypes = ['Ficción', 'Documental', 'Experimental', 'Animación'];
const _performanceTypes = [
  'Danza',
  'Teatro físico',
  'Acción poética',
  'Ritual',
  'Intervención',
  'Instalación'
];

const _kDisciplineIcons = <String, IconData>{
  'Pintura': Icons.brush_rounded,
  'Fotografía': Icons.photo_camera_rounded,
  'Escultura': Icons.architecture_rounded,
  'Música': Icons.music_note_rounded,
  'Literatura': Icons.menu_book_rounded,
  'Cine': Icons.movie_rounded,
  'Performance': Icons.theater_comedy_rounded,
};

// Advertencias de contenido sugeridas en el sello.
const _warningSuggestions = [
  'violencia',
  'gore',
  'lenguaje explícito',
  'desnudez',
  'contenido sexual',
  'horror psicológico',
  'abuso',
  'autolesión',
  'drogas',
];

// Resultado del sello final: qué decidió el artista al terminar.
typedef _SealResult = ({
  String status,
  bool isForSale,
  bool isMature,
  bool confirmsOwnership,
  bool ongoing,
  List<String> tags,
  List<String> warnings,
});

// ─── Page ─────────────────────────────────────────────────────────────────────

class UploadWorkPage extends StatefulWidget {
  final String? initialDiscipline;
  final String? initialSubdiscipline;
  final String? initialDraftId;

  const UploadWorkPage({
    super.key,
    this.initialDiscipline,
    this.initialSubdiscipline,
    this.initialDraftId,
  });

  @override
  State<UploadWorkPage> createState() => _UploadWorkPageState();
}

class _UploadWorkPageState extends State<UploadWorkPage> {
  final _formKey = GlobalKey<FormState>();

  // Campos de texto
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _manuscriptController = TextEditingController(); // Texto de la obra
  final _dimensionsController =
      TextEditingController(); // Dimensiones / Resolución
  final _extensionController = TextEditingController(); // Extensión / Duración
  final _extraController =
      TextEditingController(); // Instrumentación / Software / Enlace / Contexto

  // Servicios
  final _workService = WorkService();
  final _storageService = StorageService();

  // Estado UI
  PickedImage? _coverImage;
  String? _coverUrl;
  late String _selectedDiscipline;
  String _selectedSubdiscipline = '';
  bool _isForSale = false;
  bool _isMature = false;
  bool _isUploading = false;
  bool _isLoadingDraft = false;
  bool _isHydratingDraft = false;
  bool _confirmsOwnership = false;

  // Selecciones de identidad
  String _chipSelection = ''; // Género / Estilo / Tipo
  String _radioSelection = ''; // Formato / Soporte / Captura

  // Etiquetas y advertencias (se definen en el sello)
  List<String> _tags = [];
  List<String> _contentWarnings = [];

  // Publicación por entregas: la obra sigue recibiendo capítulos.
  bool _isOngoing = false;

  // Autosave
  String? _draftId;
  bool _isDirty = false;
  DateTime? _lastSaved;
  Timer? _autosaveTimer;

  // ─── Computed ──────────────────────────────────────────────────────────────

  _DisciplineCategory get _category {
    switch (_selectedDiscipline) {
      case 'Pintura':
        return _DisciplineCategory.painting;
      case 'Escultura':
        return _DisciplineCategory.sculpture;
      case 'Grabado':
      case 'Cerámica':
        return _DisciplineCategory.craft;
      case 'Fotografía':
        return _DisciplineCategory.photography;
      case 'Arte Digital':
      case 'Ilustración':
      case 'Diseño':
        return _DisciplineCategory.digital;
      case 'Literatura':
      case 'Poesía':
        return _DisciplineCategory.literary;
      case 'Música':
        return _DisciplineCategory.audio;
      case 'Cine':
        return _DisciplineCategory.audiovisual;
      case 'Performance':
        return _DisciplineCategory.performance;
      default:
        return _DisciplineCategory.painting;
    }
  }

  String get _workType => switch (_category) {
        _DisciplineCategory.literary => 'text',
        _DisciplineCategory.audio => 'audio',
        _DisciplineCategory.audiovisual => 'video',
        _ => 'image',
      };

  String get _identitySubtitle {
    switch (_category) {
      case _DisciplineCategory.painting:
        return 'Estilo visual, soporte y dimensiones.';
      case _DisciplineCategory.sculpture:
        return 'Material, técnica y dimensiones de la pieza.';
      case _DisciplineCategory.craft:
        return 'Técnica, formato y dimensiones de la obra.';
      case _DisciplineCategory.photography:
        return 'Captura, equipo y resolución.';
      case _DisciplineCategory.digital:
        return 'Técnica, herramienta y especificaciones digitales.';
      case _DisciplineCategory.literary:
        return 'Género, corriente y extensión de la obra.';
      case _DisciplineCategory.audio:
        return 'Subgénero, instrumentación y duración.';
      case _DisciplineCategory.audiovisual:
        return 'Tipo, duración y especificaciones técnicas.';
      case _DisciplineCategory.performance:
        return 'Tipo de acción, duración y contexto de la pieza.';
    }
  }

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _selectedDiscipline = widget.initialDiscipline ?? _disciplines.first;
    _selectedSubdiscipline = widget.initialSubdiscipline ?? '';
    _draftId = widget.initialDraftId;
    if (_draftId != null) {
      _isLoadingDraft = true;
    }

    _titleController.addListener(_onFieldChanged);
    _descController.addListener(_onFieldChanged);
    _manuscriptController.addListener(_onFieldChanged);

    _autosaveTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_isDirty && mounted) _saveDraft();
    });

    if (_draftId != null) {
      unawaited(_loadInitialDraft(_draftId!));
    }
  }

  void _onFieldChanged() {
    if (_isHydratingDraft) return;
    if (mounted) setState(() => _isDirty = true);
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    for (final c in [
      _titleController,
      _descController,
      _priceController,
      _manuscriptController,
      _dimensionsController,
      _extensionController,
      _extraController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ─── Acciones ──────────────────────────────────────────────────────────────

  Future<void> _loadInitialDraft(String draftId) async {
    try {
      final work = await _workService.getWorkById(draftId);
      if (!mounted) return;
      _applyDraft(work);
      setState(() {
        _isLoadingDraft = false;
        _isDirty = false;
        _lastSaved = work.updatedAt;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingDraft = false;
        _draftId = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showMessage('No se pudo cargar el borrador: $error');
        }
      });
    }
  }

  void _applyDraft(Work work) {
    _isHydratingDraft = true;
    _titleController.text = work.title;
    _descController.text = work.description;
    _tags = List.of(work.tags);
    _contentWarnings = List.of(work.contentWarnings);
    _priceController.text = work.price == null ? '' : '${work.price}';
    _manuscriptController.text = work.textBody ?? '';
    _dimensionsController.text = work.dimensions ?? '';
    _extensionController.text = work.duration ?? '';
    _extraController.text = work.musicGenre ?? '';
    _selectedDiscipline =
        work.discipline.isNotEmpty ? work.discipline : _selectedDiscipline;
    _selectedSubdiscipline = work.subdiscipline;
    _chipSelection = work.medium;
    _radioSelection = work.technique ?? '';
    _isForSale = work.isForSale;
    _isMature = work.isMature;
    _coverUrl = work.coverUrl;
    _isHydratingDraft = false;
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 88);
    if (picked == null) return;

    final image = await PickedImage.read(picked);
    if (!mounted) return;

    setState(() {
      _coverImage = image;
      _coverUrl = null;
      _isDirty = true;
    });
  }

  Map<String, dynamic> _buildPayload({
    required DateTime now,
    required String status,
    String? coverUrl,
  }) {
    final payload = <String, dynamic>{
      'title': _titleController.text.trim(),
      'description': _descController.text.trim(),
      'discipline': _selectedDiscipline,
      'subdiscipline': _selectedSubdiscipline,
      'medium': _chipSelection,
      'work_type': _workType,
      'status': status,
      'is_for_sale': _isForSale,
      'is_mature': _isMature,
      'year': now.year,
      'tags': _tags,
      'content_warnings': _contentWarnings,
      'is_public': status == 'published',
      'is_complete': status == 'published' && !_isOngoing,
    };

    payload['aeternum_ficha'] = AeternumFicha.fromSource({
      'source': 'upload',
      'title': _titleController.text.trim(),
      'description': _descController.text.trim(),
      'discipline': _selectedDiscipline,
      'subdiscipline': _selectedSubdiscipline,
      'genre': _category == _DisciplineCategory.audio
          ? _chipSelection
          : _selectedSubdiscipline,
      'style': _radioSelection,
      'status': status,
      'visibility': status == 'published' ? 'public' : 'private',
      'duration': _extensionController.text.trim(),
      'dimensions': _dimensionsController.text.trim(),
      'tools': _category == _DisciplineCategory.audio
          ? _radioSelection
          : _extraController.text.trim(),
      'monetization': _isForSale ? 'sale' : 'none',
      'price_plan': _priceController.text.trim(),
    }).toMap();

    if (status == 'published') {
      payload['published_at'] = now.toIso8601String();
    }
    if (coverUrl != null) {
      payload['cover_url'] = coverUrl;
    }

    if (_radioSelection.isNotEmpty) {
      payload['technique'] = _radioSelection;
    }
    if (_dimensionsController.text.trim().isNotEmpty) {
      payload['dimensions'] = _dimensionsController.text.trim();
    }
    if (_extensionController.text.trim().isNotEmpty) {
      payload['duration'] = _extensionController.text.trim();
    }

    // El género de una pieza musical viene del chip de subgénero; en el resto
    // de disciplinas la columna guarda el campo libre (equipo, software, etc.).
    if (_category == _DisciplineCategory.audio) {
      if (_chipSelection.isNotEmpty) payload['music_genre'] = _chipSelection;
    } else if (_extraController.text.trim().isNotEmpty) {
      payload['music_genre'] = _extraController.text.trim();
    }

    if (_category == _DisciplineCategory.literary) {
      final manuscript = _manuscriptController.text.trim();
      payload['text_body'] = manuscript.isEmpty ? null : manuscript;
    }

    if (_isForSale && _priceController.text.trim().isNotEmpty) {
      payload['price'] = double.tryParse(_priceController.text.trim());
    }

    return payload;
  }

  Future<void> _saveDraft() async {
    final profile = context.read<AuthProvider>().profile;
    if (profile == null || _titleController.text.trim().isEmpty) return;
    try {
      final now = DateTime.now();
      final payload = {
        ..._buildPayload(now: now, status: 'draft'),
        'profile_id': profile.id,
      };
      if (_draftId == null) {
        payload['media_urls'] = <String>[];
      }
      if (_draftId != null) {
        await _workService.updateWork(_draftId!, payload);
      } else {
        final work = await _workService.createWork(payload);
        _draftId = work.id;
      }
      if (mounted) {
        setState(() {
          _isDirty = false;
          _lastSaved = DateTime.now();
        });
      }
    } catch (_) {}
  }

  // Fase 2: abre el sello final y ejecuta la decisión del artista.
  Future<void> _finish() async {
    if (_isUploading) return;
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showMessage('El título es obligatorio para continuar.');
      return;
    }

    final result = await _openSealSheet();
    if (result == null || !mounted) return;

    setState(() {
      _isForSale = result.isForSale;
      _isMature = result.isMature;
      _confirmsOwnership = result.confirmsOwnership;
      _isOngoing = result.ongoing;
      _tags = result.tags;
      _contentWarnings = result.warnings;
    });

    await _publish(status: result.status);
  }

  Future<_SealResult?> _openSealSheet() {
    final hasImage = _coverImage != null || (_coverUrl?.isNotEmpty ?? false);
    final sheet = _SealSheet(
      title: _titleController.text.trim(),
      discipline: _selectedDiscipline,
      subdiscipline: _selectedSubdiscipline,
      coverImage: _coverImage,
      coverUrl: _coverUrl,
      hasImage: hasImage,
      priceController: _priceController,
      initialTags: _tags,
      initialWarnings: _contentWarnings,
      initialForSale: _isForSale,
      initialMature: _isMature,
      initialOwnership: _confirmsOwnership,
      initialOngoing: _isOngoing,
      showOngoing: _category == _DisciplineCategory.literary,
    );

    final wide = MediaQuery.sizeOf(context).width >= 720;
    if (wide) {
      return showDialog<_SealResult>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: AppColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: sheet,
          ),
        ),
      );
    }
    return showModalBottomSheet<_SealResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: sheet,
      ),
    );
  }

  Future<void> _publish({required String status}) async {
    final profile = context.read<AuthProvider>().profile;
    if (profile == null) {
      _showMessage('No se encontró tu perfil.');
      return;
    }

    setState(() => _isUploading = true);
    try {
      final now = DateTime.now();
      String? coverUrl;
      if (_coverImage != null) {
        coverUrl =
            await _storageService.uploadWorkImage(_coverImage!, profile.id);
      }

      final payload = {
        ..._buildPayload(now: now, status: status, coverUrl: coverUrl),
        'profile_id': profile.id,
      };
      if (coverUrl != null) {
        payload['media_urls'] = [coverUrl];
      } else if (_draftId == null) {
        payload['media_urls'] = <String>[];
      }

      final Work saved;
      if (_draftId != null) {
        saved = await _workService.updateWork(_draftId!, payload);
      } else {
        saved = await _workService.createWork(payload);
      }

      if (!mounted) return;
      if (status == 'published') {
        await showCrowFlight(context);
        if (!mounted) return;
        _showMessage('Obra sellada en el archivo');
        context.go('/work/${saved.id}');
      } else {
        _showMessage('Borrador guardado');
        context.go('/discover');
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Error: $e');
      setState(() => _isUploading = false);
    }
  }

  void _leavePublicationFlow() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/atelier');
    }
  }

  Future<void> _handleClose() async {
    if (_isUploading) return;
    final hasContent = _titleController.text.trim().isNotEmpty;
    if (!_isDirty || !hasContent) {
      _leavePublicationFlow();
      return;
    }

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Salir del Atelier?',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800)),
        content: Text(
          'Tienes cambios sin guardar. Puedes conservarlos como borrador y retomarlos después.',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.60),
              fontSize: 13,
              height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('discard'),
            child: Text('Descartar',
                style: TextStyle(
                    color: Colors.redAccent.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('stay'),
            child: Text('Seguir editando',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('save'),
            child: const Text('Guardar borrador',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (!mounted) return;
    switch (choice) {
      case 'save':
        await _saveDraft();
        if (mounted) {
          _showMessage('Borrador guardado');
          _leavePublicationFlow();
        }
      case 'discard':
        _leavePublicationFlow();
      default:
        break; // seguir editando
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.card,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 980;
    if (_isLoadingDraft) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: CorvusCrowLoader(label: 'Recuperando el borrador…'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              isUploading: _isUploading,
              isDirty: _isDirty,
              lastSaved: _lastSaved,
              onClose: _handleClose,
              onFinish: _finish,
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Form(
                    key: _formKey,
                    child: isWide ? _wideLayout(context) : _compactLayout(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wideLayout(BuildContext context) {
    final profile = context.read<AuthProvider>().profile;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ◈ ORIGEN + imagen + preview
          SizedBox(
            width: 340,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _SelectedDisciplineCard(
                    discipline: _selectedDiscipline,
                    subdiscipline: _selectedSubdiscipline,
                    onChange: _leavePublicationFlow,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 280,
                    child: _ImagePickerCard(
                      coverImage: _coverImage,
                      coverUrl: _coverUrl,
                      onTap: _pickImage,
                      onRemove: _coverImage != null || _coverUrl != null
                          ? () => setState(() {
                                _coverImage = null;
                                _coverUrl = null;
                                _isDirty = true;
                              })
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _WorkPreviewCard(
                    title: _titleController.text.trim(),
                    discipline: _selectedDiscipline,
                    subdiscipline: _selectedSubdiscipline,
                    coverImage: _coverImage,
                    coverUrl: _coverUrl,
                    authorName: profile?.displayName ?? profile?.username ?? '',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(child: _EditorPanel(child: _formContent())),
        ],
      ),
    );
  }

  Widget _compactLayout() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _SelectedDisciplineCard(
          discipline: _selectedDiscipline,
          subdiscipline: _selectedSubdiscipline,
          onChange: _leavePublicationFlow,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 260,
          child: _ImagePickerCard(
            coverImage: _coverImage,
            coverUrl: _coverUrl,
            onTap: _pickImage,
            onRemove: _coverImage != null || _coverUrl != null
                ? () => setState(() {
                      _coverImage = null;
                      _coverUrl = null;
                      _isDirty = true;
                    })
                : null,
          ),
        ),
        const SizedBox(height: 16),
        _EditorPanel(child: _formContent()),
      ],
    );
  }

  // ─── Formulario (fase 1: solo la obra) ─────────────────────────────────────

  Widget _formContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CorvusTextField(
          controller: _titleController,
          label: 'Título de la obra',
          hint: 'Ej. El jardín después del incendio',
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'El título es obligatorio'
              : null,
        ),
        const SizedBox(height: 16),
        CorvusTextField(
          controller: _descController,
          label: 'Crónica / Descripción',
          hint: 'El contexto, la idea y la historia detrás de la obra...',
          maxLines: 5,
          maxLength: 2000,
        ),
        const SizedBox(height: 32),

        // ◈ IDENTIDAD DE LA OBRA
        _SectionTitle(
          eyebrow: 'IDENTIDAD DE LA OBRA',
          title: _selectedSubdiscipline.isNotEmpty
              ? '$_selectedDiscipline · $_selectedSubdiscipline'
              : _selectedDiscipline,
          subtitle: _identitySubtitle,
          compact: true,
        ),
        const SizedBox(height: 22),

        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: KeyedSubtree(
            key: ValueKey(_selectedDiscipline),
            child: _buildIdentitySection(),
          ),
        ),

        // ◈ MANUSCRITO — solo obras literarias
        if (_category == _DisciplineCategory.literary) ...[
          const SizedBox(height: 32),
          const _SectionTitle(
            eyebrow: 'MANUSCRITO',
            title: 'Contenido de la obra',
            subtitle:
                'Escribe o pega aquí el texto. Separa capítulos con "Capítulo 1: Título" o "# Título".',
            compact: true,
          ),
          const SizedBox(height: 18),
          CorvusTextField(
            controller: _manuscriptController,
            label: 'Texto de la obra',
            hint:
                'Capítulo 1: El despertar\n\nLa ciudad amanecía en silencio...',
            maxLines: 14,
          ),
          const SizedBox(height: 10),
          _buildManuscriptStats(),
        ],

        const SizedBox(height: 20),
        _buildDateLine(),
        const SizedBox(height: 12),
        _buildSealHint(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildManuscriptStats() {
    final text = _manuscriptController.text.trim();
    if (text.isEmpty) {
      return Text(
        'El manuscrito se mostrará como capítulos en la página de la obra.',
        style: TextStyle(
            color: Colors.white.withValues(alpha: 0.28), fontSize: 12),
      );
    }
    final chapters = parseWorkChapters(text);
    final words = chapters.fold<int>(0, (sum, c) => sum + c.wordCount);
    final chapterLabel = chapters.length == 1
        ? 'capítulo único'
        : '${chapters.length} capítulos';

    return Row(
      children: [
        Icon(Icons.auto_stories_outlined,
            size: 14, color: AppColors.primary.withValues(alpha: 0.55)),
        const SizedBox(width: 8),
        Text(
          '$words palabras · $chapterLabel · ${formatReadingTime(chapters)}',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
              fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildSealHint() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(Icons.approval_rounded,
              size: 18, color: AppColors.primary.withValues(alpha: 0.55)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Etiquetas, venta y derechos se definen al finalizar, en el sello de la obra.',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.40),
                  fontSize: 12,
                  height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ─── IDENTIDAD: secciones por disciplina ──────────────────────────────────

  Widget _buildIdentitySection() {
    return switch (_category) {
      _DisciplineCategory.painting => _buildPaintingIdentity(),
      _DisciplineCategory.sculpture => _buildSculptureIdentity(),
      _DisciplineCategory.craft => _buildCraftIdentity(),
      _DisciplineCategory.photography => _buildPhotographyIdentity(),
      _DisciplineCategory.digital => _buildDigitalIdentity(),
      _DisciplineCategory.literary => _buildLiteraryIdentity(),
      _DisciplineCategory.audio => _buildAudioIdentity(),
      _DisciplineCategory.audiovisual => _buildAudiovisualIdentity(),
      _DisciplineCategory.performance => _buildPerformanceIdentity(),
    };
  }

  Widget _buildPaintingIdentity() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChipGroup(
            label: 'Estilo visual',
            options: _paintingStyles,
            selected: _chipSelection,
            onSelect: (v) => setState(() {
              _chipSelection = v;
              _isDirty = true;
            }),
          ),
          const SizedBox(height: 20),
          _ChipGroup(
            label: 'Soporte',
            options: _paintingSupports,
            selected: _radioSelection,
            onSelect: (v) => setState(() {
              _radioSelection = v;
              _isDirty = true;
            }),
          ),
          const SizedBox(height: 20),
          CorvusTextField(
              controller: _dimensionsController,
              label: 'Dimensiones físicas',
              hint: '100 × 80 cm'),
        ],
      );

  Widget _buildSculptureIdentity() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChipGroup(
            label: 'Material principal',
            options: _sculptureMaterials,
            selected: _chipSelection,
            onSelect: (v) => setState(() {
              _chipSelection = v;
              _isDirty = true;
            }),
          ),
          const SizedBox(height: 20),
          _RadioGroup(
            label: 'Tipología',
            options: _sculptureSupports,
            selected: _radioSelection,
            onSelect: (v) => setState(() {
              _radioSelection = v;
              _isDirty = true;
            }),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
                child: CorvusTextField(
                    controller: _dimensionsController,
                    label: 'Dimensiones',
                    hint: '40 × 30 × 20 cm')),
            const SizedBox(width: 12),
            Expanded(
                child: CorvusTextField(
                    controller: _extensionController,
                    label: 'Peso (opcional)',
                    hint: '12 kg')),
          ]),
        ],
      );

  Widget _buildCraftIdentity() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChipGroup(
            label: 'Técnica',
            options: _craftTechniques,
            selected: _chipSelection,
            onSelect: (v) => setState(() {
              _chipSelection = v;
              _isDirty = true;
            }),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
                child: CorvusTextField(
                    controller: _dimensionsController,
                    label: 'Dimensiones / Formato',
                    hint: '50 × 35 cm')),
            const SizedBox(width: 12),
            Expanded(
                child: CorvusTextField(
                    controller: _extraController,
                    label: 'Material',
                    hint: 'Arcilla, cobre, linóleo...')),
          ]),
        ],
      );

  Widget _buildPhotographyIdentity() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChipGroup(
            label: 'Captura',
            options: _photoCaptures,
            selected: _radioSelection,
            onSelect: (v) => setState(() {
              _radioSelection = v;
              _isDirty = true;
            }),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
                child: CorvusTextField(
                    controller: _dimensionsController,
                    label: 'Resolución / Formato',
                    hint: '6000 × 4000 px, RAW...')),
            const SizedBox(width: 12),
            Expanded(
                child: CorvusTextField(
                    controller: _extraController,
                    label: 'Cámara / Equipo',
                    hint: 'Canon 5D, Leica M6...')),
          ]),
        ],
      );

  Widget _buildDigitalIdentity() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChipGroup(
            label: 'Técnica / Estilo',
            options: _digitalStyles,
            selected: _chipSelection,
            onSelect: (v) => setState(() {
              _chipSelection = v;
              _isDirty = true;
            }),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
                child: CorvusTextField(
                    controller: _extraController,
                    label: 'Software / Herramienta',
                    hint: 'Procreate, Blender, Figma...')),
            const SizedBox(width: 12),
            Expanded(
                child: CorvusTextField(
                    controller: _dimensionsController,
                    label: 'Resolución / Formato',
                    hint: '3840 × 2160 px, SVG...')),
          ]),
        ],
      );

  Widget _buildLiteraryIdentity() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChipGroup(
            label: 'Género literario',
            options: _literaryGenres,
            selected: _chipSelection,
            onSelect: (v) => setState(() {
              _chipSelection = v;
              _isDirty = true;
            }),
          ),
          const SizedBox(height: 20),
          _ChipGroup(
            label: 'Corriente',
            options: _literaryCorrientes,
            selected: _radioSelection,
            onSelect: (v) => setState(() {
              _radioSelection = v;
              _isDirty = true;
            }),
          ),
        ],
      );

  Widget _buildAudioIdentity() {
    final subgenres = _musicSubgenreMap[_selectedSubdiscipline] ?? _musicGenres;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChipGroup(
          label: 'Subgénero',
          options: subgenres,
          selected: _chipSelection,
          onSelect: (v) => setState(() {
            _chipSelection = v;
            _isDirty = true;
          }),
        ),
        const SizedBox(height: 20),
        _ChipGroup(
          label: 'Instrumentación',
          options: _musicInstrumentation,
          selected: _radioSelection,
          onSelect: (v) => setState(() {
            _radioSelection = v;
            _isDirty = true;
          }),
        ),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
              child: CorvusTextField(
                  controller: _extensionController,
                  label: 'Duración',
                  hint: '03:48')),
          const SizedBox(width: 12),
          Expanded(
              child: CorvusTextField(
                  controller: _dimensionsController,
                  label: 'Enlace de escucha (opcional)',
                  hint: 'Spotify, SoundCloud...')),
        ]),
      ],
    );
  }

  Widget _buildAudiovisualIdentity() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChipGroup(
            label: 'Tipo',
            options: _cinemaTypes,
            selected: _chipSelection,
            onSelect: (v) => setState(() {
              _chipSelection = v;
              _isDirty = true;
            }),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
                child: CorvusTextField(
                    controller: _extensionController,
                    label: 'Duración',
                    hint: '12 min, 1h 45 min...')),
            const SizedBox(width: 12),
            Expanded(
                child: CorvusTextField(
                    controller: _dimensionsController,
                    label: 'Resolución',
                    hint: '4K, 1080p, 16mm...')),
          ]),
          const SizedBox(height: 12),
          CorvusTextField(
              controller: _extraController,
              label: 'Enlace / Trailer (opcional)',
              hint: 'Vimeo, YouTube...'),
        ],
      );

  Widget _buildPerformanceIdentity() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChipGroup(
            label: 'Tipo de performance',
            options: _performanceTypes,
            selected: _chipSelection,
            onSelect: (v) => setState(() {
              _chipSelection = v;
              _isDirty = true;
            }),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
                child: CorvusTextField(
                    controller: _extensionController,
                    label: 'Duración aproximada',
                    hint: '45 min, ciclo de 3 días...')),
            const SizedBox(width: 12),
            Expanded(
                child: CorvusTextField(
                    controller: _extraController,
                    label: 'Lugar / Contexto',
                    hint: 'Galería, espacio público...')),
          ]),
        ],
      );

  // ─── Componentes del formulario ────────────────────────────────────────────

  Widget _buildDateLine() {
    final now = DateTime.now();
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre'
    ];
    return Row(
      children: [
        Icon(Icons.calendar_today_outlined,
            size: 14, color: AppColors.primary.withValues(alpha: 0.55)),
        const SizedBox(width: 9),
        Text(
          '${now.day} de ${months[now.month - 1]} de ${now.year}',
          style: TextStyle(
              color: AppColors.primary.withValues(alpha: 0.80),
              fontSize: 13,
              fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 10),
        Text(
          '· Se registrará al publicar',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.28), fontSize: 12),
        ),
      ],
    );
  }
}

// ─── SealSheet: fase 2, al finalizar la obra ─────────────────────────────────

class _SealSheet extends StatefulWidget {
  final String title;
  final String discipline, subdiscipline;
  final PickedImage? coverImage;
  final String? coverUrl;
  final bool hasImage;
  final TextEditingController priceController;
  final List<String> initialTags;
  final List<String> initialWarnings;
  final bool initialForSale, initialMature, initialOwnership;
  final bool initialOngoing;
  final bool showOngoing;

  const _SealSheet({
    required this.title,
    required this.discipline,
    required this.subdiscipline,
    required this.coverImage,
    required this.coverUrl,
    required this.hasImage,
    required this.priceController,
    required this.initialTags,
    required this.initialWarnings,
    required this.initialForSale,
    required this.initialMature,
    required this.initialOwnership,
    this.initialOngoing = false,
    this.showOngoing = false,
  });

  @override
  State<_SealSheet> createState() => _SealSheetState();
}

class _SealSheetState extends State<_SealSheet> {
  late bool _isForSale = widget.initialForSale;
  late bool _isMature = widget.initialMature;
  late bool _confirmsOwnership = widget.initialOwnership;
  late bool _isOngoing = widget.initialOngoing;
  late List<String> _tags = List.of(widget.initialTags);
  late List<String> _warnings = List.of(widget.initialWarnings);

  _SealResult _result(String status) => (
        status: status,
        isForSale: _isForSale,
        isMature: _isMature,
        confirmsOwnership: _confirmsOwnership,
        ongoing: _isOngoing,
        tags: _tags,
        warnings: _warnings,
      );

  @override
  Widget build(BuildContext context) {
    final tag = widget.subdiscipline.isNotEmpty
        ? '${widget.discipline} · ${widget.subdiscipline}'
        : widget.discipline;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.approval_rounded,
                  color: AppColors.primary.withValues(alpha: 0.80), size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Sello de la obra',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4)),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded,
                    color: Colors.white.withValues(alpha: 0.40), size: 20),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Últimos detalles antes de registrar la pieza en el archivo.',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.42),
                fontSize: 13,
                height: 1.4),
          ),
          const SizedBox(height: 20),

          // Resumen de la obra
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: widget.coverImage != null
                        ? Image.memory(widget.coverImage!.bytes,
                            fit: BoxFit.cover)
                        : (widget.coverUrl?.isNotEmpty ?? false)
                            ? Image.network(widget.coverUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _coverFallback())
                            : _coverFallback(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(tag,
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Etiquetas
          CorvusTagInput(
            label: 'Etiquetas',
            hint: 'abstracto, color, experimental…',
            values: _tags,
            onChanged: (v) => setState(() => _tags = v),
          ),
          const SizedBox(height: 16),

          // Obra en curso (publicación por entregas)
          if (widget.showOngoing) ...[
            _ToggleTile(
              icon: Icons.auto_stories_outlined,
              title: 'Obra en curso',
              subtitle:
                  'Publicación por entregas: podrás seguir añadiendo capítulos desde el Atelier.',
              value: _isOngoing,
              onChanged: (v) => setState(() => _isOngoing = v),
            ),
            const SizedBox(height: 12),
          ],

          // En venta
          _ToggleTile(
            icon: Icons.sell_outlined,
            title: 'En venta',
            subtitle: 'Permite que otros compren esta obra.',
            value: _isForSale,
            onChanged: (v) => setState(() => _isForSale = v),
          ),
          if (_isForSale) ...[
            const SizedBox(height: 12),
            CorvusTextField(
              controller: widget.priceController,
              label: 'Precio',
              hint: '0.00',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
          const SizedBox(height: 12),

          // Contenido maduro
          _ToggleTile(
            icon: Icons.warning_amber_rounded,
            title: 'Contenido maduro',
            subtitle:
                '+18, desnudo artístico, violencia simbólica o temas sensibles.',
            value: _isMature,
            onChanged: (v) => setState(() => _isMature = v),
          ),
          if (_isMature) ...[
            const SizedBox(height: 12),
            CorvusTagInput(
              label: 'Advertencias de contenido',
              hint: 'violencia, gore, lenguaje explícito…',
              values: _warnings,
              onChanged: (v) => setState(() => _warnings = v),
              suggestions: _warningSuggestions,
              maxTags: 10,
            ),
          ],
          const SizedBox(height: 12),

          // Derechos — requerido solo para publicar
          _ToggleTile(
            icon: Icons.verified_user_outlined,
            title: 'Autoría y derechos',
            subtitle:
                'Confirmo que esta obra me pertenece o tengo permiso para publicarla.',
            value: _confirmsOwnership,
            activeColor: const Color(0xFF6BAE6B),
            onChanged: (v) => setState(() => _confirmsOwnership = v),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => context.push('/glossary'),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Row(
                children: [
                  Icon(Icons.menu_book_outlined,
                      size: 13,
                      color: AppColors.primary.withValues(alpha: 0.60)),
                  const SizedBox(width: 6),
                  Text(
                    '¿Dudas sobre derechos, propiedad o uso derivado? Consulta el glosario',
                    style: TextStyle(
                        color: AppColors.primary.withValues(alpha: 0.70),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Checklist compacto
          _checkRow('Título de la obra', done: true),
          _checkRow('Imagen principal', done: widget.hasImage, optional: true),
          _checkRow('Derechos confirmados', done: _confirmsOwnership),
          const SizedBox(height: 22),

          // Acciones
          Row(
            children: [
              Expanded(
                child: CorvusButton(
                  label: 'Guardar borrador',
                  outlined: true,
                  onPressed: () => Navigator.of(context).pop(_result('draft')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CorvusButton(
                  label: 'Publicar en el archivo',
                  onPressed: _confirmsOwnership
                      ? () => Navigator.of(context).pop(_result('published'))
                      : null,
                ),
              ),
            ],
          ),
          if (!_confirmsOwnership) ...[
            const SizedBox(height: 10),
            Text(
              'Confirma la autoría para poder publicar. El borrador no lo requiere.',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.30), fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _coverFallback() => Container(
        color: AppColors.overlay,
        child: Icon(Icons.image_not_supported_outlined,
            color: Colors.white.withValues(alpha: 0.18), size: 22),
      );

  Widget _checkRow(String label, {required bool done, bool optional = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 16,
            color: done
                ? AppColors.primary.withValues(alpha: 0.80)
                : Colors.white.withValues(alpha: 0.20),
          ),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  color: done
                      ? AppColors.textPrimary
                      : Colors.white.withValues(alpha: 0.42),
                  fontSize: 12.5,
                  fontWeight: done ? FontWeight.w700 : FontWeight.w400)),
          if (optional) ...[
            const SizedBox(width: 8),
            Text('opcional',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.25), fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

// ─── TopBar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final bool isUploading;
  final bool isDirty;
  final DateTime? lastSaved;
  final VoidCallback onClose;
  final VoidCallback onFinish;

  const _TopBar({
    required this.isUploading,
    required this.isDirty,
    required this.lastSaved,
    required this.onClose,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    String? saveLabel;
    if (lastSaved != null) {
      final diff = DateTime.now().difference(lastSaved!);
      saveLabel = diff.inMinutes < 1
          ? 'guardado ahora'
          : 'guardado hace ${diff.inMinutes} min';
    }

    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: isUploading ? null : onClose,
            icon:
                const Icon(Icons.close_rounded, color: AppColors.textSecondary),
          ),
          const Spacer(),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Atelier',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3)),
              if (isDirty)
                Text('• sin guardar',
                    style: TextStyle(
                        color: Colors.orange.withValues(alpha: 0.75),
                        fontSize: 11))
              else if (saveLabel != null)
                Text(saveLabel,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.34),
                        fontSize: 11)),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: 148,
            child: CorvusButton(
                label: 'Finalizar',
                icon: Icons.arrow_forward_rounded,
                isLoading: isUploading,
                onPressed: isUploading ? null : onFinish),
          ),
        ],
      ),
    );
  }
}

// ─── SelectedDisciplineCard ───────────────────────────────────────────────────

class _SelectedDisciplineCard extends StatelessWidget {
  final String discipline, subdiscipline;
  final VoidCallback onChange;

  const _SelectedDisciplineCard(
      {required this.discipline,
      required this.subdiscipline,
      required this.onChange});

  @override
  Widget build(BuildContext context) {
    final label =
        subdiscipline.isNotEmpty ? '$discipline · $subdiscipline' : discipline;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(13)),
            child: Icon(
                _kDisciplineIcons[discipline] ?? Icons.auto_awesome_rounded,
                color: AppColors.primary,
                size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('◈ ORIGEN',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.36),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0)),
                const SizedBox(height: 4),
                Text(label,
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onChange,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: Text('Cambiar',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ImagePickerCard ──────────────────────────────────────────────────────────

class _ImagePickerCard extends StatefulWidget {
  final PickedImage? coverImage;
  final String? coverUrl;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _ImagePickerCard(
      {required this.coverImage,
      this.coverUrl,
      required this.onTap,
      this.onRemove});

  @override
  State<_ImagePickerCard> createState() => _ImagePickerCardState();
}

class _ImagePickerCardState extends State<_ImagePickerCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final coverUrl = widget.coverUrl;
    final hasImage =
        widget.coverImage != null || (coverUrl != null && coverUrl.isNotEmpty);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: hasImage
                  ? AppColors.primary.withValues(alpha: _hovered ? 0.90 : 0.55)
                  : Colors.white.withValues(alpha: _hovered ? 0.16 : 0.08),
              width: hasImage ? 1.5 : 1,
            ),
          ),
          child: hasImage
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(23),
                      child: widget.coverImage != null
                          ? Image.memory(widget.coverImage!.bytes,
                              fit: BoxFit.cover)
                          : Image.network(
                              coverUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.white.withValues(alpha: 0.22),
                                  size: 32,
                                ),
                              ),
                            ),
                    ),
                    AnimatedOpacity(
                      opacity: _hovered ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 180),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(23),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.72)
                              ],
                            ),
                          ),
                          alignment: Alignment.bottomCenter,
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _OverlayAction(
                                  icon: Icons.photo_library_outlined,
                                  label: 'Cambiar',
                                  onTap: widget.onTap),
                              if (widget.onRemove != null) ...[
                                const SizedBox(width: 10),
                                _OverlayAction(
                                    icon: Icons.delete_outline_rounded,
                                    label: 'Eliminar',
                                    onTap: widget.onRemove!,
                                    danger: true),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedScale(
                      scale: _hovered ? 1.08 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white
                              .withValues(alpha: _hovered ? 0.09 : 0.045),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.10)),
                        ),
                        child: Icon(Icons.add_photo_alternate_outlined,
                            color: Colors.white
                                .withValues(alpha: _hovered ? 0.60 : 0.30),
                            size: 30),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Añadir imagen principal',
                        style: TextStyle(
                            color: Colors.white
                                .withValues(alpha: _hovered ? 0.95 : 0.75),
                            fontSize: 15,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text('JPG, PNG — recomendado 1200 px',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('Haz clic para explorar',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.22),
                            fontSize: 11)),
                  ],
                ),
        ),
      ),
    );
  }
}

class _OverlayAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _OverlayAction(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFE63946) : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: danger
              ? const Color(0xFFE63946).withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

// ─── WorkPreviewCard ──────────────────────────────────────────────────────────

class _WorkPreviewCard extends StatelessWidget {
  final String title, discipline, subdiscipline, authorName;
  final PickedImage? coverImage;
  final String? coverUrl;

  const _WorkPreviewCard(
      {required this.title,
      required this.discipline,
      required this.subdiscipline,
      required this.coverImage,
      this.coverUrl,
      required this.authorName});

  @override
  Widget build(BuildContext context) {
    final displayTitle = title.isNotEmpty ? title : 'Sin título';
    final tag =
        subdiscipline.isNotEmpty ? '$discipline · $subdiscipline' : discipline;

    final hasRemoteCover = coverUrl != null && coverUrl!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Text('◈ PRESENTACIÓN',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.30),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0)),
          ),
          Container(
            height: 140,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: coverImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Image.memory(coverImage!.bytes,
                        fit: BoxFit.cover, width: double.infinity))
                : hasRemoteCover
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Image.network(
                          coverUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) => Center(
                            child: Icon(Icons.broken_image_outlined,
                                color: Colors.white.withValues(alpha: 0.15),
                                size: 32),
                          ),
                        ),
                      )
                    : Center(
                        child: Icon(Icons.image_not_supported_outlined,
                            color: Colors.white.withValues(alpha: 0.15),
                            size: 32)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: title.isNotEmpty
                        ? AppColors.textPrimary
                        : Colors.white.withValues(alpha: 0.28),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    fontStyle:
                        title.isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.22)),
                      ),
                      child: Text(tag,
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800)),
                    ),
                    const Spacer(),
                    if (authorName.isNotEmpty)
                      Text(authorName,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.38),
                              fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── EditorPanel ─────────────────────────────────────────────────────────────

class _EditorPanel extends StatelessWidget {
  final Widget child;
  const _EditorPanel({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: AppColors.card.withValues(alpha: 0.66),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: SingleChildScrollView(child: child),
      );
}

// ─── SectionTitle ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String eyebrow, title, subtitle;
  final bool compact;

  const _SectionTitle(
      {required this.eyebrow,
      required this.title,
      required this.subtitle,
      this.compact = false});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eyebrow,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2)),
          SizedBox(height: compact ? 6 : 10),
          Text(title,
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: compact ? 20 : 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6)),
          const SizedBox(height: 5),
          Text(subtitle,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.42),
                  fontSize: 13,
                  height: 1.35)),
        ],
      );
}

// ─── ToggleTile ───────────────────────────────────────────────────────────────

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? activeColor;

  const _ToggleTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.value,
      required this.onChanged,
      this.activeColor});

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Icon(icon,
              color: value ? color : Colors.white.withValues(alpha: 0.42),
              size: 21),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.38),
                        fontSize: 12,
                        height: 1.35)),
              ],
            ),
          ),
          Switch(value: value, activeThumbColor: color, onChanged: onChanged),
        ],
      ),
    );
  }
}

// ─── ChipGroup ────────────────────────────────────────────────────────────────

class _ChipGroup extends StatelessWidget {
  final String label;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;

  const _ChipGroup(
      {required this.label,
      required this.options,
      required this.selected,
      required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.38),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.9)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final isSelected = selected == opt;
            return GestureDetector(
              onTap: () => onSelect(isSelected ? '' : opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.14)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.65)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  opt,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.58),
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ─── RadioGroup ───────────────────────────────────────────────────────────────

class _RadioGroup extends StatelessWidget {
  final String label;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;

  const _RadioGroup(
      {required this.label,
      required this.options,
      required this.selected,
      required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.38),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.9)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: options.map((opt) {
            final isSelected = selected == opt;
            return GestureDetector(
              onTap: () => onSelect(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.07),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.white.withValues(alpha: 0.28),
                            width: 1.5),
                      ),
                      child: isSelected
                          ? Center(
                              child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle)))
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      opt,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.90)
                            : Colors.white.withValues(alpha: 0.50),
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
