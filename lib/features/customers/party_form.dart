import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';

/// فرم ثبت/ویرایش مشتری یا تأمین‌کننده. شناسه ثبت‌شده یا null (انصراف).
Future<int?> showPartyForm(
  BuildContext context, {
  required String kind,
  Party? edit,
}) => showDialog<int>(
  context: context,
  builder: (_) => _PartyForm(kind: kind, edit: edit),
);

class _PartyForm extends StatefulWidget {
  final String kind;
  final Party? edit;
  const _PartyForm({required this.kind, this.edit});

  @override
  State<_PartyForm> createState() => _PartyFormState();
}

class _PartyFormState extends State<_PartyForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.edit?.name ?? '',
  );
  late final TextEditingController _mobile = TextEditingController(
    text: widget.edit?.mobile ?? '',
  );
  late final TextEditingController _code = TextEditingController();
  late final TextEditingController _desc = TextEditingController(
    text: widget.edit?.description ?? '',
  );
  late bool _consent = widget.edit?.smsConsent ?? false;
  late bool _active = widget.edit?.isActive ?? true;

  bool get _isCustomer => widget.kind == 'customer';

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _code.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final repo = context.svc.parties;
    final id = tryValue<int>(context, () {
      if (widget.edit == null) {
        return repo.create(
          kind: widget.kind,
          name: _name.text,
          mobile: _mobile.text,
          description: _desc.text,
          smsConsent: _consent,
          code: _code.text,
        );
      }
      repo.update(
        widget.edit!.id,
        name: _name.text,
        mobile: _mobile.text,
        description: _desc.text,
        smsConsent: _consent,
        isActive: _active,
      );
      return widget.edit!.id;
    });
    if (id != null) Navigator.pop(context, id);
  }

  @override
  Widget build(BuildContext context) {
    final noun = _isCustomer ? 'مشتری' : 'تأمین‌کننده';
    return AppDialog(
      title: widget.edit == null ? 'افزودن $noun' : 'ویرایش $noun',
      width: 460,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('انصراف'),
        ),
        FilledButton(onPressed: _save, child: const Text('ذخیره')),
      ],
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              autofocus: true,
              maxLength: 100,
              decoration: deco('نام و نام خانوادگی'),
              validator: (v) => requiredValidator(v, 'نام را وارد کنید.'),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _mobile,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: deco('شماره موبایل (اختیاری)', hint: '09123456789'),
            ),
            if (widget.edit == null) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _code,
                textDirection: TextDirection.ltr,
                decoration: deco('کد (خالی = خودکار)'),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'کد: ${widget.edit!.code}',
                style: const TextStyle(fontSize: 12.5),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _desc,
              maxLines: 2,
              maxLength: 500,
              decoration: deco('توضیحات'),
            ),
            if (_isCustomer)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('رضایت دریافت پیامک تبلیغاتی و مناسبتی'),
                subtitle: const Text(
                  'فقط با رضایت مشتری پیامک تبلیغاتی ارسال می‌شود.',
                ),
                value: _consent,
                onChanged: (v) => setState(() => _consent = v),
              ),
            if (widget.edit != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('فعال'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
          ],
        ),
      ),
    );
  }
}
