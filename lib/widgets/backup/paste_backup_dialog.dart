import 'package:flutter/material.dart';

/// Opens a dialog where the user can paste exported FreshKeep JSON text.
Future<String?> showPasteBackupDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _PasteBackupDialog(),
  );
}

class _PasteBackupDialog extends StatefulWidget {
  const _PasteBackupDialog();

  @override
  State<_PasteBackupDialog> createState() => _PasteBackupDialogState();
}

class _PasteBackupDialogState extends State<_PasteBackupDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Paste backup JSON'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Paste JSON created by FreshKeep. It will be validated before changing anything.',
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('paste-backup-field'),
              controller: _controller,
              maxLines: 8,
              minLines: 4,
              decoration: const InputDecoration(
                labelText: 'Backup JSON',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('review-pasted-backup'),
        onPressed: () => Navigator.pop(context, _controller.text),
        child: const Text('Review backup'),
      ),
    ],
  );
}
