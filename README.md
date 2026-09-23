# Flutter Budget

A local-first Flutter Web/PWA personal budget app with a VS Code-inspired dark UI.

## Features
- Dynamic budget month (rolls on the 22nd)
- Budget and Paid tables with totals
- Check an item to move it to Paid
- Uncheck/remove from Paid to move it back
- Add/delete budget items
- Local persistence in SharedPreferences
- Monthly history stored locally and exportable as a text file
- Responsive desktop/mobile layout and installable Flutter web PWA

## Run
```bash
flutter pub get
flutter run -d chrome
```

## Build PWA
```bash
flutter build web --release
```

The browser cannot silently write arbitrary files to your disk. Monthly history is therefore persisted in browser storage and can be exported as a .txt file from the History dialog.
