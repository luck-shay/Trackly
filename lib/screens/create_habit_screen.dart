import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/habit.dart';

class CreateHabitScreen extends StatefulWidget {
  const CreateHabitScreen({super.key});

  @override
  State<CreateHabitScreen> createState() => _CreateHabitScreenState();
}

class _CreateHabitScreenState extends State<CreateHabitScreen> {
  final _formKey = GlobalKey<FormState>();
  String _title = '';
  String _description = '';
  int _targetDays = 7;

  void _saveHabit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final newHabit = Habit(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _title,
        description: _description,
        createdAt: DateTime.now(),
        targetDaysPerWeek: _targetDays,
      );
      Navigator.pop(context, newHabit);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('New Routine', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What do you want to build?',
                style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold),
              ).animate().fade().slideY(begin: 0.1),
              const SizedBox(height: 32),
              
              // Name Input
              Text(
                'HABIT NAME',
                style: GoogleFonts.inter(
                  fontSize: 12, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.grey[500],
                  letterSpacing: 1.2
                ),
              ).animate().fade(delay: 100.ms),
              const SizedBox(height: 12),
              TextFormField(
                style: GoogleFonts.inter(fontSize: 18),
                decoration: InputDecoration(
                  hintText: 'e.g. Morning Run',
                  hintStyle: TextStyle(color: Colors.grey[700]),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please give your habit a name.';
                  }
                  return null;
                },
                onSaved: (value) => _title = value!,
              ).animate().fade(delay: 150.ms).slideX(begin: 0.05),
              
              const SizedBox(height: 32),
              
              // Description Input
              Text(
                'DESCRIPTION (OPTIONAL)',
                style: GoogleFonts.inter(
                  fontSize: 12, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.grey[500],
                  letterSpacing: 1.2
                ),
              ).animate().fade(delay: 200.ms),
              const SizedBox(height: 12),
              TextFormField(
                style: GoogleFonts.inter(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'e.g. 5km around the park',
                  hintStyle: TextStyle(color: Colors.grey[700]),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                maxLines: 3,
                onSaved: (value) => _description = value ?? '',
              ).animate().fade(delay: 250.ms).slideX(begin: 0.05),

              const SizedBox(height: 40),
              
              // Target Days
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TARGET FREQUENCY',
                    style: GoogleFonts.inter(
                      fontSize: 12, 
                      fontWeight: FontWeight.bold, 
                      color: Colors.grey[500],
                      letterSpacing: 1.2
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_targetDays days / week',
                      style: GoogleFonts.inter(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                ],
              ).animate().fade(delay: 300.ms),
              const SizedBox(height: 16),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Theme.of(context).colorScheme.primary,
                  inactiveTrackColor: Theme.of(context).colorScheme.surface,
                  thumbColor: Theme.of(context).colorScheme.primary,
                  overlayColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  trackHeight: 8.0,
                ),
                child: Slider(
                  value: _targetDays.toDouble(),
                  min: 1,
                  max: 7,
                  divisions: 6,
                  onChanged: (double value) {
                    setState(() {
                      _targetDays = value.toInt();
                    });
                  },
                ),
              ).animate().fade(delay: 350.ms),
              
              const SizedBox(height: 60),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _saveHabit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Create Habit',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ).animate().fade(delay: 450.ms).slideY(begin: 0.2),
            ],
          ),
        ),
      ),
    );
  }
}
