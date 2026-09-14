import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/semantic_colors.dart';

class ScheduleTab extends StatefulWidget {
  const ScheduleTab({super.key});

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  DateTime _selectedDate = DateTime.now();
  String _workingStartHour = '09:00 AM';
  String _workingEndHour = '07:00 PM';

  final List<String> _weeklyDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  final List<String> _selectedDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

  // Leave Form States
  String _leaveType = 'Full Day';
  final _leaveReasonController = TextEditingController();
  final List<Map<String, String>> _leaveHistory = [
    {'date': '04 Aug 2026', 'type': 'Full Day', 'reason': 'Medical checkup', 'status': 'Approved'},
    {'date': '28 Jul 2026', 'type': 'Half Day', 'reason': 'Family emergency', 'status': 'Approved'}
  ];

  @override
  void dispose() {
    _leaveReasonController.dispose();
    super.dispose();
  }

  void _applyForLeave() {
    if (_leaveReasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please state the reason for leave.'), backgroundColor: SemanticColors.error),
      );
      return;
    }

    setState(() {
      _leaveHistory.insert(0, {
        'date': '17 Aug 2026',
        'type': _leaveType,
        'reason': _leaveReasonController.text.trim(),
        'status': 'Pending Approval'
      });
      _leaveReasonController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Leave application submitted to Admin successfully!'), backgroundColor: SemanticColors.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Work Schedule & Leave'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Calendar Simulation card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Shift Availability Calendar', style: AppTypography.titleMedium),
                    const SizedBox(height: AppSpacing.s),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Selected Date: ${_selectedDate.day} Aug 2026',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2026),
                              lastDate: DateTime(2027),
                            );
                            if (picked != null) {
                              setState(() {
                                _selectedDate = picked;
                              });
                            }
                          },
                          child: const Text('Change Date'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.m),

            // SHIFT TIMINGS & WORKING DAYS CONFIG
            const Text('Configure Working Shift Timings', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.s),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _workingStartHour,
                            decoration: const InputDecoration(labelText: 'Start Hour', border: OutlineInputBorder()),
                            items: ['08:00 AM', '09:00 AM', '10:00 AM'].map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _workingStartHour = val);
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _workingEndHour,
                            decoration: const InputDecoration(labelText: 'End Hour', border: OutlineInputBorder()),
                            items: ['05:00 PM', '06:00 PM', '07:00 PM', '08:00 PM', '09:00 PM'].map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _workingEndHour = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.m),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Weekly Availability Days', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _weeklyDays.map((day) {
                        final isSelected = _selectedDays.contains(day);
                        return ChoiceChip(
                          label: Text(day, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : AppColors.textPrimary)),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedDays.add(day);
                              } else {
                                _selectedDays.remove(day);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Weekly shift configurations updated successfully!'), backgroundColor: SemanticColors.success),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.black,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 44),
                        shape: const RoundedRectangleBorder(borderRadius: AppRadius.small),
                      ),
                      child: const Text('Save Availability Settings'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.m),

            // APPLY FOR LEAVE FORM
            const Text('Apply For Leave (Request Offline)', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.s),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _leaveType,
                      decoration: const InputDecoration(labelText: 'Leave Type', border: OutlineInputBorder()),
                      items: ['Full Day', 'Half Day', 'Multiple Days'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _leaveType = val);
                      },
                    ),
                    const SizedBox(height: AppSpacing.s),
                    TextField(
                      controller: _leaveReasonController,
                      decoration: const InputDecoration(
                        labelText: 'Reason for leave request',
                        hintText: 'e.g. Out of station / Personal reasons',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    ElevatedButton(
                      onPressed: _applyForLeave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SemanticColors.error,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 44),
                        shape: const RoundedRectangleBorder(borderRadius: AppRadius.small),
                      ),
                      child: const Text('Submit Leave Request'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.m),

            // LEAVE HISTORY
            const Text('Leave Request History', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.s),
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _leaveHistory.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _leaveHistory[index];
                  final isApproved = item['status'] == 'Approved';
                  return ListTile(
                    title: Text('${item['type']} Leave - ${item['date']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('Reason: ${item['reason']}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isApproved ? SemanticColors.success.withValues(alpha: 0.1) : SemanticColors.warning.withValues(alpha: 0.1),
                        borderRadius: AppRadius.round,
                      ),
                      child: Text(
                        item['status'].toString(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isApproved ? SemanticColors.success : SemanticColors.warning,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
