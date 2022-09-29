//
//  BacktraceCrashLoopDetector.swift
//  Backtrace
//

import Foundation

@objc public class BacktraceCrashLoopDetector: NSObject {
        
    internal struct StartUpEvent: Codable {
        var timestamp: Double
        var isSuccessful: Bool
    }
    
    @objc private static let plistKey = "CrashLoopDB"
    @objc internal static let consecutiveCrashesThreshold = 5
    @objc internal var consecutiveCrashesCount = 0

    @objc private var threshold = consecutiveCrashesThreshold
    
    internal var startupEvents: [StartUpEvent] = []
    
    @objc internal func updateThreshold(_ threshold: Int) {
        self.threshold = threshold == 0 ? BacktraceCrashLoopDetector.consecutiveCrashesThreshold : threshold
    }
    
    @objc private func loadEvents() {
        
        // Cleanup old events - f.e, for multiple usages of detector
        startupEvents.removeAll()
        
        /*
         - Since detector's DB is relatively small, UserDefaults are a good option here,
         plus they allow to avoid a headache with reading/writing to/from the custom file.

         - But we should consider shared computers as well - comment from UserDefaults docs:
            With the exception of managed devices in educational institutions,
            a user’s defaults are stored locally on a single device,
            and persisted for backup and restore.
            To synchronize preferences and other data across a user’s connected devices,
            use NSUbiquitousKeyValueStore instead.
         */
        guard let data = UserDefaults.standard.object(forKey: BacktraceCrashLoopDetector.plistKey) as? Data
        else { return }

        guard let array = try? PropertyListDecoder().decode([StartUpEvent].self, from: data)
        else { return }
                
        startupEvents.append(contentsOf: array)
        print("Events Loaded: \(startupEvents.count)")
    }
    
    @objc internal func saveEvents() {
        let data = try? PropertyListEncoder().encode(startupEvents)
        UserDefaults.standard.set(data, forKey: BacktraceCrashLoopDetector.plistKey)
        print("Events Saved: \(startupEvents.count)")
    }

    @objc private func reportFilePath() -> String {
        let bundleIDBT = Bundle.main.bundleIdentifier ?? ""
        let appIDPath = bundleIDBT.replacingOccurrences(of: "/", with: "_")

        let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
        let cacheDir = URL(fileURLWithPath: paths.count > 0 ? paths[0] : "")

        let bundleIDPLCR = "com.plausiblelabs.crashreporter.data"
        let crashReportDir = cacheDir.appendingPathComponent(bundleIDPLCR).appendingPathComponent(appIDPath)

        let reportName = "live_report.plcrash"
        let reportFullPath = crashReportDir.appendingPathComponent(reportName).absoluteString.replacingOccurrences(of: "file://", with: "")
        print("reportFullPath: \(reportFullPath)")
        return reportFullPath
    }
    
    @objc private func hasCrashReport() -> Bool {
        let exists = FileManager.default.fileExists(atPath: reportFilePath())
        return exists
    }
    
    @objc private func addCurrentEvent() {
        
        var event = StartUpEvent(timestamp: Double(Date.timeIntervalSinceReferenceDate), isSuccessful: true)
        event.isSuccessful = !hasCrashReport()
        print("New Event: {timestamp:\(event.timestamp)--successful:\(event.isSuccessful)}")

        startupEvents.append(event)
        
        if startupEvents.count > BacktraceCrashLoopDetector.consecutiveCrashesThreshold {
            startupEvents.remove(at: 0)
        }

        print("Event Added: \(startupEvents.count)")
    }

    @objc private func badEventsCount() -> Int {
        
        var badEventsCount = 0
        for event in startupEvents {
            badEventsCount += (event.isSuccessful ? 0 : 1)
        }
        self.consecutiveCrashesCount = badEventsCount
        print("Bad Events Count: \(badEventsCount)")
        return badEventsCount
    }
    
    @objc func detectCrashloop() -> Bool {

        print("Starting Crash Loop Detection")
        
        loadEvents()

        addCurrentEvent()
        
        let count = badEventsCount()
        saveEvents()

        // true -> crash loop detected -> set safe mode
        // false -> crash loop NOT detected -> set normal mode
        let result = count >= BacktraceCrashLoopDetector.consecutiveCrashesThreshold
        print("Finishing Crash Loop Detection: \(result)")
        return result
    }
    
    @objc func deleteCrashReport() {
        let path = reportFilePath()
        let fileURL = URL(fileURLWithPath: path)
        try? FileManager.default.removeItem(at: fileURL)
        
        startupEvents.removeAll()
        saveEvents()
    }
    
//    
//    @objc func consecutiveCrashesCount() -> Int {
//        return self.consecutiveCrashesCount
//    }
}
