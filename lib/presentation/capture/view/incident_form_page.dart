import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:strop_app/app/di/service_locator.dart';
import 'package:strop_app/core/app_notifiers.dart';
import 'package:strop_app/core/services/image_compression_service.dart';
import 'package:strop_app/core/services/geoapify_service.dart';
import 'package:strop_app/core/services/location_service.dart';
import 'package:strop_app/core/widgets/app_colors.dart';
import 'package:strop_app/core/widgets/step_progress_bar.dart';
import 'package:strop_app/core/widgets/strop_dialog.dart';
import 'package:strop_app/core/widgets/strop_loader.dart';
import 'package:strop_app/domain/entities/incident.dart';
import 'package:strop_app/domain/entities/project.dart';
import 'package:strop_app/domain/repositories/incident_repository.dart';
import 'package:strop_app/domain/repositories/project_repository.dart';
import 'package:strop_app/presentation/capture/widgets/audio_recorder.dart';

class IncidentFormPage extends StatefulWidget {
  const IncidentFormPage({
    required this.imageFiles,
    this.annotations = const [],
    super.key,
  });

  final List<File> imageFiles;
  final List<List<Offset>> annotations;

  /// Notifier lets AppShell detect when the form is active so it can
  /// intercept tab-switch gestures and show a discard-confirmation dialog.
  static final isFormActive = ValueNotifier<bool>(false);

  @override
  State<IncidentFormPage> createState() => _IncidentFormPageState();
}

class _IncidentFormPageState extends State<IncidentFormPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _specificLocationController = TextEditingController();
  IncidentPriority _priority = IncidentPriority.normal;
  Trade? _selectedTrade;
  String? _audioPath;
  bool _isSaving = false;
  Project? _detectedProject;
  bool _isLoadingLocation = true;
  List<String> _recentLocations = [];

  // Focus chain for keyboard navigation
  final _titleFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();
  final _locationFocusNode = FocusNode();

  void _closeCaptureFlow() {
    IncidentFormPage.isFormActive.value = false;
    final navigator = Navigator.of(context);
    navigator.popUntil((route) => route.isFirst);
  }

  Future<void> _confirmDiscardAndClose() async {
    final discard = await StropDialog.confirm(
      context: context,
      title: '¿Descartar incidencia?',
      body: 'Tienes una incidencia sin guardar. '
          'Si sales ahora, los cambios se perderán.',
      confirmLabel: 'Descartar',
      cancelLabel: 'Seguir editando',
      isDestructive: true,
    );

    if (discard == true && mounted) {
      _closeCaptureFlow();
    }
  }

  @override
  void initState() {
    super.initState();
    IncidentFormPage.isFormActive.value = true;
    unawaited(_detectLocation());
    unawaited(_loadRecentLocations());
  }

  Future<void> _loadRecentLocations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locations = prefs.getStringList('recent_locations') ?? [];
      if (mounted) {
        setState(() {
          _recentLocations = locations;
        });
      }
    } on Exception catch (e) {
      debugPrint('Error loading recent locations: $e');
    }
  }

  Future<void> _saveRecentLocations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('recent_locations', _recentLocations);
    } on Exception catch (e) {
      debugPrint('Error saving recent locations: $e');
    }
  }

  Future<void> _detectLocation() async {
    try {
      // Use real GPS coordinates from the LocationService
      final position = await sl<LocationService>().getCurrentPosition();
      final lat = position?.latitude ?? 0.0;
      final lon = position?.longitude ?? 0.0;

      // Fetch project + reverse geocode in parallel
      final results = await Future.wait([
        sl<ProjectRepository>().getNearestProject(lat, lon),
        sl<GeoapifyService>().reverseGeocode(lat, lon),
      ]);

      final project = results[0] as Project?;
      final address = results[1] as String?;

      if (mounted) {
        setState(() {
          _detectedProject = project;
          _isLoadingLocation = false;
        });
        // Pre-fill specific location if user hasn't typed anything yet
        if (address != null && _specificLocationController.text.isEmpty) {
          _specificLocationController.text = address;
        }
      }
    } on Exception catch (e) {
      debugPrint('Error detecting location: $e');
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  @override
  void dispose() {
    IncidentFormPage.isFormActive.value = false;
    _titleController.dispose();
    _descriptionController.dispose();
    _specificLocationController.dispose();
    _titleFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _locationFocusNode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      showToast(
        context: context,
        builder: (context, overlay) => const Card(
          child: Text('El título es obligatorio.'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Compress images before saving
      final compressedImages = <File>[];
      for (final imageFile in widget.imageFiles) {
        try {
          final compressed = await ImageCompressionService().compressImage(
            imageFile,
          );
          compressedImages.add(compressed);
        } on Exception catch (e) {
          debugPrint('Error compressing image: $e');
          // If compression fails, use original
          compressedImages.add(imageFile);
        }
      }

      // Save specific location to recent locations
      if (_specificLocationController.text.isNotEmpty) {
        _recentLocations.insert(0, _specificLocationController.text);
        if (_recentLocations.length > 3) {
          _recentLocations = _recentLocations.take(3).toList();
        }
        await _saveRecentLocations();
      }

      final incident = Incident(
        id: const Uuid().v4(),
        title: _titleController.text,
        description: _descriptionController.text,
        location: _detectedProject?.name ?? 'Unknown Location',
        projectId: _detectedProject?.id, // ← FIX: populate real UUID
        specificLocation: _specificLocationController.text.isEmpty
            ? null
            : _specificLocationController.text,
        createdAt: DateTime.now(),
        priority: _priority,
        photos: compressedImages.map((file) => file.path).toList(),
        audioPath: _audioPath,
        assignedTrade: _selectedTrade,
      );

      await sl<IncidentRepository>().createIncident(incident);

      // Update the global pending-sync badge shown in AppShell bottom nav.
      final pending = await sl<IncidentRepository>().getPendingIncidentCount();
      AppNotifiers.syncPendingCount.value = pending;

      if (mounted) {
        showToast(
          context: context,
          builder: (context, overlay) => const Card(
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.success),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Incidencia Guardada',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('En cola para sincronización.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

        _closeCaptureFlow();
      }
    } on Exception catch (e) {
      debugPrint('Error saving incident: $e');
      if (mounted) {
        showToast(
          context: context,
          builder: (context, overlay) => Card(
            child: Row(
              children: [
                const Icon(Icons.error_rounded, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('Error al guardar la incidencia: $e')),
              ],
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine responsive size constraints for the Scaffold body
    final formBody = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Location Indicator
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.muted,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.border,
            ),
          ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.statusInReview),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ubicación',
                        style: Theme.of(context).typography.small,
                      ),
                      if (_isLoadingLocation)
                        const Text('Detectando proyecto cercano...')
                      else
                        Text(
                          _detectedProject?.name ?? 'Sin proyecto detectado',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                ),
                if (_isLoadingLocation) const StropLoader(size: 16),
              ],
            ),
          ),

          // Photo Gallery
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.imageFiles.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 180,
                  margin: EdgeInsets.only(
                    right: index < widget.imageFiles.length - 1 ? 8 : 0,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          widget.imageFiles[index],
                          fit: BoxFit.cover,
                        ),
                        if (widget.imageFiles.length > 1)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0x8A000000),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${index + 1}/${widget.imageFiles.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Priority Selector — three toggle buttons
          const Text('Prioridad').small.bold,
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _PriorityButton(
                  label: 'Normal',
                  value: IncidentPriority.normal,
                  groupValue: _priority,
                  onChanged: (val) => setState(() => _priority = val),
                  selectedBg: AppColors.priorityNormal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PriorityButton(
                  label: 'Urgente',
                  value: IncidentPriority.urgent,
                  groupValue: _priority,
                  onChanged: (val) => setState(() => _priority = val),
                  selectedBg: AppColors.priorityUrgent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PriorityButton(
                  label: 'Crítico',
                  value: IncidentPriority.critical,
                  groupValue: _priority,
                  onChanged: (val) => setState(() => _priority = val),
                  selectedBg: AppColors.priorityCritical,
                  icon: Icons.warning_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Title
          Row(
            children: [
              const Text(
                'Título',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const Text(
                ' *',
                style: TextStyle(
                  color: Color(0xFFB91C1C),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _titleController,
            focusNode: _titleFocusNode,
            placeholder: const Text('Ingrese el título...'),
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _descriptionFocusNode.requestFocus(),
          ),
          const SizedBox(height: 16),

          // Description
          const Text(
            'Descripción (Opcional)',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _descriptionController,
            focusNode: _descriptionFocusNode,
            placeholder: const Text('Detalles adicionales...'),
            maxLines: 3,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _locationFocusNode.requestFocus(),
          ),
          const SizedBox(height: 16),

          // Specific Location
          const Text(
            'Ubicación específica',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _specificLocationController,
            focusNode: _locationFocusNode,
            placeholder: const Text(
              'ej: "Nivel 3", "Baño Principal"',
            ),
            textInputAction: TextInputAction.done,
          ),
        const SizedBox(height: 8),
          // Recent Locations Chips
          if (_recentLocations.isNotEmpty)
            Wrap(
              spacing: 8,
              children: _recentLocations.map((loc) {
                return Button(
                  style: const ButtonStyle.ghost(),
                  onPressed: () {
                    setState(() {
                      _specificLocationController.text = loc;
                    });
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on_rounded, size: 14),
                      const SizedBox(width: 4),
                      Text(loc),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 16),

          // Trade Selector
          const Text(
            'Asignar a Gremio (Opcional)',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TradeButton(
                icon: Icons.construction,
                label: 'Albañilería',
                trade: Trade.masonry,
                isSelected: _selectedTrade == Trade.masonry,
                onTap: () {
                  setState(() {
                    _selectedTrade = _selectedTrade == Trade.masonry
                        ? null
                        : Trade.masonry;
                  });
                },
              ),
              _TradeButton(
                icon: Icons.plumbing,
                label: 'Plomería',
                trade: Trade.plumbing,
                isSelected: _selectedTrade == Trade.plumbing,
                onTap: () {
                  setState(() {
                    _selectedTrade = _selectedTrade == Trade.plumbing
                        ? null
                        : Trade.plumbing;
                  });
                },
              ),
              _TradeButton(
                icon: Icons.electrical_services,
                label: 'Eléctrico',
                trade: Trade.electrical,
                isSelected: _selectedTrade == Trade.electrical,
                onTap: () {
                  setState(() {
                    _selectedTrade = _selectedTrade == Trade.electrical
                        ? null
                        : Trade.electrical;
                  });
                },
              ),
              _TradeButton(
                icon: Icons.format_paint,
                label: 'Acabados',
                trade: Trade.finishing,
                isSelected: _selectedTrade == Trade.finishing,
                onTap: () {
                  setState(() {
                    _selectedTrade = _selectedTrade == Trade.finishing
                        ? null
                        : Trade.finishing;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Audio Note
          AudioRecordingWidget(
            onRecordingComplete: (path) {
              setState(() {
                _audioPath = path;
              });
            },
          ),
          const SizedBox(height: 32),
        ],
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _isSaving) return;
        unawaited(_confirmDiscardAndClose());
      },
      child: Scaffold(
        headers: [
          AppBar(
            title: const Text('Nueva Incidencia'),
            leading: [
              IconButton(
                variance: ButtonVariance.ghost,
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: _confirmDiscardAndClose,
              ),
            ],
          ),
          StepProgressBar(current: 3, total: 3),
        ],
        child: formBody,
        footers: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Button(
                style: const ButtonStyle.primary(),
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const StropLoader(size: 20)
                    : const Text(
                        'Guardar Incidencia',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TradeButton extends StatelessWidget {
  const _TradeButton({
    required this.icon,
    required this.label,
    required this.trade,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Trade trade;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Button(
        style: isSelected
            ? const ButtonStyle.secondary()
            : const ButtonStyle.outline(),
        onPressed: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityButton extends StatelessWidget {
  const _PriorityButton({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.selectedBg,
    this.icon,
  });

  final String label;
  final IncidentPriority value;
  final IncidentPriority groupValue;
  final ValueChanged<IncidentPriority> onChanged;
  /// Background colour when this button is selected.
  final Color selectedBg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onChanged(value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? selectedBg : theme.colorScheme.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[        
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? Colors.white
                    : theme.colorScheme.foreground,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : theme.colorScheme.foreground,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}