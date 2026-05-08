# Diary Client [![Tests](https://github.com/pyprism/Diary-Client/actions/workflows/tests.yaml/badge.svg)](https://github.com/pyprism/Diary-Client/actions/workflows/tests.yaml) [![codecov](https://codecov.io/gh/pyprism/Diary-Client/graph/badge.svg?token=nWTJP78beD)](https://codecov.io/gh/pyprism/Diary-Client)

An offline first diary application built with Flutter, featuring rich text editing and cross-platform support for Android and Web.

### Note: This project currently holds client side code only. The server side repository is: [Diary](https://github.com/pyprism/Diary)

## Features

- **Offline-First**: Local database with Drift for persistent storage
- **Rich Text Editing**: Full featured editor with Flutter Quill
- **Image Management**: Upload and manage images within diary entries
- **Tag System**: Organize entries with custom tags
- **Cross-Platform**: Android and Web support
- **State Management**: Riverpod for reactive state
- **Authentication**: User authentication system
- **Analysis Features**: Data insights and analytics
- **Share Functionality**: Share entries via various platforms

## Prerequisites

- Flutter SDK (v3.11.5 or higher)
- Dart SDK (v3.11.5 or higher)
- Android Studio (for Android development)
- Ansible (for deployment)
- Electricity (for getting shocked by the power of Flutter)

## Installation

1. Clone the repository:
```bash
git clone git@github.com:pyprism/Diary-Client.git
cd Diary-Client
```

2. Install dependencies:
```bash
flutter pub get
```

3. Generate required files:
```bash
flutter packages pub run build_runner build --delete-conflicting-outputs
flutter packages pub run build_runner build --delete-conflicting-outputs
```

## Development

### Running the App

#### Android
```bash
flutter run
```

#### Web
```bash
flutter run -d web-server
```

#### Debug Mode
```bash
flutter run --debug
```

#### Release Mode (for testing)
```bash
flutter run --release
```

### Building for Production

#### Android APK
```bash
flutter build apk --split-per-abi
```

#### Web Build
```bash
flutter build web --release
```

### Code Generation

After making changes to models or database schemas, regenerate the necessary files:

```bash
flutter packages pub run build_runner build --delete-conflicting-outputs
```

### Linting

```bash
flutter analyze
flutter format .
```

## Testing

### Run All Tests
```bash
flutter test
```

### Run Tests with Coverage
```bash
flutter test --coverage
```

### Run Specific Test File
```bash
flutter test test/features/diary/diary_test.dart
```

## Deployment

### Prerequisites for Deployment

1. Install Ansible:
```bash
pip install ansible
```

2. Configure deployment settings:
```bash
cp deploy/ansible/deploy_config.yaml.example deploy/ansible/deploy_config.yaml
```

Edit `deploy_config.yaml` with your deployment settings.

### Deployment Commands

#### Automated Deployment (Recommended)

This script will:
1. Build the Flutter web app for production
2. Install required Ansible collections
3. Run the Ansible deployment playbook

#### Manual Deployment Steps

```bash
./deploy.sh
```
## License

This project is licensed under the MIT License.

## Icon Credit

Journal icons created by Freepik - Flaticon
[https://www.flaticon.com/free-icon/notebook_8005831](https://www.flaticon.com/free-icon/notebook_8005831)
