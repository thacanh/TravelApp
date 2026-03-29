# Quick Start Scripts

## Backend

### Setup (chạy 1 lần đầu)
```bash
cd backend
setup.bat
```

### Start Server
```bash
cd backend
start.bat
```

Hoặc thủ công:
```bash
cd backend
venv\Scripts\activate
uvicorn app.main:app --reload
```

### Seed Sample Data
```bash
cd backend
venv\Scripts\activate
python seed_data.py
```

## Mobile

### Run on Emulator/Device
```bash
cd mobile
flutter run
```

### Build APK
```bash
cd mobile
build_apk.bat
```

Hoặc thủ công:
```bash
cd mobile
flutter build apk --release
```

APK sẽ được tạo tại: `build\app\outputs\flutter-apk\app-release.apk`

## Test Flow

1. **Start Backend**:
   ```bash
   cd backend
   start.bat
   ```

2. **Open API Docs**: http://localhost:8000/docs

3. **Run Mobile App**:
   ```bash
   cd mobile
   flutter run
   ```

4. **Login với test account**:
   - Email: `user@test.com`
   - Password: `user123`

## Troubleshooting

### Backend won't start
- Check if PostgreSQL is running
- Verify `.env` file exists and DATABASE_URL is correct
- Try: `pip install -r requirements.txt`

### Mobile can't connect to API
- For emulator: Use `baseUrl = "http://10.0.2.2:8000"`
- For device: Use your computer's IP address
- Make sure backend is running
- Check firewall settings

### Build APK fails
```bash
flutter clean
flutter pub get
flutter build apk --release
```

## Production Deployment

### Backend
```bash
# Install gunicorn
pip install gunicorn

# Run production server
gunicorn app.main:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000
```

### Mobile
1. Build release APK: `flutter build apk --release`
2. Sign APK for Google Play Store
3. Upload to Play Console

## Environment Variables

### Backend (.env)
```
DATABASE_URL=postgresql://user:pass@localhost/trawime_db
SECRET_KEY=your-secret-key-here
ACCESS_TOKEN_EXPIRE_MINUTES=30
```

### Mobile (lib/config/app_config.dart)
```dart
static const String baseUrl = "http://10.0.2.2:8000"; // Emulator
// or
static const String baseUrl = "http://YOUR_IP:8000"; // Device
```

## Additional Commands

### Backend
```bash
# Create new migration
alembic revision --autogenerate -m "description"

# Apply migrations
alembic upgrade head

# Check API is running
curl http://localhost:8000/health
```

### Mobile
```bash
# Check Flutter doctor
flutter doctor

# Run on specific device
flutter devices
flutter run -d DEVICE_ID

# Build for different modes
flutter build apk --debug
flutter build apk --profile
flutter build apk --release
```
