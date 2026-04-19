import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/defaulter.dart';
import '../services/defaulters_service.dart';

class DefaultersDetailsScreen extends StatefulWidget {
  final String branch;
  final String initialDate;

  const DefaultersDetailsScreen({
    super.key,
    required this.branch,
    required this.initialDate,
  });

  @override
  State<DefaultersDetailsScreen> createState() => _DefaultersDetailsScreenState();
}

class _DefaultersDetailsScreenState extends State<DefaultersDetailsScreen> {
  final DefaultersService _service = DefaultersService();
  final _fmt = NumberFormat('#,##0.00', 'en_US');
  final _searchCtrl = TextEditingController();

  DefaultDetails? _data;
  bool _loading = true;
  String? _error;
  late String _selectedDate;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final result = await _service.fetchDetails(widget.branch, _selectedDate);
    if (mounted) {
      setState(() {
        _data = result;
        _loading = false;
        if (result == null) _error = 'Failed to load data. Check connection.';
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_selectedDate) ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      _selectedDate = DateFormat('yyyy-MM-dd').format(picked);
      _load();
    }
  }

  /// Group clients by ClientId, summing their default amounts
  Map<String, _ClientGroup> _groupClients(List<DefaultClient> clients) {
    final Map<String, _ClientGroup> map = {};
    for (final c in clients) {
      if (map.containsKey(c.clientId)) {
        map[c.clientId]!.loans.add(c);
        map[c.clientId]!.totalDefault += c.defaultAmount;
      } else {
        map[c.clientId] = _ClientGroup(
          clientId: c.clientId,
          clientName: c.clientName,
          clientContact: c.clientContact,
          loans: [c],
          totalDefault: c.defaultAmount,
        );
      }
    }
    return map;
  }

  List<_ClientGroup> _filtered(Map<String, _ClientGroup> groups) {
    if (_query.isEmpty) return groups.values.toList();
    final q = _query.toLowerCase();
    return groups.values
        .where((g) =>
            g.clientName.toLowerCase().contains(q) ||
            g.clientId.toLowerCase().contains(q) ||
            g.clientContact.contains(q))
        .toList();
  }

  Future<void> _exportExcel() async {
    if (_data == null) return;
    try {
      final excel = Excel.createExcel();
      // Remove default Sheet1 and create our sheet
      final sheetName = 'Defaulters';
      final sheet = excel[sheetName];
      excel.delete('Sheet1');

      // ── Summary rows ──────────────────────────────────────────
      sheet.appendRow([
        TextCellValue('Branch'), TextCellValue(_data!.branchName),
      ]);
      sheet.appendRow([
        TextCellValue('Date'), TextCellValue(_data!.targetDate),
      ]);
      sheet.appendRow([
        TextCellValue('Total Default Amount'),
        DoubleCellValue(_data!.totalDefaultAmount),
      ]);
      sheet.appendRow([
        TextCellValue('Clients in Default'),
        IntCellValue(_data!.numberOfClientsInDefault),
      ]);
      sheet.appendRow([TextCellValue('')]);

      // ── Header row ────────────────────────────────────────────
      final headers = [
        'Loan ID',
        'Client ID',
        'Client Name',
        'Client Contact',
        'Loan Amount',
        'Weekly Payment',
        'Loan Tenure (weeks)',
        'Expected Amount by Date',
        'Total Paid Amount',
        'Default Amount',
        'Payments Expected Count',
        'Conditional Disbursement',
        'Grace Period (days)',
      ];
      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

      // ── Data rows ─────────────────────────────────────────────
      for (final c in _data!.clientsInDefault) {
        sheet.appendRow([
          IntCellValue(c.loanId),
          TextCellValue(c.clientId),
          TextCellValue(c.clientName),
          TextCellValue(c.clientContact),   // always text – no scientific notation
          DoubleCellValue(c.loanAmount),
          DoubleCellValue(c.weeklyPayment),
          IntCellValue(c.loanTenure),
          DoubleCellValue(c.expectedAmountByTargetDate),
          DoubleCellValue(c.totalPaidAmount),
          DoubleCellValue(c.defaultAmount),
          IntCellValue(c.paymentsExpectedCount),
          TextCellValue(c.conditionalDisbursement),
          IntCellValue(c.gracePeriodDays),
        ]);
      }

      // ── Save & share ──────────────────────────────────────────
      final bytes = excel.encode();
      if (bytes == null) throw Exception('Failed to encode Excel file');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/Defaulters_${widget.branch}_$_selectedDate.xlsx');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
        text: 'Defaulters Report – ${widget.branch} – $_selectedDate',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Defaulters'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Change date',
            onPressed: _pickDate,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export Excel',
            onPressed: _data != null ? _exportExcel : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary bar
          if (_data != null)
            Container(
              color: Colors.red.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Date: $_selectedDate', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(
                          '\$${_fmt.format(_data!.totalDefaultAmount)}',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Clients in default', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(
                        '${_data!.numberOfClientsInDefault}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by name, ID or contact…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () { _searchCtrl.clear(); setState(() => _query = ''); },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          // Body
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('Loading defaulters…'),
        ],
      ));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_data == null || _data!.clientsInDefault.isEmpty) {
      return const Center(child: Text('No defaulters found for this date.'));
    }

    final groups = _groupClients(_data!.clientsInDefault);
    final filtered = _filtered(groups);

    if (filtered.isEmpty) {
      return const Center(child: Text('No results match your search.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: filtered.length,
      itemBuilder: (context, i) => _buildClientTile(filtered[i]),
    );
  }

  Widget _buildClientTile(_ClientGroup group) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(group.clientName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${group.clientId}  •  ${group.clientContact}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${_fmt.format(group.totalDefault)}',
              style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text('${group.loans.length} loan${group.loans.length > 1 ? 's' : ''}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        children: group.loans.map((loan) => _buildLoanRow(loan)).toList(),
      ),
    );
  }

  Widget _buildLoanRow(DefaultClient loan) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 6),
          _row('Loan ID', '#${loan.loanId}'),
          _row('Loan Amount', '\$${_fmt.format(loan.loanAmount)}'),
          _row('Weekly Payment', '\$${_fmt.format(loan.weeklyPayment)}'),
          _row('Tenure', '${loan.loanTenure} weeks'),
          _row('Expected by Date', '\$${_fmt.format(loan.expectedAmountByTargetDate)}'),
          _row('Total Paid', '\$${_fmt.format(loan.totalPaidAmount)}'),
          _row('Default Amount', '\$${_fmt.format(loan.defaultAmount)}', highlight: true),
          _row('Payments Expected', '${loan.paymentsExpectedCount}'),
          if (loan.conditionalDisbursement.isNotEmpty)
            _row('Conditional', loan.conditionalDisbursement),
          if (loan.gracePeriodDays > 0)
            _row('Grace Period', '${loan.gracePeriodDays} days'),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
                color: highlight ? Colors.red.shade700 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientGroup {
  final String clientId;
  final String clientName;
  final String clientContact;
  final List<DefaultClient> loans;
  double totalDefault;

  _ClientGroup({
    required this.clientId,
    required this.clientName,
    required this.clientContact,
    required this.loans,
    required this.totalDefault,
  });
}
