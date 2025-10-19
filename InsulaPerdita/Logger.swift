import Foundation

class Logger {
    static let shared = Logger()

    private init() {}

    enum Event: String {
        // Tabs
        case tabChanged = "Tab Changed"
        case tabChangeSuppressed = "Tab Change Suppressed" // NEW: used when rapid/burst navigation is ignored

        // Hub View
        case settingsButtonTapped = "Settings Button Tapped"
        case addMenuTapped = "Add Menu Tapped"
        case addInjectionTapped = "Add Injection Tapped"
        case addActivityTapped = "Add Activity Tapped"
        case manualGlucoseEntered = "Manual Glucose Entered"
        case trendChanged = "Trend Changed"

        // Injection Sheet
        case injectionDoseAdjusted = "Injection Dose Adjusted"
        case saveInjectionTapped = "Save Injection Tapped"

        // Activities View
        case activitySelected = "Activity Selected"
        case activityTimeAdjusted = "Activity Time Adjusted"
        case saveActivityTapped = "Save Activity Tapped"

        // Settings
        case settingToggled = "Setting Toggled"
        case settingChanged = "Setting Changed" // granular value change logging

        // Histogram
        case histogramTimeRangeChanged = "Histogram Time Range Changed"
        case histogramRefreshed = "Histogram Refreshed"
        case histogramExported = "Histogram Exported"
        
        // NFC
        case nfcScanButtonTapped = "NFC Scan Button Tapped"
    }

    func log(_ event: Event, parameters: [String: Any]? = nil) {
        var logMessage = "[Analytics] Event: '\(event.rawValue)'"
        if let params = parameters, !params.isEmpty {
            let paramsString = params.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            logMessage += ", Parameters: [\(paramsString)]"
        }
        print(logMessage)
    }
}
