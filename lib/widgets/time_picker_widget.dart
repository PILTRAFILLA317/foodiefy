// lib/widgets/time_picker_widget.dart
import 'package:flutter/material.dart';

class TimePickerWidget extends StatefulWidget {
  final int? initialMinutes;
  final Function(int?) onTimeChanged;

  const TimePickerWidget({
    super.key,
    this.initialMinutes,
    required this.onTimeChanged,
  });

  @override
  State<TimePickerWidget> createState() => _TimePickerWidgetState();
}

class _TimePickerWidgetState extends State<TimePickerWidget> {
  int? _selectedMinutes;

  @override
  void initState() {
    super.initState();
    _selectedMinutes = widget.initialMinutes;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_selectedMinutes != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timer, color: Colors.black),
                const SizedBox(width: 8),
                Text(
                  _formatTime(_selectedMinutes!),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildTimeChip(15, '15 min'),
            _buildTimeChip(30, '30 min'),
            _buildTimeChip(45, '45 min'),
            _buildTimeChip(60, '1 hora'),
            _buildTimeChip(90, '1h 30min'),
            _buildTimeChip(120, '2 horas'),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showCustomTimePicker,
                icon: const Icon(Icons.edit),
                label: const Text('Tiempo personalizado'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.black),
              ),
            ),
            if (_selectedMinutes != null) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  setState(() => _selectedMinutes = null);
                  widget.onTimeChanged(null);
                },
                icon: const Icon(Icons.clear, color: Colors.red),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildTimeChip(int minutes, String label) {
    final isSelected = _selectedMinutes == minutes;
    return FilterChip(
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedMinutes = selected ? minutes : null;
        });
        widget.onTimeChanged(_selectedMinutes);
      },
      backgroundColor: Colors.white,
      selectedColor: Colors.grey[500],
      checkmarkColor: Colors.black,
    );
  }

  void _showCustomTimePicker() {
    int hours = (_selectedMinutes ?? 0) ~/ 60;
    int minutes = (_selectedMinutes ?? 0) % 60;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Tiempo personalizado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      const Text('Horas'),
                      SizedBox(
                        width: 60,
                        child: TextField(
                          decoration: InputDecoration(
                            fillColor: Colors.grey[300],
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          cursorColor: Colors.black,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          controller: TextEditingController(
                            text: hours.toString(),
                          ),
                          onChanged: (value) {
                            hours = int.tryParse(value) ?? 0;
                          },
                        ),
                      ),
                    ],
                  ),
                  const Text(':', style: TextStyle(fontSize: 24)),
                  Column(
                    children: [
                      const Text('Minutos'),
                      SizedBox(
                        width: 60,
                        child: TextField(
                          decoration: InputDecoration(
                            fillColor: Colors.grey[300],
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          cursorColor: Colors.black,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          controller: TextEditingController(
                            text: minutes.toString(),
                          ),
                          onChanged: (value) {
                            minutes = int.tryParse(value) ?? 0;
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancelar',
                style: TextStyle(
                  color: Colors.black,
                  // fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final totalMinutes = (hours * 60) + minutes;
                setState(
                  () =>
                      _selectedMinutes = totalMinutes > 0 ? totalMinutes : null,
                );
                widget.onTimeChanged(_selectedMinutes);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) return '${hours}h';
    return '${hours}h ${remainingMinutes}min';
  }
}
