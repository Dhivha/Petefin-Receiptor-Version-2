import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import 'dart:async';
import 'dart:io';
import '../services/auth_service.dart';
import '../models/cashbook_download.dart';

class ManageCashbookDownloadScreen extends StatefulWidget {
  @override
  _ManageCashbookDownloadScreenState createState() =>
      _ManageCashbookDownloadScreenState();
}

class _ManageCashbookDownloadScreenState
    extends State<ManageCashbookDownloadScreen>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final _cashbookDateController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  DateTime? _cashbookDate;

  bool _isRequesting = false;
  bool _isProcessing = false;
  bool _isLoadingDownloads = false;
  List<CashbookDownload> _recentDownloads = [];
  Timer? _refreshTimer;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRecentDownloads();
    _startPeriodicRefresh();
  }

  @override
  void dispose() {
    _cashbookDateController.dispose();
    _tabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRecentDownloads() async {
    setState(() {
      _isLoadingDownloads = true;
    });

    try {
      final downloads = await _authService.getRecentCashbookDownloads(
        limit: 10,
      );
      setState(() {
        _recentDownloads = downloads;
      });
    } catch (e) {
      print('Error loading downloads: $e');
    } finally {
      setState(() {
        _isLoadingDownloads = false;
      });
    }
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      if (mounted && _hasActiveDownloads()) {
        _loadRecentDownloads();
      }
    });
  }

  bool _hasActiveDownloads() {
    return _recentDownloads.any(
      (download) =>
          download.status == DownloadStatus.pending ||
          download.status == DownloadStatus.downloading,
    );
  }

  int get _activeDownloadsCount {
    return _recentDownloads
        .where(
          (download) =>
              download.status == DownloadStatus.pending ||
              download.status == DownloadStatus.downloading,
        )
        .length;
  }

  Future<void> _selectCashbookDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _cashbookDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Colors.blue,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _cashbookDate) {
      setState(() {
        _cashbookDate = picked;
        _cashbookDateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _requestCashbookDownload() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_cashbookDate == null) {
      _showSnackBar('Please select a cashbook date', isError: true);
      return;
    }

    setState(() {
      _isRequesting = true;
    });

    try {
      final result = await _authService.requestCashbookDownload(
        cashbookDate: _cashbookDate!,
      );

      if (result.success) {
        _showSnackBar(result.message);
        _clearForm();
        await _loadRecentDownloads();

        // Show background processing notification
        Future.delayed(Duration(seconds: 2), () {
          if (mounted) {
            _showSnackBar(
              'Download is being processed in the background...',
              backgroundColor: Colors.blue,
            );
          }
        });
      } else {
        _showSnackBar(result.message, isError: true);
      }
    } catch (e) {
      _showSnackBar('Download request failed: $e', isError: true);
    } finally {
      setState(() {
        _isRequesting = false;
      });
    }
  }

  Future<void> _processQueuedDownloads() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await _authService.processQueuedDownloadsManually();

      if (result.success) {
        _showSnackBar(result.message);
        await _loadRecentDownloads();
      } else {
        _showSnackBar(result.message, isError: true);
      }
    } catch (e) {
      _showSnackBar('Processing failed: $e', isError: true);
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _shareFile(CashbookDownload download) async {
    if (download.filePath == null || download.filePath!.isEmpty) {
      _showSnackBar('File not available', isError: true);
      return;
    }

    final file = File(download.filePath!);
    if (!await file.exists()) {
      _showSnackBar('File no longer exists', isError: true);
      return;
    }

    try {
      await Share.shareXFiles(
        [XFile(download.filePath!)],
        subject: 'Cashbook Report - ${download.formattedDate}',
        text:
            'Cashbook report for ${download.branchName} for ${download.formattedDate}',
      );
    } catch (e) {
      _showSnackBar('Failed to share file: $e', isError: true);
    }
  }

  Future<void> _openFile(CashbookDownload download) async {
    if (download.filePath == null || download.filePath!.isEmpty) {
      _showSnackBar('File not available', isError: true);
      return;
    }

    final file = File(download.filePath!);
    if (!await file.exists()) {
      _showSnackBar('File no longer exists', isError: true);
      return;
    }

    try {
      final result = await OpenFile.open(download.filePath!);

      if (result.type == ResultType.done) {
        _showSnackBar('File opened successfully');
      } else if (result.type == ResultType.noAppToOpen) {
        _showSnackBar('No app available to open this file', isError: true);
      } else if (result.type == ResultType.fileNotFound) {
        _showSnackBar('File not found', isError: true);
      } else {
        _showSnackBar('Failed to open file: ${result.message}', isError: true);
      }
    } catch (e) {
      _showSnackBar('Failed to open file: $e', isError: true);
    }
  }

  Future<void> _deleteDownload(CashbookDownload download) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Download'),
        content: Text(
          'Are you sure you want to delete this download?\n\n${download.formattedDate}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final result = await _authService.deleteCashbookDownload(download.id!);

        if (result.success) {
          _showSnackBar('Download deleted successfully');
          await _loadRecentDownloads();
        } else {
          _showSnackBar(result.message, isError: true);
        }
      } catch (e) {
        _showSnackBar('Failed to delete: $e', isError: true);
      }
    }
  }

  void _clearForm() {
    _cashbookDateController.clear();
    setState(() {
      _cashbookDate = null;
    });
  }

  void _showSnackBar(
    String message, {
    bool isError = false,
    Color? backgroundColor,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            backgroundColor ?? (isError ? Colors.red : Colors.green),
        duration: Duration(seconds: isError ? 4 : 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Cashbook Download',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        iconTheme: IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'New Download'),
            Tab(
              text: _activeDownloadsCount > 0
                  ? 'Recent Downloads ($_activeDownloadsCount active)'
                  : 'Recent Downloads',
            ),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildNewDownloadTab(), _buildRecentDownloadsTab()],
      ),
    );
  }

  Widget _buildNewDownloadTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Download Cashbook Report',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    SizedBox(height: 16),

                    // Cashbook Date
                    TextFormField(
                      controller: _cashbookDateController,
                      decoration: InputDecoration(
                        labelText: 'Cashbook Date',
                        hintText: 'Select cashbook date',
                        prefixIcon: Icon(
                          Icons.calendar_today,
                          color: Colors.blue,
                        ),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue, width: 2),
                        ),
                      ),
                      readOnly: true,
                      onTap: () => _selectCashbookDate(context),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select cashbook date';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 24),

                    // Download Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isRequesting
                            ? null
                            : _requestCashbookDownload,
                        icon: _isRequesting
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Icon(Icons.download, color: Colors.white),
                        label: Text(
                          _isRequesting
                              ? 'Requesting Download...'
                              : 'Request Download',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Process Queued Button
            Card(
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Process Pending Downloads',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Manually check for pending downloads and process them now',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing
                            ? null
                            : _processQueuedDownloads,
                        icon: _isProcessing
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Icon(Icons.sync, color: Colors.white),
                        label: Text(
                          _isProcessing ? 'Processing...' : 'Process Now',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Info Card
            Card(
              elevation: 2,
              color: Colors.blue[50],
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Download Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      '• Downloads are processed in the background\n'
                      '• You will be notified when download is ready\n'
                      '• Downloaded files are saved to your device\n'
                      '• Files can be shared or opened from Recent Downloads',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue[700],
                        height: 1.4,
                      ),
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

  Widget _buildRecentDownloadsTab() {
    return RefreshIndicator(
      onRefresh: _loadRecentDownloads,
      color: Colors.blue,
      child: Column(
        children: [
          // Active Downloads Status Bar
          if (_activeDownloadsCount > 0)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.0),
              color: Colors.blue[50],
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$_activeDownloadsCount download${_activeDownloadsCount == 1 ? "" : "s"} in progress...',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadRecentDownloads,
                    child: Text(
                      'Refresh',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),

          // Downloads List
          Expanded(
            child: _isLoadingDownloads
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.blue),
                        SizedBox(height: 16),
                        Text(
                          'Loading downloads...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : _recentDownloads.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.file_download, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No downloads yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Request your first cashbook download from the New Download tab',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(16.0),
                    itemCount: _recentDownloads.length,
                    itemBuilder: (context, index) {
                      final download = _recentDownloads[index];
                      return _buildDownloadCard(download);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadCard(CashbookDownload download) {
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.help;
    String statusText = 'Unknown';

    switch (download.status) {
      case DownloadStatus.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        statusText = 'Pending';
        break;
      case DownloadStatus.downloading:
        statusColor = Colors.blue;
        statusIcon = Icons.download;
        statusText = 'Downloading';
        break;
      case DownloadStatus.completed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Completed';
        break;
      case DownloadStatus.failed:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        statusText = 'Failed';
        break;
    }

    return Card(
      elevation: 3,
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Animated loading indicator for active downloads
                if (download.status == DownloadStatus.downloading ||
                    download.status == DownloadStatus.pending)
                  Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      ),
                    ),
                  ),
                Icon(statusIcon, color: statusColor, size: 20),
                SizedBox(width: 8),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Spacer(),
                Text(
                  'ID: ${download.id}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            SizedBox(height: 8),

            Text(
              download.formattedDate,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 4),

            Text(
              'Branch: ${download.branchName}',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            SizedBox(height: 4),

            Text(
              'Requested: ${DateFormat('dd/MM/yyyy HH:mm').format(download.requestedAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),

            if (download.completedAt != null) ...[
              SizedBox(height: 4),
              Text(
                'Completed: ${DateFormat('dd/MM/yyyy HH:mm').format(download.completedAt!)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],

            if (download.status == DownloadStatus.failed &&
                download.errorMessage != null) ...[
              SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Text(
                  'Error: ${download.errorMessage}',
                  style: TextStyle(fontSize: 12, color: Colors.red[700]),
                ),
              ),
            ],

            if (download.status == DownloadStatus.completed) ...[
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openFile(download),
                      icon: Icon(
                        Icons.open_in_new,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Open',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        minimumSize: Size(0, 36),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _shareFile(download),
                      icon: Icon(Icons.share, size: 16, color: Colors.white),
                      label: Text(
                        'Share',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        minimumSize: Size(0, 36),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _deleteDownload(download),
                    child: Icon(Icons.delete, size: 16, color: Colors.white),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      minimumSize: Size(36, 36),
                    ),
                  ),
                ],
              ),
            ] else ...[
              SizedBox(height: 16),
              Row(
                children: [
                  Spacer(),
                  ElevatedButton(
                    onPressed: () => _deleteDownload(download),
                    child: Icon(Icons.delete, size: 16, color: Colors.white),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      minimumSize: Size(36, 36),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
