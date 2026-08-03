import 'package:flutter/material.dart';

/// Shows a single-field title dialog and returns the trimmed input (or null if
/// cancelled).
///
/// The text controller is owned by the dialog widget so it is disposed only
/// after the close animation finishes. Disposing it eagerly (right after
/// `showDialog` returns) crashes, because the exit transition rebuilds the
/// field and touches the already-disposed controller.
Future<String?> showTitleDialog(
  BuildContext context, {
  String initial = '',
  String title = '제목',
  String hint = '',
  String confirmLabel = '저장',
}) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext ctx) => _TitleDialog(
      initial: initial,
      title: title,
      hint: hint,
      confirmLabel: confirmLabel,
    ),
  );
}

class _TitleDialog extends StatefulWidget {
  const _TitleDialog({
    required this.initial,
    required this.title,
    required this.hint,
    required this.confirmLabel,
  });

  final String initial;
  final String title;
  final String hint;
  final String confirmLabel;

  @override
  State<_TitleDialog> createState() => _TitleDialogState();
}

class _TitleDialogState extends State<_TitleDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          hintText: widget.hint.isEmpty ? null : widget.hint,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (String v) => Navigator.of(context).pop(v.trim()),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
