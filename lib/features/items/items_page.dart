import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import 'item_dialogs.dart';

class ItemsPage extends StatefulWidget {
  const ItemsPage({super.key});

  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage> {
  String kind = 'product';
  int? categoryId;
  bool includeInactive = false;
  final _q = TextEditingController();
  List<Item> list = [];
  List<Category> cats = [];
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
    final s = context.svc;
    cats = s.items.categories(kind);
    if (categoryId != null && !cats.any((c) => c.id == categoryId)) {
      categoryId = null;
    }
    final r = tryValue(
      context,
      () => s.items.list(
        kind: kind,
        categoryId: categoryId,
        includeInactive: includeInactive,
        query: _q.text,
      ),
    );
    setState(() {
      list = r ?? [];
      loading = false;
    });
  }

  Future<void> _delete(Item i) async {
    if (!await confirmDialog(
      context,
      title: 'حذف',
      message: '«${i.name}» حذف شود؟ فاکتورهای قبلی تغییری نمی‌کنند.',
      confirmLabel: 'حذف',
      danger: true,
    )) {
      return;
    }
    if (!mounted) return;
    if (tryRun(context, () => context.svc.items.delete(i.id))) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final isProduct = kind == 'product';
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'کالا و خدمات',
            subtitle: 'قیمت‌ها، موجودی و دسته‌بندی',
            actions: [
              OutlinedButton.icon(
                onPressed: () async {
                  await showCategoriesDialog(context, kind);
                  _reload();
                },
                icon: const Icon(Icons.category_outlined),
                label: const Text('دسته‌بندی‌ها'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  if (await showItemForm(context, kind: kind)) _reload();
                },
                icon: const Icon(Icons.add),
                label: Text(isProduct ? 'کالای جدید' : 'خدمت جدید'),
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
                  ButtonSegment(value: 'product', label: Text('کالاها')),
                  ButtonSegment(value: 'service', label: Text('خدمات')),
                ],
                selected: {kind},
                onSelectionChanged: (s) {
                  kind = s.first;
                  categoryId = null;
                  _reload();
                },
              ),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _q,
                  decoration: deco(
                    'جست‌وجو (نام یا کد)',
                    suffix: const Icon(Icons.search),
                  ),
                  onChanged: (_) => _reload(),
                ),
              ),
              SizedBox(
                width: 200,
                child: DropdownField<int?>(
                  label: 'دسته‌بندی',
                  value: categoryId,
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('همه'),
                    ),
                    for (final c in cats)
                      DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (v) {
                    categoryId = v;
                    _reload();
                  },
                ),
              ),
              FilterChip(
                label: const Text('نمایش غیرفعال‌ها'),
                selected: includeInactive,
                onSelected: (v) {
                  includeInactive = v;
                  _reload();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : _table(context, isProduct),
          ),
        ],
      ),
    );
  }

  Widget _table(BuildContext context, bool isProduct) {
    if (list.isEmpty) {
      return EmptyState(
        icon: Icons.inventory_2_outlined,
        text: isProduct ? 'کالایی ثبت نشده است.' : 'خدمتی ثبت نشده است.',
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
                c('دسته', w: 120, st: head),
                c('قیمت فروش', w: 115, st: head, end: true),
                c('قیمت خرید', w: 115, st: head, end: true),
                if (isProduct) c('موجودی', w: 90, st: head, end: true),
                const SizedBox(width: 12),
                const SizedBox(width: 150),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final i = list[idx];
                final low = i.lowStock;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: SizedBox(
                    height: 46,
                    child: Row(
                      children: [
                        c(
                          i.code,
                          w: 70,
                          st: TextStyle(color: AppColors.muted(context)),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  i.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (!i.isActive) ...[
                                const SizedBox(width: 8),
                                StatusChip('غیرفعال', AppColors.muted(context)),
                              ],
                            ],
                          ),
                        ),
                        c(i.categoryName ?? '—', w: 120),
                        c(fmtMoney(i.salePrice), w: 115, end: true),
                        c(
                          i.purchasePrice == 0
                              ? '—'
                              : fmtMoney(i.purchasePrice),
                          w: 115,
                          end: true,
                        ),
                        if (isProduct)
                          c(
                            i.trackStock ? fmtQty(i.stock) : '—',
                            w: 90,
                            end: true,
                            st: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: low ? AppColors.negative(context) : null,
                            ),
                          ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 150,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (isProduct && i.trackStock)
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'تعدیل موجودی',
                                  icon: const Icon(Icons.tune, size: 20),
                                  onPressed: () async {
                                    if (await showStockAdjust(context, i)) {
                                      _reload();
                                    }
                                  },
                                ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'تاریخچه',
                                icon: const Icon(Icons.history, size: 20),
                                onPressed: () => showItemHistory(context, i),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'ویرایش',
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                onPressed: () async {
                                  if (await showItemForm(
                                    context,
                                    kind: kind,
                                    edit: i,
                                  )) {
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
                                onPressed: () => _delete(i),
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
}
