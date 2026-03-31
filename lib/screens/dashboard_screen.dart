import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user.dart';
import 'clients_screen.dart';
import 'repayment_screen.dart';
import 'queued_repayments_screen.dart';
import 'bluetooth_screen.dart';
import 'receipt_numbers_screen.dart';
import 'penalties_screen.dart';
import 'admin_receipts_screen.dart';
import 'manage_transfers_screen.dart';
import 'manage_expenses_screen.dart';
import 'manage_petty_cash_screen.dart';
import 'manage_cash_count_screen.dart';
import 'manage_cashbook_download_screen.dart';
import 'manage_request_balance_screen.dart';
import 'login_screen.dart';
import 'client_management_screen.dart';
import 'add_client_screen.dart';
import 'add_client_image_screen.dart';
import 'view_client_photo_screen.dart';
import 'collateral_submission_screen.dart';
import 'branch_loan_download_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _authService = AuthService();
  int _currentIndex = 0;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _autoSyncClientsOnStart();
  }

  Future<void> _loadUser() async {
    await _authService.initialize();
    setState(() {
      _currentUser = _authService.currentUser;
    });

    if (!_authService.isLoggedIn) {
      _navigateToLogin();
    }
  }

  Future<void> _autoSyncClientsOnStart() async {
    // Auto-sync clients when dashboard loads
    try {
      await _authService.autoSyncClients();
    } catch (e) {
      print('Auto-sync failed: $e');
    }
  }

  void _navigateToLogin() {
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _handleLogout() async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await _authService.logout();
      _navigateToLogin();
    }
  }

  String _getPageTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Clients';
      case 1:
        return 'Repayments';
      case 2:
        return 'Queued Repayments';
      case 3:
        return 'Penalties';
      case 4:
        return 'Admin & Receipt';
      case 5:
        return 'Bluetooth';
      case 6:
        return 'Receipt Numbers';
      default:
        return 'Dashboard';
    }
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return const ClientsScreen();
      case 1:
        return const RepaymentScreen();
      case 2:
        return const QueuedRepaymentsScreen();
      case 3:
        return const PenaltiesScreen();
      case 4:
        return const AdminReceiptsScreen();
      case 5:
        return const BluetoothScreen();
      case 6:
        return const ReceiptNumbersScreen();
      default:
        return _buildPlaceholderScreen('Dashboard', Icons.dashboard);
    }
  }

  Widget _buildPlaceholderScreen(String title, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This feature is coming soon',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_getPageTitle()),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  _showUserProfile();
                  break;
                case 'sync':
                  _syncClients();
                  break;
                case 'logout':
                  _handleLogout();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, size: 20),
                    SizedBox(width: 8),
                    Text('Profile'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'sync',
                child: Row(
                  children: [
                    Icon(Icons.sync, size: 20),
                    SizedBox(width: 8),
                    Text('Sync Clients'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white,
                    child: Text(
                      _currentUser!.initial,
                      style: TextStyle(
                        color: Colors.blue.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: Colors.blue.shade600,
        unselectedItemColor: Colors.grey.shade600,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Clients'),
          BottomNavigationBarItem(
            icon: Icon(Icons.payment),
            label: 'Repayments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.queue),
            label: 'Queued Rep.',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.warning),
            label: 'Penalties',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Admin & FCB',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bluetooth),
            label: 'Bluetooth',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'Receipts'),
        ],
      ),
    );
  }

  void _showUserProfile() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('User Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileRow('Name', _currentUser!.fullName),
            _buildProfileRow('Position', _currentUser!.position),
            _buildProfileRow('Branch', _currentUser!.branch),
            _buildProfileRow('User ID', _currentUser!.currentUserId.toString()),
            _buildProfileRow('WhatsApp', _currentUser!.whatsAppContact),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _syncClients() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Syncing clients...'),
          ],
        ),
      ),
    );

    try {
      final result = await _authService.syncClientsForCurrentUser();

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue.shade600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Text(
                    _currentUser!.initial,
                    style: TextStyle(
                      color: Colors.blue.shade600,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _currentUser!.fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _currentUser!.branch,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          ExpansionTile(
            leading: const Icon(Icons.people, color: Colors.blue),
            title: const Text('Client Management'),
            children: [
              ListTile(
                leading: const Icon(Icons.person_add, color: Colors.blue),
                title: const Text('Add Client'),
                subtitle: const Text('Create new client profile'),
                onTap: () {
                  Navigator.of(context).pop(); // Close drawer
                  _navigateToAddClient();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.add_photo_alternate,
                  color: Colors.orange,
                ),
                title: const Text('Add Client Image'),
                subtitle: const Text('Upload photos for existing clients'),
                onTap: () {
                  Navigator.of(context).pop(); // Close drawer
                  _navigateToAddClientImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo, color: Colors.green),
                title: const Text('View Photo'),
                subtitle: const Text('View client photos'),
                onTap: () {
                  Navigator.of(context).pop(); // Close drawer
                  _navigateToViewPhoto();
                },
              ),
              ListTile(
                leading: const Icon(Icons.description, color: Colors.purple),
                title: const Text('Add Collateral'),
                subtitle: const Text('Submit collateral documents'),
                onTap: () {
                  Navigator.of(context).pop(); // Close drawer
                  _navigateToCollateralSubmission();
                },
              ),
              ListTile(
                leading: const Icon(Icons.list, color: Colors.indigo),
                title: const Text('View Clients'),
                subtitle: const Text('Manage queued and synced clients'),
                onTap: () {
                  Navigator.of(context).pop(); // Close drawer
                  _navigateToClientManagement();
                },
              ),
            ],
          ),
          ExpansionTile(
            leading: const Icon(Icons.settings, color: Colors.grey),
            title: const Text('Configuration'),
            children: [
              ListTile(
                leading: const Icon(Icons.business, color: Colors.blue),
                title: const Text('Sync Branches'),
                subtitle: FutureBuilder<DateTime?>(
                  future: _authService.getLastBranchSyncTime(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      final lastSync = snapshot.data!;
                      final now = DateTime.now();
                      final diff = now.difference(lastSync);

                      String timeAgo;
                      if (diff.inMinutes < 1) {
                        timeAgo = 'Just now';
                      } else if (diff.inMinutes < 60) {
                        timeAgo = '${diff.inMinutes}m ago';
                      } else if (diff.inHours < 24) {
                        timeAgo = '${diff.inHours}h ago';
                      } else {
                        timeAgo = '${diff.inDays}d ago';
                      }

                      return Text('Last synced: $timeAgo');
                    }
                    return const Text('Never synced');
                  },
                ),
                onTap: () {
                  Navigator.of(context).pop(); // Close drawer
                  _syncBranches();
                },
              ),
            ],
          ),
          ListTile(
            leading: const Icon(Icons.swap_horiz, color: Colors.blue),
            title: const Text('Manage Transfers'),
            subtitle: const Text('Create and track transfers'),
            onTap: () {
              Navigator.of(context).pop(); // Close drawer
              _navigateToManageTransfers();
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long, color: Colors.orange),
            title: const Text('Expenses'),
            subtitle: const Text('Create and track expenses'),
            onTap: () {
              Navigator.of(context).pop(); // Close drawer
              _navigateToExpenses();
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.account_balance_wallet,
              color: Colors.green,
            ),
            title: const Text('Fund Petty Cash'),
            subtitle: const Text('Fund and manage petty cash'),
            onTap: () {
              Navigator.of(context).pop(); // Close drawer
              _navigateToFundPettyCash();
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_balance, color: Colors.blue),
            title: const Text('Daily Cash Count'),
            subtitle: const Text('Capture and track daily cash counts'),
            onTap: () {
              Navigator.of(context).pop(); // Close drawer
              _navigateToDailyCashCount();
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_download, color: Colors.blue),
            title: const Text('Cashbook Download'),
            subtitle: const Text('Download cashbook reports as PDF'),
            onTap: () {
              Navigator.of(context).pop(); // Close drawer
              _navigateToCashbookDownload();
            },
          ),
          ListTile(
            leading: const Icon(Icons.cloud_download, color: Colors.blue),
            title: const Text('Branch Loan Download'),
            subtitle: const Text('Loan book, reports & analysis downloads'),
            onTap: () {
              Navigator.of(context).pop();
              _navigateToBranchLoanDownload();
            },
          ),
          ListTile(
            leading: const Icon(Icons.request_quote, color: Colors.blue),
            title: const Text('Request Balance'),
            subtitle: const Text('Submit balance requests with approval'),
            onTap: () {
              Navigator.of(context).pop(); // Close drawer
              _navigateToRequestBalance();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.grey),
            title: const Text('About'),
            onTap: () {
              Navigator.of(context).pop();
              _showAbout();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _syncBranches() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Syncing branches...'),
          ],
        ),
      ),
    );

    try {
      final result = await _authService.syncBranches();

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sync failed: ${result.message}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About PeteFin ZWG Receiptor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Version: 1.0.0'),
            const SizedBox(height: 8),
            const Text('Offline-first receipting system'),
            const SizedBox(height: 8),
            FutureBuilder<int>(
              future: _authService.getBranchesCount(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Text('Branches: ${snapshot.data}');
                }
                return const Text('Branches: Loading...');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _navigateToManageTransfers() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ManageTransfersScreen()),
    );
  }

  void _navigateToExpenses() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ManageExpensesScreen()),
    );
  }

  void _navigateToFundPettyCash() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ManagePettyCashScreen()),
    );
  }

  void _navigateToDailyCashCount() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ManageCashCountScreen()),
    );
  }

  void _navigateToCashbookDownload() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => ManageCashbookDownloadScreen()),
    );
  }

  void _navigateToBranchLoanDownload() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const BranchLoanDownloadScreen()),
    );
  }

  void _navigateToRequestBalance() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => ManageRequestBalanceScreen()),
    );
  }

  void _navigateToClientManagement() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ClientManagementScreen()),
    );
  }

  void _navigateToAddClient() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const AddClientScreen()));
  }

  void _navigateToAddClientImage() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AddClientImageScreen()),
    );
  }

  void _navigateToViewPhoto() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ViewClientPhotoScreen()),
    );
  }

  void _navigateToCollateralSubmission() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const CollateralSubmissionScreen()),
    );
  }
}
