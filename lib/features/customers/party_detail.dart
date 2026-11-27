import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../invoices/invoice_view.dart';
import '../payments/payment_dialog.dart';
import '../../domain/invoice_calc.dart';

/// جزئیات طرف‌حساب: مانده، فاکتورها، تاریخچه خرید کالا، خدمات دریافت‌شده، پرداخت‌ها. true = داده تغییر کرد.
Future<bool> showPartyDetail(BuildContext context, int partyId) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => _PartyDetail(partyId: partyId),
  );
  return r ?? false;
}

class _PartyDetail extends StatefulWidget {
  final int partyId;
  const _PartyDetail({required this.partyId});

  @override
  State<_PartyDetail> createState() => _PartyDetailState();
}

class _PartyDetailState extends State<_PartyDetail> {
  Party? p;
  List<InvoiceSummary> invoices = [];
  List<PaymentRow> payments = [];
  List<Map<String, Object?>> products = [];
  List<Map<String, Object?>> services = [];
  bool changed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    if (!mounted) return;
    final s = context.svc;
    final party = s.parties.get(widget.partyId);
    if (party == null) {
      Navigator.pop(context, changed);
      return;
    }
    setState(() {
      p = party;
      invoices = s.invoices.list(
        kind: party.isCustomer ? 'sale' : 'purchase',
        partyId: party.id,
        limit: 300,
      );
      payments = s.payments.of(partyId: party.id);
      if (party.isCustomer) {
        products = s.parties.linesOf(party.id, products: true);
        services = s.parties.linesOf(party.id, products: false);
      }
    });
  }

  Future<void> _pay() async {
    final party = p!;
    final ok = await showPaymentDialog(
      context,
      partyId: party.id,
      partyName: party.name,
      incoming: party.isCustomer,
      remaining: party.balance > 0 ? party.balance : null,
    );
    if (ok) {
      changed = true;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final party = p;
    if (party == null) {
      return const AppDialog(
        title: 'جزئیات',
        child: SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final b = party.balance;
    final debtLabel = party.isCustomer
        ? (b > 0 ? 'بدهکار' : (b < 0 ? 'بستانکار' : 'تسویه'))
        : (b > 0 ? 'بدهی ما' : (b < 0 ? 'مطالبه ما' : 'تسویه'));
    final tabs = <Tab>[
      const Tab(text: 'فاکتورها'),
      if (party.isCustomer) const Tab(text: 'تاریخچه خرید'),
      if (party.isCustomer) const Tab(text: 'خدمات دریافت‌شده'),
      const Tab(text: 'پرداخت‌ها'),
    ];
    return AppDialog(
      title: '${party.name}  (${party.code})',
      width: 820,
      actions: [
        OutlinedButton.icon(
          onPressed: _pay,
          icon: const Icon(Icons.payments_outlined),
          label: Text(party.isCustomer ? 'ثبت دریافت' : 'ثبت پرداخت'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, changed),
          child: const Text('بستن'),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (party.mobile != null)
            Text(
              'موبایل: ${faDigits(party.mobile)}',
              style: TextStyle(color: AppColors.muted(context)),
            ),
          if ((party.description ?? '').isNotEmpty)
            Text(
              party.description!,
              style: TextStyle(color: AppColors.muted(context)),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 230,
                child: StatCard(
                  title: party.isCustomer ? 'مجموع خرید' : 'مجموع خریدها از او',
                  value: fmtToman(party.totalAmount),
                  icon: Icons.shopping_bag_outlined,
                ),
              ),
              SizedBox(
                width: 230,
                child: StatCard(
                  title: party.isCustomer ? 'مجموع دریافتی' : 'مجموع پرداختی',
                  value: fmtToman(party.paidAmount),
                  icon: Icons.payments_outlined,
                  color: AppColors.positive(context),
                ),
              ),
              SizedBox(
                width: 250,
                child: StatCard(
                  title: 'مانده ($debtLabel)',
                  value: fmtToman(b.abs()),
                  icon: Icons.account_balance_wallet_outlined,
                  color: b > 0
                      ? AppColors.negative(context)
                      : (b < 0 ? AppColors.positive(context) : null),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 360,
            child: DefaultTabController(
              length: tabs.length,
              child: Column(
                children: [
                  TabBar(tabs: tabs),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _invoiceList(context),
                        if (party.isCustomer) _lineList(context, products),
                        if (party.isCustomer) _lineList(context, services),
                        _paymentList(context),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _invoiceList(BuildContext context) {
    if (invoices.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        text: 'فاکتوری ثبت نشده است.',
      );
    }
    return ListView.separated(
      itemCount: invoices.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final v = invoices[i];
        return ListTile(
          dense: true,
          title: Text('فاکتور ${faDigits(v.number)} — ${fmtJalali(v.date)}'),
          subtitle: Text('پرداخت‌شده: ${fmtToman(v.paid)}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                fmtToman(v.total),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 10),
              StatusChip(
                payStatusLabel(v.status),
                statusColor(context, v.status),
              ),
            ],
          ),
          onTap: () async {
            if (await showInvoiceView(context, v.id)) {
              changed = true;
              _load();
            }
          },
        );
      },
    );
  }

  Widget _lineList(BuildContext context, List<Map<String, Object?>> rows) {
    if (rows.isEmpty) {
      return const EmptyState(
        icon: Icons.inventory_2_outlined,
        text: 'موردی ثبت نشده است.',
      );
    }
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final r = rows[i];
        return ListTile(
          dense: true,
          title: Text('${r['title']}'),
          subtitle: Text(
            '${fmtJalali('${r['date']}')} • فاکتور ${faDigits(r['number'])} • ${fmtQty((r['qty_milli'] as int) / 1000)} × ${fmtMoney(r['unit_price'] as int)}',
          ),
          trailing: Text(
            fmtToman(r['line_total'] as int),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      },
    );
  }

  Widget _paymentList(BuildContext context) {
    if (payments.isEmpty) {
      return const EmptyState(
        icon: Icons.payments_outlined,
        text: 'پرداختی ثبت نشده است.',
      );
    }
    return ListView.separated(
      itemCount: payments.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final y = payments[i];
        return ListTile(
          dense: true,
          title: Text(
            '${fmtToman(y.amount)} — ${kMethodLabels[y.method] ?? y.method}',
          ),
          subtitle: Text(
            '${fmtJalali(y.date)}${y.invNumber != null ? ' • فاکتور ${faDigits(y.invNumber)}' : ' • پرداخت عمومی'}',
          ),
        );
      },
    );
  }
}
