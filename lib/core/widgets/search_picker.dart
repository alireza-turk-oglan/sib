import 'package:flutter/material.dart';

import '../utils/format.dart';
import 'common.dart';

/// دیالوگ انتخاب از فهرست با جست‌وجو. [onCreate] (اختیاری) برای «افزودن مورد جدید» در همان لحظه.
Future<T?> showSearchPicker<T>(
  BuildContext context, {
  required String title,
  required List<T> items,
  required String Function(T) label,
  String Function(T)? subtitle,
  Widget Function(T)? trailing,
  Future<T?> Function()? onCreate,
  String createLabel = 'افزودن جدید',
}) => showDialog<T>(
  context: context,
  builder: (_) => _SearchPicker<T>(
    title: title,
    items: items,
    label: label,
    subtitle: subtitle,
    trailing: trailing,
    onCreate: onCreate,
    createLabel: createLabel,
  ),
);

class _SearchPicker<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final String Function(T) label;
  final String Function(T)? subtitle;
  final Widget Function(T)? trailing;
  final Future<T?> Function()? onCreate;
  final String createLabel;
  const _SearchPicker({
    required this.title,
    required this.items,
    required this.label,
    this.subtitle,
    this.trailing,
    this.onCreate,
    required this.createLabel,
  });

  @override
  State<_SearchPicker<T>> createState() => _SearchPickerState<T>();
}

class _SearchPickerState<T> extends State<_SearchPicker<T>> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final nq = normalizeFa(enDigits(q)).toLowerCase();
    final shown = nq.isEmpty
        ? widget.items
        : widget.items.where((e) {
            final t = '${widget.label(e)} ${widget.subtitle?.call(e) ?? ''}'
                .toLowerCase();
            return t.contains(nq);
          }).toList();
    return AppDialog(
      title: widget.title,
      width: 460,
      actions: [
        if (widget.onCreate != null)
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: Text(widget.createLabel),
            onPressed: () async {
              final created = await widget.onCreate!();
              if (created != null && context.mounted) {
                Navigator.pop(context, created);
              }
            },
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('انصراف'),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            autofocus: true,
            decoration: deco('جست‌وجو', suffix: const Icon(Icons.search)),
            onChanged: (v) => setState(() => q = v),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 340,
            child: shown.isEmpty
                ? const EmptyState(
                    icon: Icons.search_off,
                    text: 'موردی پیدا نشد.',
                  )
                : ListView.builder(
                    itemCount: shown.length,
                    itemBuilder: (context, i) {
                      final e = shown[i];
                      return ListTile(
                        dense: true,
                        title: Text(widget.label(e)),
                        subtitle: widget.subtitle == null
                            ? null
                            : Text(widget.subtitle!(e)),
                        trailing: widget.trailing?.call(e),
                        onTap: () => Navigator.pop(context, e),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
