import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import 'generic_branch_download_screen.dart';

class BranchLoanDownloadScreen extends StatefulWidget {
  const BranchLoanDownloadScreen({super.key});

  @override
  State<BranchLoanDownloadScreen> createState() =>
      _BranchLoanDownloadScreenState();
}

class _BranchLoanDownloadScreenState extends State<BranchLoanDownloadScreen> {
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  User? _currentUser;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    await _authService.initialize();
    if (mounted) setState(() => _currentUser = _authService.currentUser);
  }

  bool get _isAccountsOrManagement {
    final pos = (_currentUser?.position ?? '').toLowerCase().trim();
    return pos.contains('accounts') || pos.contains('management');
  }

  List<_DownloadCard> _buildCards() {
    final branch = _currentUser?.branch ?? '';

    return [
      _DownloadCard(
        downloadType: 'loan_book',
        title: 'Download Loan Book',
        icon: Icons.menu_book,
        fileType: 'excel',
        accountsOnly: false,
        config: DownloadParamConfig(
          title: 'Download Loan Book',
          fileType: 'excel',
          paramType: DownloadInputType.branchOnly,
          apiCall: (_) => _apiService.downloadLoanBook(branch),
          summaryBuilder: (_) => 'Branch: $branch',
        ),
      ),
      _DownloadCard(
        downloadType: 'reminder_pdf',
        title: 'Reminder PDF',
        icon: Icons.picture_as_pdf,
        fileType: 'pdf',
        accountsOnly: false,
        config: DownloadParamConfig(
          title: 'Reminder PDF',
          fileType: 'pdf',
          paramType: DownloadInputType.singleDate,
          apiCall: (p) => _apiService.downloadReminderPdf(branch, p['targetDate']!),
          summaryBuilder: (p) => 'Branch: $branch | Date: ${p['targetDate']}',
        ),
      ),
      _DownloadCard(
        downloadType: 'defaulters',
        title: 'Defaulters Report',
        icon: Icons.warning_amber,
        fileType: 'pdf',
        accountsOnly: false,
        config: DownloadParamConfig(
          title: 'Defaulters Report',
          fileType: 'pdf',
          paramType: DownloadInputType.singleDate,
          apiCall: (p) => _apiService.downloadDefaultersReport(branch, p['targetDate']!),
          summaryBuilder: (p) => 'Branch: $branch | Date: ${p['targetDate']}',
        ),
      ),
      _DownloadCard(
        downloadType: 'loan_book_analysis',
        title: 'Loan Book Analysis',
        icon: Icons.analytics,
        fileType: 'excel',
        accountsOnly: true,
        config: DownloadParamConfig(
          title: 'Loan Book Analysis',
          fileType: 'excel',
          paramType: DownloadInputType.singleDate,
          apiCall: (p) => _apiService.downloadLoanBookAnalysis(p['targetDate']!),
          summaryBuilder: (p) => 'Date: ${p['targetDate']}',
        ),
      ),
      _DownloadCard(
        downloadType: 'consolidated_branch',
        title: 'Consolidated Income (Branch)',
        icon: Icons.account_balance,
        fileType: 'excel',
        accountsOnly: true,
        config: DownloadParamConfig(
          title: 'Consolidated Income (Branch)',
          fileType: 'excel',
          paramType: DownloadInputType.dateRange,
          apiCall: (p) => _apiService.downloadConsolidatedBranch(p['startDate']!, p['endDate']!),
          summaryBuilder: (p) => '${p['startDate']} to ${p['endDate']}',
        ),
      ),
      _DownloadCard(
        downloadType: 'consolidated_day',
        title: 'Consolidated Income (Day)',
        icon: Icons.today,
        fileType: 'excel',
        accountsOnly: true,
        config: DownloadParamConfig(
          title: 'Consolidated Income (Day)',
          fileType: 'excel',
          paramType: DownloadInputType.dateRange,
          apiCall: (p) => _apiService.downloadConsolidatedDay(p['startDate']!, p['endDate']!),
          summaryBuilder: (p) => '${p['startDate']} to ${p['endDate']}',
        ),
      ),
      _DownloadCard(
        downloadType: 'daily_income',
        title: 'Daily Income',
        icon: Icons.attach_money,
        fileType: 'excel',
        accountsOnly: true,
        config: DownloadParamConfig(
          title: 'Daily Income',
          fileType: 'excel',
          paramType: DownloadInputType.dateRange,
          apiCall: (p) => _apiService.downloadDailyIncome(p['startDate']!, p['endDate']!),
          summaryBuilder: (p) => '${p['startDate']} to ${p['endDate']}',
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Branch Loan Download',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.blue,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(child: CircularProgressIndicator(color: Colors.blue)),
      );
    }

    final filtered = _buildCards().where((card) {
      if (card.accountsOnly && !_isAccountsOrManagement) return false;
      if (_searchQuery.isNotEmpty) {
        return card.title.toLowerCase().contains(_searchQuery.toLowerCase());
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Branch Loan Download',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search downloads...',
                prefixIcon: const Icon(Icons.search, color: Colors.blue),
                border: const OutlineInputBorder(),
                focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue, width: 2)),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          if (_searchQuery.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                '${filtered.length} download option${filtered.length == 1 ? '' : 's'} available',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('No downloads match "$_searchQuery"',
                            style: TextStyle(
                                fontSize: 16, color: Colors.grey[600])),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.05,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) => _buildCard(filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(_DownloadCard card) {
    return Card(
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GenericBranchDownloadScreen(
              config: card.config,
              downloadType: card.downloadType,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(card.icon, color: Colors.blue, size: 36),
              const SizedBox(height: 10),
              Text(
                card.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: card.fileType == 'pdf'
                      ? Colors.red[50]
                      : Colors.green[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: card.fileType == 'pdf'
                          ? Colors.red[200]!
                          : Colors.green[200]!),
                ),
                child: Text(
                  card.fileType.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: card.fileType == 'pdf'
                        ? Colors.red[700]
                        : Colors.green[700],
                  ),
                ),
              ),
              if (card.accountsOnly) ...[
                const SizedBox(height: 4),
                Text(
                  'Accounts/Mgmt only',
                  style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DownloadCard {
  final String downloadType;
  final String title;
  final IconData icon;
  final String fileType;
  final bool accountsOnly;
  final DownloadParamConfig config;

  const _DownloadCard({
    required this.downloadType,
    required this.title,
    required this.icon,
    required this.fileType,
    required this.accountsOnly,
    required this.config,
  });
}

