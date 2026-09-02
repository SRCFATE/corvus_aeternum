import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/aeternum_ficha.dart';
import '../../models/aeternum_certificate.dart';
import '../../models/collection.dart';
import '../../models/user_profile.dart';
import '../../models/work.dart';
import '../../models/work_comment.dart';
import '../../core/supabase_config.dart';
import '../../providers/auth_provider.dart';
import '../../services/collection_service.dart';
import '../../services/certificate_service.dart';
import '../../services/notification_service.dart';
import '../../services/profile_service.dart';
import '../../services/work_service.dart';
import '../../shared/widgets/corvus_crow_animations.dart';
import '../../shared/widgets/corvus_empty_state.dart';
import '../../shared/widgets/corvus_markdown_preview.dart';
import '../../shared/widgets/user_avatar.dart';
import 'upload_wizard_sheet.dart';
import 'work_reading_utils.dart';

// ─── Cover height per discipline ──────────────────────────────────────────────

double _coverHeightFor(String discipline) {
  final d = discipline.toLowerCase();
  if (d == 'fotografía' || d == 'pintura' || d == 'escultura') return 420;
  if (d == 'cine') return 380;
  if (d == 'literatura') return 260;
  return 320;
}

String _fmtNum(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

class _AeternumCatalogSection {
  final String title;
  final IconData icon;
  final List<(String, String)> rows;
  final List<String> chips;

  const _AeternumCatalogSection({
    required this.title,
    required this.icon,
    required this.rows,
    this.chips = const [],
  });
}

String _monthName(int month) {
  const names = [
    '',
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic'
  ];
  return names[month];
}

bool _isLiterary(String discipline) {
  final d = discipline.toLowerCase();
  return d == 'literatura' ||
      d == 'poesía' ||
      d == 'poesia' ||
      d == 'narrativa' ||
      d == 'dramaturgia';
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class WorkDetailPage extends StatefulWidget {
  final String workId;
  const WorkDetailPage({super.key, required this.workId});

  @override
  State<WorkDetailPage> createState() => _WorkDetailPageState();
}

class _WorkDetailPageState extends State<WorkDetailPage> {
  final _workService = WorkService();
  final _collectionService = CollectionService();
  final _certificateService = CertificateService();
  final _notificationService = NotificationService();
  final _profileService = ProfileService();
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();

  Work? _work;
  List<WorkComment> _comments = [];
  UserProfile? _authorProfile;
  List<Work> _relatedWorks = [];
  AeternumCertificate? _certificate;
  bool _isLoading = true;
  bool _isLiked = false;
  bool _isSaved = false;
  bool _submittingComment = false;
  bool _isRequestingPurchaseInquiry = false;
  bool _purchaseInquirySent = false;
  bool _isIssuingCertificate = false;
  bool _isSynopsisExpanded = false;
  int _likesDelta = 0;
  int _savesDelta = 0;

  List<WorkChapter> _chapters = [];

  String? _getUserId() => supabase.auth.currentUser?.id;

  bool _hasReadableContent(Work work) =>
      _isLiterary(work.discipline) &&
      work.textBody != null &&
      work.textBody!.trim().isNotEmpty;

  int _visibleLikes(Work work) {
    final count = work.likesCount + _likesDelta;
    return count < 0 ? 0 : count;
  }

  int _visibleSaves(Work work) {
    final count = work.savesCount + _savesDelta;
    return count < 0 ? 0 : count;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      // Load work + comments in parallel
      final core = await Future.wait<dynamic>([
        _workService.getWorkById(widget.workId),
        _workService.getComments(widget.workId),
      ]);

      final work = core[0] as Work;
      final comments = core[1] as List<WorkComment>;

      // Derive chapters
      final chapters = parseWorkChapters(work.textBody ?? '');

      // Load liked/saved + author profile + related works in parallel (secondary)
      final userId = _getUserId();
      final secondary = await Future.wait<dynamic>([
        if (userId != null) _workService.isLiked(userId, widget.workId),
        if (userId != null) _workService.isSaved(userId, widget.workId),
        _profileService.getProfileById(work.profileId),
        _workService.getWorksByProfile(work.profileId,
            limit: 4, excludeId: widget.workId),
        _certificateService.getForWork(widget.workId),
      ]);

      int i = 0;
      bool liked = false;
      bool saved = false;
      if (userId != null) {
        liked = secondary[i++] as bool;
        saved = secondary[i++] as bool;
      }
      final authorProfile = secondary[i++] as UserProfile?;
      final related = secondary[i++] as List<Work>;
      final certificate = secondary[i] as AeternumCertificate?;

      if (mounted) {
        setState(() {
          _work = work;
          _comments = comments;
          _chapters = chapters;
          _isLiked = liked;
          _isSaved = saved;
          _likesDelta = 0;
          _savesDelta = 0;
          _authorProfile = authorProfile;
          _relatedWorks = related;
          _certificate = certificate;
          _isLoading = false;
        });
        _workService.recordView(widget.workId, userId);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike() async {
    final uid = _getUserId();
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicia sesión para apreciar obras')),
      );
      return;
    }
    final wasLiked = _isLiked;
    setState(() {
      _isLiked = !wasLiked;
      _likesDelta += _isLiked ? 1 : -1;
    });
    try {
      if (_isLiked) {
        await _workService.likeWork(uid, widget.workId);
      } else {
        await _workService.unlikeWork(uid, widget.workId);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLiked = wasLiked;
          _likesDelta += wasLiked ? 1 : -1;
        });
      }
    }
  }

  Future<void> _toggleSave() async {
    final uid = _getUserId();
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Inicia sesión para guardar en biblioteca')),
      );
      return;
    }
    final wasSaved = _isSaved;
    setState(() {
      _isSaved = !wasSaved;
      _savesDelta += _isSaved ? 1 : -1;
    });
    try {
      if (_isSaved) {
        await _workService.saveWork(uid, widget.workId);
      } else {
        await _workService.unsaveWork(uid, widget.workId);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaved = wasSaved;
          _savesDelta += wasSaved ? 1 : -1;
        });
      }
    }
  }

  Future<void> _submitComment() async {
    final uid = _getUserId();
    final text = _commentController.text.trim();
    if (text.isEmpty || uid == null) return;
    setState(() => _submittingComment = true);
    try {
      final comment = await _workService.addComment(widget.workId, uid, text);
      if (mounted) {
        _commentController.clear();
        setState(() {
          _comments.add(comment);
          _submittingComment = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _submittingComment = false);
    }
  }

  void _share() {
    final work = _work;
    final title = work == null ? 'Obra en Corvus Aeternum' : work.title;
    Clipboard.setData(
      ClipboardData(text: '$title\ncorvus://work/${widget.workId}'),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enlace copiado')),
    );
  }

  void _openPrimaryExperience(Work work) {
    if (_hasReadableContent(work)) {
      context.push('/work/${work.id}/chapter/0');
      return;
    }
    if (work.hasImage) {
      _showImagePreview(work);
      return;
    }
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  void _showImagePreview(Work work) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(28),
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          work.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        color: AppColors.textSecondary,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(20),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: work.displayImage,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const SizedBox(
                        height: 420,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => _buildCoverPlaceholder(work),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddToCollection() async {
    final uid = _getUserId();
    final work = _work;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicia sesión para usar colecciones')),
      );
      return;
    }
    if (work == null) return;
    late final List<Collection> collections;
    late final Set<String> collectionIds;
    try {
      final allCollections = await _collectionService.getUserCollections(uid);
      final canAppearPublicly = work.isPublic && work.status == 'published';
      collections = allCollections
          .where(
            (collection) => !collection.isPublic || canAppearPublicly,
          )
          .toList();
      collectionIds = await _collectionService.getCollectionIdsForWork(
        widget.workId,
        collections.map((collection) => collection.id).toList(),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron abrir tus colecciones')),
      );
      return;
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (_) => _AddToCollectionSheet(
        collections: collections,
        initialCollectionIds: collectionIds,
        workId: widget.workId,
        profileId: uid,
        collectionService: _collectionService,
      ),
    );
  }

  Future<void> _requestPurchaseInquiry(Work work) async {
    if (_isRequestingPurchaseInquiry) return;

    final uid = _getUserId();
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicia sesion para consultar compra')),
      );
      return;
    }
    if (uid == work.profileId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta obra ya pertenece a tu archivo')),
      );
      return;
    }

    setState(() => _isRequestingPurchaseInquiry = true);
    try {
      await _notificationService.createPurchaseInquiry(
        profileId: work.profileId,
        actorId: uid,
        workId: work.id,
        workTitle: work.title,
      );
      if (!mounted) return;
      setState(() => _purchaseInquirySent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Consulta enviada al artista')),
      );
    } on PurchaseInquiryFailure catch (error) {
      debugPrint('Purchase inquiry rejected: $error');
      if (!mounted) return;
      if (error.alreadySent) {
        setState(() => _purchaseInquirySent = true);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error, stackTrace) {
      debugPrint('Purchase inquiry failed: $error\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo enviar la consulta. Intenta de nuevo.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isRequestingPurchaseInquiry = false);
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CorvusCrowLoader(label: 'Consultando el archivo…')),
      );
    }
    if (_work == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/discover'),
          ),
        ),
        body: CorvusEmptyState(
          icon: Icons.auto_stories_outlined,
          title: 'Obra no encontrada',
          subtitle: 'Esta pieza no existe, fue archivada o ya no esta publica.',
          actionText: 'Volver a explorar',
          onAction: () => context.go('/discover'),
        ),
      );
    }

    final work = _work!;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildGlobalTopBar(work),
          Expanded(
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                _buildSliverAppBar(work),
                SliverToBoxAdapter(child: _buildContent(work)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalTopBar(Work work) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 900;
    final profile = context.watch<AuthProvider>().profile;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.92),
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(compact ? 10 : 18, 10, 18, 10),
              child: SizedBox(
                height: 48,
                child: Row(
                  children: [
                    _TopBarIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      tooltip: 'Volver',
                      onTap: () => context.canPop()
                          ? context.pop()
                          : context.go('/discover'),
                    ),
                    const SizedBox(width: 8),
                    _TopBarBrand(compact: compact),
                    if (!compact) ...[
                      const SizedBox(width: 34),
                      Expanded(child: _TopBarNav(current: 'Obra')),
                    ] else ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          work.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                    if (!compact) const SizedBox(width: 34),
                    _TopBarIconButton(
                      icon: Icons.search_rounded,
                      tooltip: 'Buscar',
                      onTap: () => context.go('/discover'),
                    ),
                    const SizedBox(width: 8),
                    _TopBarIconButton(
                      icon: Icons.menu_book_outlined,
                      tooltip: 'Glosario',
                      onTap: () => context.push('/glossary'),
                    ),
                    const SizedBox(width: 8),
                    _TopBarIconButton(
                      icon: _isSaved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      tooltip: _isSaved ? 'En biblioteca' : 'Guardar',
                      highlighted: _isSaved,
                      onTap: _toggleSave,
                    ),
                    if (!compact) ...[
                      const SizedBox(width: 8),
                      if (profile != null)
                        GestureDetector(
                          onTap: () => context.go('/profile'),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color:
                                    AppColors.primary.withValues(alpha: 0.24),
                              ),
                            ),
                            child: Center(
                              child: UserAvatar(
                                imageUrl: profile.avatarUrl,
                                displayName: profile.displayName,
                                radius: 15,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 10),
                      _TopBarPrimaryButton(
                        label: 'Crear obra',
                        onTap: () => showUploadWizard(context),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Cover ───────────────────────────────────────────────────────────────────

  Widget _buildSliverAppBar(Work work) {
    final h = _coverHeightFor(work.discipline);

    return SliverAppBar(
      expandedHeight: h,
      elevation: 0,
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      toolbarHeight: 0,
      collapsedHeight: 0,
      pinned: false,
      flexibleSpace: FlexibleSpaceBar(background: _buildCoverBackdrop(work)),
    );
  }

  Widget _buildCoverBackdrop(Work work) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (work.hasImage)
          CachedNetworkImage(
            imageUrl: work.displayImage,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: AppColors.overlay),
            errorWidget: (_, __, ___) => _buildCoverPlaceholder(work),
          )
        else
          _buildCoverPlaceholder(work),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.22),
                AppColors.background.withValues(alpha: 0.44),
                AppColors.background,
              ],
              stops: const [0.0, 0.58, 1.0],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppColors.background.withValues(alpha: 0.74),
                Colors.transparent,
                AppColors.primaryDark.withValues(alpha: 0.26),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCoverPlaceholder(Work work) {
    final initial =
        work.title.trim().isEmpty ? 'C' : work.title.trim()[0].toUpperCase();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF160B10), Color(0xFF050507)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -60,
            top: -40,
            child: Icon(
              Icons.auto_stories_rounded,
              size: 260,
              color: AppColors.primary.withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            left: 92,
            bottom: 48,
            child: Container(
              width: 126,
              height: 126,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.22),
                ),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    color: AppColors.textPrimary.withValues(alpha: 0.78),
                    fontSize: 58,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Content container ────────────────────────────────────────────────────────

  Widget _buildContent(Work work) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 36),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 860) {
                return _buildDesktopLayout(work);
              }
              return _buildMobileLayout(work);
            },
          ),
        ),
      ),
    );
  }

  // ─── Desktop two-column ───────────────────────────────────────────────────────

  Widget _buildDesktopLayout(Work work) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildMainColumn(work, inSidebar: false)),
        const SizedBox(width: 36),
        SizedBox(width: 320, child: _buildSidebarColumn(work)),
      ],
    );
  }

  // ─── Mobile single column ─────────────────────────────────────────────────────

  Widget _buildMobileLayout(Work work) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMainColumn(work, inSidebar: false),
        const SizedBox(height: 36),
        _buildFichaDeArchivo(work),
        const SizedBox(height: 36),
        _buildSobreElAutor(work),
        if (_certificate != null || work.profileId == _getUserId()) ...[
          const SizedBox(height: 24),
          _buildCertificateCard(work),
        ],
        if (work.isForSale && work.price != null) ...[
          const SizedBox(height: 24),
          _buildEnVentaCard(work),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  // ─── Main column ──────────────────────────────────────────────────────────────

  Widget _buildMainColumn(Work work, {required bool inSidebar}) {
    final isLiterary = _isLiterary(work.discipline);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroBlock(work),
        const SizedBox(height: 32),
        if (work.description.isNotEmpty) ...[
          _buildSinopsisCard(work),
          const SizedBox(height: 32),
        ],
        _buildAeternumCatalogCard(work),
        const SizedBox(height: 32),
        if (isLiterary) ...[
          _buildContenidoDeObra(work),
          const SizedBox(height: 36),
        ],
        if (_relatedWorks.isNotEmpty) ...[
          _buildRelatedWorks(work),
          const SizedBox(height: 36),
        ],
        _buildDividerLabel('LECTURAS CRÍTICAS'),
        const SizedBox(height: 20),
        _buildLecturasCriticas(),
        const SizedBox(height: 80),
      ],
    );
  }

  // ─── Sidebar ─────────────────────────────────────────────────────────────────

  Widget _buildSidebarColumn(Work work) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFichaDeArchivo(work),
        const SizedBox(height: 28),
        _buildSobreElAutor(work),
        if (_certificate != null || work.profileId == _getUserId()) ...[
          const SizedBox(height: 24),
          _buildCertificateCard(work),
        ],
        if (work.isForSale && work.price != null) ...[
          const SizedBox(height: 24),
          _buildEnVentaCard(work),
        ],
        const SizedBox(height: 80),
      ],
    );
  }

  // ─── Hero block ───────────────────────────────────────────────────────────────

  Widget _buildHeroBlock(Work work) {
    final eyebrowParts = <String>[];
    if (work.discipline.isNotEmpty) {
      eyebrowParts.add(work.discipline.toUpperCase());
    }
    if (work.medium.isNotEmpty) eyebrowParts.add(work.medium.toUpperCase());

    final date = work.createdAt;
    final dateStr = '${_monthName(date.month)} ${date.year}';
    final isSerial = _isLiterary(work.discipline) && !work.isComplete;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.cardElevated.withValues(alpha: 0.72),
            AppColors.surface.withValues(alpha: 0.92),
          ],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showCover = constraints.maxWidth >= 640;
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (eyebrowParts.isNotEmpty)
                    _MetaChip(
                      icon: Icons.category_outlined,
                      label: eyebrowParts.join(' · '),
                      color: AppColors.primary,
                    ),
                  _MetaChip(
                    icon: work.isComplete
                        ? Icons.verified_outlined
                        : Icons.motion_photos_on_outlined,
                    label: isSerial ? 'EN CURSO' : 'ARCHIVO COMPLETO',
                    color: isSerial ? AppColors.success : AppColors.gold,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                work.title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  height: 1.02,
                ),
              ),
              if (work.subdiscipline.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  work.subdiscipline,
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.82),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _buildAuthorRow(work),
              const SizedBox(height: 22),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _MetricTile(
                    icon: Icons.calendar_month_outlined,
                    value: dateStr,
                    label: 'archivo',
                  ),
                  _MetricTile(
                    icon: Icons.visibility_outlined,
                    value: _fmtNum(work.viewsCount),
                    label: work.viewsCount == 1 ? 'lectura' : 'lecturas',
                  ),
                  _MetricTile(
                    icon: Icons.rate_review_outlined,
                    value: _fmtNum(_comments.length),
                    label: _comments.length == 1 ? 'crítica' : 'críticas',
                  ),
                  _MetricTile(
                    icon: Icons.favorite_border_rounded,
                    value: _fmtNum(_visibleLikes(work)),
                    label: _visibleLikes(work) == 1 ? 'aprecio' : 'aprecios',
                    active: _isLiked,
                    onTap: _toggleLike,
                  ),
                  _MetricTile(
                    icon: Icons.bookmark_border_rounded,
                    value: _fmtNum(_visibleSaves(work)),
                    label: _visibleSaves(work) == 1 ? 'guardado' : 'guardados',
                    active: _isSaved,
                    onTap: _toggleSave,
                  ),
                ],
              ),
              if (work.isMature || work.contentWarnings.isNotEmpty) ...[
                const SizedBox(height: 18),
                _buildContentWarnings(work),
              ],
              const SizedBox(height: 22),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _PrimaryActionButton(
                    icon: _hasReadableContent(work)
                        ? Icons.menu_book_rounded
                        : work.hasImage
                            ? Icons.open_in_full_rounded
                            : Icons.article_outlined,
                    label: _hasReadableContent(work)
                        ? 'Leer ahora'
                        : work.hasImage
                            ? 'Ver portada'
                            : 'Ver ficha',
                    onTap: () => _openPrimaryExperience(work),
                  ),
                  _ActionButton(
                    icon: _isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    label: _isLiked ? 'Apreciada' : 'Apreciar',
                    active: _isLiked,
                    onTap: _toggleLike,
                  ),
                  _ActionButton(
                    icon: _isSaved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    label: _isSaved ? 'En biblioteca' : 'Guardar',
                    active: _isSaved,
                    onTap: _toggleSave,
                  ),
                  _ActionButton(
                    icon: Icons.collections_bookmark_outlined,
                    label: 'Colección',
                    onTap: _showAddToCollection,
                  ),
                  _ActionButton(
                    icon: Icons.share_outlined,
                    label: 'Compartir',
                    onTap: _share,
                  ),
                ],
              ),
            ],
          );

          if (!showCover) return details;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: details),
              const SizedBox(width: 22),
              _buildHeroCoverPortrait(work),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeroCoverPortrait(Work work) {
    return GestureDetector(
      onTap: () => _openPrimaryExperience(work),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 154,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.36),
                blurRadius: 26,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 0.72,
              child: work.hasImage
                  ? CachedNetworkImage(
                      imageUrl: work.displayImage,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => _buildPortraitPlaceholder(work),
                      errorWidget: (_, __, ___) =>
                          _buildPortraitPlaceholder(work),
                    )
                  : _buildPortraitPlaceholder(work),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPortraitPlaceholder(Work work) {
    final initial =
        work.title.trim().isEmpty ? 'C' : work.title.trim()[0].toUpperCase();
    return Container(
      color: AppColors.primaryMuted,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Icon(
              Icons.auto_stories_rounded,
              size: 120,
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
          ),
          Center(
            child: Text(
              initial,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 56,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Author row ───────────────────────────────────────────────────────────────

  Widget _buildAuthorRow(Work work) {
    return GestureDetector(
      onTap: () {
        if (work.authorUsername != null) {
          context.push('/artist/${work.profileId}');
        }
      },
      child: MouseRegion(
        cursor: work.authorUsername != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar(
                imageUrl: work.authorAvatarUrl,
                displayName: work.authorDisplayName,
                radius: 16),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  work.authorDisplayName ?? work.authorUsername ?? 'Artista',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
                if (work.authorUsername != null)
                  Text(
                    '@${work.authorUsername}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.30),
                        fontSize: 11),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Advertencias de contenido ────────────────────────────────────────────────

  Widget _buildContentWarnings(Work work) {
    final amber = Colors.amber.withValues(alpha: 0.75);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (work.isMature)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.30)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded, size: 12, color: amber),
                const SizedBox(width: 5),
                Text(
                  'CONTENIDO MADURO',
                  style: TextStyle(
                    color: amber,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ...work.contentWarnings.map((w) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.18)),
              ),
              child: Text(
                w,
                style: TextStyle(
                  color: Colors.amber.withValues(alpha: 0.60),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )),
      ],
    );
  }

  // ─── Sinopsis ─────────────────────────────────────────────────────────────────

  Widget _buildSinopsisCard(Work work) {
    final shouldCollapse = work.description.length > 520;
    final isCollapsed = shouldCollapse && !_isSynopsisExpanded;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.20),
                  ),
                ),
                child: const Icon(
                  Icons.notes_rounded,
                  color: AppColors.primary,
                  size: 17,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SINOPSIS',
                      style: TextStyle(
                        color: AppColors.primary.withValues(alpha: 0.72),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Descripción archivada de la obra',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.38),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            work.description,
            maxLines: isCollapsed ? 7 : null,
            overflow: isCollapsed ? TextOverflow.fade : null,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              height: 1.65,
              letterSpacing: 0.1,
            ),
          ),
          if (shouldCollapse) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () {
                setState(() => _isSynopsisExpanded = !_isSynopsisExpanded);
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isSynopsisExpanded
                          ? 'Mostrar menos'
                          : 'Leer descripción completa',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _isSynopsisExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Contenido de la obra (literatura) ────────────────────────────────────────

  Widget _buildAeternumCatalogCard(Work work) {
    final AeternumFicha ficha = work.aeternumFicha;
    final sections = [
      _AeternumCatalogSection(
        title: 'Identidad',
        icon: Icons.fingerprint_rounded,
        rows: _cleanAeternumRows([
          ('Subtítulo', ficha.subtitle),
          ('Nombre interno', ficha.internalName),
          ('Disciplina', ficha.discipline),
          ('Subdisciplina', ficha.subdiscipline),
          ('Género', ficha.genre),
          ('Subgénero', ficha.subgenre),
          ('Estilo', ficha.style),
          ('Idioma', ficha.language),
          ('Estado', _humanizeAeternumValue(ficha.status)),
        ]),
      ),
      _AeternumCatalogSection(
        title: 'Universo',
        icon: Icons.public_rounded,
        rows: _cleanAeternumRows([
          ('Universo', ficha.universe),
          ('Rama', ficha.branch),
          ('Tono', ficha.aestheticTone),
          ('Atmósfera', ficha.atmosphere),
          ('Paleta', ficha.palette),
          ('Personajes', _joinAeternumList(ficha.relatedCharacters)),
          ('Lugares', _joinAeternumList(ficha.relatedPlaces)),
          ('Eventos', _joinAeternumList(ficha.relatedEvents)),
          ('Facciones', _joinAeternumList(ficha.relatedFactions)),
          ('Símbolos', _joinAeternumList(ficha.symbols)),
        ]),
      ),
      _AeternumCatalogSection(
        title: 'Producción',
        icon: Icons.tune_rounded,
        rows: _cleanAeternumRows([
          ('Formato', ficha.productionFormat),
          ('Duración', ficha.duration),
          ('Dimensiones', ficha.dimensions),
          ('Herramientas', ficha.tools),
          ('Software', ficha.software),
          ('Hardware', ficha.hardware),
          ('Materiales', ficha.materials),
          ('Versión', ficha.currentVersion),
          ('Inicio', ficha.startedAt),
          ('Finalización', ficha.finishedAt),
        ]),
      ),
      _AeternumCatalogSection(
        title: 'Derechos y salida',
        icon: Icons.verified_user_outlined,
        rows: _cleanAeternumRows([
          ('Titular', ficha.rightsHolder),
          ('Licencia', _humanizeAeternumValue(ficha.license)),
          ('Monetización', _humanizeAeternumValue(ficha.monetization)),
          ('Precio / plan', ficha.pricePlan),
          ('Publicación', ficha.publicationPlan),
          ('Visibilidad', _humanizeAeternumValue(ficha.visibility)),
          ('Certificado', ficha.certificateId),
          ('Créditos', _joinAeternumList(ficha.credits)),
          ('Colaboradores', _joinAeternumList(ficha.collaborators)),
        ]),
      ),
      _AeternumCatalogSection(
        title: 'Archivo vivo',
        icon: Icons.account_tree_outlined,
        rows: _cleanAeternumRows([
          ('Proyecto Atelier', ficha.sourceProjectId),
          ('Obra raíz', ficha.rootWorkId),
          ('Nodos conectados', _joinAeternumList(ficha.linkedNodes, take: 8)),
          ('Referencias', _joinAeternumList(ficha.references)),
          ('Inspiraciones', _joinAeternumList(ficha.inspirations)),
          ('Idiomas extra', _joinAeternumList(ficha.secondaryLanguages)),
        ]),
        chips: work.tags.take(10).toList(),
      ),
    ]
        .where((section) => section.rows.isNotEmpty || section.chips.isNotEmpty)
        .toList();

    if (sections.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.20),
                  ),
                ),
                child: const Icon(
                  Icons.auto_stories_outlined,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FICHA AETERNUM',
                      style: TextStyle(
                        color: AppColors.primary.withValues(alpha: 0.72),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ficha.source == 'atelier'
                          ? 'Registro maestro generado desde Atelier'
                          : 'Registro público de la obra',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.38),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          for (var index = 0; index < sections.length; index++) ...[
            if (index > 0)
              Divider(
                height: 26,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            _buildAeternumSection(sections[index]),
          ],
        ],
      ),
    );
  }

  Widget _buildAeternumSection(_AeternumCatalogSection section) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns = constraints.maxWidth >= 620;
        final rowWidth = useTwoColumns
            ? (constraints.maxWidth - 18) / 2
            : constraints.maxWidth;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(section.icon, color: AppColors.textSecondary, size: 17),
                const SizedBox(width: 8),
                Text(
                  section.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            if (section.rows.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 18,
                runSpacing: 10,
                children: section.rows
                    .map(
                      (row) => SizedBox(
                        width: rowWidth,
                        child: _buildAeternumDataRow(row.$1, row.$2),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (section.chips.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: section.chips.map(_buildAeternumChip).toList(),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildAeternumDataRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.30),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              height: 1.55,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SelectableText(
            value,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAeternumChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.primary.withValues(alpha: 0.82),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  List<(String, String)> _cleanAeternumRows(
    List<(String, String)> rows,
  ) {
    return rows.where((row) => row.$2.trim().isNotEmpty).toList();
  }

  String _joinAeternumList(List<String> values, {int take = 6}) {
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .take(take)
        .join(', ');
  }

  String _humanizeAeternumValue(String value) {
    final normalized = value.trim().toLowerCase();
    const translations = {
      'draft': 'Borrador',
      'in_progress': 'En desarrollo',
      'published': 'Publicada',
      'public': 'Pública',
      'private': 'Privada',
      'unlisted': 'No listada',
      'sale': 'En venta',
      'none': 'No comercial',
    };
    final translated = translations[normalized];
    if (translated != null) return translated;
    if (normalized.isEmpty) return '';
    final words = normalized.split(RegExp(r'[_-]+'));
    return words
        .map((word) =>
            word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  Widget _buildContenidoDeObra(Work work) {
    final hasContent =
        work.textBody != null && work.textBody!.trim().isNotEmpty;
    final totalChapters = _chapters.length;
    final isSingle = totalChapters == 1 && _chapters.first.title.isEmpty;
    final readingTime = hasContent ? formatReadingTime(_chapters) : null;
    final totalWords =
        _chapters.fold<int>(0, (sum, chapter) => sum + chapter.wordCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDividerLabel('CONTENIDO DE LA OBRA'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.cardElevated.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.24),
                  ),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasContent
                          ? isSingle
                              ? 'Capítulo único disponible'
                              : '$totalChapters capítulos disponibles'
                          : 'Sin capítulos publicados',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        if (totalWords > 0)
                          _InlineMeta(
                            icon: Icons.article_outlined,
                            label: '${_formattedWords(totalWords)} palabras',
                          ),
                        if (readingTime != null)
                          _InlineMeta(
                            icon: Icons.schedule_rounded,
                            label: readingTime,
                          ),
                        _InlineMeta(
                          icon: work.isComplete
                              ? Icons.check_circle_outline_rounded
                              : Icons.motion_photos_on_outlined,
                          label: work.isComplete ? 'Completa' : 'En curso',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              if (hasContent)
                _PrimaryActionButton(
                  icon: Icons.play_arrow_rounded,
                  label: 'Leer',
                  compact: true,
                  onTap: () => context.push('/work/${work.id}/chapter/0'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!hasContent)
          _buildChaptersEmpty()
        else if (isSingle)
          _buildSingleChapterCard(work, _chapters.first)
        else
          ..._chapters.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildChapterCard(work, e.value, e.key),
                ),
              ),
      ],
    );
  }

  String _formattedWords(int words) {
    if (words >= 1000) return '${(words / 1000).toStringAsFixed(1)}K';
    return '$words';
  }

  Widget _buildChaptersEmpty() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.hourglass_empty_rounded,
            color: Colors.white.withValues(alpha: 0.24),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Esta obra todavía no tiene capítulos publicados.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.40),
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleChapterCard(Work work, WorkChapter chapter) {
    return _ChapterCard(
      chapterLabel: 'Capítulo único',
      title: chapter.title.isNotEmpty ? chapter.title : work.title,
      preview: chapter.preview,
      wordCount: chapter.wordCount,
      onTap: () => context.push('/work/${work.id}/chapter/0'),
    );
  }

  Widget _buildChapterCard(Work work, WorkChapter chapter, int index) {
    final label = 'CAP. ${index + 1}';
    return _ChapterCard(
      chapterLabel: label,
      title: chapter.title.isNotEmpty ? chapter.title : 'Sin título',
      preview: chapter.preview,
      wordCount: chapter.wordCount,
      onTap: () => context.push('/work/${work.id}/chapter/$index'),
    );
  }

  // ─── Ficha de archivo ────────────────────────────────────────────────────────

  Widget _buildFichaDeArchivo(Work work) {
    final rows = _buildFichaRows(work);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: AppColors.primary,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'FICHA DE ARCHIVO',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (rows.isEmpty)
            Text(
              'Sin datos de archivo.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.28),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            ...rows.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildArchiveRow(r.$1, r.$2),
              ),
            ),
          if (work.tags.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: work.tags.take(8).map((tag) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(99),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.48),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildArchiveRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.36),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  List<(String, String)> _buildFichaRows(Work work) {
    final rows = <(String, String)>[];
    final d = work.discipline.toLowerCase();

    final date = work.createdAt;
    final dateStr = '${_monthName(date.month).toUpperCase()} ${date.year}';
    rows.add(('Archivo', dateStr));

    if (_isLiterary(d)) {
      if (work.medium.isNotEmpty) rows.add(('Género', work.medium));
      if (work.workType.isNotEmpty && work.workType != 'text') {
        rows.add(('Formato', work.workType));
      }
      if (work.technique != null) {
        rows.add(('Estilo / corriente', work.technique!));
      }
      if (work.language != null) rows.add(('Idioma', work.language!));
      if (_chapters.isNotEmpty) {
        final n = _chapters.length;
        rows.add(('Capítulos', n == 1 ? 'Capítulo único' : '$n capítulos'));
      }
      rows.add(('Estado', work.isComplete ? 'Completa' : 'En curso'));
    } else if (d == 'fotografía') {
      if (work.medium.isNotEmpty) rows.add(('Tipo', work.medium));
      if (work.technique != null) rows.add(('Captura', work.technique!));
      if (work.dimensions != null) rows.add(('Resolución', work.dimensions!));
    } else if (d == 'música') {
      if (work.musicGenre != null) {
        rows.add(('Género musical', work.musicGenre!));
      }
      if (work.duration != null) rows.add(('Duración', work.duration!));
      if (work.technique != null) {
        rows.add(('Instrumentación', work.technique!));
      }
    } else if (d == 'cine') {
      if (work.medium.isNotEmpty) rows.add(('Tipo audiovisual', work.medium));
      if (work.duration != null) rows.add(('Duración', work.duration!));
      if (work.dimensions != null) {
        rows.add(('Resolución / formato', work.dimensions!));
      }
    } else if (d == 'performance') {
      if (work.medium.isNotEmpty) rows.add(('Tipo', work.medium));
      if (work.duration != null) rows.add(('Duración aprox.', work.duration!));
    } else {
      // Default: pintura, escultura, ilustración, arte digital, etc.
      if (work.technique != null) rows.add(('Técnica', work.technique!));
      if (work.medium.isNotEmpty) rows.add(('Soporte / medio', work.medium));
      if (work.dimensions != null) rows.add(('Dimensiones', work.dimensions!));
    }

    return rows;
  }

  // ─── Sobre el autor ───────────────────────────────────────────────────────────

  Widget _buildSobreElAutor(Work work) {
    final hasProfile = _authorProfile != null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SOBRE EL AUTOR',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.34),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              UserAvatar(
                imageUrl: work.authorAvatarUrl,
                displayName: work.authorDisplayName,
                radius: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      work.authorDisplayName ??
                          work.authorUsername ??
                          'Artista',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (work.authorUsername != null)
                      Text(
                        '@${work.authorUsername}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.34),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (hasProfile && _authorProfile!.bio.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              _authorProfile!.bio,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.54),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
          if (hasProfile) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                _MiniStat(
                    value: '${_authorProfile!.worksCount}', label: 'obras'),
                const SizedBox(width: 16),
                _MiniStat(
                    value: '${_authorProfile!.followersCount}',
                    label: 'seguidores'),
              ],
            ),
          ],
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => context.push('/artist/${work.profileId}'),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.055),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: Text(
                  'Ver perfil',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _issueCertificate(Work work) async {
    if (_isIssuingCertificate) return;
    final editionController = TextEditingController(text: 'Original');
    var ownerPublic = false;
    final result = await showDialog<(String, bool)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Emitir certificado'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: editionController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Edición',
                    hintText: 'Original, 03/25, prueba de artista...',
                    prefixIcon: Icon(Icons.numbers_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: ownerPublic,
                  onChanged: (value) {
                    setDialogState(() => ownerPublic = value);
                  },
                  title: const Text('Mostrar titular públicamente'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () {
                final edition = editionController.text.trim();
                if (edition.isNotEmpty) {
                  Navigator.pop(context, (edition, ownerPublic));
                }
              },
              icon: const Icon(Icons.verified_rounded, size: 18),
              label: const Text('Emitir'),
            ),
          ],
        ),
      ),
    );
    editionController.dispose();
    if (result == null || !mounted) return;

    setState(() => _isIssuingCertificate = true);
    try {
      await _certificateService.issueCertificate(
        workId: work.id,
        editionLabel: result.$1,
        ownerPublic: result.$2,
      );
      final certificate = await _certificateService.getForWork(work.id);
      if (!mounted) return;
      setState(() {
        _certificate = certificate;
        _isIssuingCertificate = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Certificado emitido')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isIssuingCertificate = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Widget _buildCertificateCard(Work work) {
    final certificate = _certificate;
    if (certificate == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.verified_outlined, color: AppColors.gold, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'CERTIFICADO AETERNUM',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed:
                  _isIssuingCertificate ? null : () => _issueCertificate(work),
              icon: _isIssuingCertificate
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_rounded, size: 18),
              label: Text(
                _isIssuingCertificate ? 'Emitiendo...' : 'Emitir certificado',
              ),
            ),
          ],
        ),
      );
    }

    return Material(
      color: AppColors.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: certificate.isValid
              ? AppColors.gold.withValues(alpha: 0.34)
              : AppColors.error.withValues(alpha: 0.34),
        ),
      ),
      child: InkWell(
        onTap: () => context.push(
          '/certificate/${certificate.certificateNumber}',
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    certificate.isValid
                        ? Icons.verified_rounded
                        : Icons.gpp_bad_rounded,
                    color: certificate.isValid
                        ? AppColors.gold
                        : AppColors.errorLight,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      certificate.certificateNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                certificate.editionLabel,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${certificate.statusLabel} · ${certificate.ownerLabel}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── En venta ─────────────────────────────────────────────────────────────────

  Widget _buildEnVentaCard(Work work) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EN VENTA',
            style: TextStyle(
                color: AppColors.primary.withValues(alpha: 0.65),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4),
          ),
          const SizedBox(height: 10),
          Text(
            '\$${work.price!.toStringAsFixed(0)} ${work.currency}',
            style: const TextStyle(
                color: AppColors.primary,
                fontSize: 22,
                fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'Pieza original disponible',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.40), fontSize: 12),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _isRequestingPurchaseInquiry || _purchaseInquirySent
                ? null
                : () => _requestPurchaseInquiry(work),
            child: MouseRegion(
              cursor: _isRequestingPurchaseInquiry || _purchaseInquirySent
                  ? SystemMouseCursors.basic
                  : SystemMouseCursors.click,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _purchaseInquirySent
                      ? AppColors.success
                      : _isRequestingPurchaseInquiry
                          ? AppColors.primary.withValues(alpha: 0.58)
                          : AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: _isRequestingPurchaseInquiry
                      ? const SizedBox(
                          key: ValueKey('loading'),
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : _purchaseInquirySent
                          ? const Row(
                              key: ValueKey('sent'),
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_outline_rounded,
                                  color: Colors.white,
                                  size: 17,
                                ),
                                SizedBox(width: 7),
                                Text(
                                  'Consulta enviada',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            )
                          : const Text(
                              'Consultar',
                              key: ValueKey('label'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800),
                            ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Obras relacionadas ───────────────────────────────────────────────────────

  Widget _buildRelatedWorks(Work work) {
    if (_relatedWorks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDividerLabel('MÁS DE ESTE AUTOR'),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _relatedWorks.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final w = _relatedWorks[i];
              return GestureDetector(
                onTap: () => context.push('/work/${w.id}'),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    width: 140,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.07)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cover
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12)),
                          child: SizedBox(
                            height: 110,
                            child: w.hasImage
                                ? CachedNetworkImage(
                                    imageUrl: w.displayImage,
                                    width: 140,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) =>
                                        _relatedPlaceholder(w),
                                  )
                                : _relatedPlaceholder(w),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                w.discipline,
                                style: TextStyle(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.55),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                w.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _relatedPlaceholder(Work w) {
    return Container(
      width: 140,
      height: 110,
      color: AppColors.overlay,
      child: Center(
        child: Text(
          w.discipline.isNotEmpty ? w.discipline[0].toUpperCase() : '?',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.15),
              fontSize: 28,
              fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  // ─── Lecturas críticas (comments) ─────────────────────────────────────────────

  Widget _buildLecturasCriticas() {
    final uid = _getUserId();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (uid != null) ...[
          _buildCommentInput(),
          const SizedBox(height: 20),
        ],
        if (_comments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Sé el primero en dejar una lectura crítica.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          ..._comments.map(_buildCommentTile),
      ],
    );
  }

  Widget _buildCommentInput() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: CorvusMarkdownFieldPreview(
            controller: _commentController,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
              ),
              child: TextField(
                controller: _commentController,
                style:
                    const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Escribe tu lectura crítica...',
                  hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.25),
                      fontSize: 14),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                maxLines: 3,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submitComment(),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _submittingComment
            ? const SizedBox(
                width: 40,
                height: 40,
                child: Center(
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary))),
              )
            : GestureDetector(
                onTap: _submitComment,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.28)),
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: AppColors.primary, size: 18),
                ),
              ),
      ],
    );
  }

  Widget _buildCommentTile(WorkComment comment) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
              imageUrl: comment.authorAvatarUrl,
              displayName: comment.authorDisplayName,
              radius: 14),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(
                    comment.authorDisplayName ??
                        comment.authorUsername ??
                        'Usuario',
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _timeAgo(comment.createdAt),
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.25),
                        fontSize: 11),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(
                  comment.body,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.70),
                      fontSize: 13,
                      height: 1.50),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Shared helpers ───────────────────────────────────────────────────────────

  Widget _buildDividerLabel(String label) {
    return Row(children: [
      Text(
        label,
        style: TextStyle(
            color: Colors.white.withValues(alpha: 0.28),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5),
      ),
      const SizedBox(width: 14),
      Expanded(
          child: Container(
              height: 0.5, color: Colors.white.withValues(alpha: 0.07))),
    ]);
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 30) return '${date.day}/${date.month}/${date.year}';
    if (diff.inDays > 0) return 'hace ${diff.inDays}d';
    if (diff.inHours > 0) return 'hace ${diff.inHours}h';
    if (diff.inMinutes > 0) return 'hace ${diff.inMinutes}min';
    return 'ahora';
  }
}

// ─── Widgets ─────────────────────────────────────────────────────────────────

class _TopBarBrand extends StatelessWidget {
  final bool compact;

  const _TopBarBrand({required this.compact});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/discover'),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.26),
                ),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.primary,
                size: 18,
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: 11),
              const Text(
                'Corvus Aeternum',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopBarNav extends StatelessWidget {
  final String current;

  const _TopBarNav({required this.current});

  static const _items = [
    ('Explorar', '/feed'),
    ('Descubrir', '/discover'),
    ('Atelier', '/atelier'),
    ('Subastas', '/auctions'),
    ('Artistas', '/artists'),
    ('Colecciones', '/collections'),
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        spacing: 8,
        children: _items.map((item) {
          return _TopBarNavLink(
            label: item.$1,
            selected: item.$1 == current,
            onTap: () => context.go(item.$2),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _TopBarNavLink extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TopBarNavLink({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_TopBarNavLink> createState() => _TopBarNavLinkState();
}

class _TopBarNavLinkState extends State<_TopBarNavLink> {
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
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppColors.primary.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: active ? AppColors.textPrimary : AppColors.textMuted,
              fontSize: 13,
              fontWeight: active ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBarIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool highlighted;
  final VoidCallback onTap;

  const _TopBarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  State<_TopBarIconButton> createState() => _TopBarIconButtonState();
}

class _TopBarIconButtonState extends State<_TopBarIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.highlighted || _hovered;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: widget.highlighted
                  ? AppColors.primary.withValues(alpha: 0.13)
                  : Colors.white.withValues(alpha: _hovered ? 0.075 : 0.04),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: active
                    ? AppColors.primary.withValues(alpha: 0.24)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Icon(
              widget.icon,
              size: 19,
              color: widget.highlighted
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBarPrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _TopBarPrimaryButton({required this.label, required this.onTap});

  @override
  State<_TopBarPrimaryButton> createState() => _TopBarPrimaryButtonState();
}

class _TopBarPrimaryButtonState extends State<_TopBarPrimaryButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.primaryLight : AppColors.primary,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color:
                    AppColors.primary.withValues(alpha: _hovered ? 0.28 : 0.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color.withValues(alpha: 0.85)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.88),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _MetricTile({
    required this.icon,
    required this.value,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor:
            onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active
                  ? AppColors.primary.withValues(alpha: 0.28)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 16,
                  color: color.withValues(alpha: active ? 0.85 : 0.42)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: color.withValues(alpha: active ? 0.90 : 0.74),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: TextStyle(
                      color: color.withValues(alpha: active ? 0.62 : 0.36),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool compact;
  final VoidCallback onTap;

  const _PrimaryActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : 18,
            vertical: compact ? 10 : 12,
          ),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(compact ? 12 : 14),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: compact ? 17 : 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineMeta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InlineMeta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.34)),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.40),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _ActionButton(
      {required this.icon,
      required this.label,
      this.active = false,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: active
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.09),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 15,
                  color: active
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.55)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: active
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  const _MiniStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(children: [
        TextSpan(
          text: value,
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800),
        ),
        TextSpan(
          text: ' $label',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35), fontSize: 12),
        ),
      ]),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  final String chapterLabel;
  final String title;
  final String preview;
  final int wordCount;
  final VoidCallback onTap;

  const _ChapterCard({
    required this.chapterLabel,
    required this.title,
    required this.preview,
    required this.wordCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = wordCount <= 0 ? 0 : (wordCount / 220).ceil();
    final badge = chapterLabel.startsWith('CAP.')
        ? chapterLabel.replaceAll('CAP. ', '')
        : '1';

    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
          decoration: BoxDecoration(
            color: AppColors.card.withValues(alpha: 0.64),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.18),
                  ),
                ),
                child: Center(
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 9,
                      runSpacing: 4,
                      children: [
                        _InlineMeta(
                            icon: Icons.flag_outlined, label: chapterLabel),
                        if (wordCount > 0)
                          _InlineMeta(
                            icon: Icons.article_outlined,
                            label: '$wordCount palabras',
                          ),
                        if (minutes > 0)
                          _InlineMeta(
                            icon: Icons.schedule_rounded,
                            label: '$minutes min',
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.46),
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddToCollectionSheet extends StatefulWidget {
  final List<Collection> collections;
  final Set<String> initialCollectionIds;
  final String workId;
  final String profileId;
  final CollectionService collectionService;

  const _AddToCollectionSheet({
    required this.collections,
    required this.initialCollectionIds,
    required this.workId,
    required this.profileId,
    required this.collectionService,
  });

  @override
  State<_AddToCollectionSheet> createState() => _AddToCollectionSheetState();
}

class _AddToCollectionSheetState extends State<_AddToCollectionSheet> {
  late List<Collection> _collections;
  late Set<String> _collectionIds;
  final _titleController = TextEditingController();
  final _searchController = TextEditingController();
  bool _showCreate = false;
  bool _creating = false;
  String? _busyCollectionId;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _collections = List<Collection>.from(widget.collections);
    _collectionIds = Set<String>.from(widget.initialCollectionIds);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addToCollection(Collection collection) async {
    final wasIncluded = _collectionIds.contains(collection.id);
    setState(() => _busyCollectionId = collection.id);
    try {
      if (wasIncluded) {
        await widget.collectionService.removeWorkFromCollection(
          collection.id,
          widget.workId,
        );
      } else {
        await widget.collectionService.addWorkToCollection(
          collection.id,
          widget.workId,
        );
      }
      if (!mounted) return;
      setState(() {
        _busyCollectionId = null;
        final index =
            _collections.indexWhere((item) => item.id == collection.id);
        if (wasIncluded) {
          _collectionIds.remove(collection.id);
        } else {
          _collectionIds.add(collection.id);
        }
        if (index >= 0) {
          _collections[index] = collection.copyWith(
            piecesCount: (collection.piecesCount + (wasIncluded ? -1 : 1))
                .clamp(0, 1 << 30),
          );
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasIncluded
                ? 'Obra retirada de ${collection.title}'
                : 'Obra añadida a ${collection.title}',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busyCollectionId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo añadir a la colección')),
      );
    }
  }

  Future<void> _createCollectionAndAdd() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un nombre para la colección')),
      );
      return;
    }
    setState(() => _creating = true);
    try {
      final collection = await widget.collectionService.createCollection(
        profileId: widget.profileId,
        title: title,
        description: '',
        isPublic: false,
      );
      await widget.collectionService
          .addWorkToCollection(collection.id, widget.workId);
      if (!mounted) return;
      setState(() {
        _collections.insert(0, collection.copyWith(piecesCount: 1));
        _collectionIds.add(collection.id);
        _showCreate = false;
        _creating = false;
        _titleController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Colección "$title" creada')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo crear la colección')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final visibleCollections = query.isEmpty
        ? _collections
        : _collections
            .where(
              (collection) => [
                collection.title,
                collection.typeLabel,
                ...collection.tags,
              ].join(' ').toLowerCase().contains(query),
            )
            .toList();
    return SafeArea(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 620),
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Añadir a colección',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _showCreate = !_showCreate);
                    },
                    icon: Icon(
                      _showCreate ? Icons.close_rounded : Icons.add_rounded,
                      size: 17,
                    ),
                    label: Text(_showCreate ? 'Cancelar' : 'Nueva'),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              if (_showCreate) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.035),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _titleController,
                          autofocus: true,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Nombre de colección',
                            counterText: '',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.32),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          maxLength: 120,
                          onSubmitted: (_) => _createCollectionAndAdd(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _creating
                          ? const SizedBox(
                              width: 34,
                              height: 34,
                              child: Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            )
                          : IconButton(
                              onPressed: _createCollectionAndAdd,
                              icon: const Icon(Icons.check_rounded),
                              color: AppColors.primary,
                            ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Buscar colección',
                  prefixIcon: const Icon(Icons.search_rounded, size: 19),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpiar búsqueda',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              if (visibleCollections.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  child: Text(
                    _collections.isEmpty
                        ? 'No tienes colecciones aún.'
                        : 'No encontramos colecciones.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.38),
                      fontSize: 13,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: visibleCollections.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final collection = visibleCollections[index];
                      final busy = _busyCollectionId == collection.id;
                      final included = _collectionIds.contains(collection.id);
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: busy ? null : () => _addToCollection(collection),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.035),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.collections_bookmark_outlined,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      collection.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${collection.piecesCount} piezas · ${collection.isPublic ? 'pública' : 'privada'}',
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.36),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (busy)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                )
                              else
                                Icon(
                                  included
                                      ? Icons.check_circle_rounded
                                      : Icons.add_circle_outline_rounded,
                                  color: included
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
