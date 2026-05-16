# TSP Dashboard (Slow Pour)

Operational-first Flutter app for fast beverage cart order punching.

## Setup

1. Create platform scaffolding (if you didn’t already):

```bash
cd tsp_dashboard
flutter create .
```

2. Install packages:

```bash
flutter pub get
```

3. Configure Firebase (recommended):

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This generates Firebase options for your app. Make sure Firestore + Auth are enabled.

## Firestore collections used (current)

- `menuItems`
  - `name` (string)
  - `pricePaise` (number)
  - `category` (string)
  - `available` (bool)
- `orders`
- `balances/current`

