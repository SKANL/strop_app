import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strop_app/app/di/service_locator.dart';
import 'package:strop_app/core/services/image_compression_service.dart';
import 'package:strop_app/domain/entities/incident.dart';
import 'package:strop_app/domain/entities/project.dart';
import 'package:strop_app/domain/repositories/incident_repository.dart';
import 'package:strop_app/domain/repositories/project_repository.dart';
import 'package:strop_app/presentation/capture/widgets/audio_recorder.dart';
import 'package:uuid/uuid.dart';

class IncidentFormPage extends StatefulWidget {
  const IncidentFormPage({
    required this.imageFiles,
    this.annotations = const [],
    super.key,
  });

  final List<File> imageFiles;
  final List<List<Offset>> annotations;

  @override
  State<IncidentFormPage> createState() => _IncidentFormPageState();
}

class _IncidentFormPageState extends State<IncidentFormPage> {
  final _formKey = GlobalKey<FormState>();
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

  @override
  void initState() {
    super.initState();
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
      // Simulate getting GPS coords
      final project = await sl<ProjectRepository>().getNearestProject(0, 0);
      if (mounted) {
        setState(() {
          _detectedProject = project;
          _isLoadingLocation = false;
        });
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
    _titleController.dispose();
    _descriptionController.dispose();
    _specificLocationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

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

      if (mounted) {
        shadcn.showToast(
          context: context,
          builder: (context, overlay) => const shadcn.Card(
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Incident Saved',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('Your report has been queued for sync.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

        // Navigate back to Home
        context.go('/');
      }
    } on Exception catch (e) {
      debugPrint('Error saving incident: $e');
      if (mounted) {
        shadcn.showToast(
          context: context,
          builder: (context, overlay) => shadcn.Card(
            child: Row(
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to save incident: $e')),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Incident'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Location Indicator
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Location',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (_isLoadingLocation)
                          const Text('Detecting nearby project...')
                        else
                          Text(
                            _detectedProject?.name ?? 'No project detected',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                  ),
                  if (_isLoadingLocation)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
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
                                  color: Colors.black54,
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

            // Priority Selector
            const Text('Priority'),
            const SizedBox(height: 8),
            SegmentedButton<IncidentPriority>(
              segments: const [
                ButtonSegment(
                  value: IncidentPriority.normal,
                  label: Text('Low'),
                ),
                ButtonSegment(
                  value: IncidentPriority.urgent,
                  label: Text('Medium'),
                ),
                ButtonSegment(
                  value: IncidentPriority.critical,
                  label: Text('High'),
                ),
              ],
              selected: {_priority},
              onSelectionChanged: (newSelection) {
                setState(() {
                  _priority = newSelection.first;
                });
              },
            ),
            const SizedBox(height: 16),

            // Title
            shadcn.TextField(
              controller: _titleController,
              placeholder: const Text('Title'),
            ),
            const SizedBox(height: 16),

            // Description
            shadcn.TextField(
              controller: _descriptionController,
              placeholder: const Text('Description (Optional)'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Specific Location
            shadcn.TextField(
              controller: _specificLocationController,
              placeholder: const Text(
                'Specific location (e.g., "Level 3", "Main Bathroom")',
              ),
            ),
            const SizedBox(height: 8),

            // Recent Locations Chips
            if (_recentLocations.isNotEmpty)
              Wrap(
                spacing: 8,
                children: _recentLocations.map((loc) {
                  return shadcn.Button.ghost(
                    onPressed: () {
                      setState(() {
                        _specificLocationController.text = loc;
                      });
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on, size: 14),
                        const SizedBox(width: 4),
                        Text(loc),
                      ],
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 16),

            // Trade Selector
            const Text('Assign to Trade (Optional)'),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
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

            // Save Button
            shadcn.Button.primary(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save Incident'),
            ),
          ],
        ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Colors.blue
                : Colors.grey.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? Colors.blue : Colors.grey[700],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.blue : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
