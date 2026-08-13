import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/sub_book.dart';
import '../models/transaction.dart';

class LedgerExporter {
  static Future<void> exportJson({
    required List<LedgerTransaction> transactions,
    required List<LedgerSubBook> subBooks,
  }) async {
    final now = DateTime.now();
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'ledger-export-${_fileStamp(now)}.json';
    final file = File('${directory.path}/$fileName');
    final payload = {
      'format': 'ledger-mobile-export',
      'version': 1,
      'exportedAt': now.toIso8601String(),
      'transactions': transactions.map((item) => item.toJson()).toList(),
      'subBooks': subBooks.map((item) => item.toJson()).toList(),
    };
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Ledger 账目备份',
      text: 'Ledger JSON 账目备份（${transactions.length} 条账目）',
    );
  }

  static String _fileStamp(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}${value.month.toString().padLeft(2, '0')}${value.day.toString().padLeft(2, '0')}-'
      '${value.hour.toString().padLeft(2, '0')}${value.minute.toString().padLeft(2, '0')}${value.second.toString().padLeft(2, '0')}';
}
