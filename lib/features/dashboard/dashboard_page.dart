import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/utils/jalali.dart';
import '../../core/widgets/bar_chart.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../data/repos/reports_repo.dart';
import '../customers/party_form.dart';
import '../invoices/invoice_editor_page.dart';

class DashboardPage extends StatefulWidget {
  /// جابه‌جایی به یک بخش (ایندکس منوی اصلی)
  final void Function(int index) onNavigate;
  const DashboardPage({super.key, required this.onNavigate});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DashboardData? d;
  List<Item> low = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    if (!mounted) return;
    final s = context.svc;
    final data = tryValue(context, () => s.reports.dashboard());
    final lowItems = s.items
        .list(kind: 'product', includeInactive: false)
        .where((i) => i.lowStock)
        .take(6)
        .toList();
    setState(() {
      d = data;
      low = lowItems;
    });
  }

  @override
  Widget build(BuildContext context) {
    final x = d;
    final pos = AppColors.positive(context);
    final neg = AppColors.negative(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          PageHeader(
            title: 'داشبورد',
            subtitle: fmtJalaliLong(isoDate(DateTime.now())),
            actions: [
              OutlinedButton.icon(
                onPressed: () async {
                  if (await openInvoiceEditor(context, kind: 'purchase')) {
                    _load();
                  }
                },
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('فاکتور خرید / هزینه'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  if (await showPartyForm(context, kind: 'customer') != null) {
                    _load();
                  }
                },
                icon: const Icon(Icons.person_add_alt),
                label: const Text('مشتری جدید'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  if (await openInvoiceEditor(context, kind: 'sale')) _load();
                },
                icon: const Icon(Icons.add),
                label: const Text('فاکتور فروش جدید'),
              ),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                tooltip: 'بازخوانی',
              ),
            ],
          ),
          if (x == null)
            const Padding(
              padding: EdgeInsets.all(60),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _w(
                  StatCard(
                    title: 'فروش امروز',
                    value: fmtToman(x.todaySales),
                    icon: Icons.point_of_sale,
                  ),
                ),
                _w(
                  StatCard(
                    title: 'دریافتی امروز',
                    value: fmtToman(x.todayReceived),
                    icon: Icons.south_west,
                    color: pos,
                  ),
                ),
                _w(
                  StatCard(
                    title: 'دریافتی ماه جاری',
                    value: fmtToman(x.monthReceived),
                    icon: Icons.account_balance_wallet_outlined,
                    color: pos,
                    subtitle: 'فروش ماه: ${fmtToman(x.monthSales)}',
                  ),
                ),
                _w(
                  StatCard(
                    title: 'تعداد فاکتورهای فروش',
                    value: faDigits(x.saleInvoicesTotal),
                    icon: Icons.receipt_long_outlined,
                    subtitle: 'این ماه: ${faDigits(x.saleInvoicesMonth)}',
                    onTap: () => widget.onNavigate(3),
                  ),
                ),
                _w(
                  StatCard(
                    title: 'تعداد مشتریان',
                    value: faDigits(x.customers),
                    icon: Icons.people_outline,
                    onTap: () => widget.onNavigate(1),
                  ),
                ),
                _w(
                  StatCard(
                    title: 'هزینه‌های ماه جاری',
                    value: fmtToman(x.monthExpenses),
                    icon: Icons.trending_down,
                    color: AppColors.warning(context),
                  ),
                ),
                _w(
                  StatCard(
                    title: 'سود تقریبی ماه جاری',
                    value: fmtToman(x.monthProfit),
                    icon: x.monthProfit >= 0
                        ? Icons.trending_up
                        : Icons.trending_down,
                    color: x.monthProfit >= 0 ? pos : neg,
                    subtitle: 'فروش − بهای تمام‌شده − هزینه‌ها',
                  ),
                ),
                _w(
                  StatCard(
                    title: 'فاکتورهای پرداخت‌نشده',
                    value: faDigits(x.unsettledCount),
                    icon: Icons.pending_actions_outlined,
                    color: neg,
                    subtitle: 'مانده: ${fmtToman(x.unsettledRemaining)}',
                    onTap: () => widget.onNavigate(3),
                  ),
                ),
                _w(
                  StatCard(
                    title: 'بدهی مشتریان',
                    value: fmtToman(x.customersDebt),
                    icon: Icons.account_balance_outlined,
                    color: neg,
                    onTap: () => widget.onNavigate(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    x.chart.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  BarChartView(data: x.chart, height: 240),
                ],
              ),
            ),
            if (low.isNotEmpty) ...[
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.warning(context),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'کالاهای کم‌موجودی',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    for (final i in low)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(i.name),
                        trailing: Text(
                          'موجودی ${fmtQty(i.stock)}',
                          style: TextStyle(
                            color: neg,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _w(Widget c) => SizedBox(width: 290, child: c);
}
