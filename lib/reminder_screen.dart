import 'package:flutter/material.dart';

import 'data/inventory_database.dart';
import 'domain/reminder.dart';
import 'reminders/notification_service.dart';
import 'reminders/reminder_controller.dart';

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key, required this.database, this.controller});
  final InventoryDatabase database;
  final ReminderController? controller;
  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  late final ReminderController _controller;
  bool _loading = true;
  bool _saving = false;
  bool _enabled = false;
  bool _dirty = false;
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  int _leadDays = 3;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ??
        ReminderController(widget.database, PreviewNotifications());
    _controller.addListener(_updated);
    _load();
  }

  void _updated() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    await _controller.start();
    if (!mounted) return;
    final settings = _controller.settings;
    setState(() {
      _enabled = settings.enabled;
      _time = TimeOfDay(hour: settings.hour, minute: settings.minute);
      _leadDays = settings.leadDays;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_updated);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _controller.save(
        ReminderSettings(
          enabled: _enabled,
          hour: _time.hour,
          minute: _time.minute,
          leadDays: _leadDays,
        ),
      );
      if (mounted) setState(() => _dirty = false);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not save reminder settings. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    setState(() => _saving = true);
    try {
      await _controller.service.sendTest();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test notification requested. Check your device.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not send a test. Check Android notification permissions.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reminders')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'Review food dates',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'One reminder per batch each day in the lead window, through its printed-date day. Unknown dates, past dates and depleted batches are excluded.',
                  ),
                  const SizedBox(height: 16),
                  if (!_controller.service.supported)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Web preview · Settings save in this browser. No background or device notifications are scheduled here. Android delivery needs a phone check.',
                        ),
                      ),
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable reminders'),
                    subtitle: const Text('Save below to apply changes.'),
                    value: _enabled,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() {
                            _enabled = value;
                            _dirty = true;
                          }),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _time,
                              );
                              if (picked != null && mounted) {
                                setState(() {
                                  _time = picked;
                                  _dirty = true;
                                });
                              }
                            },
                      icon: const Icon(Icons.schedule),
                      label: Text('Daily time · ${_time.format(context)}'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: _leadDays,
                    decoration: const InputDecoration(labelText: 'Lead window'),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1 day ahead')),
                      DropdownMenuItem(value: 3, child: Text('3 days ahead')),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) => setState(() {
                            _leadDays = value!;
                            _dirty = true;
                          }),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(
                          _saving ? 'Saving…' : 'Save reminder settings',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _saving
                            ? null
                            : () async {
                                setState(() => _saving = true);
                                await _controller.refresh();
                                if (mounted) setState(() => _saving = false);
                              },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Resync saved settings'),
                      ),
                      if (_controller.service.supported)
                        OutlinedButton(
                          onPressed: _saving ? null : _test,
                          child: const Text('Send test notification'),
                        ),
                    ],
                  ),
                  if (_dirty)
                    const Text(
                      'Unsaved changes. The preview below uses your saved settings.',
                    ),
                  if (_error != null)
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    _controller.status,
                    style: TextStyle(
                      color: _controller.failed
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Upcoming alerts · ${_controller.plan.length}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    _controller.settings.enabled
                        ? 'Preview for saved settings. Times are local to your device.'
                        : 'Reminders are off. These are preview times only.',
                  ),
                  if (_controller.plan.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'No future alerts qualify. Add an active batch with a printed date. Times already passed today are skipped.',
                      ),
                    ),
                  for (final reminder in _controller.plan.take(12))
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.notifications_none),
                        title: Text(reminder.food),
                        subtitle: Text(
                          '${MaterialLocalizations.of(context).formatMediumDate(reminder.at)} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(reminder.at))}\nPrinted date: ${reminder.printedDate} · Batch #${reminder.batchId}',
                        ),
                        isThreeLine: true,
                      ),
                    ),
                  if (_controller.plan.length > 12)
                    const Text('Showing the first 12 upcoming alerts.'),
                  const SizedBox(height: 16),
                  const ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text('How reminders work'),
                    children: [
                      Text(
                        'Includes the printed-date day. Alerts review recorded dates, not freshness. Passing a date never changes stock or records waste. Android timing may be delayed by battery settings. Timezone changes are picked up on reopen, resume, or resync.',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
  );
}
