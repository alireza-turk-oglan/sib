import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../club/club_page.dart';
import '../payments/payment_dialog.dart';
import 'party_detail.dart';
import 'party_form.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  String kind = 'customer';
  final _q = TextEditingController();
  List<Party> list = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    final r = tryValue(
      context,
      () => context.svc.parties.list(kind, query: _q.text),
    );
    setState(() {
      list = r ?? [];
      loading = false;
    });
  }

  Future<void> _delete(Party p) async {
    if (!await confirmDialog(
      context,
      title: 'حذف',
      message: '«${p.name}» حذف شود؟ سوابق فاکتور و پرداخت او حفظ می‌شود.',
      confirmLabel: 'حذف',
      danger: true,
    )) {
      return;
    }
    if (!mounted) return;
    if (tryRun(context, () => context.svc.parties.delete(p.id))) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final isCustomer = kind == 'customer';
    final debt = list
        .where((p) => p.balance > 0)
        .fold<int>(0, (a, p) => a + p.balance);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: isCustomer ? 'مشتریان' : 'تأمین‌کنندگان',
            subtitle:
                '${faDigits(list.length)} مورد • ${isCustomer ? 'جمع بدهی مشتریان' : 'جمع بدهی ما'}: ${fmtToman(debt)}',
            actions: [
              FilledButton.icon(
                onPressed: () async {
                  if (await showPartyForm(context, kind: kind) != null) {
                    _reload();
                  }
                },
                icon: const Icon(Icons.person_add_alt),
                label: Text(isCustomer ? 'مشتری جدید' : 'تأمین‌کننده جدید'),
              ),
            ],
          ),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'customer', label: Text('مشتریان')),
                  ButtonSegment(
                    value: 'supplier',
                    label: Text('تأمین‌کنندگان'),
                  ),
                ],
                selected: {kind},
                onSelectionChanged: (s) {
                  kind = s.first;
                  _reload();
                },
              ),
              SizedBox(
                width: 300,
                child: TextField(
                  controller: _q,
                  decoration: deco(
                    'جست‌وجو (نام، موبایل یا کد)',
                    suffix: const Icon(Icons.search),
                  ),
                  onChanged: (_) => _reload(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : _table(context, isCustomer),
          ),
        ],
      ),
    );
  }

  Widget _table(BuildContext context, bool isCustomer) {
    if (list.isEmpty) {
      return EmptyState(
        icon: Icons.people_outline,
        text: isCustomer
            ? 'مشتری‌ای ثبت نشده است.'
            : 'تأمین‌کننده‌ای ثبت نشده است.',
      );
    }
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
                c('کد', w: 70, st: head),
                c('نام', st: head),
                c('موبایل', w: 120, st: head),
                c(
                  isCustomer ? 'مجموع خرید' : 'مجموع خرید ما',
                  w: 120,
                  st: head,
                  end: true,
                ),
                c('مانده', w: 140, st: head, end: true),
                const SizedBox(width: 12),
                const SizedBox(width: 170),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final p = list[idx];
                final b = p.balance;
                final label = isCustomer
                    ? (b > 0 ? 'بدهکار' : (b < 0 ? 'بستانکار' : 'تسویه'))
                    : (b > 0 ? 'بدهی ما' : (b < 0 ? 'مطالبه ما' : 'تسویه'));
                final color = b > 0
                    ? AppColors.negative(context)
                    : (b < 0
                          ? AppColors.positive(context)
                          : AppColors.muted(context));
                return InkWell(
                  onTap: () async {
                    if (await showPartyDetail(context, p.id)) _reload();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: SizedBox(
                      height: 46,
                      child: Row(
                        children: [
                          c(
                            p.code,
                            w: 70,
                            st: TextStyle(color: AppColors.muted(context)),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    p.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (!p.isActive) ...[
                                  const SizedBox(width: 8),
                                  StatusChip(
                                    'غیرفعال',
                                    AppColors.muted(context),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          c(
                            p.mobile == null ? '—' : faDigits(p.mobile),
                            w: 120,
                          ),
                          c(fmtMoney(p.totalAmount), w: 120, end: true),
                          SizedBox(
                            width: 140,
                            child: Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: Text(
                                b == 0
                                    ? 'تسویه'
                                    : '${fmtMoney(b.abs())}  $label',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 170,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: isCustomer
                                      ? 'ثبت دریافت'
                                      : 'ثبت پرداخت',
                                  icon: const Icon(
                                    Icons.payments_outlined,
                                    size: 20,
                                  ),
                                  onPressed: () async {
                                    final ok = await showPaymentDialog(
                                      context,
                                      partyId: p.id,
                                      partyName: p.name,
                                      incoming: isCustomer,
                                      remaining: b > 0 ? b : null,
                                    );
                                    if (ok) _reload();
                                  },
                                ),
                                if (p.mobile != null)
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'ارسال پیامک',
                                    icon: const Icon(
                                      Icons.sms_outlined,
                                      size: 20,
                                    ),
                                    onPressed: () => showQuickSms(context, p),
                                  ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'ویرایش',
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 20,
                                  ),
                                  onPressed: () async {
                                    if (await showPartyForm(
                                          context,
                                          kind: kind,
                                          edit: p,
                                        ) !=
                                        null) {
                                      _reload();
                                    }
                                  },
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'حذف',
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                  ),
                                  onPressed: () => _delete(p),
                                ),
                              ],
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
}
