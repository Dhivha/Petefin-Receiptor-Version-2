import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:http/http.dart' as http;
import '../models/branch_download.dart';
import '../services/branch_download_service.dart';

enum DownloadInputType { branchOnly, singleDate, dateRange }

class DownloadParamConfig {
  final String title;
  final String fileType;
  final DownloadInputType paramType;
  final Future<http.Response> Function(Map<String, String> params) apiCall;
  final String Function(Map<String, String> params) summaryBuilder;

  const DownloadParamConfig({
    required this.title,
    required this.fileType,
    required this.paramType,
    required this.apiCall,
    required this.summaryBuilder,
  });
}

class GenericBranchDownloadScreen extends StatefulWidget {
  final DownloadParamConfig config;
  final String downloadType;

  const GenericBranchDownloadScreen({
    super.key,
    required this.config,
    required this.downloadType,
  });

  @override
  State<GenericBranchDownloadScreen> createState() =>
      _GenericBranchDownloadScreenState();
}

class _GenericBranchDownloadScreenState
    extends State<GenericBranchDownloadScreen> with SingleTickerProviderStateMixin {
  final BranchDownloadService _service = BranchDownloadService();
  late TabController _tabController;
  Timer? _refreshTimer;

  // Form state
  final _formKey = GlobalKey<FormState>();
  DateTime? _targetDate;
  DateTime? _startDate;
  DateTime? _endDate;
  final _targetDateCtrl = TextEditingController();
  final _startDateCtrl = TextEditingController();
  final _endDateCtrl = TextEditingController();

  bool _isDownloading = false;
  List<BranchDownload> _recentDownloads = [];
  bool _isLoadingDownloads = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDownloads();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && _hasActive) _loadDownloads();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    _targetDateCtrl.dispose();
    _startDateCtrl.dispose();
    _endDateCtrl.dispose();
    super.dispose();
  }

  bool get _hasActive =>
      _recentDownloads.any((d) => d.isActive);

  int get _activeCount =>
      _recentDownloads.where((d) => d.isActive).length;

  Future<void> _loadDownloads() async {
    setState(() => _isLoadingDownloads = true);
    try {
      final list = await _service.getRecentDownloads(widget.downloadType, limit: 5);
      if (mounted) setState(() => _recentDownloads = list);
    } catch (e) {
      print('Error loading downloads: $e');
    } finally {
      if (mounted) setState(() => _isLoadingDownloads = false);
    }
  }

  Future<void> _pickDate(BuildContext context,
      {required TextEditingController ctrl,
      required void Function(DateTime) onPicked}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: Colors.blue,
                onPrimary: Colors.white,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      ctrl.text = DateFormat('dd/MM/yyyy').format(picked);
      onPicked(picked);
    }
  }

  Future<void> _startDownload() async {
    if (!_formKey.currentState!.validate()) return;

    final cfg = widget.config;
    final params = <String, String>{};

    if (cfg.paramType == DownloadInputType.singleDate) {
      if (_targetDate == null) {
        _snack('Please select a date', isError: true);
        return;
      }
      params['targetDate'] = DateFormat('yyyy-MM-dd').format(_targetDate!);
    } else if (cfg.paramType == DownloadInputType.dateRange) {
      if (_startDate == null || _endDate == null) {
        _snack('Please select both start and end dates', isError: true);
        return;
      }
      params['startDate'] = DateFormat('yyyy-MM-dd').format(_startDate!);
      params['endDate'] = DateFormat('yyyy-MM-dd').format(_endDate!);
    }

    setState(() => _isDownloading = true);
    try {
      await _service.startDownload(
        downloadType: widget.downloadType,
        displayTitle: cfg.title,
        parametersSummary: cfg.summaryBuilder(params),
        fileType: cfg.fileType,
        apiFn: () => cfg.apiCall(params),
      );
      _snack('Download started — running in background', backgroundColor: Colors.blue);
      _clearForm();
      await _loadDownloads();
      _tabController.animateTo(1);
    } catch (e) {
      _snack('Failed to start download: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  void _clearForm() {
    _targetDateCtrl.clear();
    _startDateCtrl.clear();
    _endDateCtrl.clear();
    setState(() {
      _targetDate = null;
      _startDate = null;
      _endDate = null;
    });
  }

  Future<void> _openFile(BranchDownload dl) async {
    if (dl.filePath == null || !File(dl.filePath!).existsSync()) {
      _snack('File no longer exists', isError: true);
      return;
    }
    final result = await OpenFile.open(dl.filePath!);
    if (result.type != ResultType.done) _snack(result.message, isError: true);
  }

  Future<void> _shareFile(BranchDownload dl) async {
    if (dl.filePath == null || !File(dl.filePath!).existsSync()) {
      _snack('File no longer exists', isError: true);
      return;
    }
    await Share.shareXFiles([XFile(dl.filePath!)],
        subject: dl.displayTitle, text: dl.parametersSummary);
  }

  Future<void> _deleteDownload(BranchDownload dl) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Download'),
        content: Text('Delete this download?\n\n${dl.parametersSummary}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _service.deleteById(dl.id!);
      _snack('Deleted');
      await _loadDownloads();
    }
  }

  void _snack(String msg, {bool isError = false, Color? backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: backgroundColor ?? (isError ? Colors.red : Colors.green),
      duration: Duration(seconds: isError ? 4 : 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.config.title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            const Tab(text: 'New Download'),
            Tab(
              text: _activeCount > 0
                  ? 'Recent ($_activeCount active)'
                  : 'Recent Downloads',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildFormTab(), _buildRecentTab()],
      ),
    );
  }

  Widget _buildFormTab() {
    final cfg = widget.config;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cfg.title,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue),
                    ),
                    const SizedBox(height: 16),

                    // Single date
                    if (cfg.paramType == DownloadInputType.singleDate) ...[
                      TextFormField(
                        controller: _targetDateCtrl,
                        readOnly: true,
                        onTap: () => _pickDate(context,
                            ctrl: _targetDateCtrl,
                            onPicked: (d) => setState(() => _targetDate = d)),
                        decoration: InputDecoration(
                          labelText: 'Target Date',
                          hintText: 'Select date',
                          prefixIcon: const Icon(Icons.calendar_today, color: Colors.blue),
                          border: const OutlineInputBorder(),
                          focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue, width: 2)),
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Please select a date' : null,
                      ),
                    ],

                    // Date range
                    if (cfg.paramType == DownloadInputType.dateRange) ...[
                      TextFormField(
                        controller: _startDateCtrl,
                        readOnly: true,
                        onTap: () => _pickDate(context,
                            ctrl: _startDateCtrl,
                            onPicked: (d) => setState(() => _startDate = d)),
                        decoration: InputDecoration(
                          labelText: 'Start Date',
                          hintText: 'Select start date',
                          prefixIcon: const Icon(Icons.calendar_today, color: Colors.blue),
                          border: const OutlineInputBorder(),
                          focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue, width: 2)),
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Please select start date' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _endDateCtrl,
                        readOnly: true,
                        onTap: () => _pickDate(context,
                            ctrl: _endDateCtrl,
                            onPicked: (d) => setState(() => _endDate = d)),
                        decoration: InputDecoration(
                          labelText: 'End Date',
                          hintText: 'Select end date',
                          prefixIcon: const Icon(Icons.calendar_today, color: Colors.blue),
                          border: const OutlineInputBorder(),
                          focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue, width: 2)),
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Please select end date' : null,
                      ),
                    ],

                    // branchOnly — no input needed
                    if (cfg.paramType == DownloadInputType.branchOnly)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info, color: Colors.blue, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Download will use your current branch',
                              style: TextStyle(color: Colors.blue[700]),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isDownloading ? null : _startDownload,
                        icon: _isDownloading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(Colors.white)))
                            : const Icon(Icons.download, color: Colors.white),
                        label: Text(
                          _isDownloading ? 'Starting Download...' : 'Download',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.info, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text('Download Information',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue)),
                    ]),
                    const SizedBox(height: 12),
                    Text(
                      '• Downloads run in the background — you can leave this screen\n'
                      '• Return here anytime to check progress\n'
                      '• Top 5 recent downloads are shown in Recent Downloads\n'
                      '• Downloads auto-delete after 12 hours\n'
                      '• File type: ${cfg.fileType.toUpperCase()}',
                      style: TextStyle(
                          fontSize: 14, color: Colors.blue[700], height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTab() {
    return RefreshIndicator(
      onRefresh: _loadDownloads,
      color: Colors.blue,
      child: Column(
        children: [
          if (_activeCount > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.blue[50],
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.blue)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$_activeCount download${_activeCount == 1 ? "" : "s"} in progress...',
                      style: TextStyle(
                          color: Colors.blue[700], fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadDownloads,
                    child: const Text('Refresh', style: TextStyle(color: Colors.blue)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoadingDownloads
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.blue),
                        SizedBox(height: 16),
                        Text('Loading downloads...'),
                      ],
                    ),
                  )
                : _recentDownloads.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.file_download,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text('No downloads yet',
                                style: TextStyle(
                                    fontSize: 18, color: Colors.grey[600])),
                            const SizedBox(height: 8),
                            Text(
                              'Tap New Download to get started',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _recentDownloads.length,
                        itemBuilder: (ctx, i) =>
                            _buildDownloadCard(_recentDownloads[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadCard(BranchDownload dl) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (dl.status) {
      case BranchDownloadStatus.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        statusText = 'Pending';
        break;
      case BranchDownloadStatus.downloading:
        statusColor = Colors.blue;
        statusIcon = Icons.download;
        statusText = 'Downloading';
        break;
      case BranchDownloadStatus.completed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Completed';
        break;
      case BranchDownloadStatus.failed:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        statusText = 'Failed';
        break;
    }

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (dl.isActive)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(statusColor)),
                    ),
                  ),
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Text(statusText,
                    style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: dl.fileType == 'pdf'
                        ? Colors.red[50]
                        : Colors.green[50],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: dl.fileType == 'pdf'
                            ? Colors.red[200]!
                            : Colors.green[200]!),
                  ),
                  child: Text(
                    dl.fileType.toUpperCase(),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: dl.fileType == 'pdf'
                            ? Colors.red[700]
                            : Colors.green[700]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(dl.parametersSummary,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              'Requested: ${DateFormat('dd/MM/yyyy HH:mm').format(dl.requestedAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (dl.completedAt != null) ...[
              const SizedBox(height: 2),
              Text(
                'Completed: ${DateFormat('dd/MM/yyyy HH:mm').format(dl.completedAt!)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
            Text(
              'Expires: ${DateFormat('dd/MM/yyyy HH:mm').format(dl.expiresAt)}',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
            if (dl.status == BranchDownloadStatus.failed &&
                dl.errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Text('Error: ${dl.errorMessage}',
                    style:
                        TextStyle(fontSize: 12, color: Colors.red[700])),
              ),
            ],
            const SizedBox(height: 16),
            if (dl.isCompleted)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openFile(dl),
                      icon: const Icon(Icons.open_in_new,
                          size: 16, color: Colors.white),
                      label: const Text('Open',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          minimumSize: const Size(0, 36)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _shareFile(dl),
                      icon: const Icon(Icons.share,
                          size: 16, color: Colors.white),
                      label: const Text('Share',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          minimumSize: const Size(0, 36)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _deleteDownload(dl),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        minimumSize: const Size(36, 36)),
                    child: const Icon(Icons.delete,
                        size: 16, color: Colors.white),
                  ),
                ],
              )
            else
              Row(
                children: [
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => _deleteDownload(dl),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        minimumSize: const Size(36, 36)),
                    child: const Icon(Icons.delete,
                        size: 16, color: Colors.white),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

