import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../data/database.dart' show DomainError;
import '../../data/models.dart';
import '../../services/sms_sender.dart';

const Map<SmsKind, List<String>> _templates = {
  SmsKind.info: [
    'سلام {name} عزیز، فاکتور شما آماده است. با تشکر از خرید شما.',
    'سلام {name} عزیز، یادآوری: مانده حساب شما هنوز تسویه نشده است. لطفاً در اولین فرصت اقدام فرمایید.',
  ],
  SmsKind.promo: [
    'سلام {name} عزیز، تخفیف ویژه ما برای شما! برای اطلاع از جزئیات تماس بگیرید.',
    'مشتری گرامی {name}، محصولات جدید رسید. منتظر دیدار شما هستیم.',
  ],
  SmsKind.occasion: [
    '{name} عزیز، عید نوروز و سال نو بر شما مبارک!',
    '{name} عزیز، شب یلدا بر شما مبارک!',
    '{name} عزیز، از همراهی شما سپاسگزاریم. روزتان خوش!',
  ],
};

class ClubPage extends StatefulWidget {
  const ClubPage({super.key});

  @override
  State<ClubPage> createState() => _ClubPageState();
}

class _ClubPageState extends State<ClubPage> {
  SmsKind kind = SmsKind.info;
  final _msg = TextEditingController();
  final _q = TextEditingController();
  List<Party> customers = [];
  final Set<int> selected = {};
  bool debtorsOnly = false;
  bool sending = false;
  int done = 0;
  int total = 0;
  bool historyView = false;
  List<SmsLogRow> history = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _msg.dispose();
    _q.dispose();
    super.dispose();
  }

  void _load() {
    if (!mounted) return;
    final s = context.svc;
    setState(() {
      customers = s.parties
          .list('customer', query: _q.text)
          .where((p) => p.mobile != null && p.isActive)
          .toList();
      history = s.sms.history();
    });
  }

  List<Party> get _shown =>
      debtorsOnly ? customers.where((p) => p.balance > 0).toList() : customers;
  bool _eligible(Party p) => !kind.needsConsent || p.smsConsent;

  void _selectAll() => setState(() {
    for (final p in _shown) {
      if (_eligible(p)) selected.add(p.id);
    }
  });

  Future<void> _send() async {
    final err = SmsSender.validate(_msg.text);
    if (err != null) return toast(context, err, error: true);
    final recs = customers
        .where((p) => selected.contains(p.id))
        .map(
          (p) => SmsRecipient(
            partyId: p.id,
            name: p.name,
            mobile: p.mobile!,
            consent: p.smsConsent,
          ),
        )
        .toList();
    if (recs.isEmpty) {
      return toast(context, 'گیرنده‌ای انتخاب نشده است.', error: true);
    }
    final parts = SmsSender.parts(_msg.text);
    final ok = await confirmDialog(
      context,
      title: 'ارسال پیامک ${kind.label}',
      message:
          'پیامک برای ${faDigits(recs.length)} نفر ارسال می‌شود (حدود ${faDigits(parts)} بخش برای هر پیام). ادامه می‌دهید؟',
      confirmLabel: 'ارسال',
    );
    if (!ok || !mounted) return;
    final app = context.app;
    final svc = context.svc;
    setState(() {
      sending = true;
      done = 0;
      total = recs.length;
    });
    SmsOutcome? out;
    try {
      out = await SmsSender((m, to) => app.auth.sendSms(m, to), svc.sms).send(
        recipients: recs,
        template: _msg.text,
        kind: kind,
        onProgress: (d, t) {
          if (mounted) setState(() => done = d);
        },
      );
    } on DomainError catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => sending = false);
    }
    if (out == null || !mounted) return;
    final failedIds = svc.sms.failedPartyIds(out.batchId);
    _load();
    setState(() {
      selected
        ..clear()
        ..addAll(failedIds); // برای «تلاش مجدد» فقط ناموفق‌ها انتخاب بمانند
    });
    await messageDialog(
      context,
      'نتیجه ارسال',
      'موفق: ${faDigits(out.sent)}\nناموفق: ${faDigits(out.failed)}${out.skippedNoConsent > 0 ? '\nبدون رضایت (ارسال نشد): ${faDigits(out.skippedNoConsent)}' : ''}'
          '${out.errors.isNotEmpty ? '\n\nعلت خطا:\n${out.errors.map((e) => '• $e').join('\n')}' : ''}'
          '${out.failed > 0 ? '\n\nگیرندگان ناموفق انتخاب شده‌اند؛ می‌توانید دوباره ارسال کنید.' : ''}',
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'باشگاه مشتریان',
          subtitle:
              'ارسال پیامک اطلاع‌رسانی، تبلیغاتی و مناسبتی (از طریق سرور)',
          actions: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('ارسال پیامک')),
                ButtonSegment(value: true, label: Text('تاریخچه')),
              ],
              selected: {historyView},
              onSelectionChanged: (s) {
                setState(() => historyView = s.first);
                _load();
              },
            ),
          ],
        ),
        Expanded(child: historyView ? _history(context) : _compose(context)),
      ],
    ),
  );

  Widget _compose(BuildContext context) {
    final parts = SmsSender.parts(_msg.text);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 400,
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionTitle('متن پیام'),
                SegmentedButton<SmsKind>(
                  segments: [
                    for (final k in SmsKind.values)
                      ButtonSegment(value: k, label: Text(k.label)),
                  ],
                  selected: {kind},
                  onSelectionChanged: (s) => setState(() {
                    kind = s.first;
                    selected.removeWhere(
                      (id) => !_eligible(
                        customers.firstWhere(
                          (p) => p.id == id,
                          orElse: () => customers.first,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in _templates[kind]!)
                      ActionChip(
                        label: SizedBox(
                          width: 300,
                          child: Text(
                            t,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        onPressed: () => setState(() => _msg.text = t),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _msg,
                  maxLines: 6,
                  maxLength: SmsSender.maxLength,
                  onChanged: (_) => setState(() {}),
                  decoration: deco(
                    'متن پیامک',
                    hint: 'برای درج نام مشتری از {name} استفاده کنید',
                  ),
                ),
                Text(
                  'تعداد بخش‌ها: ${faDigits(parts)}   •   {name} = نام مشتری (برای هر نفر جداگانه ارسال می‌شود)',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.muted(context),
                  ),
                ),
                if (kind.needsConsent)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'پیام ${kind.label} فقط برای مشتریانی ارسال می‌شود که رضایت دریافت پیامک داده‌اند.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.warning(context),
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                if (sending) ...[
                  LinearProgressIndicator(
                    value: total == 0 ? null : done / total,
                  ),
                  const SizedBox(height: 6),
                  Text('در حال ارسال… ${faDigits(done)} از ${faDigits(total)}'),
                ] else
                  FilledButton.icon(
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                    label: Text('ارسال به ${faDigits(selected.length)} نفر'),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: _recipients(context)),
      ],
    );
  }

  Widget _recipients(BuildContext context) {
    final shown = _shown;
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _q,
                  decoration: deco(
                    'جست‌وجوی مشتری',
                    suffix: const Icon(Icons.search),
                  ),
                  onChanged: (_) => _load(),
                ),
              ),
              const SizedBox(width: 10),
              FilterChip(
                label: const Text('فقط بدهکاران'),
                selected: debtorsOnly,
                onSelected: (v) => setState(() => debtorsOnly = v),
              ),
              const SizedBox(width: 6),
              TextButton(
                onPressed: _selectAll,
                child: const Text('انتخاب همه'),
              ),
              TextButton(
                onPressed: () => setState(selected.clear),
                child: const Text('هیچ‌کدام'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: shown.isEmpty
                ? const EmptyState(
                    icon: Icons.groups_outlined,
                    text: 'مشتری فعالی با شماره موبایل ثبت نشده است.',
                  )
                : ListView.separated(
                    itemCount: shown.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final p = shown[i];
                      final ok = _eligible(p);
                      return InkWell(
                        onTap: ok
                            ? () => setState(
                                () => selected.contains(p.id)
                                    ? selected.remove(p.id)
                                    : selected.add(p.id),
                              )
                            : null,
                        child: Opacity(
                          opacity: ok ? 1 : 0.45,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: selected.contains(p.id),
                                  onChanged: ok
                                      ? (v) => setState(
                                          () => v == true
                                              ? selected.add(p.id)
                                              : selected.remove(p.id),
                                        )
                                      : null,
                                ),
                                Expanded(child: Text(p.name)),
                                SizedBox(
                                  width: 120,
                                  child: Text(
                                    faDigits(p.mobile),
                                    textDirection: TextDirection.ltr,
                                    textAlign: TextAlign.end,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 90,
                                  child: p.smsConsent
                                      ? StatusChip(
                                          'رضایت دارد',
                                          AppColors.positive(context),
                                        )
                                      : StatusChip(
                                          'بدون رضایت',
                                          AppColors.muted(context),
                                        ),
                                ),
                                SizedBox(
                                  width: 110,
                                  child: Text(
                                    p.balance > 0 ? fmtMoney(p.balance) : '',
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                      color: AppColors.negative(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _history(BuildContext context) {
    if (history.isEmpty) {
      return const EmptyState(
        icon: Icons.sms_outlined,
        text: 'هنوز پیامکی ارسال نشده است.',
      );
    }
    return AppCard(
      padding: EdgeInsets.zero,
      child: ListView.separated(
        itemCount: history.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final h = history[i];
          final ok = h.status == 'sent';
          final kindLabel = SmsKind.values
              .firstWhere((k) => k.db == h.kind, orElse: () => SmsKind.info)
              .label;
          return ListTile(
            dense: true,
            title: Text(
              '${h.name.isEmpty ? '' : '${h.name} • '}${faDigits(h.mobile)}',
            ),
            subtitle: Text(
              '${h.message}${h.error != null ? '\nخطا: ${h.error}' : ''}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusChip(
                  ok ? 'ارسال شد' : 'ناموفق',
                  ok
                      ? AppColors.positive(context)
                      : AppColors.negative(context),
                ),
                Text(
                  '$kindLabel • ${fmtJalaliDateTime(h.createdAt)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.muted(context),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// ارسال سریع پیامک به یک مشتری (از صفحه مشتریان)
Future<void> showQuickSms(BuildContext context, Party p) => showDialog<void>(
  context: context,
  builder: (_) => _QuickSms(party: p),
);

class _QuickSms extends StatefulWidget {
  final Party party;
  const _QuickSms({required this.party});

  @override
  State<_QuickSms> createState() => _QuickSmsState();
}

class _QuickSmsState extends State<_QuickSms> {
  late final TextEditingController _msg = TextEditingController(
    text: widget.party.balance > 0
        ? 'سلام {name} عزیز، مانده حساب شما ${fmtToman(widget.party.balance)} است. لطفاً در اولین فرصت اقدام فرمایید.'
        : 'سلام {name} عزیز، ',
  );
  SmsKind kind = SmsKind.info;
  bool busy = false;

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final app = context.app;
    final svc = context.svc;
    setState(() => busy = true);
    try {
      final out = await SmsSender((m, to) => app.auth.sendSms(m, to), svc.sms)
          .send(
            recipients: [
              SmsRecipient(
                partyId: widget.party.id,
                name: widget.party.name,
                mobile: widget.party.mobile!,
                consent: widget.party.smsConsent,
              ),
            ],
            template: _msg.text,
            kind: kind,
          );
      if (!mounted) return;
      if (out.sent > 0) {
        toast(context, 'پیامک ارسال شد.');
        Navigator.pop(context);
      } else {
        toast(
          context,
          out.errors.isNotEmpty ? out.errors.first : 'ارسال ناموفق بود.',
          error: true,
        );
      }
    } on DomainError catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: 'پیامک به ${widget.party.name}',
    width: 460,
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('انصراف'),
      ),
      FilledButton.icon(
        onPressed: busy ? null : _send,
        icon: const Icon(Icons.send),
        label: const Text('ارسال'),
      ),
    ],
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'شماره: ${faDigits(widget.party.mobile)}',
          textDirection: TextDirection.rtl,
        ),
        const SizedBox(height: 10),
        DropdownField<SmsKind>(
          label: 'نوع پیام',
          value: kind,
          items: [
            for (final k in SmsKind.values)
              DropdownMenuItem(value: k, child: Text(k.label)),
          ],
          onChanged: (v) => setState(() => kind = v ?? SmsKind.info),
        ),
        if (kind.needsConsent && !widget.party.smsConsent)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'این مشتری رضایت دریافت پیامک تبلیغاتی/مناسبتی نداده است.',
              style: TextStyle(color: AppColors.warning(context), fontSize: 12),
            ),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _msg,
          maxLines: 5,
          maxLength: SmsSender.maxLength,
          decoration: deco('متن پیامک'),
        ),
      ],
    ),
  );
}
