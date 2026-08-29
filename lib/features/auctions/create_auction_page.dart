import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/auction.dart';
import '../../models/aeternum_certificate.dart';
import '../../models/work.dart';
import '../../providers/auth_provider.dart';
import '../../services/auction_service.dart';
import '../../services/certificate_service.dart';
import '../../shared/layout/corvus_page.dart';
import '../../shared/widgets/corvus_button.dart';
import '../../shared/widgets/corvus_empty_state.dart';
import '../../shared/widgets/corvus_text_field.dart';

class CreateAuctionPage extends StatefulWidget {
  final String? auctionId;

  const CreateAuctionPage({super.key, this.auctionId});

  @override
  State<CreateAuctionPage> createState() => _CreateAuctionPageState();
}

class _CreateAuctionPageState extends State<CreateAuctionPage> {
  final _formKey = GlobalKey<FormState>();
  final _auctionService = AuctionService();
  final _certificateService = CertificateService();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _startingBidController = TextEditingController(text: '500');
  final _incrementController = TextEditingController(text: '50');
  final _reserveController = TextEditingController();
  final _conditionController = TextEditingController();
  final _editionController = TextEditingController();
  final _shippingController = TextEditingController();
  final _certificateController = TextEditingController();
  final _startsController = TextEditingController();
  final _endsController = TextEditingController();

  List<Work> _works = [];
  List<AeternumCertificate> _certificates = [];
  Work? _selectedWork;
  Auction? _auction;
  String _currency = 'MXN';
  String _lotType = 'digital';
  DateTime _startsAt = DateTime.now().add(const Duration(minutes: 15));
  DateTime _endsAt = DateTime.now().add(const Duration(days: 3));
  bool _antiSnipe = true;
  bool _isLoading = true;
  bool _isSaving = false;

  bool get _isEditing => widget.auctionId != null;

  @override
  void initState() {
    super.initState();
    _refreshDateLabels();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _startingBidController.dispose();
    _incrementController.dispose();
    _reserveController.dispose();
    _conditionController.dispose();
    _editionController.dispose();
    _shippingController.dispose();
    _certificateController.dispose();
    _startsController.dispose();
    _endsController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profile = context.read<AuthProvider>().profile;
    if (profile == null) return;
    try {
      final worksFuture = _auctionService.getEligibleWorks(profile.id);
      final certificatesFuture =
          _certificateService.getMyCertificates(profile.id);
      final auctionFuture = _isEditing
          ? _auctionService.getAuctionById(widget.auctionId!)
          : Future<Auction?>.value(null);
      final results = await Future.wait([
        worksFuture,
        auctionFuture,
        certificatesFuture,
      ]);
      if (!mounted) return;
      final works = results[0] as List<Work>;
      final auction = results[1] as Auction?;
      final certificates = results[2] as List<AeternumCertificate>;
      setState(() {
        _works = works;
        _certificates = certificates;
        _auction = auction;
        if (auction != null) {
          _selectedWork = works.cast<Work?>().firstWhere(
                (work) => work?.id == auction.workId,
                orElse: () => works.isEmpty ? null : works.first,
              );
          _titleController.text = auction.lotTitle;
          _descriptionController.text = auction.description;
          _startingBidController.text = _amountText(auction.startingBid);
          _incrementController.text = _amountText(auction.bidIncrement);
          _reserveController.text = auction.reservePrice == null
              ? ''
              : _amountText(auction.reservePrice!);
          _conditionController.text = auction.condition;
          _editionController.text = auction.editionLabel;
          _shippingController.text = auction.shippingNotes;
          _certificateController.text = auction.certificateId;
          _currency = auction.currency;
          _lotType = auction.lotType;
          _startsAt = auction.startsAt ?? _startsAt;
          _endsAt = auction.endsAt ?? _endsAt;
          _antiSnipe = auction.antiSnipeMinutes > 0;
        } else if (works.isNotEmpty) {
          _selectedWork = works.first;
          _titleController.text = works.first.title;
          _descriptionController.text = works.first.description;
          _certificateController.text =
              _certificateFor(works.first)?.certificateNumber ?? '';
        }
        _refreshDateLabels();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron cargar tus obras')),
      );
    }
  }

  String _amountText(double amount) {
    return amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
  }

  AeternumCertificate? _certificateFor(Work work) {
    for (final certificate in _certificates) {
      if (certificate.workId == work.id &&
          certificate.isValid &&
          certificate.ownerProfileId ==
              context.read<AuthProvider>().profile?.id) {
        return certificate;
      }
    }
    return null;
  }

  void _refreshDateLabels() {
    final formatter = DateFormat('dd MMM yyyy, HH:mm');
    _startsController.text = formatter.format(_startsAt);
    _endsController.text = formatter.format(_endsAt);
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickStart() async {
    final selected = await _pickDateTime(_startsAt);
    if (selected == null) return;
    setState(() {
      final duration = _endsAt.difference(_startsAt);
      _startsAt = selected;
      _endsAt = selected
          .add(duration.isNegative ? const Duration(days: 3) : duration);
      _refreshDateLabels();
    });
  }

  Future<void> _pickEnd() async {
    final selected = await _pickDateTime(_endsAt);
    if (selected == null) return;
    setState(() {
      _endsAt = selected;
      _refreshDateLabels();
    });
  }

  String? _positiveAmount(String? value) {
    final amount = double.tryParse((value ?? '').trim());
    if (amount == null || amount <= 0) return 'Escribe un monto mayor a cero';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final profile = context.read<AuthProvider>().profile;
    final work = _selectedWork;
    if (profile == null || work == null) return;
    if (!_endsAt.isAfter(_startsAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El cierre debe ser posterior al inicio')),
      );
      return;
    }
    if (_endsAt.difference(_startsAt) < const Duration(minutes: 15)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('La subasta debe durar al menos 15 minutos')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final start = double.parse(_startingBidController.text.trim());
      final increment = double.parse(_incrementController.text.trim());
      final reserveText = _reserveController.text.trim();
      final reserve = reserveText.isEmpty ? null : double.parse(reserveText);
      if (reserve != null && reserve < start) {
        throw const AuctionFailure(
          'El precio de reserva no puede ser menor que la puja inicial.',
        );
      }

      final Auction saved;
      if (_isEditing) {
        saved = await _auctionService.updateAuction(
          auctionId: widget.auctionId!,
          lotTitle: _titleController.text,
          description: _descriptionController.text,
          startsAt: _startsAt,
          endsAt: _endsAt,
          startingBid: start,
          bidIncrement: increment,
          reservePrice: reserve,
          currency: _currency,
          lotType: _lotType,
          condition: _conditionController.text,
          editionLabel: _editionController.text,
          shippingNotes: _shippingController.text,
          certificateId: _certificateController.text,
        );
      } else {
        saved = await _auctionService.createAuction(
          work: work,
          sellerProfileId: profile.id,
          artistName: profile.displayName.isEmpty
              ? profile.username
              : profile.displayName,
          lotTitle: _titleController.text,
          description: _descriptionController.text,
          startsAt: _startsAt,
          endsAt: _endsAt,
          startingBid: start,
          bidIncrement: increment,
          reservePrice: reserve,
          currency: _currency,
          lotType: _lotType,
          condition: _conditionController.text,
          editionLabel: _editionController.text,
          shippingNotes: _shippingController.text,
          certificateId: _certificateController.text,
          antiSnipeMinutes: _antiSnipe ? 2 : 0,
          extensionMinutes: _antiSnipe ? 5 : 0,
        );
      }
      if (!mounted) return;
      context.go('/auction/${saved.id}');
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    if (_works.isEmpty) return _buildNoWorks();
    final locked = _auction?.hasBids == true;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar subasta' : 'Nueva subasta'),
        leading: IconButton(
          tooltip: 'Cerrar',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/auctions'),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: CorvusFormPage(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 20, 0, 60),
            children: [
              Text(
                locked
                    ? 'El lote ya recibió pujas. Solo puedes actualizar su información descriptiva.'
                    : 'Configura el lote, la ventana de puja y sus condiciones.',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                initialValue: _selectedWork?.id,
                decoration: const InputDecoration(
                  labelText: 'Obra',
                  prefixIcon: Icon(Icons.image_outlined),
                ),
                items: _works
                    .map(
                      (work) => DropdownMenuItem(
                        value: work.id,
                        child: Text(
                          work.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: locked
                    ? null
                    : (id) {
                        final work = _works.firstWhere((item) => item.id == id);
                        setState(() {
                          _selectedWork = work;
                          _certificateController.text =
                              _certificateFor(work)?.certificateNumber ?? '';
                          if (_titleController.text.trim().isEmpty) {
                            _titleController.text = work.title;
                          }
                        });
                      },
              ),
              const SizedBox(height: 16),
              CorvusTextField(
                controller: _titleController,
                label: 'Título del lote',
                maxLength: 160,
                validator: (value) => (value?.trim().length ?? 0) < 3
                    ? 'Usa al menos 3 caracteres'
                    : null,
              ),
              const SizedBox(height: 16),
              CorvusTextField(
                controller: _descriptionController,
                label: 'Descripción del lote',
                maxLines: 5,
                maxLength: 1600,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _lotType,
                      decoration: const InputDecoration(labelText: 'Formato'),
                      items: const [
                        DropdownMenuItem(
                          value: 'digital',
                          child: Text('Digital'),
                        ),
                        DropdownMenuItem(
                          value: 'physical',
                          child: Text('Físico'),
                        ),
                        DropdownMenuItem(
                          value: 'hybrid',
                          child: Text('Físico + digital'),
                        ),
                        DropdownMenuItem(
                          value: 'service',
                          child: Text('Comisión'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _lotType = value ?? 'digital'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _currency,
                      decoration: const InputDecoration(labelText: 'Moneda'),
                      items: const [
                        DropdownMenuItem(value: 'MXN', child: Text('MXN')),
                        DropdownMenuItem(value: 'USD', child: Text('USD')),
                        DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                      ],
                      onChanged: locked
                          ? null
                          : (value) =>
                              setState(() => _currency = value ?? 'MXN'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CorvusTextField(
                      controller: _startingBidController,
                      label: 'Puja inicial',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: _positiveAmount,
                      readOnly: locked,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CorvusTextField(
                      controller: _incrementController,
                      label: 'Incremento mínimo',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: _positiveAmount,
                      readOnly: locked,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CorvusTextField(
                controller: _reserveController,
                label: 'Precio de reserva (opcional)',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                readOnly: locked,
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return null;
                  return _positiveAmount(text);
                },
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CorvusTextField(
                      controller: _startsController,
                      label: 'Inicio',
                      readOnly: true,
                      onTap: locked ? null : _pickStart,
                      suffixIcon: const Icon(Icons.calendar_today_outlined),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CorvusTextField(
                      controller: _endsController,
                      label: 'Cierre',
                      readOnly: true,
                      onTap: locked ? null : _pickEnd,
                      suffixIcon: const Icon(Icons.event_busy_outlined),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildAntiSnipeToggle(locked),
              const SizedBox(height: 20),
              const Divider(color: AppColors.border),
              const SizedBox(height: 20),
              CorvusTextField(
                controller: _editionController,
                label: 'Edición',
                hint: 'Ej. 03/25, pieza única',
              ),
              const SizedBox(height: 16),
              CorvusTextField(
                controller: _conditionController,
                label: 'Estado de conservación',
                hint: 'Nuevo, original, restaurado...',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey(
                  '${_selectedWork?.id}-${_certificateController.text}',
                ),
                initialValue: _certificateController.text,
                decoration: const InputDecoration(
                  labelText: 'Certificado Aeternum',
                  prefixIcon: Icon(Icons.verified_outlined),
                ),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Sin certificado'),
                  ),
                  ..._certificates
                      .where(
                        (certificate) =>
                            certificate.workId == _selectedWork?.id &&
                            certificate.isValid,
                      )
                      .map(
                        (certificate) => DropdownMenuItem(
                          value: certificate.certificateNumber,
                          child: Text(
                            '${certificate.certificateNumber} · ${certificate.editionLabel}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                ],
                onChanged: locked
                    ? null
                    : (value) => _certificateController.text = value ?? '',
              ),
              const SizedBox(height: 16),
              CorvusTextField(
                controller: _shippingController,
                label: 'Entrega y envío',
                maxLines: 3,
                maxLength: 600,
              ),
              const SizedBox(height: 30),
              CorvusButton(
                label: _isEditing ? 'Guardar lote' : 'Publicar subasta',
                icon: _isEditing ? Icons.save_outlined : Icons.gavel_rounded,
                isLoading: _isSaving,
                onPressed: _save,
                width: double.infinity,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAntiSnipeToggle(bool locked) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.overlay,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Protección de cierre',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Una puja en los últimos 2 minutos extiende el cierre 5 minutos.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: _antiSnipe,
            onChanged:
                locked ? null : (value) => setState(() => _antiSnipe = value),
          ),
        ],
      ),
    );
  }

  Widget _buildNoWorks() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go('/auctions'),
        ),
      ),
      body: CorvusEmptyState(
        icon: Icons.image_not_supported_outlined,
        title: 'No tienes obras elegibles',
        subtitle: 'Publica una obra visible antes de crear un lote de subasta.',
        actionText: 'Publicar obra',
        onAction: () => context.go('/upload'),
      ),
    );
  }
}
