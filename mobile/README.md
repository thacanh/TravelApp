# TRAWiMe Mobile App

Flutter mobile application for TRAWiMe travel platform.

## Features

- ✅ User authentication (login/register)
- ✅ Browse and search locations
- ✅ View location details with images
- ✅ Check-in at locations
- ✅ Rate and review locations
- ✅ Manage travel itineraries
- ✅ AI chatbot assistant
- ✅ Beautiful Material Design 3 UI

## Getting Started

### Prerequisites

- Flutter SDK 3.16 or higher
- Android Studio or VS Code
- Android device or emulator

### Installation

1. Install dependencies:
```bash
flutter pub get
```

2. Configure API endpoint in `lib/config/app_config.dart`:
```dart
static const String baseUrl = "http://10.0.2.2:8000"; // For emulator
// or
static const String baseUrl = "http://YOUR_IP:8000"; // For physical device
```

3. Run the app:
```bash
flutter run
```

### Building APK

**Debug APK:**
```bash
flutter build apk --debug
```

**Release APK:**
```bash
flutter build apk --release
```

The APK will be generated at: `build/app/outputs/flutter-apk/`

## Project Structure

```
lib/
├── config/          # App configuration
│   ├── app_config.dart
│   ├── routes.dart
│   └── theme.dart
├── models/          # Data models
├── providers/       # State management
├── screens/         # UI screens
├── services/        # API services
├── widgets/         # Reusable widgets
└── main.dart        # App entry point
```

## Architecture

- **State Management**: Provider
- **HTTP Client**: Dio
- **Routing**: Named routes
- **Theme**: Material Design 3

## Features Detail

### Authentication
- Login with email and password
- Registration
- Secure token storage
- Auto-login

### Location Discovery
- Grid view of locations
- Search functionality
- Filter by category and city
- Rating display
- Beautiful image carousels

### Location Details
- HD image gallery
- Detailed information
- Ratings and reviews
- Check-in button
- Add to itinerary

### AI Chatbot
- Real-time chat interface
- Smart suggestions
- Travel recommendations
- Question answering

### Profile
- User information
- Avatar display
- Activity history
- Settings
- Logout

## Customization

### Changing Theme Colors

Edit `lib/config/theme.dart`:
```dart
static const Color primaryColor = Color(0xFF00BCD4);
static const Color secondaryColor = Color(0xFFFF5722);
```

### Changing API Base URL

Edit `lib/config/app_config.dart`:
```dart
static const String baseUrl = "YOUR_API_URL";
```

## Troubleshooting

### Cannot connect to API
- Check if backend is running
- Verify baseUrl configuration
- For emulator: use `10.0.2.2`
- For device: use computer's IP address (same WiFi network)

### Build errors
```bash
flutter clean
flutter pub get
flutter build apk
```

## Dependencies

Main dependencies:
- `provider` - State management
- `dio` - HTTP client
- `google_fonts` - Typography
- `cached_network_image` - Image caching
- `carousel_slider` - Image carousel
- `flutter_rating_bar` - Rating UI
- `flutter_secure_storage` - Secure storage

See `pubspec.yaml` for complete list.

## License

MIT

## Support

For issues and questions, please create an issue in the repository.
