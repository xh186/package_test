import 'package:flutter/material.dart';

import '../data/ledger_controller.dart';
import '../models/sub_book.dart';
import '../models/transaction.dart';
import '../theme/ledger_theme.dart';
import '../widgets/transaction_editor.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final LedgerController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  String _query = '';
  String? _type;
  String? _category;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    widget.controller.initialize();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => mounted ? setState(() {}) : null;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: LedgerTheme.paper,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        title: const _Brand(),
        actions: [
          IconButton(
            tooltip: '同步云端',
            onPressed: controller.isSyncing ? null : controller.sync,
            icon: controller.isSyncing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: controller.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (controller.syncMessage != null) _SyncBanner(message: controller.syncMessage!),
                Expanded(child: _buildView(controller)),
              ],
            ),
      floatingActionButton: _tab == 2
          ? FloatingActionButton.extended(
              onPressed: _createSubBook,
              icon: const Icon(Icons.add),
              label: const Text('新建子账本'),
            )
          : FloatingActionButton(
              tooltip: '新增账目',
              onPressed: () => _editTransaction(),
              child: const Icon(Icons.add),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: '总账本'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: '账目'),
          NavigationDestination(icon: Icon(Icons.folder_copy_outlined), selectedIcon: Icon(Icons.folder_copy), label: '子账本'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: '统计'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: '日历'),
        ],
      ),
    );
  }

  Widget _buildView(LedgerController controller) {
    return switch (_tab) {
      0 => _Overview(controller: controller, onEdit: (item) => _editTransaction(item)),
      1 => _Records(
          transactions: _filteredTransactions(controller.transactions),
          query: _query,
          type: _type,
          category: _category,
          onQuery: (value) => setState(() => _query = value),
          onType: (value) => setState(() => _type = value),
          onCategory: (value) => setState(() => _category = value),
          onEdit: (item) => _editTransaction(item),
          onDelete: _deleteTransaction,
        ),
      2 => _SubBooks(books: controller.subBooks, onOpen: _openSubBook),
      3 => _Statistics(transactions: controller.transactions),
      _ => _Calendar(transactions: controller.transactions, month: _month, onMonth: (value) => setState(() => _month = value), onOpen: _openDay),
    };
  }

  List<LedgerTransaction> _filteredTransactions(List<LedgerTransaction> source) {
    return source.where((item) {
      final query = _query.toLowerCase();
      final matchesQuery = query.isEmpty || '${item.note} ${item.category} ${item.type}'.toLowerCase().contains(query);
      return matchesQuery && (_type == null || item.type == _type) && (_category == null || item.category == _category);
    }).toList();
  }

  Future<void> _editTransaction([LedgerTransaction? item, int? subBookId]) async {
    final result = await showModalBottomSheet<TransactionDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionEditor(transaction: item),
    );
    if (result == null) return;
    if (item == null) {
      await widget.controller.addTransaction(
        type: result.type,
        amount: result.amount,
        category: result.category,
        note: result.note,
        date: result.date,
        subBookId: subBookId,
      );
    } else {
      await widget.controller.updateTransaction(LedgerTransaction(
        id: item.id,
        type: result.type,
        amount: result.amount,
        category: result.category,
        note: result.note,
        transactionDate: result.date,
        createdAt: item.createdAt,
        subBookId: item.subBookId,
      ));
    }
  }

  Future<void> _deleteTransaction(LedgerTransaction item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除账目？'),
        content: const Text('删除后将同步到云端。'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除'))],
      ),
    );
    if (confirmed == true) await widget.controller.deleteTransaction(item);
  }

  Future<void> _createSubBook() async {
    final name = TextEditingController();
    DateTime date = DateTime.now();
    final result = await showDialog<(String, DateTime)>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, update) => AlertDialog(
            title: const Text('新建子账本'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: '名称')),
              const SizedBox(height: 12),
              ListTile(contentPadding: EdgeInsets.zero, title: const Text('活动日期'), subtitle: Text(_date(date)), trailing: const Icon(Icons.calendar_today_outlined), onTap: () async {
                final selected = await showDatePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDate: date);
                if (selected != null) update(() => date = selected);
              }),
            ]),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(context, (name.text.trim(), date)), child: const Text('创建'))],
          )),
    );
    if (result != null && result.$1.isNotEmpty) await widget.controller.createSubBook(result.$1, result.$2);
  }

  void _openSubBook(LedgerSubBook book) {
    final transactions = widget.controller.transactions.where((item) => item.subBookId == book.id).toList();
    final detail = LedgerSubBook(id: book.id, name: book.name, eventDate: book.eventDate, transactions: transactions);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _SubBookDetail(book: detail, controller: widget.controller, edit: _editTransaction, remove: _deleteTransaction)));
  }
  void _openDay(DateTime day) => showModalBottomSheet<void>(context: context, builder: (_) => _DaySheet(day: day, transactions: widget.controller.transactions.where((item) => _sameDay(item.transactionDate, day)).toList(), onEdit: (item) => _editTransaction(item), onDelete: _deleteTransaction));
}

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) => const Row(mainAxisSize: MainAxisSize.min, children: [
        _LedgerMark(),
        SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text('ledger', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)), Text('PERSONAL FINANCE', style: TextStyle(fontSize: 9, letterSpacing: 1.2, color: LedgerTheme.muted))]),
      ]);
}

class _LedgerMark extends StatelessWidget {
  const _LedgerMark();
  @override
  Widget build(BuildContext context) => Transform.rotate(angle: -.07, child: Container(width: 34, height: 34, decoration: BoxDecoration(border: Border.all(color: LedgerTheme.ink), borderRadius: const BorderRadius.only(topLeft: Radius.circular(9), topRight: Radius.circular(4), bottomLeft: Radius.circular(4), bottomRight: Radius.circular(9))), child: const Icon(Icons.subject_outlined, size: 21)));
}

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), color: LedgerTheme.paperDeep, child: Text(message, style: const TextStyle(fontSize: 12, color: LedgerTheme.muted)));
}

class _Overview extends StatelessWidget {
  const _Overview({required this.controller, required this.onEdit});
  final LedgerController controller;
  final Future<void> Function(LedgerTransaction? item) onEdit;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 110), children: [
        const _Heading(kicker: 'OVERVIEW / MAIN LEDGER', title: '总账本'),
        const SizedBox(height: 20),
        _SummaryCards(income: controller.income, expense: controller.expense, balance: controller.balance),
        const SizedBox(height: 32),
        const _PanelKicker(text: 'RECENT ACTIVITY'),
        const SizedBox(height: 6),
        const Text('最近账目', style: TextStyle(fontFamily: 'serif', fontSize: 24, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        if (controller.transactions.isEmpty) const _EmptyState(text: '还没有账目\n点按右下角开始记录') else ...controller.transactions.take(5).map((item) => _TransactionTile(item: item, onTap: () => onEdit(item))),
      ]);
}

class _Records extends StatelessWidget {
  const _Records({required this.transactions, required this.query, required this.type, required this.category, required this.onQuery, required this.onType, required this.onCategory, required this.onEdit, required this.onDelete});
  final List<LedgerTransaction> transactions;
  final String query;
  final String? type;
  final String? category;
  final ValueChanged<String> onQuery;
  final ValueChanged<String?> onType;
  final ValueChanged<String?> onCategory;
  final Future<void> Function(LedgerTransaction) onEdit;
  final void Function(LedgerTransaction) onDelete;
  @override
  Widget build(BuildContext context) {
    final categories = transactions.map((item) => item.category).toSet().toList()..sort();
    return ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 110), children: [
      const _Heading(kicker: 'LEDGER / ALL RECORDS', title: '全部账目'),
      const SizedBox(height: 18),
      TextField(onChanged: onQuery, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: '搜索备注或标签')),
      const SizedBox(height: 12),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
        _FilterChip(label: '全部', selected: type == null, onTap: () => onType(null)),
        _FilterChip(label: '收入', selected: type == 'income', onTap: () => onType('income')),
        _FilterChip(label: '支出', selected: type == 'expense', onTap: () => onType('expense')),
        ...categories.map((item) => _FilterChip(label: item, selected: category == item, onTap: () => onCategory(category == item ? null : item))),
      ])),
      const SizedBox(height: 18),
      Text('共 ${transactions.length} 条记录', style: const TextStyle(color: LedgerTheme.muted, fontSize: 12, letterSpacing: 1)),
      const SizedBox(height: 8),
      if (transactions.isEmpty) const _EmptyState(text: '没有匹配的账目') else ...transactions.map((item) => Dismissible(key: ValueKey(item.id), direction: DismissDirection.endToStart, confirmDismiss: (_) async { onDelete(item); return false; }, background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 24), color: LedgerTheme.coral, child: const Icon(Icons.delete_outline)), child: _TransactionTile(item: item, onTap: () => onEdit(item)))),
    ]);
  }
}

class _SubBooks extends StatelessWidget {
  const _SubBooks({required this.books, required this.onOpen});
  final List<LedgerSubBook> books;
  final ValueChanged<LedgerSubBook> onOpen;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 110), children: [
        const _Heading(kicker: 'ACTIVITY / COLLECTIONS', title: '子账本'),
        const SizedBox(height: 18),
        if (books.isEmpty) const _EmptyState(text: '还没有子账本\n可按旅行、装修等活动建立独立账本') else ...books.map((book) => Card(child: InkWell(onTap: () => onOpen(book), borderRadius: BorderRadius.circular(8), child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Icon(Icons.folder_copy_outlined, color: LedgerTheme.cobalt), Text(_date(book.eventDate), style: const TextStyle(color: LedgerTheme.muted, fontSize: 12))]), const SizedBox(height: 12), Text(book.name, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 12), Text('${book.transactionCount} 条账目', style: const TextStyle(color: LedgerTheme.muted)), const SizedBox(height: 12), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_MiniStat('收入', book.income, LedgerTheme.mint), _MiniStat('支出', book.expense, LedgerTheme.coral), _MiniStat('结余', book.balance, LedgerTheme.yellow)]), const SizedBox(height: 12), const Align(alignment: Alignment.centerRight, child: Text('查看明细  →', style: TextStyle(color: LedgerTheme.cobalt, fontWeight: FontWeight.w700)))]))))),
      ]);
}

class _Statistics extends StatelessWidget {
  const _Statistics({required this.transactions});
  final List<LedgerTransaction> transactions;
  @override
  Widget build(BuildContext context) {
    final grouped = <String, double>{};
    for (final item in transactions) {
      final key = '${item.transactionDate.year}-${item.transactionDate.month.toString().padLeft(2, '0')}';
      grouped[key] = (grouped[key] ?? 0) + (item.isIncome ? item.amount : -item.amount);
    }
    final values = grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final max = values.fold<double>(1, (current, item) => item.value.abs() > current ? item.value.abs() : current);
    return ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 110), children: [const _Heading(kicker: 'ANALYSIS / MAIN LEDGER', title: '统计'), const SizedBox(height: 22), Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const _PanelKicker(text: 'MONTHLY BALANCE'), const SizedBox(height: 18), SizedBox(height: 220, child: values.isEmpty ? const _EmptyState(text: '这个范围还没有数据') : Row(crossAxisAlignment: CrossAxisAlignment.end, children: values.map((entry) { final height = (entry.value.abs() / max * 150).clamp(8, 150).toDouble(); final positive = entry.value >= 0; return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [Text(entry.value.toStringAsFixed(0), style: const TextStyle(fontSize: 10, color: LedgerTheme.muted)), const SizedBox(height: 4), Container(height: height, decoration: BoxDecoration(color: positive ? LedgerTheme.cobalt : LedgerTheme.coral, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))), const SizedBox(height: 6), Text(entry.key.substring(5), style: const TextStyle(fontSize: 10, color: LedgerTheme.muted))]))); }).toList()))])))]);
  }
}

class _Calendar extends StatelessWidget {
  const _Calendar({required this.transactions, required this.month, required this.onMonth, required this.onOpen});
  final List<LedgerTransaction> transactions;
  final DateTime month;
  final ValueChanged<DateTime> onMonth;
  final ValueChanged<DateTime> onOpen;
  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final offset = (first.weekday - 1);
    final totals = <String, List<double>>{};
    for (final item in transactions) { final key = _date(item.transactionDate); final row = totals.putIfAbsent(key, () => [0, 0]); row[item.isIncome ? 0 : 1] += item.amount; }
    return ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 110), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const _Heading(kicker: 'CALENDAR / DAILY FLOW', title: '日历'), Row(children: [IconButton(tooltip: '上个月', onPressed: () => onMonth(DateTime(month.year, month.month - 1)), icon: const Icon(Icons.chevron_left)), Text('${month.year}年${month.month}月'), IconButton(tooltip: '下个月', onPressed: () => onMonth(DateTime(month.year, month.month + 1)), icon: const Icon(Icons.chevron_right))])]),
      const SizedBox(height: 18),
      Card(child: Padding(padding: const EdgeInsets.all(10), child: GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: offset + days, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: .8), itemBuilder: (_, index) { if (index < offset) return const SizedBox.shrink(); final day = index - offset + 1; final date = DateTime(month.year, month.month, day); final row = totals[_date(date)] ?? [0, 0]; return InkWell(onTap: () => onOpen(date), child: Padding(padding: const EdgeInsets.all(4), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$day', style: const TextStyle(fontWeight: FontWeight.w700)), if (row[0] > 0) Text('+${row[0].toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, color: Color(0xFF277849))), if (row[1] > 0) Text('-${row[1].toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, color: Color(0xFFBD543F)))]))); })))]);
  }
}

class _SubBookDetail extends StatelessWidget {
  const _SubBookDetail({required this.book, required this.controller, required this.edit, required this.remove});
  final LedgerSubBook book;
  final LedgerController controller;
  final Future<void> Function([LedgerTransaction? item, int? subBookId]) edit;
  final Future<void> Function(LedgerTransaction) remove;
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(book.name)), body: ListView(padding: const EdgeInsets.all(20), children: [_SummaryCards(income: book.income, expense: book.expense, balance: book.balance), if (book.id <= 0) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('子账本正在等待同步，完成后即可新增账目。', style: TextStyle(color: LedgerTheme.muted))), const SizedBox(height: 16), ...book.transactions.map((item) => _TransactionTile(item: item, onTap: () => edit(item), onDelete: () => remove(item))) ]), floatingActionButton: FloatingActionButton(onPressed: book.id > 0 ? () => edit(null, book.id) : null, tooltip: '新增账目', child: const Icon(Icons.add)));
}

class _DaySheet extends StatelessWidget {
  const _DaySheet({required this.day, required this.transactions, required this.onEdit, required this.onDelete});
  final DateTime day;
  final List<LedgerTransaction> transactions;
  final Future<void> Function(LedgerTransaction) onEdit;
  final void Function(LedgerTransaction) onDelete;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${day.year}年${day.month}月${day.day}日', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (transactions.isEmpty)
              const Text('当天没有账目', style: TextStyle(color: LedgerTheme.muted))
            else
              ...transactions.map((item) => _TransactionTile(
                    item: item,
                    onTap: () => onEdit(item),
                    onDelete: () => onDelete(item),
                  )),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.income, required this.expense, required this.balance});
  final double income;
  final double expense;
  final double balance;
  @override
  Widget build(BuildContext context) => Row(children: [_SummaryCard(label: '总收入', value: income, color: LedgerTheme.mint), const SizedBox(width: 8), _SummaryCard(label: '总支出', value: expense, color: LedgerTheme.coral), const SizedBox(width: 8), _SummaryCard(label: '当前结余', value: balance, color: LedgerTheme.yellow)]);
}

class _SummaryCard extends StatelessWidget { const _SummaryCard({required this.label, required this.value, required this.color}); final String label; final double value; final Color color; @override Widget build(BuildContext context) => Expanded(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12)), const SizedBox(height: 8), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('¥${value.toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'monospace', fontSize: 17, fontWeight: FontWeight.w700)))]))); }
class _MiniStat extends StatelessWidget { const _MiniStat(this.label, this.value, this.color); final String label; final double value; final Color color; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), color: color, child: Text('$label  ¥${value.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11))); }
class _Heading extends StatelessWidget { const _Heading({required this.kicker, required this.title}); final String kicker; final String title; @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(kicker, style: const TextStyle(fontSize: 10, color: LedgerTheme.muted, letterSpacing: 1.3)), const SizedBox(height: 4), Text(title, style: Theme.of(context).textTheme.headlineMedium)]); }
class _PanelKicker extends StatelessWidget { const _PanelKicker({required this.text}); final String text; @override Widget build(BuildContext context) => Row(children: [Container(width: 18, height: 3, color: LedgerTheme.cobalt), const SizedBox(width: 7), Text(text, style: const TextStyle(fontSize: 10, color: LedgerTheme.muted, letterSpacing: 1.2))]); }
class _FilterChip extends StatelessWidget { const _FilterChip({required this.label, required this.selected, required this.onTap}); final String label; final bool selected; final VoidCallback onTap; @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap(), selectedColor: LedgerTheme.cobalt.withValues(alpha: .15), side: const BorderSide(color: LedgerTheme.line))); }
class _EmptyState extends StatelessWidget { const _EmptyState({required this.text}); final String text; @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 48), child: Center(child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: LedgerTheme.muted, height: 1.6)))); }
class _TransactionTile extends StatelessWidget { const _TransactionTile({required this.item, required this.onTap, this.onDelete}); final LedgerTransaction item; final VoidCallback onTap; final VoidCallback? onDelete; @override Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(onTap: onTap, leading: CircleAvatar(backgroundColor: item.isIncome ? LedgerTheme.mint : LedgerTheme.coral, child: Icon(item.isIncome ? Icons.south_west : Icons.north_east, color: LedgerTheme.ink, size: 17)), title: Text(item.category), subtitle: Text('${_date(item.transactionDate)}${item.note.isEmpty ? '' : ' · ${item.note}'}', maxLines: 1, overflow: TextOverflow.ellipsis), trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text('${item.isIncome ? '+' : '-'}¥${item.amount.toStringAsFixed(2)}', style: TextStyle(color: item.isIncome ? const Color(0xFF277849) : const Color(0xFFBD543F), fontFamily: 'monospace', fontWeight: FontWeight.w700)), if (onDelete != null) IconButton(tooltip: '删除', onPressed: onDelete, icon: const Icon(Icons.delete_outline, size: 19))]))); }
bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
String _date(DateTime value) => '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
