import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/auction.dart';
import '../../providers/auth_provider.dart';
import '../../services/auction_service.dart';
import '../../shared/layout/corvus_page.dart';
import '../../shared/widgets/corvus_empty_state.dart';

class AuctionsPage extends StatefulWidget {
  const AuctionsPage({super.key});

  @override
  State<AuctionsPage> createState() => _AuctionsPageState();
}

class _AuctionsPageState extends State<AuctionsPage>
    with SingleTickerProviderStateMixin {
  final _auctionService = AuctionService();
  late final TabController _tabController;
  Timer? _ticker;
  List<Auction> _liveAuctions = [];
  List<Auction> _upcomingAuctions = [];
  List<Auction> _endedAuctions = [];
  List<Auction> _myAuctions = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _liveAuctions.isNotEmpty) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final profileId = context.read<AuthProvider>().profile?.id;
      final results = await Future.wait([
        _auctionService.getAuctions(status: 'live'),
        _auctionService.getAuctions(status: 'upcoming'),
        _auctionService.getAuctions(status: 'ended'),
        profileId == null
            ? Future.value(<Auction>[])
            : _auctionService.getMyAuctions(profileId),
      ]);
      if (!mounted) return;
      setState(() {
        _liveAuctions = results[0];
        _upcomingAuctions = results[1];
        _endedAuctions = results[2];
        _myAuctions = results[3];
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'No fue posible cargar las subastas.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CorvusPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SafeArea(bottom: false, child: _buildHeader()),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'EN VIVO'),
                Tab(text: 'PRÓXIMAS'),
                Tab(text: 'FINALIZADAS'),
                Tab(text: 'MIS LOTES'),
              ],
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ÁGORA',
                  style: TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Subastas',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filled(
            onPressed: () async {
              await context.push('/auction/create');
              if (mounted) _load();
            },
            tooltip: 'Crear subasta',
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_errorMessage != null) {
      return CorvusEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Subastas no disponibles',
        subtitle: _errorMessage!,
        actionText: 'Reintentar',
        onAction: _load,
      );
    }
    return TabBarView(
      controller: _tabController,
      children: [
        _buildAuctionGrid(
          _liveAuctions,
          icon: Icons.gavel_rounded,
          title: 'No hay subastas en vivo',
          subtitle: 'Los lotes activos aparecerán aquí.',
        ),
        _buildAuctionGrid(
          _upcomingAuctions,
          icon: Icons.schedule_rounded,
          title: 'No hay subastas programadas',
          subtitle: 'Los próximos lotes aparecerán aquí.',
        ),
        _buildAuctionGrid(
          _endedAuctions,
          icon: Icons.inventory_2_outlined,
          title: 'El archivo está vacío',
          subtitle: 'Las subastas concluidas aparecerán aquí.',
        ),
        _buildAuctionGrid(
          _myAuctions,
          icon: Icons.collections_bookmark_outlined,
          title: 'Aún no tienes lotes',
          subtitle: 'Publica una de tus obras como subasta.',
          actionText: 'Crear subasta',
          onAction: () async {
            await context.push('/auction/create');
            if (mounted) _load();
          },
        ),
      ],
    );
  }

  Widget _buildAuctionGrid(
    List<Auction> auctions, {
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionText,
    VoidCallback? onAction,
  }) {
    if (auctions.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 72),
          children: [
            CorvusEmptyState(
              icon: icon,
              title: title,
              subtitle: subtitle,
              actionText: actionText,
              onAction: onAction,
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 18, 0, 96),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 430,
          mainAxisExtent: 390,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: auctions.length,
        itemBuilder: (_, index) => _AuctionCard(
          auction: auctions[index],
          onTap: () async {
            await context.push('/auction/${auctions[index].id}');
            if (mounted) _load();
          },
        ),
      ),
    );
  }
}

class _AuctionCard extends StatelessWidget {
  final Auction auction;
  final VoidCallback onTap;

  const _AuctionCard({required this.auction, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final formatter = _currency(auction);
    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: auction.isLive
              ? AppColors.primary.withValues(alpha: 0.38)
              : AppColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (auction.coverUrl?.isNotEmpty == true)
                    CachedNetworkImage(
                      imageUrl: auction.coverUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: AppColors.overlay),
                      errorWidget: (_, __, ___) => _imageFallback(),
                    )
                  else
                    _imageFallback(),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _StatusBadge(auction: auction),
                  ),
                  if (auction.isFeatured)
                    const Positioned(
                      top: 10,
                      right: 10,
                      child: Icon(
                        Icons.workspace_premium_rounded,
                        color: AppColors.gold,
                        size: 21,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 170,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      auction.lotTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      auction.sellerLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                auction.currentBid == null
                                    ? 'PUJA INICIAL'
                                    : 'PUJA ACTUAL',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatter.format(auction.displayBid),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.primaryLight,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _timeLabel(auction),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        const Icon(
                          Icons.gavel_rounded,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${auction.bidsCount} pujas',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.visibility_outlined,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${auction.watchersCount}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                        const Spacer(),
                        Expanded(
                          child: Text(
                            auction.lotTypeLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      color: AppColors.overlay,
      child: const Icon(
        Icons.image_outlined,
        color: AppColors.textMuted,
        size: 38,
      ),
    );
  }

  static NumberFormat _currency(Auction auction) {
    final symbol = switch (auction.currency) {
      'EUR' => '€',
      'USD' => 'US\$',
      _ => '\$',
    };
    return NumberFormat.currency(symbol: symbol, decimalDigits: 2);
  }

  static String _timeLabel(Auction auction) {
    if (auction.isCancelled) return 'Cancelada';
    if (auction.hasEnded) return 'Cerrada';
    final target = auction.isUpcoming ? auction.startsAt : auction.endsAt;
    if (target == null) return 'Sin fecha';
    final difference = target.difference(DateTime.now());
    if (difference.isNegative) return 'Actualizando';
    if (difference.inDays > 0) {
      return auction.isUpcoming
          ? 'Inicia en\n${difference.inDays} d'
          : 'Cierra en\n${difference.inDays} d';
    }
    final hours = difference.inHours.toString().padLeft(2, '0');
    final minutes =
        difference.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        difference.inSeconds.remainder(60).toString().padLeft(2, '0');
    final prefix = auction.isUpcoming ? 'Inicia' : 'Cierra';
    return '$prefix\n$hours:$minutes:$seconds';
  }
}

class _StatusBadge extends StatelessWidget {
  final Auction auction;

  const _StatusBadge({required this.auction});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (auction.status) {
      'live' => ('EN VIVO', AppColors.primaryLight),
      'upcoming' => ('PRÓXIMA', AppColors.secondaryLight),
      'ended' => ('FINALIZADA', AppColors.silver),
      'cancelled' => ('CANCELADA', AppColors.textMuted),
      _ => ('BORRADOR', AppColors.textMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.65)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
