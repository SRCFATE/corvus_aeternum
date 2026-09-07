import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/atelier_models.dart';
import '../../providers/atelier_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/conspiration_provider.dart';
import '../../shared/layout/corvus_page.dart';
import '../../shared/widgets/corvus_crow_animations.dart';
import '../../shared/widgets/corvus_markdown_preview.dart';
import 'billing/presentation/export_sheet.dart';
import 'billing/widgets/plan_badge.dart';
import 'billing/widgets/usage_indicator.dart';
import 'atelier_catalog.dart';
import 'atelier_ui.dart';
import 'atelier_element_editor.dart';
import 'atelier_review_workspace.dart';
import 'character_editor_page.dart';
import 'mundiarium_workspace.dart';
import 'universe_editor_page.dart';

enum AtelierInitialSection {
  home,
  studio,
  mundiarium,
  archive,
  review,
  publication,
}

enum _AtelierSection {
  inicio,
  studio,
  mundiarium,
  archivo,
  revision,
  publicacion,
}

extension _AtelierSectionMeta on _AtelierSection {
  String get label => switch (this) {
        _AtelierSection.inicio => 'Inicio',
        _AtelierSection.studio => 'Studio',
        _AtelierSection.mundiarium => 'Mundiarium',
        _AtelierSection.archivo => 'Archivo',
        _AtelierSection.revision => 'Revision',
        _AtelierSection.publicacion => 'Publicacion',
      };

  IconData get icon => switch (this) {
        _AtelierSection.inicio => Icons.dashboard_customize_outlined,
        _AtelierSection.studio => Icons.edit_note_rounded,
        _AtelierSection.mundiarium => Icons.public_rounded,
        _AtelierSection.archivo => Icons.account_tree_outlined,
        _AtelierSection.revision => Icons.fact_check_outlined,
        _AtelierSection.publicacion => Icons.rocket_launch_outlined,
      };
}


class AtelierPage extends StatefulWidget {
  final Map<String, dynamic>? initialProject;
  final AtelierInitialSection initialSection;

  const AtelierPage({
    super.key,
    this.initialProject,
    this.initialSection = AtelierInitialSection.home,
  });

  @override
  State<AtelierPage> createState() => _AtelierPageState();
}

class _AtelierPageState extends State<AtelierPage> {
  final _searchController = TextEditingController();
  late _AtelierSection _section;
  String? _loadedProfileId;
  String _query = '';
  bool _handledInitialProject = false;

  @override
  void initState() {
    super.initState();
    _section = _fromInitialSection(widget.initialSection);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profileId = context.watch<AuthProvider>().profile?.id;
    if (profileId != null && profileId != _loadedProfileId) {
      _loadedProfileId = profileId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<AtelierProvider>().load(profileId);
      });
    }
  }

  @override
  void didUpdateWidget(covariant AtelierPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialProject != oldWidget.initialProject) {
      _handledInitialProject = false;
    }
    if (widget.initialSection != oldWidget.initialSection) {
      _section = _fromInitialSection(widget.initialSection);
    }
  }

  _AtelierSection _fromInitialSection(AtelierInitialSection section) {
    return switch (section) {
      AtelierInitialSection.home => _AtelierSection.inicio,
      AtelierInitialSection.studio => _AtelierSection.studio,
      AtelierInitialSection.mundiarium => _AtelierSection.mundiarium,
      AtelierInitialSection.archive => _AtelierSection.archivo,
      AtelierInitialSection.review => _AtelierSection.revision,
      AtelierInitialSection.publication => _AtelierSection.publicacion,
    };
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<ConspirationProvider>().accent;
    final auth = context.watch<AuthProvider>();
    final atelier = context.watch<AtelierProvider>();
    final profile = auth.profile;
    final compact = MediaQuery.sizeOf(context).width < 760;
    _maybeOpenInitialProjectDialog(profile?.id, atelier);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CorvusPage(
        padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 40),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 18, 0, 16),
                  child: _AtelierTopBar(
                    accent: accent,
                    section: _section,
                    query: _query,
                    controller: _searchController,
                    onQueryChanged: (value) {
                      setState(() => _query = value.trim());
                    },
                    onCreateProject: profile == null
                        ? null
                        : () => _openProjectDialog(profileId: profile.id),
                    onCreateUniverse:
                        atelier.activeProject == null || profile == null
                            ? null
                            : () => _openUniverseDialog(
                                  profileId: profile.id,
                                  projectId: atelier.activeProject!.id,
                                ),
                    onCreateNode:
                        atelier.activeProject == null || profile == null
                            ? null
                            : () => _openNodeDialog(
                                  profileId: profile.id,
                                  projectId: atelier.activeProject!.id,
                                  initialKind: _defaultKindForSection(),
                                ),
                    onExport: atelier.activeProject == null
                        ? null
                        : _openExportDialog,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Builder(
                builder: (context) {
                  if (profile == null) {
                    return AtelierMessagePanel(
                      accent: accent,
                      icon: Icons.lock_outline_rounded,
                      title: 'Inicia sesion para usar Atelier',
                      message:
                          'Atelier guarda proyectos privados por perfil. Cuando haya sesion activa se cargara tu espacio creativo.',
                    );
                  }

                  if (atelier.loading) {
                    return SizedBox(
                      height: 320,
                      child: Center(
                        child: CorvusCrowLoader(
                          color: accent,
                          label: 'Desplegando el atelier…',
                        ),
                      ),
                    );
                  }

                  if (atelier.schemaMissing) {
                    return _SchemaSetupPanel(
                      accent: accent,
                      onRetry: () => atelier.load(profile.id),
                    );
                  }

                  if (atelier.error != null) {
                    return AtelierMessagePanel(
                      accent: accent,
                      icon: Icons.error_outline_rounded,
                      title: 'No se pudo cargar Atelier',
                      message: atelier.error!,
                      actionLabel: 'Reintentar',
                      onAction: () => atelier.load(profile.id),
                    );
                  }

                  if (atelier.activeProject == null) {
                    return _EmptyAtelierPanel(
                      accent: accent,
                      onCreate: () => _openProjectDialog(profileId: profile.id),
                    );
                  }

                  return _AtelierWorkspace(
                    accent: accent,
                    compact: compact,
                    section: _section,
                    query: _query,
                    profileId: profile.id,
                    atelier: atelier,
                    onSectionChanged: (section) {
                      setState(() => _section = section);
                    },
                    onSelectProject: (projectId) {
                      atelier.selectProject(profile.id, projectId);
                    },
                    onCreateProject: () =>
                        _openProjectDialog(profileId: profile.id),
                    onEditProject: () => _openProjectDialog(
                      profileId: profile.id,
                      project: atelier.activeProject,
                    ),
                    onDeleteProject: () => _confirmDeleteProject(profile.id),
                    onCreateNode: (kind) => _openNodeDialog(
                      profileId: profile.id,
                      projectId: atelier.activeProject!.id,
                      initialKind: kind,
                    ),
                    onCreateUniverse: () => _openUniverseDialog(
                      profileId: profile.id,
                      projectId: atelier.activeProject!.id,
                    ),
                    onEditNode: (node) => node.kind == 'universe'
                        ? _openUniverseDialog(
                            profileId: profile.id,
                            projectId: atelier.activeProject!.id,
                            node: node,
                          )
                        : _openNodeDialog(
                            profileId: profile.id,
                            projectId: atelier.activeProject!.id,
                            node: node,
                            initialKind: node.kind,
                          ),
                    onDeleteNode: (node) =>
                        _confirmDeleteNode(profile.id, node),
                    onCreateRelation: () => _openRelationDialog(profile.id),
                    onDeleteRelation: (relation) =>
                        atelier.deleteRelation(profile.id, relation),
                    onCreateVersion: () => _openVersionDialog(profile.id),
                    onProjectSettings: () =>
                        _openPublicationSettings(profile.id),
                    onPreparePublication: _preparePublication,
                    onUpdatePublication: _updatePublication,
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 48)),
          ],
        ),
      ),
    );
  }

  String _defaultKindForSection() {
    final project = context.read<AtelierProvider>().activeProject;
    final branch = branchSpec(branchIdForProject(project));
    return switch (_section) {
      _AtelierSection.studio => branch.primaryKind,
      _AtelierSection.mundiarium => 'universe',
      _AtelierSection.archivo => 'note',
      _AtelierSection.revision => 'event',
      _AtelierSection.publicacion => branch.primaryKind,
      _AtelierSection.inicio => 'note',
    };
  }

  void _maybeOpenInitialProjectDialog(
    String? profileId,
    AtelierProvider atelier,
  ) {
    final initial = widget.initialProject;
    if (_handledInitialProject ||
        profileId == null ||
        initial == null ||
        initial['openProjectDialog'] != true ||
        atelier.loading ||
        atelier.schemaMissing ||
        atelier.error != null) {
      return;
    }

    _handledInitialProject = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openProjectDialog(
        profileId: profileId,
        initialTitle: initial['title'] as String?,
        initialBranch: initial['branch'] as String?,
        initialType: initial['type'] as String?,
        initialGenre: initial['genre'] as String?,
        initialLanguage: initial['language'] as String?,
        initialSourceDiscipline: initial['sourceDiscipline'] as String?,
      );
    });
  }

  Future<void> _openProjectDialog({
    required String profileId,
    AtelierProject? project,
    String? initialTitle,
    String? initialBranch,
    String? initialType,
    String? initialGenre,
    String? initialLanguage,
    String? initialSourceDiscipline,
  }) async {
    String metadataText(String key, [String fallback = '']) {
      if (key == 'description') {
        final description = project?.metadata['description'];
        if (description is String && description.trim().isNotEmpty) {
          return description;
        }
        final short = project?.metadata['synopsis_short'];
        if (short is String && short.trim().isNotEmpty) return short;
        final long = project?.metadata['synopsis_long'];
        if (long is String && long.trim().isNotEmpty) return long;
      }
      final value = project?.metadata[key];
      if (value == null) return fallback;
      if (value is String) return value;
      return '$value';
    }

    bool metadataBool(String key, [bool fallback = false]) {
      final value = project?.metadata[key];
      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true';
      return fallback;
    }

    final metadataControllers = <String, TextEditingController>{};
    TextEditingController metadataController(
      String key, {
      String fallback = '',
    }) {
      return metadataControllers.putIfAbsent(
        key,
        () => TextEditingController(text: metadataText(key, fallback)),
      );
    }

    TextEditingController controllerForField(AeternumMetadataField field) {
      return metadataController(field.key);
    }

    final titleController =
        TextEditingController(text: project?.title ?? initialTitle ?? '');
    final genreController =
        TextEditingController(text: project?.genre ?? initialGenre ?? '');
    final universeController =
        TextEditingController(text: project?.universe ?? '');
    final goalController = TextEditingController(
      text: project?.weeklyWordGoal == null || project!.weeklyWordGoal == 0
          ? ''
          : '${project.weeklyWordGoal}',
    );
    final accent = context.read<ConspirationProvider>().accent;
    const totalSteps = 9;
    var selectedBranch = branchSpec(
      project == null
          ? initialBranch ?? 'writing'
          : branchIdForProject(project),
    ).id;
    var selectedType = project?.type.trim().isNotEmpty == true
        ? project!.type.trim()
        : initialType?.trim().isNotEmpty == true
            ? initialType!.trim()
            : branchSpec(selectedBranch).types.first.name;
    var selectedLanguage = project?.language.trim().isNotEmpty == true
        ? project!.language.trim()
        : initialLanguage?.trim().isNotEmpty == true
            ? initialLanguage!.trim()
            : 'es';
    var status = project?.status ?? 'idea';
    var selectedVisibility = project?.visibility.trim().isNotEmpty == true
        ? project!.visibility.trim()
        : 'private';
    var selectedAgeRating = metadataText('age_rating', 'all');
    var selectedPriority = metadataText('creative_priority', 'normal');
    var selectedLicense = metadataText('license', 'all_rights_reserved');
    var selectedMonetization = metadataText('monetization', 'none');
    var translationAvailable = metadataBool('translation_available');
    var publicProgress = project?.publicProgressEnabled ?? false;
    var technicalProductionEnabled =
        metadataBool('technical_production_enabled');
    var wizardStep = project == null ? 0 : 2;
    AtelierProject? persistedProject = project;
    var savingStep = false;

    // Persiste el proyecto con los valores actuales del wizard. La primera
    // llamada crea el proyecto; las siguientes lo actualizan.
    Future<void> persistProject() async {
      final provider = context.read<AtelierProvider>();
      final selectedBranchSpec = branchSpec(selectedBranch);
      final descriptionText = metadataController('description').text.trim();
      final projectMetadata = {
        if (persistedProject != null) ...persistedProject!.metadata,
        for (final entry in metadataControllers.entries)
          entry.key: entry.value.text.trim(),
        'description': descriptionText,
        'synopsis_short': descriptionText,
        'aeternum_card': true,
        'aeternum_card_version': 1,
        'atelier_branch': selectedBranch,
        'discipline': selectedBranchSpec.label,
        'subdiscipline': selectedType,
        'main_genre': genreController.text.trim(),
        'linked_universe': universeController.text.trim(),
        'age_rating': selectedAgeRating,
        'maturity_level': selectedAgeRating,
        'creative_priority': selectedPriority,
        'license': selectedLicense,
        'monetization': selectedMonetization,
        'translation_available': translationAvailable,
        'publication_visibility': selectedVisibility,
        'technical_production_enabled': technicalProductionEnabled,
        if (initialSourceDiscipline?.trim().isNotEmpty == true)
          'source_discipline': initialSourceDiscipline!.trim(),
      };
      if (persistedProject == null) {
        await provider.createProject(
          profileId: profileId,
          title: titleController.text,
          type: selectedType,
          status: status,
          genre: genreController.text,
          universe: universeController.text,
          language: selectedLanguage,
          visibility: selectedVisibility,
          weeklyWordGoal: int.tryParse(goalController.text.trim()) ?? 0,
          publicProgressEnabled: publicProgress,
          metadata: projectMetadata,
        );
        persistedProject = provider.activeProject;
      } else {
        await provider.updateProject(
          persistedProject!.copyWith(
            title: titleController.text,
            type: selectedType,
            status: status,
            genre: genreController.text,
            universe: universeController.text,
            language: selectedLanguage,
            visibility: selectedVisibility,
            weeklyWordGoal: int.tryParse(goalController.text.trim()) ?? 0,
            publicProgressEnabled: publicProgress,
            metadata: projectMetadata,
          ),
        );
        persistedProject = provider.activeProject ?? persistedProject;
      }
    }

    final saved = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.82),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final branch = branchSpec(selectedBranch);
          final identityCopy = identityCopyForBranch(selectedBranch);
          final stepTitle = switch (wizardStep) {
            0 => 'Que quieres crear',
            1 => 'Tipo de obra',
            2 => 'Identidad artistica',
            3 => 'Clasificacion creativa',
            4 => 'Idioma',
            5 => 'Estado y ritmo',
            6 => 'Estructura y tecnica',
            7 => 'Creditos y derechos',
            _ => 'Publicacion y revision',
          };
          final stepSubtitle = switch (wizardStep) {
            0 => 'Elige el taller que mejor acompana esta pieza.',
            1 => 'Define el formato especifico dentro de ${branch.label}.',
            2 => 'Construye el pasaporte base de la obra.',
            3 => 'Datos para descubrimiento, rankings y recomendaciones.',
            4 => 'Idiomas de la obra y disponibilidad de traduccion.',
            5 => 'Produccion, prioridad y cadencia creativa.',
            6 => 'Campos dinamicos segun la disciplina elegida.',
            7 => 'Roles, permisos, titularidad y licencia.',
            _ => 'Destino publico, monetizacion y auditoria final.',
          };
          final technicalStarted =
              disciplineFieldsForBranch(selectedBranch).any((field) {
            return metadataController(field.key).text.trim().isNotEmpty;
          });
          final showTechnicalProduction = technicalProductionEnabled ||
              const {
                'final',
                'lista',
                'lista_para_publicar',
                'publicada',
                'edicion_definitiva',
              }.contains(status);
          final reviewItems = [
            AeternumReviewItem(
              label: 'Identidad',
              detail: titleController.text.trim().isNotEmpty
                  ? 'Titulo listo.'
                  : 'Falta el titulo de la obra.',
              done: titleController.text.trim().isNotEmpty,
            ),
            AeternumReviewItem(
              label: 'Clasificacion',
              detail: genreController.text.trim().isNotEmpty
                  ? 'Genero principal definido.'
                  : 'Falta genero, estilo o categoria principal.',
              done: genreController.text.trim().isNotEmpty,
            ),
            AeternumReviewItem(
              label: 'Portada',
              detail: metadataController('cover_url').text.trim().isNotEmpty
                  ? 'Portada principal registrada.'
                  : 'La obra aun no tiene portada.',
              done: metadataController('cover_url').text.trim().isNotEmpty,
            ),
            AeternumReviewItem(
              label: 'Ficha tecnica',
              detail: technicalStarted
                  ? 'Campos tecnicos de la disciplina iniciados.'
                  : 'Falta informacion tecnica de la disciplina.',
              done: technicalStarted,
            ),
            AeternumReviewItem(
              label: 'Derechos',
              detail: metadataController('rights_holder').text.trim().isNotEmpty
                  ? 'Titular de derechos definido.'
                  : 'Falta titular de derechos.',
              done: metadataController('rights_holder').text.trim().isNotEmpty,
            ),
            AeternumReviewItem(
              label: 'Publicacion',
              detail: selectedVisibility == 'private'
                  ? 'Quedara como obra privada.'
                  : 'Visibilidad configurada.',
              done: selectedVisibility.trim().isNotEmpty,
            ),
          ];
          return _ProjectWizardDialog(
            title: stepTitle,
            subtitle: stepSubtitle,
            accent: accent,
            step: wizardStep,
            totalSteps: totalSteps,
            canGoBack: wizardStep > 0,
            isLastStep: wizardStep == totalSteps - 1,
            isSavingStep: savingStep,
            onSaveStep: wizardStep == 0
                ? null
                : () async {
                    if (titleController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Añade un título a la obra antes de guardar.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    setDialogState(() => savingStep = true);
                    try {
                      await persistProject();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Progreso guardado'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('No se pudo guardar: $error'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } finally {
                      if (context.mounted) {
                        setDialogState(() => savingStep = false);
                      }
                    }
                  },
            onBack: () => setDialogState(() {
              if (wizardStep > 0) wizardStep--;
            }),
            onNext: () => setDialogState(() {
              if (wizardStep < totalSteps - 1) wizardStep++;
            }),
            content: switch (wizardStep) {
              0 => [
                  _ProjectBranchPicker(
                    selected: selectedBranch,
                    onSelected: (value) {
                      setDialogState(() {
                        selectedBranch = value;
                        selectedType = branchSpec(value).types.first.name;
                        genreController.clear();
                        metadataController('subgenre').clear();
                        wizardStep = 1;
                      });
                    },
                  ),
                ],
              1 => [
                  _ProjectFieldGroup(
                    title: branch.label,
                    icon: branch.icon,
                    accent: branch.color,
                    child: Text(
                      branch.description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.48),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                  _ProjectTypePicker(
                    selected: selectedType,
                    branchId: selectedBranch,
                    accent: accent,
                    onSelected: (value) {
                      setDialogState(() => selectedType = value);
                    },
                  ),
                ],
              2 => [
                  _ProjectFieldGroup(
                    title: 'Ficha Aeternum',
                    icon: identityCopy.icon,
                    accent: accent,
                    child: Column(
                      children: [
                        _CoverImageSelector(
                          controller: metadataController('cover_url'),
                          accent: accent,
                        ),
                        const SizedBox(height: 16),
                        _DialogTextField(
                          controller: titleController,
                          label: identityCopy.titleLabel,
                        ),
                        const SizedBox(height: 12),
                        _AeternumFieldGrid(
                          fields: const [
                            AeternumMetadataField(
                              key: 'subtitle',
                              label: 'Subtitulo (opcional)',
                            ),
                            AeternumMetadataField(
                              key: 'description',
                              label: 'Descripcion',
                              minLines: 4,
                              maxLines: 7,
                            ),
                          ],
                          controllerFor: controllerForField,
                        ),
                      ],
                    ),
                  ),
                ],
              3 => [
                  _ProjectFieldGroup(
                    title: 'Clasificacion creativa',
                    icon: Icons.category_outlined,
                    accent: accent,
                    child: Column(
                      children: [
                        _DialogTextField(
                          controller: genreController,
                          label: identityCopy.genreLabel,
                          suggestions: genreSuggestionsForBranch(
                            selectedBranch,
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                        const SizedBox(height: 12),
                        _AeternumFieldGrid(
                          fields: const [
                            AeternumMetadataField(
                              key: 'subgenre',
                              label: 'Subgenero',
                            ),
                            AeternumMetadataField(
                              key: 'style',
                              label: 'Estilo',
                            ),
                            AeternumMetadataField(
                              key: 'artistic_movement',
                              label: 'Movimiento artistico',
                            ),
                            AeternumMetadataField(
                              key: 'creative_format',
                              label: 'Formato',
                            ),
                            AeternumMetadataField(
                              key: 'target_audience',
                              label: 'Publico objetivo',
                            ),
                            AeternumMetadataField(
                              key: 'primary_tags',
                              label: 'Etiquetas principales',
                              minLines: 2,
                              maxLines: 3,
                            ),
                            AeternumMetadataField(
                              key: 'secondary_tags',
                              label: 'Etiquetas secundarias',
                              minLines: 2,
                              maxLines: 3,
                            ),
                            AeternumMetadataField(
                              key: 'content_warnings',
                              label: 'Advertencias de contenido',
                              minLines: 2,
                              maxLines: 4,
                            ),
                          ],
                          controllerFor: controllerForField,
                          suggestionsFor: (field) =>
                              classificationSuggestionsForField(
                            field.key,
                            selectedBranch,
                            genreController.text,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _SelectionOptionPicker(
                          options: ageRatingOptions,
                          selected: selectedAgeRating,
                          onSelected: (value) {
                            setDialogState(() => selectedAgeRating = value);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              4 => [
                  _ProjectFieldGroup(
                    title: 'Idioma',
                    icon: Icons.language_rounded,
                    accent: accent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ProjectLanguagePicker(
                          selected: selectedLanguage,
                          accent: accent,
                          onSelected: (value) {
                            setDialogState(() => selectedLanguage = value);
                          },
                        ),
                        const SizedBox(height: 14),
                        _AeternumFieldGrid(
                          fields: const [
                            AeternumMetadataField(
                              key: 'secondary_languages',
                              label: 'Idiomas secundarios',
                            ),
                          ],
                          controllerFor: controllerForField,
                        ),
                        const SizedBox(height: 14),
                        _AeternumSwitchTile(
                          title: 'Disponible para traduccion',
                          subtitle:
                              'Permite marcar esta obra como candidata a versiones localizadas.',
                          value: translationAvailable,
                          accent: accent,
                          onChanged: (value) {
                            setDialogState(() => translationAvailable = value);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              5 => [
                  _ProjectFieldGroup(
                    title: identityCopy.rhythmTitle,
                    icon: Icons.track_changes_rounded,
                    accent: accent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ProjectStatusPicker(
                          selected: status,
                          onSelected: (value) {
                            setDialogState(() => status = value);
                          },
                        ),
                        const SizedBox(height: 16),
                        _AeternumFieldGrid(
                          fields: [
                            AeternumMetadataField(
                              key: 'weekly_goal_label',
                              label: identityCopy.goalLabel,
                              keyboardType: TextInputType.number,
                            ),
                            const AeternumMetadataField(
                              key: 'daily_goal',
                              label: 'Objetivo diario',
                              keyboardType: TextInputType.number,
                            ),
                            const AeternumMetadataField(
                              key: 'target_date',
                              label: 'Fecha objetivo',
                              datePicker: true,
                            ),
                            const AeternumMetadataField(
                              key: 'creative_streak',
                              label: 'Racha creativa (dias)',
                              keyboardType: TextInputType.number,
                            ),
                            const AeternumMetadataField(
                              key: 'rhythm_notes',
                              label: 'Notas de ritmo y seguimiento',
                              minLines: 3,
                              maxLines: 5,
                            ),
                          ],
                          controllerFor: (field) {
                            if (field.key == 'weekly_goal_label') {
                              return goalController;
                            }
                            return controllerForField(field);
                          },
                        ),
                        const SizedBox(height: 16),
                        _SelectionOptionPicker(
                          options: priorityOptions,
                          selected: selectedPriority,
                          onSelected: (value) {
                            setDialogState(() => selectedPriority = value);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              6 => [
                  _ProjectFieldGroup(
                    title: 'Estructura ${branch.label}',
                    icon: branch.icon,
                    accent: branch.color,
                    child: _AeternumFieldGrid(
                      fields: disciplineFieldsForBranch(selectedBranch),
                      controllerFor: controllerForField,
                    ),
                  ),
                ],
              7 => [
                  _ProjectFieldGroup(
                    title: 'Creditos y colaboradores',
                    icon: Icons.groups_outlined,
                    accent: accent,
                    child: _AeternumFieldGrid(
                      fields: const [
                        AeternumMetadataField(
                          key: 'primary_creator',
                          label: 'Creador principal',
                        ),
                        AeternumMetadataField(
                          key: 'collaborators',
                          label: 'Colaboradores',
                          minLines: 2,
                          maxLines: 4,
                        ),
                        AeternumMetadataField(
                          key: 'credits',
                          label: 'Creditos por rol',
                          minLines: 3,
                          maxLines: 6,
                        ),
                        AeternumMetadataField(
                          key: 'collaborator_permissions',
                          label: 'Permisos de colaboradores',
                          minLines: 2,
                          maxLines: 4,
                        ),
                      ],
                      controllerFor: controllerForField,
                    ),
                  ),
                  _ProjectFieldGroup(
                    title: 'Derechos y licencias',
                    icon: Icons.verified_user_outlined,
                    accent: accent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SelectionOptionPicker(
                          options: licenseOptions,
                          selected: selectedLicense,
                          onSelected: (value) {
                            setDialogState(() => selectedLicense = value);
                          },
                        ),
                        const SizedBox(height: 14),
                        _AeternumFieldGrid(
                          fields: const [
                            AeternumMetadataField(
                              key: 'rights_holder',
                              label: 'Titular de derechos',
                            ),
                            AeternumMetadataField(
                              key: 'property_type',
                              label: 'Tipo de propiedad',
                            ),
                            AeternumMetadataField(
                              key: 'commercial_use',
                              label: 'Uso comercial permitido',
                            ),
                            AeternumMetadataField(
                              key: 'derivative_use',
                              label: 'Uso derivado permitido',
                            ),
                            AeternumMetadataField(
                              key: 'external_registration',
                              label: 'Registro externo',
                            ),
                            AeternumMetadataField(
                              key: 'identifier_code',
                              label: 'ISBN / ISRC / SKU / codigo interno',
                            ),
                          ],
                          controllerFor: controllerForField,
                        ),
                      ],
                    ),
                  ),
                ],
              _ => [
                  _ProjectFieldGroup(
                    title: 'Publicacion y visibilidad',
                    icon: Icons.rocket_launch_outlined,
                    accent: accent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SelectionOptionPicker(
                          options: visibilityOptions,
                          selected: selectedVisibility,
                          onSelected: (value) {
                            setDialogState(() => selectedVisibility = value);
                          },
                        ),
                        const SizedBox(height: 14),
                        _AeternumSwitchTile(
                          title: 'Atelier Viviente',
                          subtitle:
                              'Permitir progreso publico controlado cuando la obra sea visible.',
                          value: publicProgress,
                          accent: accent,
                          onChanged: (value) {
                            setDialogState(() => publicProgress = value);
                          },
                        ),
                        const SizedBox(height: 14),
                        _AeternumSwitchTile(
                          title: 'Obra terminada o publicada en fisico',
                          subtitle:
                              'Activa la ficha tecnica solo cuando la obra ya este lista para publicar o exista fuera de Corvus.',
                          value: showTechnicalProduction,
                          accent: accent,
                          onChanged: (value) {
                            setDialogState(
                              () => technicalProductionEnabled = value,
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        _AeternumFieldGrid(
                          fields: const [
                            AeternumMetadataField(
                              key: 'publication_plan',
                              label: 'Plan de publicacion',
                            ),
                            AeternumMetadataField(
                              key: 'publish_date',
                              label: 'Fecha de publicacion',
                            ),
                            AeternumMetadataField(
                              key: 'availability',
                              label: 'Disponibilidad',
                            ),
                            AeternumMetadataField(
                              key: 'collection_target',
                              label: 'Agregar a coleccion',
                            ),
                          ],
                          controllerFor: controllerForField,
                        ),
                      ],
                    ),
                  ),
                  _ProjectFieldGroup(
                    title: 'Monetizacion',
                    icon: Icons.payments_outlined,
                    accent: accent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SelectionOptionPicker(
                          options: monetizationOptions,
                          selected: selectedMonetization,
                          onSelected: (value) {
                            setDialogState(() => selectedMonetization = value);
                          },
                        ),
                        const SizedBox(height: 14),
                        _AeternumFieldGrid(
                          fields: const [
                            AeternumMetadataField(
                              key: 'price',
                              label: 'Precio',
                              keyboardType: TextInputType.number,
                            ),
                            AeternumMetadataField(
                              key: 'currency',
                              label: 'Moneda',
                            ),
                            AeternumMetadataField(
                              key: 'stock',
                              label: 'Stock',
                              keyboardType: TextInputType.number,
                            ),
                            AeternumMetadataField(
                              key: 'limited_units',
                              label: 'Unidades limitadas',
                              keyboardType: TextInputType.number,
                            ),
                            AeternumMetadataField(
                              key: 'platform_fee',
                              label: 'Comision de plataforma',
                              keyboardType: TextInputType.number,
                            ),
                            AeternumMetadataField(
                              key: 'production_cost',
                              label: 'Costo de produccion',
                              keyboardType: TextInputType.number,
                            ),
                            AeternumMetadataField(
                              key: 'estimated_margin',
                              label: 'Margen estimado',
                              keyboardType: TextInputType.number,
                            ),
                          ],
                          controllerFor: controllerForField,
                        ),
                      ],
                    ),
                  ),
                  if (showTechnicalProduction)
                    _ProjectFieldGroup(
                      title: 'Tecnica y produccion',
                      icon: Icons.construction_rounded,
                      accent: accent,
                      child: _AeternumFieldGrid(
                        fields: technicalProductionFields,
                        controllerFor: controllerForField,
                      ),
                    ),
                  _ProjectFieldGroup(
                    title: 'Revision final',
                    icon: Icons.fact_check_outlined,
                    accent: accent,
                    child: _AeternumReviewPanel(
                      items: reviewItems,
                      accent: accent,
                    ),
                  ),
                ],
            },
          );
        },
      ),
    );

    if (saved != true || !mounted) return;
    await persistProject();
  }

  Future<void> _openNodeDialog({
    required String profileId,
    required String projectId,
    required String initialKind,
    AtelierNode? node,
  }) async {
    final project = context.read<AtelierProvider>().activeProject;
    final kindLabels = Map<String, String>.from(
        nodeKindsForBranch(branchIdForProject(project)));
    final kind = node?.kind ?? initialKind;
    kindLabels.putIfAbsent(kind, () => kind);

    if (kind == 'character') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => CharacterEditorPage(
            profileId: profileId,
            projectId: projectId,
            node: node,
          ),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AtelierElementEditor(
          profileId: profileId,
          projectId: projectId,
          initialKind: kind,
          kindLabels: kindLabels,
          node: node,
        ),
      ),
    );
  }

  Future<void> _openUniverseDialog({
    required String profileId,
    required String projectId,
    AtelierNode? node,
  }) async {
    final linkedEditorSaved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => UniverseEditorPage(
          profileId: profileId,
          projectId: projectId,
          node: node,
        ),
      ),
    );
    // A false result is reserved for compatibility with the previous editor.
    if (!mounted || linkedEditorSaved != false) return;

    String metadataText(String key) {
      final value = node?.metadata[key];
      if (value == null) return '';
      if (value is String) return value;
      return '$value';
    }

    final metadataControllers = <String, TextEditingController>{};
    TextEditingController metadataController(String key) {
      return metadataControllers.putIfAbsent(
        key,
        () => TextEditingController(text: metadataText(key)),
      );
    }

    TextEditingController controllerForField(AeternumMetadataField field) {
      return metadataController(field.key);
    }

    final titleController = TextEditingController(text: node?.title ?? '');
    final descriptionController = TextEditingController(text: node?.body ?? '');
    final tagsController =
        TextEditingController(text: node?.tags.join(', ') ?? '');
    var status = node?.status ?? 'active';
    var canonStatus = node?.canonStatus ?? 'canon';

    final saved = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.82),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return _AtelierDialog(
            title: node == null ? 'Nuevo universo' : 'Editar universo',
            wide: true,
            content: [
              _ProjectFieldGroup(
                title: 'Identidad del universo',
                icon: Icons.public_rounded,
                accent: AppColors.gold,
                child: Column(
                  children: [
                    _DialogTextField(
                      controller: titleController,
                      label: 'Nombre del universo',
                    ),
                    const SizedBox(height: 12),
                    _DialogTextField(
                      controller: descriptionController,
                      label: 'Descripcion base',
                      minLines: 4,
                      maxLines: 7,
                    ),
                    const SizedBox(height: 12),
                    _AeternumFieldGrid(
                      fields: const [
                        AeternumMetadataField(
                          key: 'world_scope',
                          label: 'Alcance',
                        ),
                        AeternumMetadataField(
                          key: 'creative_format',
                          label: 'Formato matriz',
                        ),
                        AeternumMetadataField(
                          key: 'main_genre',
                          label: 'Genero base',
                        ),
                        AeternumMetadataField(
                          key: 'target_audience',
                          label: 'Publico objetivo',
                        ),
                      ],
                      controllerFor: controllerForField,
                    ),
                  ],
                ),
              ),
              _ProjectFieldGroup(
                title: 'Mundo y continuidad',
                icon: Icons.travel_explore_rounded,
                accent: AppColors.gold,
                child: _AeternumFieldGrid(
                  fields: const [
                    AeternumMetadataField(
                      key: 'world_timeline',
                      label: 'Linea temporal',
                    ),
                    AeternumMetadataField(
                      key: 'internal_period',
                      label: 'Periodo interno',
                    ),
                    AeternumMetadataField(
                      key: 'world_regions',
                      label: 'Regiones',
                      minLines: 2,
                      maxLines: 3,
                    ),
                    AeternumMetadataField(
                      key: 'world_factions',
                      label: 'Facciones',
                      minLines: 2,
                      maxLines: 3,
                    ),
                    AeternumMetadataField(
                      key: 'world_systems',
                      label: 'Sistemas',
                      minLines: 2,
                      maxLines: 3,
                    ),
                    AeternumMetadataField(
                      key: 'world_rules',
                      label: 'Reglas internas',
                      minLines: 3,
                      maxLines: 5,
                    ),
                  ],
                  controllerFor: controllerForField,
                ),
              ),
              _ProjectFieldGroup(
                title: 'Tono y estetica',
                icon: Icons.auto_awesome_outlined,
                accent: AppColors.gold,
                child: _AeternumFieldGrid(
                  fields: const [
                    AeternumMetadataField(
                      key: 'main_theme',
                      label: 'Tema principal',
                    ),
                    AeternumMetadataField(
                      key: 'secondary_themes',
                      label: 'Temas secundarios',
                      minLines: 2,
                      maxLines: 3,
                    ),
                    AeternumMetadataField(
                      key: 'emotional_tone',
                      label: 'Tono emocional',
                    ),
                    AeternumMetadataField(
                      key: 'atmosphere',
                      label: 'Atmosfera',
                    ),
                    AeternumMetadataField(
                      key: 'aesthetic',
                      label: 'Estetica',
                    ),
                    AeternumMetadataField(
                      key: 'symbols',
                      label: 'Simbolos',
                    ),
                    AeternumMetadataField(
                      key: 'inspirations',
                      label: 'Inspiraciones',
                      minLines: 2,
                      maxLines: 4,
                    ),
                    AeternumMetadataField(
                      key: 'references',
                      label: 'Referencias',
                      minLines: 2,
                      maxLines: 4,
                    ),
                  ],
                  controllerFor: controllerForField,
                ),
              ),
              _ProjectFieldGroup(
                title: 'Archivo',
                icon: Icons.inventory_2_outlined,
                accent: AppColors.gold,
                child: Column(
                  children: [
                    _DialogTextField(
                      controller: tagsController,
                      label: 'Etiquetas separadas por coma',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _DialogDropdown(
                            label: 'Estado',
                            value: status,
                            values: const [
                              'idea',
                              'active',
                              'draft',
                              'review',
                              'done',
                              'archived',
                            ],
                            onChanged: (value) =>
                                setDialogState(() => status = value),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DialogDropdown(
                            label: 'Canon',
                            value: canonStatus,
                            values: const [
                              'canon',
                              'semi-canon',
                              'no-canon',
                              'draft',
                              'alternate',
                              'retcon',
                            ],
                            onChanged: (value) =>
                                setDialogState(() => canonStatus = value),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    if (saved != true || !mounted) return;

    final metadata = <String, dynamic>{
      if (node != null) ...node.metadata,
      for (final entry in metadataControllers.entries)
        entry.key: entry.value.text.trim(),
      'universe_card': true,
      'universe_card_version': 1,
    };
    final tags = _parseTags(tagsController.text);
    final provider = context.read<AtelierProvider>();
    if (node == null) {
      await provider.createNode(
        profileId: profileId,
        projectId: projectId,
        kind: 'universe',
        title: titleController.text,
        body: descriptionController.text,
        status: status,
        canonStatus: canonStatus,
        tags: tags,
        metadata: metadata,
      );
    } else {
      await provider.updateNode(
        node.copyWith(
          kind: 'universe',
          title: titleController.text,
          body: descriptionController.text,
          status: status,
          canonStatus: canonStatus,
          tags: tags,
          metadata: metadata,
        ),
      );
    }
  }

  Future<void> _openRelationDialog(String profileId) async {
    final atelier = context.read<AtelierProvider>();
    final project = atelier.activeProject;
    if (project == null || atelier.nodes.length < 2) {
      _showMessage('Necesitas al menos dos elementos para crear una relacion.');
      return;
    }

    String sourceId = atelier.nodes.first.id;
    String targetId = atelier.nodes.skip(1).first.id;
    final typeController = TextEditingController(text: 'menciona');
    final descriptionController = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return _AtelierDialog(
            title: 'Nueva relacion',
            content: [
              _NodeDropdown(
                label: 'Origen',
                value: sourceId,
                nodes: atelier.nodes,
                onChanged: (value) => setDialogState(() => sourceId = value),
              ),
              _DialogTextField(
                controller: typeController,
                label: 'Tipo de relacion',
              ),
              _NodeDropdown(
                label: 'Destino',
                value: targetId,
                nodes: atelier.nodes,
                onChanged: (value) => setDialogState(() => targetId = value),
              ),
              _DialogTextField(
                controller: descriptionController,
                label: 'Descripcion',
                minLines: 2,
                maxLines: 4,
              ),
            ],
          );
        },
      ),
    );

    if (saved != true || sourceId == targetId) return;
    await atelier.createRelation(
      profileId: profileId,
      projectId: project.id,
      sourceNodeId: sourceId,
      relationType: typeController.text,
      targetNodeId: targetId,
      description: descriptionController.text,
    );
  }

  Future<void> _openVersionDialog(String profileId) async {
    final atelier = context.read<AtelierProvider>();
    final project = atelier.activeProject;
    if (project == null) return;
    final labelController =
        TextEditingController(text: 'v${atelier.versions.length + 1}');
    final descriptionController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _AtelierDialog(
        title: 'Crear version',
        content: [
          _DialogTextField(controller: labelController, label: 'Etiqueta'),
          _DialogTextField(
            controller: descriptionController,
            label: 'Descripcion del cambio',
            minLines: 3,
            maxLines: 5,
          ),
        ],
      ),
    );
    if (saved == true) {
      await atelier.createVersionSnapshot(
        profileId: profileId,
        projectId: project.id,
        label: labelController.text,
        description: descriptionController.text,
      );
    }
  }

  Future<void> _openPublicationSettings(String profileId) async {
    final atelier = context.read<AtelierProvider>();
    final project = atelier.activeProject;
    if (project == null) return;
    final synopsisController = TextEditingController(
      text: (project.metadata['description'] as String?) ??
          (project.metadata['synopsis_short'] as String?) ??
          '',
    );
    final coverController = TextEditingController(
      text: project.metadata['cover_url'] as String? ?? '',
    );
    final ageController = TextEditingController(
      text: project.metadata['age_rating'] as String? ?? '',
    );
    var publicProgress = project.publicProgressEnabled;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return _AtelierDialog(
            title: 'Metadatos de publicacion',
            wide: true,
            content: [
              _DialogTextField(
                controller: synopsisController,
                label: 'Descripcion',
                minLines: 3,
                maxLines: 5,
              ),
              _DialogTextField(
                controller: coverController,
                label: 'URL de portada',
              ),
              _DialogTextField(
                controller: ageController,
                label: 'Clasificacion por edad',
              ),
              SwitchListTile(
                value: publicProgress,
                onChanged: (value) =>
                    setDialogState(() => publicProgress = value),
                title: const Text('Atelier Viviente'),
                subtitle: const Text('Permitir progreso publico controlado'),
              ),
            ],
          );
        },
      ),
    );

    if (saved != true) return;
    await atelier.updateProject(
      project.copyWith(
        publicProgressEnabled: publicProgress,
        metadata: {
          ...project.metadata,
          'description': synopsisController.text.trim(),
          'synopsis_short': synopsisController.text.trim(),
          'cover_url': coverController.text.trim(),
          'age_rating': ageController.text.trim(),
        },
      ),
    );
  }

  /// La exportacion dejo de ser un volcado JSON: ahora es la hoja de formatos,
  /// con Markdown, TXT y JSON siempre abiertos —llevarse la obra no se cobra— y
  /// los formatos de produccion con su puerta.
  Future<void> _openExportDialog() async {
    final profile = context.read<AuthProvider>().profile;
    await showAtelierExportSheet(
      context,
      workspace: context.read<AtelierProvider>().workspace,
      author: profile?.displayName.trim().isNotEmpty == true
          ? profile!.displayName.trim()
          : '',
    );
  }

  Future<void> _preparePublication() async {
    final atelier = context.read<AtelierProvider>();
    if (!atelier.canPreparePublication) {
      _showMessage('Completa el checklist antes de preparar la publicacion.');
      return;
    }
    try {
      final workId = await atelier.preparePublication();
      if (!mounted) return;
      if (workId == null) {
        _showMessage('No se pudo encontrar una obra activa para publicar.');
        return;
      }
      _showMessage('Borrador listo para completar publicacion.');
      context.push('/upload', extra: {'draftId': workId});
    } catch (error) {
      if (!mounted) return;
      _showMessage('No se pudo preparar la publicacion: $error');
    }
  }

  // Publicación por entregas: vuelca los capítulos nuevos en la obra ya
  // publicada sin repetir el sello.
  Future<void> _updatePublication() async {
    final atelier = context.read<AtelierProvider>();
    try {
      final result = await atelier.syncPublication();
      if (!mounted) return;
      if (result == null) {
        _showMessage(
            'No hay una obra vinculada todavía. Usa "Preparar" primero.');
        return;
      }
      if (result.isPublished) {
        await showCrowFlight(context);
        if (!mounted) return;
        final chapters = result.chapters == 1
            ? '1 capitulo'
            : '${result.chapters} capitulos';
        _showMessage('Publicacion actualizada · $chapters en el archivo.');
      } else {
        _showMessage(
            'Borrador actualizado (${result.chapters} elementos). Termina el sello para publicarlo.');
        context.push('/upload', extra: {'draftId': result.workId});
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage('No se pudo actualizar la publicacion: $error');
    }
  }

  Future<void> _confirmDeleteProject(String profileId) async {
    final atelier = context.read<AtelierProvider>();
    final project = atelier.activeProject;
    if (project == null) return;
    final confirmed = await _confirm(
      'Eliminar obra',
      'Se eliminara "${project.title}" y todos sus nodos de Atelier.',
    );
    if (confirmed == true) await atelier.deleteActiveProject(profileId);
  }

  Future<void> _confirmDeleteNode(String profileId, AtelierNode node) async {
    final confirmed = await _confirm(
      'Eliminar elemento',
      'Se eliminara "${node.title}" y sus relaciones.',
    );
    if (confirmed == true && mounted) {
      await context.read<AtelierProvider>().deleteNode(profileId, node);
    }
  }

  Future<bool?> _confirm(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  List<String> _parseTags(String raw) {
    return raw
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.cardElevated,
      ),
    );
  }
}

class _AtelierTopBar extends StatelessWidget {
  final Color accent;
  final _AtelierSection section;
  final String query;
  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback? onCreateProject;
  final VoidCallback? onCreateUniverse;
  final VoidCallback? onCreateNode;
  final VoidCallback? onExport;

  const _AtelierTopBar({
    required this.accent,
    required this.section,
    required this.query,
    required this.controller,
    required this.onQueryChanged,
    required this.onCreateProject,
    required this.onCreateUniverse,
    required this.onCreateNode,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final (titleText, subtitleText, titleIcon) = switch (section) {
      _AtelierSection.mundiarium => (
          'Mundiarium',
          'Universos y continuidad transmedia',
          Icons.public_rounded,
        ),
      _AtelierSection.archivo => (
          'Archivo Aeternum',
          'Ideas, referencias y memoria creativa',
          Icons.account_tree_outlined,
        ),
      _ => (
          'Atelier',
          'Centro creativo privado',
          Icons.auto_stories_rounded,
        ),
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final title = Row(
          children: [
            AtelierIconBox(icon: titleIcon, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        final search = _AtelierSearchField(
          controller: controller,
          query: query,
          accent: accent,
          onChanged: onQueryChanged,
        );

        final actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // El plan se ve donde se trabaja, sin ocupar sitio y sin pedir
            // nada. Free tambien luce el suyo.
            const PlanBadge(compact: true),
            const SizedBox(width: 10),
            AtelierIconAction(
              icon: Icons.create_new_folder_outlined,
              tooltip: 'Nueva obra',
              onTap: onCreateProject,
            ),
            const SizedBox(width: 8),
            AtelierIconAction(
              icon: Icons.public_rounded,
              tooltip: 'Nuevo universo',
              onTap: onCreateUniverse,
            ),
            const SizedBox(width: 8),
            AtelierIconAction(
              icon: Icons.add_rounded,
              tooltip: 'Nuevo elemento',
              onTap: onCreateNode,
            ),
            const SizedBox(width: 8),
            AtelierIconAction(
              icon: Icons.download_outlined,
              tooltip: 'Exportar',
              onTap: onExport,
            ),
          ],
        );

        if (compact) {
          return Column(
            children: [
              title,
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: search),
                const SizedBox(width: 8),
                actions
              ]),
            ],
          );
        }

        return Row(
          children: [
            SizedBox(width: 320, child: title),
            const SizedBox(width: 18),
            Expanded(child: search),
            const SizedBox(width: 12),
            actions,
          ],
        );
      },
    );
  }
}

class _AtelierWorkspace extends StatelessWidget {
  final Color accent;
  final bool compact;
  final _AtelierSection section;
  final String query;
  final String profileId;
  final AtelierProvider atelier;
  final ValueChanged<_AtelierSection> onSectionChanged;
  final ValueChanged<String> onSelectProject;
  final VoidCallback onCreateProject;
  final VoidCallback onEditProject;
  final VoidCallback onDeleteProject;
  final VoidCallback onCreateUniverse;
  final ValueChanged<String> onCreateNode;
  final ValueChanged<AtelierNode> onEditNode;
  final ValueChanged<AtelierNode> onDeleteNode;
  final VoidCallback onCreateRelation;
  final ValueChanged<AtelierRelation> onDeleteRelation;
  final VoidCallback onCreateVersion;
  final VoidCallback onProjectSettings;
  final VoidCallback onPreparePublication;
  final VoidCallback onUpdatePublication;

  const _AtelierWorkspace({
    required this.accent,
    required this.compact,
    required this.section,
    required this.query,
    required this.profileId,
    required this.atelier,
    required this.onSectionChanged,
    required this.onSelectProject,
    required this.onCreateProject,
    required this.onEditProject,
    required this.onDeleteProject,
    required this.onCreateUniverse,
    required this.onCreateNode,
    required this.onEditNode,
    required this.onDeleteNode,
    required this.onCreateRelation,
    required this.onDeleteRelation,
    required this.onCreateVersion,
    required this.onProjectSettings,
    required this.onPreparePublication,
    required this.onUpdatePublication,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (query.isNotEmpty) ...[
          _SearchResultsPanel(
            accent: accent,
            results: atelier.search(query),
            onEditNode: onEditNode,
          ),
          const SizedBox(height: 14),
        ],
        switch (section) {
          _AtelierSection.inicio => _HomeView(
              accent: accent,
              atelier: atelier,
              onCreateNode: onCreateNode,
              onCreateUniverse: onCreateUniverse,
              onEditNode: onEditNode,
              onSectionChanged: onSectionChanged,
            ),
          _AtelierSection.studio => _StudioView(
              accent: accent,
              atelier: atelier,
              onCreateNode: onCreateNode,
              onEditNode: onEditNode,
              onDeleteNode: onDeleteNode,
              onCreateVersion: onCreateVersion,
            ),
          _AtelierSection.mundiarium => _MundiariumView(
              accent: accent,
              atelier: atelier,
              onCreateUniverse: onCreateUniverse,
              onCreateNode: onCreateNode,
              onEditNode: onEditNode,
              onDeleteNode: onDeleteNode,
              onCreateRelation: onCreateRelation,
              onDeleteRelation: onDeleteRelation,
            ),
          _AtelierSection.archivo => _ArchiveView(
              accent: accent,
              atelier: atelier,
              onCreateNode: onCreateNode,
              onEditNode: onEditNode,
              onDeleteNode: onDeleteNode,
            ),
          _AtelierSection.revision => _ReviewView(
              accent: accent,
              atelier: atelier,
            ),
          _AtelierSection.publicacion => _PublicationView(
              accent: accent,
              atelier: atelier,
              onSettings: onProjectSettings,
              onPreparePublication: onPreparePublication,
              onUpdatePublication: onUpdatePublication,
            ),
        },
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProjectRail(
            accent: accent,
            atelier: atelier,
            compact: true,
            onSelectProject: onSelectProject,
            onCreateProject: onCreateProject,
            onEditProject: onEditProject,
            onDeleteProject: onDeleteProject,
          ),
          const SizedBox(height: 12),
          _SectionNav(
            accent: accent,
            selected: section,
            compact: true,
            onChanged: onSectionChanged,
          ),
          const SizedBox(height: 14),
          content,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 260,
          child: Column(
            children: [
              _ProjectRail(
                accent: accent,
                atelier: atelier,
                compact: false,
                onSelectProject: onSelectProject,
                onCreateProject: onCreateProject,
                onEditProject: onEditProject,
                onDeleteProject: onDeleteProject,
              ),
              const SizedBox(height: 12),
              _SectionNav(
                accent: accent,
                selected: section,
                compact: false,
                onChanged: onSectionChanged,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: content),
      ],
    );
  }
}

class _HomeView extends StatelessWidget {
  final Color accent;
  final AtelierProvider atelier;
  final ValueChanged<String> onCreateNode;
  final VoidCallback onCreateUniverse;
  final ValueChanged<AtelierNode> onEditNode;
  final ValueChanged<_AtelierSection> onSectionChanged;

  const _HomeView({
    required this.accent,
    required this.atelier,
    required this.onCreateNode,
    required this.onCreateUniverse,
    required this.onEditNode,
    required this.onSectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final project = atelier.activeProject!;
    final branch = branchSpec(branchIdForProject(project));
    final recent = atelier.nodes.take(6).toList();
    final studioCount = atelier.nodes
        .where((node) => branch.studioKinds.contains(node.kind))
        .length;
    final primaryMetric =
        branch.id == 'writing' ? atelier.wordCount : studioCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AtelierPanel(
          accent: accent,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 700;
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AtelierEyebrow('Obra activa', color: accent),
                  const SizedBox(height: 8),
                  Text(
                    project.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${branch.label} / ${project.type} / ${project.status} / ${project.visibility}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AtelierActionButton(
                    label: branch.primaryAction,
                    icon: Icons.add_rounded,
                    accent: accent,
                    onTap: () => onCreateNode(branch.primaryKind),
                  ),
                  AtelierSoftButton(
                    label: 'Abrir taller',
                    icon: branch.icon,
                    onTap: () => onSectionChanged(_AtelierSection.studio),
                  ),
                  AtelierSoftButton(
                    label: 'Nuevo universo',
                    icon: Icons.public_rounded,
                    onTap: onCreateUniverse,
                  ),
                  AtelierSoftButton(
                    label: 'Nueva nota',
                    icon: Icons.note_add_outlined,
                    onTap: () => onCreateNode('note'),
                  ),
                  AtelierSoftButton(
                    label: 'Revisar',
                    icon: Icons.fact_check_outlined,
                    onTap: () => onSectionChanged(_AtelierSection.revision),
                  ),
                ],
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, const SizedBox(height: 18), actions],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 20),
                  actions,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        AtelierMetricGrid(
          metrics: [
            AtelierMetric('$primaryMetric', branch.primaryMetricLabel),
            AtelierMetric('$studioCount', 'taller'),
            AtelierMetric('${atelier.assets.length}', 'assets'),
            AtelierMetric('${atelier.relations.length}', 'relaciones'),
            AtelierMetric('${atelier.notes.length}', 'notas'),
            AtelierMetric('${atelier.projectHealth}%', 'salud'),
          ],
        ),
        const SizedBox(height: 14),
        const _AtelierPlanPanel(),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 820;
            final recentPanel = AtelierPanel(
              accent: accent,
              title: 'Actividad reciente',
              icon: Icons.history_rounded,
              child: recent.isEmpty
                  ? AtelierEmptyInline(
                      message: 'Aun no hay elementos en esta obra.',
                      actionLabel: 'Crear primer elemento',
                      onAction: () => onCreateNode(branch.primaryKind),
                    )
                  : Column(
                      children: recent
                          .map((node) => AtelierNodeRow(
                                node: node,
                                onTap: () => onEditNode(node),
                              ))
                          .toList(),
                    ),
            );
            final reviewPanel = AtelierPanel(
              accent: AppColors.warning,
              title: 'Revision',
              icon: Icons.rule_folder_outlined,
              child: atelier.reviewIssues.isEmpty
                  ? const AtelierSuccessInline(message: 'No hay alertas abiertas.')
                  : Column(
                      children: atelier.reviewIssues
                          .take(4)
                          .map((issue) => AtelierIssueRow(issue: issue))
                          .toList(),
                    ),
            );
            if (!wide) {
              return Column(
                children: [
                  recentPanel,
                  const SizedBox(height: 14),
                  reviewPanel
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: recentPanel),
                const SizedBox(width: 14),
                Expanded(child: reviewPanel),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Plan y espacio, en el sitio donde se trabaja.
///
/// Aparece siempre —tambien en Free— porque saber cuanto espacio queda es
/// informacion util, no una amenaza. Solo cuando de verdad escasea cambia de
/// color y ofrece salidas.
class _AtelierPlanPanel extends StatelessWidget {
  const _AtelierPlanPanel();

  @override
  Widget build(BuildContext context) {
    return AtelierPanel(
      accent: AppColors.gold,
      title: 'Plan y espacio',
      icon: Icons.workspace_premium_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PlanBadge(),
              const Spacer(),
              TextButton(
                onPressed: () => context.push('/settings/billing'),
                child: const Text('Facturacion'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const StorageIndicator(),
        ],
      ),
    );
  }
}

class _StudioView extends StatefulWidget {
  final Color accent;
  final AtelierProvider atelier;
  final ValueChanged<String> onCreateNode;
  final ValueChanged<AtelierNode> onEditNode;
  final ValueChanged<AtelierNode> onDeleteNode;
  final VoidCallback onCreateVersion;

  const _StudioView({
    required this.accent,
    required this.atelier,
    required this.onCreateNode,
    required this.onEditNode,
    required this.onDeleteNode,
    required this.onCreateVersion,
  });

  @override
  State<_StudioView> createState() => _StudioViewState();
}

class _StudioViewState extends State<_StudioView> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String? _selectedNodeId;

  CreativeBranch get _branch =>
      branchSpec(branchIdForProject(widget.atelier.activeProject));

  List<AtelierNode> get _documents {
    final studioKinds = _branch.studioKinds;
    return widget.atelier.nodes
        .where((node) => studioKinds.contains(node.kind))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
  }

  AtelierNode? get _selectedNode {
    if (_documents.isEmpty) return null;
    return widget.atelier.nodeById(_selectedNodeId) ?? _documents.first;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncSelection());
  }

  @override
  void didUpdateWidget(covariant _StudioView oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncSelection());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _syncSelection() {
    if (!mounted) return;
    final node = _selectedNode;
    if (node == null) return;
    if (_selectedNodeId != node.id) {
      setState(() => _selectedNodeId = node.id);
    }
    if (_titleController.text != node.title) _titleController.text = node.title;
    if (_bodyController.text != node.body) _bodyController.text = node.body;
  }

  Future<void> _save() async {
    final node = _selectedNode;
    if (node == null) return;
    await widget.atelier.updateNode(
      node.copyWith(
        title: _titleController.text,
        body: _bodyController.text,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Texto guardado.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final branch = _branch;
    final docs = _documents;
    final selected = _selectedNode;
    final primaryLabel = nodeKinds[branch.primaryKind] ?? branch.primaryKind;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AtelierSectionHeader(
          eyebrow: branch.label,
          title: branch.studioTitle,
          subtitle: branch.studioSubtitle,
          accent: widget.accent,
          trailing: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...branch.studioKinds.take(3).map(
                    (kind) => AtelierSoftButton(
                      label: nodeKinds[kind] ?? kind,
                      icon: Icons.add_rounded,
                      onTap: () => widget.onCreateNode(kind),
                    ),
                  ),
              AtelierSoftButton(
                label: 'Version',
                icon: Icons.history_rounded,
                onTap: widget.onCreateVersion,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final outline = AtelierPanel(
              accent: widget.accent,
              title: 'Estructura',
              icon: Icons.view_agenda_outlined,
              child: docs.isEmpty
                  ? AtelierEmptyInline(
                      message: 'Aun no hay elementos de taller.',
                      actionLabel: 'Crear $primaryLabel',
                      onAction: () => widget.onCreateNode(branch.primaryKind),
                    )
                  : Column(
                      children: docs
                          .map(
                            (node) => AtelierSelectableNodeRow(
                              node: node,
                              selected: selected?.id == node.id,
                              onTap: () {
                                setState(() {
                                  _selectedNodeId = node.id;
                                  _titleController.text = node.title;
                                  _bodyController.text = node.body;
                                });
                              },
                              onEdit: () => widget.onEditNode(node),
                              onDelete: () => widget.onDeleteNode(node),
                            ),
                          )
                          .toList(),
                    ),
            );
            final editor = AtelierPanel(
              accent: widget.accent,
              padding: EdgeInsets.zero,
              child: selected == null
                  ? AtelierEditorEmpty(
                      actionLabel: 'Crear $primaryLabel',
                      onCreate: () => widget.onCreateNode(branch.primaryKind),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              AtelierKindBadge(kind: selected.kind),
                              const Spacer(),
                              Text(
                                '${_bodyController.text.trim().isEmpty ? 0 : RegExp(r'\S+').allMatches(_bodyController.text).length} palabras',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 10),
                              AtelierActionButton(
                                label: 'Guardar',
                                icon: Icons.save_outlined,
                                accent: widget.accent,
                                onTap: _save,
                              ),
                            ],
                          ),
                        ),
                        Divider(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.07),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              CorvusMarkdownFieldPreview(
                                controller: _titleController,
                                child: TextField(
                                  controller: _titleController,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: 'Titulo',
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              CorvusMarkdownFieldPreview(
                                controller: _bodyController,
                                child: TextField(
                                  controller: _bodyController,
                                  minLines: 16,
                                  maxLines: 28,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 15,
                                    height: 1.55,
                                  ),
                                  decoration: InputDecoration(
                                    hintText:
                                        'Escribe aqui. Puedes usar [[enlaces internos]] para conectar ideas.',
                                    hintStyle: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.26),
                                    ),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            );

            if (!wide) {
              return Column(
                  children: [outline, const SizedBox(height: 14), editor]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 320, child: outline),
                const SizedBox(width: 14),
                Expanded(child: editor),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MundiariumView extends StatelessWidget {
  final Color accent;
  final AtelierProvider atelier;
  final VoidCallback onCreateUniverse;
  final ValueChanged<String> onCreateNode;
  final ValueChanged<AtelierNode> onEditNode;
  final ValueChanged<AtelierNode> onDeleteNode;
  final VoidCallback onCreateRelation;
  final ValueChanged<AtelierRelation> onDeleteRelation;

  const _MundiariumView({
    required this.accent,
    required this.atelier,
    required this.onCreateUniverse,
    required this.onCreateNode,
    required this.onEditNode,
    required this.onDeleteNode,
    required this.onCreateRelation,
    required this.onDeleteRelation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AtelierSectionHeader(
          eyebrow: 'Mundiarium',
          title: 'Worldbuilding',
          subtitle:
              'Universos, personajes, lugares, facciones, eventos y sistemas.',
          accent: AppColors.gold,
          trailing: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AtelierActionButton(
                label: 'Universo',
                icon: Icons.public_rounded,
                accent: AppColors.gold,
                onTap: onCreateUniverse,
              ),
              AtelierSoftButton(
                label: 'Personaje',
                icon: Icons.person_add_alt_1_outlined,
                onTap: () => onCreateNode('character'),
              ),
              AtelierSoftButton(
                label: 'Lugar',
                icon: Icons.place_outlined,
                onTap: () => onCreateNode('place'),
              ),
              AtelierSoftButton(
                label: 'Relacion',
                icon: Icons.link_rounded,
                onTap: onCreateRelation,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        MundiariumWorkspace(
          accent: accent,
          atelier: atelier,
          onCreateUniverse: onCreateUniverse,
          onCreateNode: onCreateNode,
          onEditNode: onEditNode,
          onDeleteNode: onDeleteNode,
          onCreateRelation: onCreateRelation,
          onDeleteRelation: onDeleteRelation,
        ),
      ],
    );
  }
}

class _ArchiveView extends StatelessWidget {
  final Color accent;
  final AtelierProvider atelier;
  final ValueChanged<String> onCreateNode;
  final ValueChanged<AtelierNode> onEditNode;
  final ValueChanged<AtelierNode> onDeleteNode;

  const _ArchiveView({
    required this.accent,
    required this.atelier,
    required this.onCreateNode,
    required this.onEditNode,
    required this.onDeleteNode,
  });

  @override
  Widget build(BuildContext context) {
    final notes = atelier.notes;
    final selected = notes.isNotEmpty ? notes.first : null;
    final backlinks =
        selected == null ? <AtelierNode>[] : atelier.backlinksFor(selected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AtelierSectionHeader(
          eyebrow: 'Archivo Aeternum',
          title: 'Notas enlazadas',
          subtitle: 'Ideas, referencias, backlinks y tags.',
          accent: AppColors.secondaryLight,
          trailing: AtelierActionButton(
            label: 'Nueva nota',
            icon: Icons.note_add_outlined,
            accent: AppColors.secondaryLight,
            onTap: () => onCreateNode('note'),
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 860;
            final notePanel = AtelierPanel(
              accent: AppColors.secondaryLight,
              title: 'Notas',
              icon: Icons.sticky_note_2_outlined,
              child: notes.isEmpty
                  ? AtelierEmptyInline(
                      message: 'No hay notas en el archivo.',
                      actionLabel: 'Crear nota',
                      onAction: () => onCreateNode('note'),
                    )
                  : Column(
                      children: notes
                          .map((note) => AtelierNodeRow(
                                node: note,
                                onTap: () => onEditNode(note),
                                onDelete: () => onDeleteNode(note),
                              ))
                          .toList(),
                    ),
            );
            final backlinksPanel = AtelierPanel(
              accent: accent,
              title: 'Backlinks',
              icon: Icons.link_rounded,
              child: selected == null
                  ? const AtelierEmptyInline(message: 'Selecciona o crea una nota.')
                  : backlinks.isEmpty
                      ? const AtelierEmptyInline(
                          message: 'La primera nota no tiene backlinks.',
                        )
                      : Column(
                          children: backlinks
                              .map((node) => AtelierNodeRow(
                                    node: node,
                                    onTap: () => onEditNode(node),
                                  ))
                              .toList(),
                        ),
            );
            if (!wide) {
              return Column(
                children: [
                  notePanel,
                  const SizedBox(height: 14),
                  backlinksPanel
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: notePanel),
                const SizedBox(width: 14),
                Expanded(child: backlinksPanel),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ReviewView extends StatelessWidget {
  final Color accent;
  final AtelierProvider atelier;

  const _ReviewView({
    required this.accent,
    required this.atelier,
  });

  @override
  Widget build(BuildContext context) {
    return AtelierReviewWorkspace(
      accent: accent,
      atelier: atelier,
    );
  }
}

class _PublicationView extends StatelessWidget {
  final Color accent;
  final AtelierProvider atelier;
  final VoidCallback onSettings;
  final VoidCallback onPreparePublication;
  final VoidCallback onUpdatePublication;

  const _PublicationView({
    required this.accent,
    required this.atelier,
    required this.onSettings,
    required this.onPreparePublication,
    required this.onUpdatePublication,
  });

  @override
  Widget build(BuildContext context) {
    final project = atelier.activeProject!;
    final branch = branchSpec(branchIdForProject(project));
    final checklist = atelier.publicationChecklist;
    final publicationWorkId =
        project.metadata['publication_work_id'] as String?;
    final hasPublication = publicationWorkId?.isNotEmpty == true;
    final studioCount = atelier.nodes
        .where((node) => branch.studioKinds.contains(node.kind))
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AtelierSectionHeader(
          eyebrow: 'Publicacion',
          title: 'Preparar salida a Corvus',
          subtitle:
              'Crea un borrador real usando los elementos de ${branch.label}.',
          accent: accent,
          trailing: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AtelierSoftButton(
                label: 'Metadatos',
                icon: Icons.tune_rounded,
                onTap: onSettings,
              ),
              if (hasPublication)
                AtelierActionButton(
                  label: 'Actualizar',
                  icon: Icons.published_with_changes_rounded,
                  accent: accent,
                  onTap: onUpdatePublication,
                ),
              AtelierActionButton(
                label: hasPublication ? 'Re-preparar' : 'Preparar',
                icon: Icons.rocket_launch_outlined,
                accent: accent,
                onTap:
                    atelier.canPreparePublication ? onPreparePublication : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.025),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Icon(Icons.auto_stories_outlined,
                  size: 17, color: accent.withValues(alpha: 0.65)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasPublication
                      ? 'Publicacion por entregas: cada vez que termines un capitulo, pulsa "Actualizar" para volcarlo a la obra publicada sin repetir el sello.'
                      : 'No necesitas terminar la obra para publicarla: prepara la salida con los capitulos que ya tengas y ve actualizando por entregas.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.44),
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 820;
            final checklistPanel = AtelierPanel(
              accent: accent,
              title: 'Checklist',
              icon: Icons.checklist_rounded,
              child: Column(
                children: checklist
                    .map((item) => AtelierChecklistRow(item: item, accent: accent))
                    .toList(),
              ),
            );
            final livingPanel = AtelierPanel(
              accent: AppColors.gold,
              title: 'Atelier Viviente',
              icon: Icons.visibility_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AtelierInfoLine(label: 'Visibilidad', value: project.visibility),
                  AtelierInfoLine(
                    label: 'Progreso publico',
                    value: project.publicProgressEnabled ? 'activo' : 'cerrado',
                  ),
                  AtelierInfoLine(
                    label: 'Borrador de publicacion',
                    value: publicationWorkId?.isNotEmpty == true
                        ? publicationWorkId!
                        : 'sin preparar',
                  ),
                  AtelierInfoLine(
                    label: 'Elementos incluidos',
                    value: '$studioCount',
                    last: true,
                  ),
                ],
              ),
            );
            if (!wide) {
              return Column(
                children: [
                  checklistPanel,
                  const SizedBox(height: 14),
                  livingPanel
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: checklistPanel),
                const SizedBox(width: 14),
                Expanded(child: livingPanel),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ProjectRail extends StatelessWidget {
  final Color accent;
  final AtelierProvider atelier;
  final bool compact;
  final ValueChanged<String> onSelectProject;
  final VoidCallback onCreateProject;
  final VoidCallback onEditProject;
  final VoidCallback onDeleteProject;

  const _ProjectRail({
    required this.accent,
    required this.atelier,
    required this.compact,
    required this.onSelectProject,
    required this.onCreateProject,
    required this.onEditProject,
    required this.onDeleteProject,
  });

  @override
  Widget build(BuildContext context) {
    final project = atelier.activeProject!;
    return AtelierPanel(
      accent: accent,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: project.id,
                    dropdownColor: AppColors.surface,
                    iconEnabledColor: AppColors.textSecondary,
                    items: atelier.projects
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(
                              item.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) onSelectProject(value);
                    },
                  ),
                ),
              ),
              AtelierTinyIconButton(
                icon: Icons.add_rounded,
                tooltip: 'Nueva obra',
                onTap: onCreateProject,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              AtelierTag(project.type, color: accent),
              AtelierTag(project.status, color: AppColors.secondaryLight),
              if (project.genre.isNotEmpty)
                AtelierTag(project.genre, color: AppColors.gold),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AtelierMiniMetric(
                    value: '${atelier.wordCount}', label: 'palabras'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AtelierMiniMetric(
                    value: '${atelier.nodes.length}', label: 'nodos'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AtelierSoftButton(
                  label: 'Editar',
                  icon: Icons.tune_rounded,
                  onTap: onEditProject,
                ),
              ),
              const SizedBox(width: 8),
              AtelierTinyIconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Eliminar obra',
                onTap: onDeleteProject,
                danger: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionNav extends StatelessWidget {
  final Color accent;
  final _AtelierSection selected;
  final bool compact;
  final ValueChanged<_AtelierSection> onChanged;

  const _SectionNav({
    required this.accent,
    required this.selected,
    required this.compact,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final items = _AtelierSection.values.map((section) {
      final active = selected == section;
      return GestureDetector(
        onTap: () => onChanged(section),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : 12,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            color: active ? accent.withValues(alpha: 0.13) : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: active
                  ? accent.withValues(alpha: 0.28)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            children: [
              Icon(
                section.icon,
                color: active ? accent : AppColors.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 9),
              Text(
                section.label,
                style: TextStyle(
                  color:
                      active ? AppColors.textPrimary : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();

    if (compact) {
      return SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemBuilder: (_, index) => items[index],
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemCount: items.length,
        ),
      );
    }

    return AtelierPanel(
      accent: accent,
      padding: const EdgeInsets.all(8),
      child: Column(
        children: items
            .map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: item,
                ))
            .toList(),
      ),
    );
  }
}

class _SchemaSetupPanel extends StatelessWidget {
  final Color accent;
  final VoidCallback onRetry;

  const _SchemaSetupPanel({
    required this.accent,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return AtelierMessagePanel(
      accent: accent,
      icon: Icons.storage_outlined,
      title: 'Atelier necesita sus tablas',
      message:
          'El codigo funcional ya esta conectado. Aplica docs/atelier_schema.sql en Supabase y vuelve a cargar.',
      actionLabel: 'Reintentar',
      onAction: onRetry,
    );
  }
}

class _EmptyAtelierPanel extends StatelessWidget {
  final Color accent;
  final VoidCallback onCreate;

  const _EmptyAtelierPanel({
    required this.accent,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return AtelierMessagePanel(
      accent: accent,
      icon: Icons.auto_stories_outlined,
      title: 'Tu Atelier esta vacio',
      message:
          'Crea una obra privada para empezar a escribir, conectar notas y construir mundo.',
      actionLabel: 'Crear obra',
      onAction: onCreate,
    );
  }
}

class _SearchResultsPanel extends StatelessWidget {
  final Color accent;
  final List<AtelierNode> results;
  final ValueChanged<AtelierNode> onEditNode;

  const _SearchResultsPanel({
    required this.accent,
    required this.results,
    required this.onEditNode,
  });

  @override
  Widget build(BuildContext context) {
    return AtelierPanel(
      accent: accent,
      title: 'Resultados',
      icon: Icons.search_rounded,
      child: results.isEmpty
          ? const AtelierEmptyInline(message: 'No hay coincidencias.')
          : Column(
              children: results
                  .map((node) =>
                      AtelierNodeRow(node: node, onTap: () => onEditNode(node)))
                  .toList(),
            ),
    );
  }
}

class _ProjectWizardDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final int step;
  final int totalSteps;
  final bool canGoBack;
  final bool isLastStep;
  final bool isSavingStep;
  final VoidCallback? onSaveStep;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final List<Widget> content;

  const _ProjectWizardDialog({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.step,
    required this.totalSteps,
    required this.canGoBack,
    required this.isLastStep,
    this.isSavingStep = false,
    this.onSaveStep,
    required this.onBack,
    required this.onNext,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 900,
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.card.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.16),
                      blurRadius: 60,
                      offset: const Offset(0, 24),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.55),
                      blurRadius: 36,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(0.2, -1),
                            radius: 1.15,
                            colors: [
                              accent.withValues(alpha: 0.12),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ProjectWizardHeader(
                          title: title,
                          subtitle: subtitle,
                          accent: accent,
                          step: step,
                          totalSteps: totalSteps,
                          onBack: onBack,
                          canGoBack: canGoBack,
                          onClose: () => Navigator.of(context).pop(false),
                        ),
                        Divider(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.07),
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(26, 22, 26, 26),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (var i = 0; i < content.length; i++) ...[
                                  content[i],
                                  if (i < content.length - 1)
                                    const SizedBox(height: 24),
                                ],
                              ],
                            ),
                          ),
                        ),
                        _ProjectWizardFooter(
                          accent: accent,
                          canGoBack: canGoBack,
                          isLastStep: isLastStep,
                          isSavingStep: isSavingStep,
                          onSaveStep: onSaveStep,
                          onBack: onBack,
                          onNext: onNext,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectWizardHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final int step;
  final int totalSteps;
  final bool canGoBack;
  final VoidCallback onBack;
  final VoidCallback onClose;

  const _ProjectWizardHeader({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.step,
    required this.totalSteps,
    required this.canGoBack,
    required this.onBack,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final compactSteps = MediaQuery.sizeOf(context).width < 560;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 18, 22),
      child: Row(
        children: [
          if (canGoBack) ...[
            Tooltip(
              message: 'Volver',
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onBack,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.045),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppColors.textSecondary,
                      size: 17,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withValues(alpha: 0.25)),
            ),
            child: Icon(
              Icons.auto_awesome_outlined,
              color: accent,
              size: 23,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ATELIER PRIVADO / PASO ${step + 1} DE $totalSteps',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.34),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.46),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (compactSteps)
            Text(
              '${step + 1}/$totalSteps',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.52),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            )
          else
            Row(
              children: List.generate(totalSteps, (index) {
                final active = index == step;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: active ? 22 : 7,
                  height: 7,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color:
                        active ? accent : Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(99),
                  ),
                );
              }),
            ),
          const SizedBox(width: 12),
          Tooltip(
            message: 'Cerrar',
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onClose,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.045),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectWizardFooter extends StatelessWidget {
  final Color accent;
  final bool canGoBack;
  final bool isLastStep;
  final bool isSavingStep;
  final VoidCallback? onSaveStep;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _ProjectWizardFooter({
    required this.accent,
    required this.canGoBack,
    required this.isLastStep,
    this.isSavingStep = false,
    this.onSaveStep,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 620;

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.paddingOf(context).bottom + 20,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.12),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
        ),
      ),
      child: Row(
        children: [
          // Guardar progreso sin cerrar el wizard
          if (onSaveStep != null)
            OutlinedButton.icon(
              onPressed: isSavingStep ? null : onSaveStep,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.75),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: isSavingStep
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 16),
              label: Text(
                compact ? 'Guardar' : 'Guardar cambios',
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Cancelar'),
          ),
          if (canGoBack && !compact) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 15),
              label: const Text('Atras'),
            ),
          ],
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed:
                isLastStep ? () => Navigator.of(context).pop(true) : onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: AppColors.background,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            icon: Icon(
              isLastStep ? Icons.check_rounded : Icons.arrow_forward_rounded,
              size: 18,
            ),
            label: Text(
              isLastStep ? 'Guardar' : 'Continuar',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectFieldGroup extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final Widget child;

  const _ProjectFieldGroup({
    required this.title,
    required this.icon,
    required this.accent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accent.withValues(alpha: 0.20)),
              ),
              child: Icon(icon, color: accent, size: 16),
            ),
            const SizedBox(width: 10),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.36),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}

class _AeternumFieldGrid extends StatelessWidget {
  final List<AeternumMetadataField> fields;
  final TextEditingController Function(AeternumMetadataField field)
      controllerFor;
  final List<String> Function(AeternumMetadataField field)? suggestionsFor;

  const _AeternumFieldGrid({
    required this.fields,
    required this.controllerFor,
    this.suggestionsFor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final twoColumns = width >= 620;
        const gap = 12.0;
        final columnWidth = twoColumns ? (width - gap) / 2 : width;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: fields.map((field) {
            final wide = field.maxLines > 1 || field.minLines > 1;
            final numeric = field.keyboardType == TextInputType.number;
            final suggestions = numeric ||
                    field.datePicker ||
                    plainAeternumFieldKeys.contains(field.key)
                ? const <String>[]
                : suggestionsFor?.call(field) ??
                    suggestionsForAeternumField(field.key);
            return SizedBox(
              width: wide ? width : columnWidth,
              child: _DialogTextField(
                controller: controllerFor(field),
                label: field.label,
                minLines: field.minLines,
                maxLines: field.maxLines,
                keyboardType: field.keyboardType,
                suggestions: suggestions,
                appendSuggestions: shouldAppendAeternumSuggestion(field.key),
                numericControls: numeric,
                datePicker: field.datePicker,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _SelectionOptionPicker extends StatelessWidget {
  final List<SelectionOption> options;
  final String selected;
  final ValueChanged<String> onSelected;

  const _SelectionOptionPicker({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final visibleOptions = <SelectionOption>[...options];
    if (selected.isNotEmpty &&
        !visibleOptions.any((option) => option.value == selected)) {
      visibleOptions.add(
        SelectionOption(
          value: selected,
          label: selected,
          icon: Icons.label_outline_rounded,
          color: AppColors.textSecondary,
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: visibleOptions.map((option) {
        return _SelectionOptionChip(
          option: option,
          selected: option.value == selected,
          onTap: () => onSelected(option.value),
        );
      }).toList(),
    );
  }
}

class _SelectionOptionChip extends StatefulWidget {
  final SelectionOption option;
  final bool selected;
  final VoidCallback onTap;

  const _SelectionOptionChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_SelectionOptionChip> createState() => _SelectionOptionChipState();
}

class _SelectionOptionChipState extends State<_SelectionOptionChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final option = widget.option;
    final active = widget.selected || _hovered;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: widget.selected
                ? option.color.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: _hovered ? 0.075 : 0.04),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: active
                  ? option.color.withValues(alpha: 0.62)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.selected ? Icons.check_rounded : option.icon,
                color: widget.selected
                    ? option.color
                    : Colors.white.withValues(alpha: 0.48),
                size: 15,
              ),
              const SizedBox(width: 7),
              Text(
                option.label,
                style: TextStyle(
                  color: widget.selected
                      ? AppColors.textPrimary
                      : Colors.white.withValues(alpha: 0.66),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AeternumSwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;

  const _AeternumSwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            activeThumbColor: accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _AeternumReviewPanel extends StatelessWidget {
  final List<AeternumReviewItem> items;
  final Color accent;

  const _AeternumReviewPanel({
    required this.items,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final completed = items.where((item) => item.done).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: 0.20)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.fact_check_outlined, color: accent, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ficha Aeternum',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$completed de ${items.length} secciones listas para guardar.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.50),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  item.done
                      ? Icons.check_circle_rounded
                      : Icons.warning_amber_rounded,
                  color: item.done ? const Color(0xFF6BAE6B) : accent,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.detail,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _ProjectBranchPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _ProjectBranchPicker({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 640
            ? 3
            : width >= 430
                ? 2
                : 1;
        const gap = 12.0;
        final cardWidth = (width - (gap * (columns - 1))) / columns;

        final visibleBranches =
            branchSpecs.where((branch) => branch.id != 'space').toList();

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: visibleBranches.map((branch) {
            return SizedBox(
              width: cardWidth,
              child: _ProjectBranchCard(
                branch: branch,
                selected: branch.id == selected,
                onTap: () => onSelected(branch.id),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ProjectBranchCard extends StatefulWidget {
  final CreativeBranch branch;
  final bool selected;
  final VoidCallback onTap;

  const _ProjectBranchCard({
    required this.branch,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_ProjectBranchCard> createState() => _ProjectBranchCardState();
}

class _ProjectBranchCardState extends State<_ProjectBranchCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final branch = widget.branch;
    final active = widget.selected || _hovered;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 104,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: widget.selected
                ? branch.color.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: _hovered ? 0.07 : 0.035),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active
                  ? branch.color.withValues(alpha: 0.58)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: branch.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: branch.color.withValues(alpha: 0.22),
                  ),
                ),
                child: Icon(branch.icon, color: branch.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      branch.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      branch.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.42),
                        fontSize: 11,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.selected) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.check_circle_rounded,
                  color: branch.color,
                  size: 18,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectTypePicker extends StatelessWidget {
  final String selected;
  final String branchId;
  final Color accent;
  final ValueChanged<String> onSelected;

  const _ProjectTypePicker({
    required this.selected,
    required this.branchId,
    required this.accent,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final options = <ProjectTypeOption>[...branchSpec(branchId).types];
    if (selected.isNotEmpty &&
        !options.any((option) => option.name == selected)) {
      options.add(
        ProjectTypeOption(
          name: selected,
          description: 'Formato personalizado de esta obra.',
          icon: Icons.auto_awesome_outlined,
          color: accent,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 640
            ? 3
            : width >= 430
                ? 2
                : 1;
        const gap = 14.0;
        final cardWidth = (width - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: options.map((option) {
            return SizedBox(
              width: cardWidth,
              child: _ProjectTypeCard(
                option: option,
                selected: option.name == selected,
                onTap: () => onSelected(option.name),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ProjectTypeCard extends StatefulWidget {
  final ProjectTypeOption option;
  final bool selected;
  final VoidCallback onTap;

  const _ProjectTypeCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_ProjectTypeCard> createState() => _ProjectTypeCardState();
}

class _ProjectTypeCardState extends State<_ProjectTypeCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final option = widget.option;
    final active = widget.selected || _hovered;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 160),
          scale: _hovered ? 1.018 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 132,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.selected
                  ? option.color.withValues(alpha: 0.14)
                  : Colors.white.withValues(alpha: _hovered ? 0.07 : 0.035),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active
                    ? option.color.withValues(alpha: 0.58)
                    : Colors.white.withValues(alpha: 0.08),
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: option.color.withValues(alpha: 0.14),
                        blurRadius: 26,
                        offset: const Offset(0, 12),
                      ),
                    ]
                  : [],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: option.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: option.color.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Icon(option.icon, color: option.color, size: 21),
                    ),
                    const Spacer(),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 140),
                      opacity: widget.selected ? 1 : 0,
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: option.color,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  option.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  option.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.44),
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectLanguagePicker extends StatelessWidget {
  final String selected;
  final Color accent;
  final ValueChanged<String> onSelected;

  const _ProjectLanguagePicker({
    required this.selected,
    required this.accent,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final options = <LanguageOption>[...languageOptions];
    if (selected.isNotEmpty &&
        !options.any((option) => option.code == selected)) {
      final short = selected.length > 3
          ? selected.substring(0, 3).toUpperCase()
          : selected.toUpperCase();
      options.add(
        LanguageOption(
          code: selected,
          label: selected.toUpperCase(),
          shortLabel: short,
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((option) {
        return _ProjectLanguageChip(
          option: option,
          selected: option.code == selected,
          accent: accent,
          onTap: () => onSelected(option.code),
        );
      }).toList(),
    );
  }
}

class _ProjectLanguageChip extends StatefulWidget {
  final LanguageOption option;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _ProjectLanguageChip({
    required this.option,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_ProjectLanguageChip> createState() => _ProjectLanguageChipState();
}

class _ProjectLanguageChipState extends State<_ProjectLanguageChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected || _hovered;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 48,
          constraints: const BoxConstraints(minWidth: 116),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: widget.selected
                ? widget.accent.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: _hovered ? 0.075 : 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active
                  ? widget.accent.withValues(alpha: 0.58)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.accent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  widget.option.shortLabel,
                  style: TextStyle(
                    color: widget.selected
                        ? widget.accent
                        : Colors.white.withValues(alpha: 0.58),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                widget.option.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: widget.selected
                      ? AppColors.textPrimary
                      : Colors.white.withValues(alpha: 0.64),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectStatusPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _ProjectStatusPicker({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final options = <ProjectStatusOption>[...projectStatusOptions];
    if (selected.isNotEmpty &&
        !options.any((option) => option.value == selected)) {
      options.add(
        ProjectStatusOption(
          value: selected,
          label: selected,
          icon: Icons.label_outline_rounded,
          color: AppColors.textSecondary,
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((option) {
        return _ProjectStatusChip(
          option: option,
          selected: option.value == selected,
          onTap: () => onSelected(option.value),
        );
      }).toList(),
    );
  }
}

class _ProjectStatusChip extends StatefulWidget {
  final ProjectStatusOption option;
  final bool selected;
  final VoidCallback onTap;

  const _ProjectStatusChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_ProjectStatusChip> createState() => _ProjectStatusChipState();
}

class _ProjectStatusChipState extends State<_ProjectStatusChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final option = widget.option;
    final active = widget.selected || _hovered;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: widget.selected
                ? option.color.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: _hovered ? 0.075 : 0.04),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: active
                  ? option.color.withValues(alpha: 0.62)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.selected ? Icons.check_rounded : option.icon,
                color: widget.selected
                    ? option.color
                    : Colors.white.withValues(alpha: 0.48),
                size: 15,
              ),
              const SizedBox(width: 7),
              Text(
                option.label,
                style: TextStyle(
                  color: widget.selected
                      ? AppColors.textPrimary
                      : Colors.white.withValues(alpha: 0.66),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AtelierDialog extends StatelessWidget {
  final String title;
  final List<Widget> content;
  final bool wide;

  const _AtelierDialog({
    required this.title,
    required this.content,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: wide ? 620 : 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final child in content) ...[
                child,
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _CoverImageSelector extends StatefulWidget {
  final TextEditingController controller;
  final Color accent;

  const _CoverImageSelector({
    required this.controller,
    required this.accent,
  });

  @override
  State<_CoverImageSelector> createState() => _CoverImageSelectorState();
}

class _CoverImageSelectorState extends State<_CoverImageSelector> {
  Uint8List? _previewBytes;
  String? _fileName;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    widget.controller.value = TextEditingValue(
      text: image.path,
      selection: TextSelection.collapsed(offset: image.path.length),
    );
    setState(() {
      _previewBytes = bytes;
      _fileName = image.name;
    });
  }

  void _clearImage() {
    widget.controller.clear();
    setState(() {
      _previewBytes = null;
      _fileName = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.text.trim();
    final isRemote =
        value.startsWith('http://') || value.startsWith('https://');

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final preview = ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: compact ? double.infinity : 190,
            height: compact ? 180 : 210,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: _previewBytes != null
                ? Image.memory(_previewBytes!, fit: BoxFit.cover)
                : isRemote
                    ? Image.network(value, fit: BoxFit.cover)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_outlined,
                            color: widget.accent,
                            size: 34,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            value.isEmpty ? 'Portada principal' : value,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.48),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
          ),
        );

        final controls = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Portada principal',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Selecciona una imagen desde tu dispositivo. Se guarda la ruta local como referencia de la ficha.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.46),
                fontSize: 12,
                height: 1.35,
              ),
            ),
            if (_fileName != null || value.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                _fileName ?? value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Seleccionar imagen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.accent,
                    foregroundColor: AppColors.background,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                if (value.isNotEmpty)
                  TextButton.icon(
                    onPressed: _clearImage,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Quitar'),
                  ),
              ],
            ),
          ],
        );

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [preview, const SizedBox(height: 14), controls],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    preview,
                    const SizedBox(width: 16),
                    Expanded(child: controls)
                  ],
                ),
        );
      },
    );
  }
}

class _DialogTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int minLines;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<String> suggestions;
  final bool appendSuggestions;
  final bool numericControls;
  final bool datePicker;
  final ValueChanged<String>? onChanged;

  const _DialogTextField({
    required this.controller,
    required this.label,
    this.minLines = 1,
    this.maxLines = 1,
    this.keyboardType,
    this.suggestions = const [],
    this.appendSuggestions = false,
    this.numericControls = false,
    this.datePicker = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (datePicker) {
      return _DateTextField(
        controller: controller,
        label: label,
      );
    }

    if (numericControls || keyboardType == TextInputType.number) {
      return _SteppedNumberField(
        controller: controller,
        label: label,
      );
    }

    final Widget field;
    if (suggestions.isNotEmpty) {
      field = _SuggestedTextField(
        controller: controller,
        label: label,
        minLines: minLines,
        maxLines: maxLines,
        keyboardType: keyboardType,
        suggestions: suggestions,
        appendSuggestions: appendSuggestions,
        onChanged: onChanged,
      );
    } else {
      field = TextField(
        controller: controller,
        minLines: minLines,
        maxLines: maxLines,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label),
      );
    }

    return CorvusMarkdownFieldPreview(
      controller: controller,
      child: field,
    );
  }
}

class _SteppedNumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _SteppedNumberField({
    required this.controller,
    required this.label,
  });

  void _step(int delta) {
    final current = int.tryParse(controller.text.trim()) ?? 0;
    final next = (current + delta).clamp(0, 999999);
    controller.value = TextEditingValue(
      text: '$next',
      selection: TextSelection.collapsed(offset: '$next'.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: SizedBox(
          width: 84,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Tooltip(
                message: 'Disminuir',
                child: IconButton(
                  onPressed: () => _step(-1),
                  icon: const Icon(Icons.remove_rounded),
                ),
              ),
              Tooltip(
                message: 'Aumentar',
                child: IconButton(
                  onPressed: () => _step(1),
                  icon: const Icon(Icons.add_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _DateTextField({
    required this.controller,
    required this.label,
  });

  DateTime? _parseDate() {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _parseDate() ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 20),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primary,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    final value =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: () => _pickDate(context),
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: Tooltip(
          message: 'Abrir calendario',
          child: IconButton(
            onPressed: () => _pickDate(context),
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ),
      ),
    );
  }
}

class _SuggestedTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final int minLines;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<String> suggestions;
  final bool appendSuggestions;
  final ValueChanged<String>? onChanged;

  const _SuggestedTextField({
    required this.controller,
    required this.label,
    required this.minLines,
    required this.maxLines,
    required this.suggestions,
    required this.appendSuggestions,
    this.onChanged,
    this.keyboardType,
  });

  @override
  State<_SuggestedTextField> createState() => _SuggestedTextFieldState();
}

class _SuggestedTextFieldState extends State<_SuggestedTextField> {
  bool _expanded = false;

  String get _query {
    final text = widget.controller.text.trim();
    if (!widget.appendSuggestions) return text.toLowerCase();
    final parts = text.split(',');
    return parts.isEmpty ? '' : parts.last.trim().toLowerCase();
  }

  List<String> get _visibleSuggestions {
    final query = _query;
    if (query.isEmpty) return widget.suggestions;
    final starts = widget.suggestions.where((suggestion) {
      return suggestion.toLowerCase().startsWith(query);
    });
    final contains = widget.suggestions.where((suggestion) {
      final lower = suggestion.toLowerCase();
      return !lower.startsWith(query) && lower.contains(query);
    });
    return [...starts, ...contains];
  }

  void _applySuggestion(String suggestion) {
    final current = widget.controller.text.trim();
    var next = suggestion;
    if (widget.appendSuggestions && current.isNotEmpty) {
      final parts = current.split(',');
      parts[parts.length - 1] = suggestion;
      next = parts
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .join(', ');
    }
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    widget.onChanged?.call(next);
    if (!widget.appendSuggestions) {
      setState(() => _expanded = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleSuggestions = _visibleSuggestions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          keyboardType: widget.keyboardType,
          onChanged: (value) {
            widget.onChanged?.call(value);
            setState(() => _expanded = true);
          },
          decoration: InputDecoration(
            labelText: widget.label,
            suffixIcon: Tooltip(
              message: 'Ver opciones',
              child: IconButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: AnimatedRotation(
                  duration: const Duration(milliseconds: 160),
                  turns: _expanded ? 0.5 : 0,
                  child: const Icon(Icons.keyboard_arrow_down_rounded),
                ),
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.98),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: visibleSuggestions.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Sin coincidencias',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.48),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: visibleSuggestions.map((suggestion) {
                          return InkWell(
                            onTap: () => _applySuggestion(suggestion),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    widget.appendSuggestions
                                        ? Icons.add_rounded
                                        : Icons.check_rounded,
                                    color: Colors.white.withValues(alpha: 0.46),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      suggestion,
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.72),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        height: 1.25,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ),
          crossFadeState:
              _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 160),
        ),
      ],
    );
  }
}

class _DialogDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  const _DialogDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: values.contains(value) ? value : values.first,
      dropdownColor: AppColors.surface,
      decoration: InputDecoration(labelText: label),
      items: values
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(item),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _NodeDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<AtelierNode> nodes;
  final ValueChanged<String> onChanged;

  const _NodeDropdown({
    required this.label,
    required this.value,
    required this.nodes,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      dropdownColor: AppColors.surface,
      decoration: InputDecoration(labelText: label),
      items: nodes
          .map(
            (node) => DropdownMenuItem(
              value: node.id,
              child:
                  Text('${nodeKinds[node.kind] ?? node.kind}: ${node.title}'),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _AtelierSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final Color accent;
  final ValueChanged<String> onChanged;

  const _AtelierSearchField({
    required this.controller,
    required this.query,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: query.isEmpty
              ? Colors.white.withValues(alpha: 0.08)
              : accent.withValues(alpha: 0.34),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(Icons.search_rounded, color: accent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Buscar nodos, tags o texto...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.32),
                  fontSize: 13,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (query.isNotEmpty)
            GestureDetector(
              onTap: () {
                controller.clear();
                onChanged('');
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(
                  Icons.close_rounded,
                  color: Colors.white.withValues(alpha: 0.40),
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
