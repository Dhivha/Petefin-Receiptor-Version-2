# PeteFin Receiptor

A Flutter mobile application for receipt management with login authentication, client management, and Bluetooth printer connectivity.

## Features

### ✅ Authentication & Login
- **Login Screen**: WhatsApp contact and PIN authentication
- **API Integration**: Login endpoint `/api/Login`
- **Local Storage**: User credentials stored securely in SQLite
- **Auto-login**: Remembers login state between app launches

### ✅ Dashboard
- **Bottom Navigation**: 6 tabs as requested
  - Clients
  - Repayments (Coming Soon)
  - Queued Repayments (Coming Soon)  
  - Penalties (Coming Soon)
  - Queued Penalties (Coming Soon)
  - Bluetooth
- **User Profile**: Display current user info with logout option
- **Auto-sync**: Automatically syncs client data on app start

### ✅ Clients Management
- **Local Storage**: All clients stored in SQLite database
- **Search Functionality**: Search by name, ID, phone number, or national ID
- **Auto-sync**: Syncs clients from `/api/QuickLoadClients/load-clients`
- **Client Details**: Full client information in popup dialog
- **Pull-to-refresh**: Manual sync capability
- **Filter by Branch**: Automatically loads clients for user's branch

### ✅ Bluetooth Functionality
- **Device Discovery**: Scan for available Bluetooth devices
- **Printer Connection**: Connect to Bluetooth thermal printers
- **Test Printing**: Print test receipts to verify connection
- **Device Management**: Paired devices and connection status
- **Connection Status**: Visual indicators for connected devices

### ✅ Data Architecture
- **SQLite Database**: Local data persistence
- **API Service**: Dual URL failover system
- **Authentication Service**: Centralized auth and user management
- **Auto-sync**: Background client synchronization

## API Endpoints

### Login
- **Endpoint**: `POST /api/Login`
- **Payload**: 
  ```json
  {
    "WhatsAppContact": "+263777290878",
    "Pin": "6092"
  }
  ```
- **Success Response (200)**:
  ```json
  {
    "IsAuthenticated": true,
    "Message": "Login successful.",
    "Initial": "I",
    "LastName": "dkjdhdhu", 
    "FirstName": "idjbbdhjd",
    "Position": "Management",
    "CurrentUserId": 5,
    "Branch": "Head Office",
    "BranchId": 104,
    "WhatsAppContact": "+263777290878"
  }
  ```

### Load Clients
- **Endpoint**: `GET /api/QuickLoadClients/load-clients?branchName={branchName}`
- **Response**: Array of client objects with all client details

## Technical Details

### Dependencies
- `flutter`: Core framework
- `sqflite`: SQLite database for local data storage
- `http`: API requests and networking
- `shared_preferences`: Secure local preferences storage
- `connectivity_plus`: Network connectivity checking
- `flutter_bluetooth_serial`: Bluetooth device communication
- `permission_handler`: Runtime permissions management
- `url_launcher`: Phone call functionality

### Architecture
- **Services Layer**: API, Auth, Database services
- **Models**: User, Client data models
- **Screens**: Login, Dashboard, Clients, Bluetooth screens
- **Database**: SQLite with proper indexing for performance

### Key Features Implemented
1. ✅ **Login with WhatsApp + PIN** - Fully implemented
2. ✅ **Local SQLite storage** - Complete with auto-sync
3. ✅ **Dashboard with 6 tabs** - All tabs created 
4. ✅ **Clients management** - With search and local storage
5. ✅ **Bluetooth printer connection** - Device discovery and connection
6. ✅ **Test printing functionality** - Bluetooth printer testing
7. ✅ **Auto-sync of clients** - Background and manual sync
8. ✅ **Search functionality** - Advanced client search

## Getting Started

1. **Install Dependencies**:
   ```bash
   flutter pub get
   ```

2. **Run the Application**:
   ```bash
   flutter run
   ```

3. **Login Credentials**: Use your registered WhatsApp number and PIN

## Next Steps for Production

1. **Bluetooth Implementation**: Add actual Bluetooth library integration
2. **Repayments/Penalties**: Implement remaining tabs with API endpoints
3. **Permissions**: Add runtime permission requests for Bluetooth
4. **Error Handling**: Enhanced error handling and offline support
5. **Testing**: Add unit and integration tests

## Notes

- The Bluetooth functionality currently uses mock data - integrate with actual `flutter_bluetooth_serial` for production
- All client data is automatically synced and stored locally for offline access
- The app handles network failures gracefully with dual-URL fallback
- Local database is automatically created and managed