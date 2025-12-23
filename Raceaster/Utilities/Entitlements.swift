// This file previously contained an `Entitlements` class used during development.
// Renamed to avoid type name collision with Ads/AdManager's `Entitlements`.
// App uses `AppEntitlements` (Utilities/AppEntitlements.swift) as the application-wide singleton.

final class LegacyEntitlements {
    // Placeholder for historical data or migration code if needed.
    static let shared = LegacyEntitlements()

    private init() {}
}
