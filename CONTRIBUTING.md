# Contributing to Routeva

Thank you for helping improve Routeva.

1. Open an issue before a large behavioral or architecture change.
2. Fork the repository and work from the latest `main`.
3. Keep iOS changes under `app/ios` unless the change is specifically about
   another product-workspace area.
4. Never commit subscriptions, node credentials, certificates, provisioning
   profiles, signing keys, App Store credentials, archives, or build caches.
5. Run:

   ```sh
   cd app/ios
   swift test
   ./Scripts/audit-public-source.sh
   ```

6. Explain user impact, tests, and any dependency or license change in the pull
   request.

By contributing, you agree that your contribution is licensed under
GPL-3.0-or-later.
