import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/group.dart';
import '../models/group_task.dart';
import '../services/group_service.dart';
import '../theme/app_layout.dart';
import '../utils/quantity_format.dart';

class CreateGroupTaskScreen extends StatefulWidget {
  final Group group;
  final GroupTask? initialTask;

  const CreateGroupTaskScreen({
    super.key,
    required this.group,
    this.initialTask,
  });

  @override
  State<CreateGroupTaskScreen> createState() => _CreateGroupTaskScreenState();
}

class _CreateGroupTaskScreenState extends State<CreateGroupTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _quantUnitController;
  late final TextEditingController _quantMaxController;

  bool _isQuantified = false;
  bool _isSaving = false;

  bool get _isEditMode => widget.initialTask != null;

  @override
  void initState() {
    super.initState();
    final initialTask = widget.initialTask;
    _titleController = TextEditingController(text: initialTask?.title ?? '');
    _descriptionController = TextEditingController(
      text: initialTask?.description ?? '',
    );
    _quantUnitController = TextEditingController(
      text: initialTask?.quantUnit ?? 'units',
    );
    _quantMaxController = TextEditingController(
      text: formatQuantity(initialTask?.quantMax ?? 10, maxDecimals: 1),
    );
    _isQuantified = initialTask?.isQuantified ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _quantUnitController.dispose();
    _quantMaxController.dispose();
    super.dispose();
  }

  String _formatTarget(double value) {
    return formatQuantity(value, maxDecimals: 1);
  }

  bool _setPresetUnit(String unit) {
    final parsedMax = double.tryParse(_quantMaxController.text.trim());
    final currentMax = parsedMax ?? 10;

    _quantUnitController.text = unit;
    _quantMaxController.text = _formatTarget(currentMax);
    return true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    var quantUnit = _quantUnitController.text.trim();
    var quantMax = double.tryParse(_quantMaxController.text.trim());

    if (_isQuantified) {
      if (quantUnit.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please enter a unit.')));
        return;
      }
      if (quantMax == null || !quantMax.isFinite || quantMax <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid daily target.')),
        );
        return;
      }
    } else {
      quantUnit = 'units';
      quantMax = 1;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final task = _isEditMode
          ? await GroupService().updateGroupTaskAsAdmin(
              existingTask: widget.initialTask!,
              title: _titleController.text.trim(),
              description: _descriptionController.text.trim(),
              isQuantified: _isQuantified,
              quantUnit: quantUnit,
              quantMax: quantMax,
            )
          : await GroupService().createGroupTask(
              groupId: widget.group.id,
              title: _titleController.text.trim(),
              description: _descriptionController.text.trim(),
              isQuantified: _isQuantified,
              quantUnit: quantUnit,
              quantMax: quantMax,
            );

      if (!mounted) {
        return;
      }

      Navigator.pop(context, task);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not ${_isEditMode ? 'update' : 'create'} group task. ${error.toString().split('\n').first}',
          ),
        ),
      );
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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Edit Group Task' : 'New Group Task',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: AppLayout.screenPadding,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEditMode
                    ? 'Update task in ${widget.group.name}'
                    : 'Add a task to ${widget.group.name}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: scheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
              const VGap(AppLayout.lg),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Task title',
                  hintText: 'e.g. Kitchen cleanup rotation',
                  filled: true,
                  fillColor: scheme.surface,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: scheme.onSurface.withValues(alpha: 0.1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: scheme.primary.withValues(alpha: 0.8),
                      width: 1.4,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: scheme.onSurface.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a task title.';
                  }
                  return null;
                },
              ),
              const VGap(AppLayout.md),
              TextFormField(
                controller: _descriptionController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Add context, acceptance criteria, or schedule.',
                  filled: true,
                  fillColor: scheme.surface,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: scheme.onSurface.withValues(alpha: 0.1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: scheme.primary.withValues(alpha: 0.8),
                      width: 1.4,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: scheme.onSurface.withValues(alpha: 0.1),
                    ),
                  ),
                ),
              ),
              const VGap(AppLayout.lg),
              SwitchListTile.adaptive(
                value: _isQuantified,
                onChanged: (value) {
                  setState(() {
                    _isQuantified = value;
                  });
                },
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Quantified tracking',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  _isQuantified
                      ? 'Members log a value instead of simple checkbox completion.'
                      : 'Simple completed / not completed toggle.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: 0.68),
                  ),
                ),
              ),
              if (_isQuantified) ...[
                const VGap(AppLayout.sm),
                TextFormField(
                  controller: _quantUnitController,
                  decoration: InputDecoration(
                    labelText: 'Unit',
                    hintText: 'e.g. km, pages, glasses',
                    filled: true,
                    fillColor: scheme.surface,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: scheme.onSurface.withValues(alpha: 0.1),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: scheme.primary.withValues(alpha: 0.8),
                        width: 1.4,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: scheme.onSurface.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (!_isQuantified) {
                      return null;
                    }
                    if (value == null || value.trim().isEmpty) {
                      return 'Unit is required.';
                    }
                    return null;
                  },
                ),
                const VGap(AppLayout.xs),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['units', 'reps', 'km', 'hours', 'pages', 'steps']
                      .map((unit) {
                        final selected =
                            _quantUnitController.text.trim().toLowerCase() ==
                            unit;
                        return ChoiceChip(
                          label: Text(unit),
                          selected: selected,
                          onSelected: (_) {
                            setState(() {
                              _setPresetUnit(unit);
                            });
                          },
                        );
                      })
                      .toList(),
                ),
                const VGap(AppLayout.sm),
                TextFormField(
                  controller: _quantMaxController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Daily target',
                    hintText: 'e.g. 10',
                    filled: true,
                    fillColor: scheme.surface,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: scheme.onSurface.withValues(alpha: 0.1),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: scheme.primary.withValues(alpha: 0.8),
                        width: 1.4,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: scheme.onSurface.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (!_isQuantified) {
                      return null;
                    }
                    final parsed = double.tryParse((value ?? '').trim());
                    if (parsed == null || !parsed.isFinite || parsed <= 0) {
                      return 'Enter a valid number greater than 0.';
                    }
                    return null;
                  },
                ),
              ],
              const VGap(AppLayout.xl),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _isSaving
                        ? (_isEditMode ? 'Updating...' : 'Creating...')
                        : (_isEditMode
                              ? 'Update Group Task'
                              : 'Create Group Task'),
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
