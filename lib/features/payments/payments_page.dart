import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/utils/jalali.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/jalali_picker.dart';
import '../../core/widgets/search_picker.dart';
import '../../data/models.dart';
import '../customers/party_detail.dart';
import 'payment_dialog.dart';

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  bool balancesView = false;
  DateRange range = DateRange.thisJalaliMonth();
  int? partyId;
  String method = '';
  String direction = '';
  List<Map<String, Object?>> rows = [];
  List<Party> parties = [];
  // مانده‌ها
  String balKind = 'customer';
  List<Party> balances = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _reload(reloadParties: true),
    );
  }

  void _reload({bool reloadParties = false}) {
    if (!mounted) return;
    final s = context.svc;
    if (reloadParties) {
      parties = [...s.parties.list('customer'), ...s.parties.list('supplier')];
    }
    final r = tryValue(
      context,
      () => s.payments.listDetailed(
        from: range.fromIso,
        to: range.toIso,
        partyId: partyId,
        method: method,
        direction: direction,
      ),
    );
    final b = s.parties.list(balKind).where((p) => p.balance != 0).toList()
      ..sort((a, c) => c.balance.abs().compareTo(a.balance.abs()));
    setState(() {
      rows = r ?? [];
      balances = b;
      loading = false;
    });
  }

  Future<void> _newPayment() async {
    final p = await showSearchPicker<Party>(
      context,
      title: 'انتخاب طرف‌حساب',
      items: parties,
      label: (p) => p.name,
      subtitle: (p) =>
          '${p.isCustomer ? 'مشتری' : 'تأمین‌کننده'} • ${p.code}${p.balance != 0 ? ' • مانده ${fmtMoney(p.balance)}' : ''}',
    );
    if (p == null || !mounted) return;
    final ok = await showPaymentDialog(
      context,
      partyId: p.id,
      partyName: p.name,
      incoming: p.isCustomer,
      remaining: p.balance > 0 ? p.balance : null,
    );
    if (ok) _reload(reloadParties: true);
  }

  Future<void> _allocate(Map<String, Object?> r) async {
    final pid = r['party_id'] as int?;
    if (pid == null) return;
    final svc = context.svc;
    final party = svc.parties.get(pid);
    if (party == null) return;
    final open = svc.payments.openInvoicesOf(
      pid,
      party.isCustomer ? 'sale' : 'purchase',
    );
    if (open.isEmpty) {
      return toast(context, 'فاکتور بازی برای اختصاص وجود ندارد.', error: true);
    }
    final amount = r['amount'] as int;
    final picked = await showSearchPicker<Map<String, Object?>>(
      context,
      title: 'اختصاص ${fmtToman(amount)} به فاکتور',
      items: open,
      label: (i) =>
          'فاکتور ${faDigits(i['number'])} — ${fmtJalali('${i['date']}')}',
      subtitle: (i) =>
          'مانده: ${fmtToman((i['total'] as int) - (i['paid'] as int))}',
    );
    if (picked == null || !mounted) return;
    if (tryRun(
      context,
      () => svc.payments.allocate(r['id'] as int, picked['id'] as int),
    )) {
      toast(context, 'به فاکتور اختصاص یافت.');
      _reload();
    }
  }

  Future<void> _delete(Map<String, Object?> r) async {
    if (!await confirmDialog(
      context,
      title: 'حذف پرداخت',
      message:
          '${fmtToman(r['amount'] as int)} مورخ ${fmtJalali('${r['date']}')} حذف شود؟',
      confirmLabel: 'حذف',
      danger: true,
    )) {
      return;
    }
    if (!mounted) return;
    if (tryRun(context, () => context.svc.payments.delete(r['id'] as int))) {
      _reload(reloadParties: true);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'مدیریت پرداخت‌ها',
          subtitle: 'دریافت و پرداخت وجه، مانده و بستانکاری',
          actions: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('پرداخت‌ها')),
                ButtonSegment(value: true, label: Text('مانده حساب‌ها')),
              ],
              selected: {balancesView},
              onSelectionChanged: (s) => setState(() => balancesView = s.first),
            ),
            FilledButton.icon(
              onPressed: _newPayment,
              icon: const Icon(Icons.add),
              label: const Text('ثبت دریافت / پرداخت'),
            ),
          ],
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : (balancesView ? _balances(context) : _payments(context)),
        ),
      ],
    ),
  );

  Widget _payments(BuildContext context) {
    var cin = 0, cout = 0;
    for (final r in rows) {
      if (r['direction'] == 'in') {
        cin += r['amount'] as int;
      } else {
        cout += r['amount'] as int;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DateRangeBar(
          range: range,
          onChanged: (r) {
            range = r;
            _reload();
          },
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            SizedBox(
              width: 240,
              child: DropdownField<int?>(
                label: 'طرف‌حساب',
                value: partyId,
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('همه')),
                  for (final p in parties)
                    DropdownMenuItem<int?>(
                      value: p.id,
                      child: Text(p.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) {
                  partyId = v;
                  _reload();
                },
              ),
            ),
            SizedBox(
              width: 170,
              child: DropdownField<String>(
                label: 'روش',
                value: method,
                items: [
                  const DropdownMenuItem(value: '', child: Text('همه')),
                  for (final e in kMethodLabels.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) {
                  method = v ?? '';
                  _reload();
                },
              ),
            ),
            SizedBox(
              width: 150,
              child: DropdownField<String>(
                label: 'جهت',
                value: direction,
                items: const [
                  DropdownMenuItem(value: '', child: Text('همه')),
                  DropdownMenuItem(value: 'in', child: Text('دریافت')),
                  DropdownMenuItem(value: 'out', child: Text('پرداخت')),
                ],
                onChanged: (v) {
                  direction = v ?? '';
                  _reload();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            SizedBox(
              width: 260,
              child: StatCard(
                title: 'جمع دریافتی',
                value: fmtToman(cin),
                icon: Icons.south_west,
                color: AppColors.positive(context),
              ),
            ),
            SizedBox(
              width: 260,
              child: StatCard(
                title: 'جمع پرداختی',
                value: fmtToman(cout),
                icon: Icons.north_east,
                color: AppColors.warning(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: rows.isEmpty
              ? const EmptyState(
                  icon: Icons.payments_outlined,
                  text: 'پرداختی در این بازه ثبت نشده است.',
                )
              : _paymentTable(context),
        ),
      ],
    );
  }

  Widget _paymentTable(BuildContext context) {
    final head = TextStyle(fontSize: 12, color: AppColors.muted(context));
    Widget c(String t, {double? w, TextStyle? st, bool end = false}) {
      final x = Align(
        alignment: end
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: Text(t, style: st, maxLines: 1, overflow: TextOverflow.ellipsis),
      );
      return w == null ? Expanded(child: x) : SizedBox(width: w, child: x);
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                c('تاریخ', w: 90, st: head),
                c('طرف‌حساب', st: head),
                c('فاکتور', w: 70, st: head),
                c('جهت', w: 70, st: head),
                c('روش', w: 100, st: head),
                c('مبلغ', w: 120, st: head, end: true),
                const SizedBox(width: 12),
                const SizedBox(width: 90),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final r = rows[i];
                final incoming = r['direction'] == 'in';
                final general = r['invoice_id'] == null;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: SizedBox(
                    height: 44,
                    child: Row(
                      children: [
                        c(fmtJalali('${r['date']}'), w: 90),
                        c(
                          '${r['party']}'.isEmpty
                              ? 'متفرقه'
                              : '${r['party']}${(r['description'] as String).isNotEmpty ? '  •  ${r['description']}' : ''}',
                        ),
                        c(
                          general ? 'عمومی' : faDigits(r['inv_number']),
                          w: 70,
                          st: general
                              ? TextStyle(
                                  color: AppColors.warning(context),
                                  fontSize: 12.5,
                                )
                              : null,
                        ),
                        c(
                          incoming ? 'دریافت' : 'پرداخت',
                          w: 70,
                          st: TextStyle(
                            color: incoming
                                ? AppColors.positive(context)
                                : AppColors.warning(context),
                          ),
                        ),
                        c(
                          kMethodLabels['${r['method']}'] ?? '${r['method']}',
                          w: 100,
                        ),
                        c(
                          fmtMoney(r['amount'] as int),
                          w: 120,
                          end: true,
                          st: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 90,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (general && r['party_id'] != null)
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'اختصاص به فاکتور',
                                  icon: const Icon(Icons.link, size: 20),
                                  onPressed: () => _allocate(r),
                                ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'حذف',
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                ),
                                onPressed: () => _delete(r),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  Widget _balances(BuildContext context) {
    final isC = balKind == 'customer';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'customer', label: Text('مشتریان')),
              ButtonSegment(value: 'supplier', label: Text('تأمین‌کنندگان')),
            ],
            selected: {balKind},
            onSelectionChanged: (s) {
              balKind = s.first;
              _reload();
            },
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: balances.isEmpty
              ? const EmptyState(
                  icon: Icons.verified_outlined,
                  text: 'همه حساب‌ها تسویه است.',
                )
              : AppCard(
                  padding: EdgeInsets.zero,
                  child: ListView.separated(
                    itemCount: balances.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final p = balances[i];
                      final b = p.balance;
                      final label = isC
                          ? (b > 0 ? 'بدهکار' : 'بستانکار')
                          : (b > 0 ? 'بدهی ما' : 'مطالبه ما');
                      final color = b > 0
                          ? AppColors.negative(context)
                          : AppColors.positive(context);
                      return ListTile(
                        title: Text(
                          p.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${p.code}${p.mobile != null ? ' • ${faDigits(p.mobile)}' : ''}',
                        ),
                        onTap: () async {
                          if (await showPartyDetail(context, p.id)) {
                            _reload(reloadParties: true);
                          }
                        },
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${fmtToman(b.abs())}  $label',
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (b > 0)
                              FilledButton.tonalIcon(
                                icon: const Icon(Icons.payments_outlined),
                                label: Text(isC ? 'دریافت' : 'پرداخت'),
                                onPressed: () async {
                                  final ok = await showPaymentDialog(
                                    context,
                                    partyId: p.id,
                                    partyName: p.name,
                                    incoming: isC,
                                    remaining: b,
                                  );
                                  if (ok) _reload(reloadParties: true);
                                },
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
