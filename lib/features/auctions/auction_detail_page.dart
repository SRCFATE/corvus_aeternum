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
import '../../shared/widgets/corvus_crow_animations.dart';
import '../../shared/widgets/corvus_empty_state.dart';

class AuctionDetailPage extends StatefulWidget {
  final String auctionId;

  const AuctionDetailPage({super.key, required this.auctionId});

  @override
  State<AuctionDetailPage> createState() => _AuctionDetailPageState();
}

class _AuctionDetailPageState extends State<AuctionDetailPage> {
  final _auctionService = AuctionService();
  final _bidController = TextEditingController();
  Auction? _auction;
  List<AuctionBid> _bids = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isWatching = false;
  bool _isWatchBusy = false;
  bool _isBidding = false;
  String? _errorMessage;
  Timer? _ticker;
  StreamSubscription<List<Map<String, dynamic>>>? _auctionSubscription;

  String? get _profileId => context.read<AuthProvider>().profile?.id;
  bool get _isOwner => _auction?.isOwnedBy(_profileId) == true;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _auction?.isLive == true) setState(() {});
    });
    _load();
    _auctionSubscription = _auctionService
        .watchAuctionUpdates(widget.auctionId)
        .skip(1)
        .listen((_) => _load(silent: true));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _auctionSubscription?.cancel();
    _bidController.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final profileId = _profileId;
      final results = await Future.wait([
        _auctionService.getAuctionById(widget.auctionId),
        _auctionService.getAuctionBids(widget.auctionId),
        profileId == null
            ? Future.value(false)
            : _auctionService.isWatching(widget.auctionId, profileId),
      ]);
      if (!mounted) return;
      final auction = results[0] as Auction;
      setState(() {
        _auction = auction;
        _bids = results[1] as List<AuctionBid>;
        _isWatching = results[2] as bool;
        _isLoading = false;
        _errorMessage = null;
        if (!_isBidding) {
          _bidController.text = _amountText(auction.minimumBid);
        }
      });
    } catch (_) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'La subasta no está disponible.';
        });
      }
    } finally {
      _isRefreshing = false;
    }
  }

  String _amountText(double amount) {
    return amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
  }

  NumberFormat _currency(Auction auction) {
    final symbol = switch (auction.currency) {
      'EUR' => '€',
      'USD' => 'US\$',
      _ => '\$',
    };
    return NumberFormat.currency(
      symbol: symbol,
      decimalDigits: 2,
      name: auction.currency,
    );
  }

  Future<void> _toggleWatch() async {
    final profileId = _profileId;
    if (profileId == null || _isWatchBusy) return;
    final next = !_isWatching;
    setState(() {
      _isWatching = next;
      _isWatchBusy = true;
    });
    try {
      if (next) {
        await _auctionService.watchAuction(widget.auctionId, profileId);
      } else {
        await _auctionService.unwatchAuction(widget.auctionId, profileId);
      }
      if (mounted) setState(() => _isWatchBusy = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isWatching = !next;
        _isWatchBusy = false;
      });
    }
  }

  Future<void> _placeBid() async {
    final auction = _auction;
    if (auction == null || _isBidding) return;
    final amount = double.tryParse(_bidController.text.trim());
    if (amount == null || amount < auction.minimumBid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'La puja mínima es ${_currency(auction).format(auction.minimumBid)}.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar puja'),
        content: Text(
          'Vas a pujar ${_currency(auction).format(amount)} por “${auction.lotTitle}”.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.gavel_rounded, size: 17),
            label: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isBidding = true);
    try {
      await _auctionService.placeBid(widget.auctionId, amount);
      if (!mounted) return;
      await _load(silent: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Puja registrada')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) setState(() => _isBidding = false);
    }
  }

  Future<void> _cancelAuction() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar subasta'),
        content: const Text(
          'El lote dejará de aceptar pujas y quedará registrado como cancelado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar subasta'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _auctionService.cancelAuction(widget.auctionId);
    if (mounted) _load();
  }

  Future<void> _deleteAuction() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar lote'),
        content:
            const Text('Esta acción elimina la subasta sin modificar la obra.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _auctionService.deleteAuction(widget.auctionId);
    if (mounted) context.go('/auctions');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CorvusCrowLoader(label: 'Abriendo lote...')),
      );
    }
    if (_auction == null) return _buildUnavailable();
    final auction = _auction!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/auctions'),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
        actions: [
          IconButton(
            tooltip: _isWatching ? 'Dejar de seguir' : 'Seguir subasta',
            onPressed: _toggleWatch,
            icon: Icon(
              _isWatching
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
              color: _isWatching ? AppColors.primary : null,
            ),
          ),
          if (_isOwner)
            PopupMenuButton<String>(
              tooltip: 'Administrar lote',
              onSelected: (value) {
                if (value == 'edit') {
                  context
                      .push('/auction/${auction.id}/edit')
                      .then((_) => _load());
                }
                if (value == 'cancel') _cancelAuction();
                if (value == 'delete') _deleteAuction();
              },
              itemBuilder: (_) => [
                if (!auction.hasEnded && !auction.isCancelled)
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Editar lote'),
                  ),
                if (!auction.hasBids &&
                    !auction.hasEnded &&
                    !auction.isCancelled)
                  const PopupMenuItem(
                    value: 'cancel',
                    child: Text('Cancelar subasta'),
                  ),
                if (!auction.hasBids)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Eliminar lote'),
                  ),
              ],
            ),
        ],
      ),
      body: CorvusPage(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _load,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 880;
              final content = desktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: _buildLotColumn(auction)),
                        const SizedBox(width: 24),
                        SizedBox(
                          width: 340,
                          child: _buildBidPanel(auction),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildLotColumn(auction),
                        const SizedBox(height: 18),
                        _buildBidPanel(auction),
                      ],
                    );
              return ListView(
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 100),
                children: [content],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLotColumn(Auction auction) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (auction.coverUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: CachedNetworkImage(
                imageUrl: auction.coverUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: AppColors.overlay),
                errorWidget: (_, __, ___) => Container(
                  color: AppColors.overlay,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            _AuctionBadge(label: _statusLabel(auction)),
            _AuctionBadge(label: auction.lotTypeLabel),
            if (auction.workDiscipline?.isNotEmpty == true)
              _AuctionBadge(label: auction.workDiscipline!),
            if (auction.isExtended)
              const _AuctionBadge(label: 'Cierre extendido'),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          auction.lotTitle,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Por ${auction.sellerLabel}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        if (auction.description.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            auction.description,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.65,
            ),
          ),
        ],
        const SizedBox(height: 20),
        _buildLotFacts(auction),
        if (auction.workId != null) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.push('/work/${auction.workId}'),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Abrir obra original'),
            ),
          ),
        ],
        const SizedBox(height: 26),
        Row(
          children: [
            const Expanded(
              child: Text(
                'HISTORIAL DE PUJAS',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Text(
              '${_bids.length}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_bids.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text(
              'Aún no hay pujas registradas.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          )
        else
          ..._bids.map((bid) => _buildBidRow(auction, bid)),
      ],
    );
  }

  Widget _buildLotFacts(Auction auction) {
    final facts = <(String, String)>[
      if (auction.editionLabel.isNotEmpty) ('Edición', auction.editionLabel),
      if (auction.condition.isNotEmpty) ('Estado', auction.condition),
      if (auction.certificateId.isNotEmpty)
        ('Certificado', auction.certificateId),
      if (auction.shippingNotes.isNotEmpty) ('Entrega', auction.shippingNotes),
      if (auction.startsAt != null)
        ('Inicio', DateFormat('dd MMM yyyy, HH:mm').format(auction.startsAt!)),
      if (auction.endsAt != null)
        ('Cierre', DateFormat('dd MMM yyyy, HH:mm').format(auction.endsAt!)),
    ];
    if (facts.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: facts
          .map(
            (fact) => SizedBox(
              width: 230,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fact.$1.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fact.$2,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildBidPanel(Auction auction) {
    final formatter = _currency(auction);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: auction.isLive
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            auction.currentBid == null ? 'PUJA INICIAL' : 'PUJA ACTUAL',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatter.format(auction.displayBid),
            style: const TextStyle(
              color: AppColors.primaryLight,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            '${auction.bidsCount} pujas · ${auction.watchersCount} seguidores',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          _buildTimeStatus(auction),
          if (auction.isLive && !_isOwner) ...[
            const SizedBox(height: 18),
            TextField(
              controller: _bidController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Tu puja (${auction.currency})',
                helperText: 'Mínimo ${formatter.format(auction.minimumBid)}',
                prefixIcon: const Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _isBidding ? null : _placeBid,
              icon: _isBidding
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.gavel_rounded, size: 18),
              label: Text(_isBidding ? 'Registrando...' : 'Realizar puja'),
            ),
          ],
          if (_isOwner && auction.isLive) ...[
            const SizedBox(height: 16),
            const Text(
              'Este lote es tuyo. Puedes seguir las pujas y editar la información descriptiva.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ],
          if (auction.hasEnded) ...[
            const SizedBox(height: 16),
            _buildSettlement(auction),
          ],
          if (auction.reservePrice != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  auction.reserveMet
                      ? Icons.check_circle_outline_rounded
                      : Icons.lock_outline_rounded,
                  size: 16,
                  color: auction.reserveMet
                      ? AppColors.successLight
                      : AppColors.textMuted,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    auction.reserveMet
                        ? 'Precio de reserva alcanzado'
                        : 'Precio de reserva no alcanzado',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeStatus(Auction auction) {
    final target = auction.isUpcoming ? auction.startsAt : auction.endsAt;
    if (target == null) return const SizedBox.shrink();
    final label = auction.isUpcoming ? 'Comienza en' : 'Tiempo restante';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 10),
              ),
              const SizedBox(height: 2),
              Text(
                _countdown(target),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettlement(Auction auction) {
    final text = auction.hasWinner
        ? auction.winnerId == _profileId
            ? 'Ganaste esta subasta. El acuerdo de entrega está pendiente.'
            : 'Subasta adjudicada. El acuerdo de entrega está pendiente.'
        : 'La subasta cerró sin adjudicación.';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: auction.hasWinner
            ? AppColors.success.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          height: 1.45,
        ),
      ),
    );
  }

  Widget _buildBidRow(Auction auction, AuctionBid bid) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bid.isWinning
            ? AppColors.primary.withValues(alpha: 0.07)
            : Colors.white.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: bid.isWinning
              ? AppColors.primary.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.overlay,
            backgroundImage: bid.bidderAvatarUrl == null
                ? null
                : CachedNetworkImageProvider(bid.bidderAvatarUrl!),
            child: bid.bidderAvatarUrl == null
                ? const Icon(Icons.person_outline_rounded, size: 16)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bid.bidderId == _profileId ? 'Tu puja' : bid.bidderLabel,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  DateFormat('dd MMM, HH:mm:ss').format(bid.createdAt),
                  style:
                      const TextStyle(color: AppColors.textMuted, fontSize: 10),
                ),
              ],
            ),
          ),
          Text(
            _currency(auction).format(bid.amount),
            style: TextStyle(
              color: bid.isWinning
                  ? AppColors.primaryLight
                  : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnavailable() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(),
      body: CorvusEmptyState(
        icon: Icons.gavel_outlined,
        title: 'Subasta no disponible',
        subtitle: _errorMessage ?? 'El lote no existe o fue retirado.',
        actionText: 'Volver a subastas',
        onAction: () => context.go('/auctions'),
      ),
    );
  }

  String _countdown(DateTime target) {
    final difference = target.difference(DateTime.now());
    if (difference.isNegative) return '00:00:00';
    final days = difference.inDays;
    final hours = difference.inHours.remainder(24).toString().padLeft(2, '0');
    final minutes =
        difference.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        difference.inSeconds.remainder(60).toString().padLeft(2, '0');
    return days > 0
        ? '${days}d $hours:$minutes:$seconds'
        : '$hours:$minutes:$seconds';
  }

  String _statusLabel(Auction auction) {
    if (auction.isLive) return 'En vivo';
    if (auction.isUpcoming) return 'Próxima';
    if (auction.hasEnded) return 'Finalizada';
    if (auction.isCancelled) return 'Cancelada';
    return 'Borrador';
  }
}

class _AuctionBadge extends StatelessWidget {
  final String label;

  const _AuctionBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.primaryLight,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
