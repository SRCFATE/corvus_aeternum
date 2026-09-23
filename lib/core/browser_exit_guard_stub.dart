class BrowserExitGuard {
  BrowserExitGuard(bool Function() hasPendingChanges);
  void dispose() {}
}
