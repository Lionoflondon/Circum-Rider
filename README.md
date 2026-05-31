# Circum Rider

Flutter rider app for receiving and completing delivery requests from the
Circum customer app.

## Request Flow

- Riders go online from the home screen.
- The Circum customer app calls `sendPackage`, which broadcasts
  `broadcast-request` notifications to nearby online riders.
- The rider app refreshes available requests when a broadcast is received.
- Riders can accept, decline, start delivery, message the customer, and mark the
  delivery complete.

Rider-to-customer push updates now go through the backend callable
`sendRiderUpdate`. Deploy the matching Cloud Function from the Circum customer
backend before testing accept, location-broadcast, message, or completion flows.

## Run Locally

```sh
flutter pub get
flutter run
```

## Backend

Deploy Cloud Functions from the Circum customer app repository:

```sh
cd server/functions
npm install
firebase deploy --only functions
```

Never place Firebase Admin service-account JSON or private keys in the Flutter
client.
