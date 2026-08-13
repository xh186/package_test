import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../theme/ledger_theme.dart';

class TransactionDraft {
  const TransactionDraft({required this.type, required this.amount, required this.category, required this.note, required this.date});
  final String type;
  final double amount;
  final String category;
  final String note;
  final DateTime date;
}

class TransactionEditor extends StatefulWidget {
  const TransactionEditor({super.key, this.transaction});
  final LedgerTransaction? transaction;
  @override
  State<TransactionEditor> createState() => _TransactionEditorState();
}

class _TransactionEditorState extends State<TransactionEditor> {
  late String _type;
  late String _category;
  late DateTime _date;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  final _formKey = GlobalKey<FormState>();
  static const _expenseCategories = ['餐饮', '交通', '购物', '娱乐', '学习', '订阅', '社交', '其他'];
  static const _incomeCategories = ['工资', '理财', '红包', '其他'];

  @override
  void initState() { super.initState(); final item = widget.transaction; _type = item?.type ?? 'expense'; _category = item?.category ?? _expenseCategories.first; _date = item?.transactionDate ?? DateTime.now(); _amount = TextEditingController(text: item == null ? '' : item.amount.toStringAsFixed(2)); _note = TextEditingController(text: item?.note ?? ''); }
  @override
  void dispose() { _amount.dispose(); _note.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom), child: Material(color: LedgerTheme.paper, borderRadius: const BorderRadius.vertical(top: Radius.circular(18)), child: SafeArea(top: false, child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 20), child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: LedgerTheme.line, borderRadius: BorderRadius.circular(2)))), const SizedBox(height: 18), Text(widget.transaction == null ? '新增账目' : '编辑账目', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 18), SegmentedButton<String>(segments: const [ButtonSegment(value: 'expense', label: Text('支出')), ButtonSegment(value: 'income', label: Text('收入'))], selected: {_type}, onSelectionChanged: (value) => setState(() { _type = value.first; _category = (_type == 'income' ? _incomeCategories : _expenseCategories).first; })), const SizedBox(height: 16), TextFormField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '金额', prefixText: '¥ '), validator: (value) { final amount = double.tryParse(value ?? ''); return amount == null || amount <= 0 ? '请输入大于 0 的金额' : null; }), const SizedBox(height: 14), DropdownButtonFormField<String>(value: (_type == 'income' ? _incomeCategories : _expenseCategories).contains(_category) ? _category : null, decoration: const InputDecoration(labelText: '标签'), items: (_type == 'income' ? _incomeCategories : _expenseCategories).map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(), onChanged: (value) => setState(() => _category = value ?? _category)), const SizedBox(height: 14), TextFormField(controller: _note, maxLength: 120, decoration: const InputDecoration(labelText: '备注（选填）')), const SizedBox(height: 4), ListTile(contentPadding: EdgeInsets.zero, title: const Text('账目日期'), subtitle: Text(_date.toString().substring(0, 10)), trailing: const Icon(Icons.calendar_today_outlined), onTap: () async { final selected = await showDatePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDate: _date); if (selected != null) setState(() => _date = selected); }), const SizedBox(height: 12), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () { if (_formKey.currentState?.validate() != true) return; Navigator.pop(context, TransactionDraft(type: _type, amount: double.parse(_amount.text), category: _category, note: _note.text.trim(), date: _date)); }, icon: const Icon(Icons.arrow_upward_rounded), label: Text(widget.transaction == null ? '新增账目' : '保存修改')))])))));
}
