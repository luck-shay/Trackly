import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/group.dart';
import '../services/group_service.dart';
import '../theme/app_layout.dart';

class CreateGroupTaskScreen extends StatefulWidget {
  final Group group;

  const CreateGroupTaskScreen({super.key, required this.group});

  @override
  State<CreateGroupTaskScreen> createState() => _CreateGroupTaskScreenState();
}

class _CreateGroupTaskScreenState extends State<CreateGroupTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isQuantified = false;
  String _quantUnit = 'units';
  double _quantMax = 10;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final task = await GroupService().createGroupTask(
        groupId: widget.group.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        isQuantified: _isQuantified,
        quantUnit: _quantUnit,
        quantMax: _quantMax,
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
            'Could not create group task. ${error.toString().split('\n').first}',
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
          'New Group Task',
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
                'Add a task to ${widget.group.name}',
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
                DropdownButtonFormField<String>(
                  initialValue: _quantUnit,
                  decoration: InputDecoration(
                    labelText: 'Unit',
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
                  items: const [
                    DropdownMenuItem(value: 'units', child: Text('units')),
                    DropdownMenuItem(value: 'reps', child: Text('reps')),
                    DropdownMenuItem(value: 'km', child: Text('km')),
                    DropdownMenuItem(value: 'hours', child: Text('hours')),
                    DropdownMenuItem(value: 'pages', child: Text('pages')),
                    DropdownMenuItem(value: 'steps', child: Text('steps')),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _quantUnit = value;
                    });
                  },
                ),
                const VGap(AppLayout.sm),
                Text(
                  'Daily goal: ${_quantMax.toStringAsFixed(0)} $_quantUnit',
                  style: GoogleFonts.inter(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Slider(
                  value: _quantMax,
                  min: 1,
                  max: 100,
                  divisions: 99,
                  onChanged: (value) {
                    setState(() {
                      _quantMax = value;
                    });
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
                    _isSaving ? 'Creating...' : 'Create Group Task',
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
