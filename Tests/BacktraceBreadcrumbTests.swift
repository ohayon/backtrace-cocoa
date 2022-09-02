// swiftlint:disable function_body_length

import XCTest
import Nimble
import Quick

@testable import Backtrace

/** Module test, not unit test. Tests the entire breadcrumbs module */
final class BacktraceBreadcrumbTests: QuickSpec {

    let breadcrumbLogFileName = "bt-breadcrumbs-0"

    func breadcrumbLogPath(_ create: Bool) throws -> String {
        var fileURL = try FileManager.default.url(for: .documentDirectory,
                                                  in: .userDomainMask,
                                                  appropriateFor: nil,
                                                  create: create)
        fileURL.appendPathComponent(breadcrumbLogFileName)
        return fileURL.path
    }

    func readBreadcrumbText() -> String? {
        do {
            let path = try breadcrumbLogPath(true)
            let fileURL = URL(fileURLWithPath: path)
            let content = try String(contentsOf: fileURL, encoding: .ascii)
            return content
        } catch {
            return nil
        }
    }

    override func spec() {
        describe("BreadcrumbsLogManager") {
            var manager: BacktraceBreadcrumbsLogManager?
            beforeEach {
                do {
                    let setting = BacktraceBreadcrumbSettings(maxQueueFileSizeBytes: 8192)
                    try manager = BacktraceBreadcrumbsLogManager(breadcrumbSettings: setting)
                    _ = manager?.clear()
                } catch {
                    fail("\(error.localizedDescription)")
                }
            }
            context("when constructed") {
                it("Clear clears the file") {
                    expect { manager?.addBreadcrumb("this is a Breadcrumb",
                                                    attributes: nil,
                                                    type: BacktraceBreadcrumbType.system,
                                                    level: BacktraceBreadcrumbLevel.debug)}.to(beTrue())

                    expect { self.readBreadcrumbText() }.to(contain("this is a Breadcrumb"))

                    expect { manager?.clear() }.to(beTrue())

                    expect { self.readBreadcrumbText() }.toNot(contain("this is a Breadcrumb"))

                    expect { manager?.addBreadcrumb("this is a Breadcrumb",
                                                    attributes: nil,
                                                    type: BacktraceBreadcrumbType.system,
                                                    level: BacktraceBreadcrumbLevel.debug)}.to(beTrue())

                    expect { self.readBreadcrumbText() }.to(contain("this is a Breadcrumb"))
                }
            }
        }
        describe("BacktraceBreadcrumbs") {
            let breadcrumbs = BacktraceBreadcrumbs()

            afterEach {
                _ = breadcrumbs.clear()
                breadcrumbs.disableBreadcrumbs()
            }
            context("breadcrumbs are not enabled") {
                it("fails to add breadcrumb") {
                    breadcrumbs.disableBreadcrumbs()
                    expect { breadcrumbs.isBreadcrumbsEnabled }.to(beFalse())
                    expect { breadcrumbs.getCurrentBreadcrumbId }.to(beNil())
                    expect { breadcrumbs.addBreadcrumb("Breadcrumb submit test") }.to(beFalse())
                    expect { self.readBreadcrumbText() }.toNot(contain("Breadcrumb submit test"))
                }
            }
            context("breadcrumbs are enabled") {
                it("fails to add breadcrumb for lower breadcrumb level") {
                    breadcrumbs.enableBreadcrumbs(BacktraceBreadcrumbSettings(breadcrumbLevel: BacktraceBreadcrumbLevel.error))
                    expect { breadcrumbs.allowBreadcrumbsToAdd(.info) }.to(beFalse())
                    expect { breadcrumbs.addBreadcrumb("Info Breadcrumb", level: .info) }.to(beFalse())
                    expect { self.readBreadcrumbText() }.toNot(contain("Info Breadcrumb"))
                }
                it("able to add breadcrumb for higher breadcrumb level") {
                    breadcrumbs.enableBreadcrumbs(BacktraceBreadcrumbSettings(breadcrumbLevel: BacktraceBreadcrumbLevel.error))
                    expect { breadcrumbs.allowBreadcrumbsToAdd(.fatal) }.to(beTrue())
                    expect { breadcrumbs.addBreadcrumb("Fatal Breadcrumb", level: .fatal) }.to(beTrue())
                    let breadcrumbText = self.readBreadcrumbText()
                    expect { breadcrumbText }.toNot(beNil())
                    expect { breadcrumbText }.to(contain("Fatal Breadcrumb"))
                    expect { breadcrumbText }.to(contain("\"level\":\"fatal\""))
                }
                it("Able to add breadcrumbs and they are all added to the breadcrumb file without overflowing") {
                    breadcrumbs.enableBreadcrumbs()
                    expect { breadcrumbs.isBreadcrumbsEnabled }.to(beTrue())
                    expect { BreadcrumbsInfo.currentBreadcrumbsId }.toNot(beNil())
                    expect { breadcrumbs.getCurrentBreadcrumbId }.toNot(beNil())
                    expect { BreadcrumbsInfo.currentBreadcrumbsId }.to(equal(breadcrumbs.getCurrentBreadcrumbId))

                    //  50 iterations won't overflow the file yet
                    for index in 0...50 {
                        expect { breadcrumbs.addBreadcrumb("this is Breadcrumb number \(index)") }.to(beTrue())
                    }

                    let breadcrumbText = self.readBreadcrumbText()
                    for index in 0...50 {
                        expect { breadcrumbText }.to(contain("this is Breadcrumb number \(index)"))
                    }
                }
                it("Able to add breadcrumbs with all possible options (level, type, attributes)") {
                    breadcrumbs.enableBreadcrumbs()

                    expect { breadcrumbs.addBreadcrumb("this is a Breadcrumb ",
                                                       attributes: ["a": "b", "c": "1"],
                                                       type: .navigation,
                                                       level: .fatal) }.to(beTrue())

                    let breadcrumbText = self.readBreadcrumbText()
                    expect { breadcrumbText }.to(contain("this is a Breadcrumb"))
                    expect { breadcrumbText }.to(contain("\"type\":\"navigation\""))
                    expect { breadcrumbText }.to(contain("\"level\":\"fatal\""))
                    expect { breadcrumbText }.to(contain("\"attributes\":{"))
                    expect { breadcrumbText }.to(contain("\"a\":\"b\""))
                    expect { breadcrumbText }.to(contain("\"c\":\"1\""))
                }
                it("Too long breadcrumb (>4kB) gets rejected") {
                    breadcrumbs.enableBreadcrumbs()

                    var text = "this is a Breadcrumb"
                    while text.utf8.count < 4096 {
                        text += text
                    }

                    expect { breadcrumbs.addBreadcrumb(text)}.to(beFalse())

                    let breadcrumbText = self.readBreadcrumbText()
                    expect { breadcrumbText }.notTo(contain("this is a Breadcrumb"))
                }
                it("Again disable breadcrumb") {
                    breadcrumbs.disableBreadcrumbs()
                    expect { breadcrumbs.isBreadcrumbsEnabled }.to(beFalse())
                    expect { breadcrumbs.getCurrentBreadcrumbId }.to(beNil())
                }
            }
            context("rollover and async tests") {
                it("rolls over after enough breadcrumbs are added to get to the maximum file size") {
                    let settings = BacktraceBreadcrumbSettings()
                    settings.maxQueueFileSizeBytes = 32 * 1024
                    breadcrumbs.enableBreadcrumbs(settings)

                    let group = DispatchGroup()

                    // intentionally write over allowed bytes, causing the file to overflow and rotate
                    var writeIndex = 0
                    while writeIndex < 1000 {
                        let text = "this is Breadcrumb number \(writeIndex)"
                        // submit a task to the queue for background execution
                        DispatchQueue.global().async(group: group, execute: {
                            expect { breadcrumbs.addBreadcrumb(text) }.to(beTrue())
                        })
                        writeIndex += 1
                    }

                    group.wait()

                    let breadcrumbText = self.readBreadcrumbText()!

                    // Not very scientific, but this is apparently when the file wraps
                    #if canImport(Cassette)
                    let wrapIndex = 742
                    #else
                    let wrapIndex = 733
                    #endif
                    for readIndex in 0...wrapIndex {
                        // should have been rolled away
                        expect { breadcrumbText }.toNot(contain("\"this is Breadcrumb number \(readIndex)\""))
                    }

                    var matches = 0
                    if writeIndex < wrapIndex {
                        fail("\(writeIndex) is smaller than \(wrapIndex)")
                    } else {
                        for readIndex in wrapIndex...writeIndex {
                            let match = breadcrumbText.contains("\"this is Breadcrumb number \(readIndex)\"")
                            if match {
                                matches += 1
                            }
                        }

                        // Why the - 1?
                        // Because one line is liable to get mangled by the wrapping - half will
                        // be at the bottom and half at the top of the circular file.
                        // Currently, we accept we lose this Breadcrumb in the UI - it will still be in the file
                        // for manual inspection.
                        let expectedNumberOfMatches = writeIndex - wrapIndex - 1
                        expect(matches).to(beGreaterThanOrEqualTo(expectedNumberOfMatches),
                                           description: "Not enough (\(matches) out of \(expectedNumberOfMatches)) " +
                                           "breadcrumb matches found in breadcrumbs file: \n\(breadcrumbText)")

                        let attr = try FileManager.default.attributesOfItem(atPath: self.breadcrumbLogPath(false))
                        let fileSize = attr[FileAttributeKey.size] as? Int
                        let requestedSize = settings.maxQueueFileSizeBytes
                        expect { fileSize }.to(beLessThanOrEqualTo(requestedSize))
                        expect { fileSize }.to(beGreaterThanOrEqualTo(requestedSize - 1000))
                    }
                }
            }
        }
        describe("BacktraceNotificationObserver") {
            let backtraceBreadcrumbs = BacktraceBreadcrumbs()

            afterEach {
                _ = backtraceBreadcrumbs.clear()
                backtraceBreadcrumbs.disableBreadcrumbs()
            }
            context("when notifications are enabled") {
                it("notification startObserving called for each observer") {
                    let backtraceObserverMock1 = BacktraceObserverMock()
                    let backtraceObserverMock2 = BacktraceObserverMock()
                    BacktraceNotificationObserver(breadcrumbs: backtraceBreadcrumbs, handlerDelegates: [
                        backtraceObserverMock1,
                        backtraceObserverMock2]).enableNotificationObserver()

                    expect { backtraceObserverMock1.startObservingCalled }.to(beTrue())
                    expect { backtraceObserverMock2.startObservingCalled }.to(beTrue())
                }
            }

#if os(iOS) || os(tvOS)
            context("when iOS/tvOS notifications update") {
                it("iOS/tvOS memory warning breadcrumb added") {
                    backtraceBreadcrumbs.enableBreadcrumbs()

                    // Simulate memory event:
                    // https://stackoverflow.com/questions/4717138/ios-development-how-can-i-induce-low-memory-warnings-on-device
                    // Can't seem to control much of the levels (warning vs fatal, etc), so we just test the warning level
                    UIControl().sendAction(Selector(("_performMemoryWarning")), to: UIApplication.shared, for: nil)

                    expect { self.readBreadcrumbText() }.toEventually(contain("Warning level memory pressure event"))
                }
            }
#endif
#if os(iOS)
            context("when iOS notifications update") {
                it("iOS orientation breadcrumb added") {
                    backtraceBreadcrumbs.enableBreadcrumbs()

                    class OverriddenOrientationNotificationObsrvr: BacktraceOrientationNotificationObserver {
                        var mockOrientation: UIDeviceOrientation?

                        override var orientation: UIDeviceOrientation { mockOrientation ?? super.orientation }
                    }

                    let backtraceObserver = OverriddenOrientationNotificationObsrvr()

                    let backtraceNotificationObserver = BacktraceNotificationObserver(breadcrumbs: backtraceBreadcrumbs,
                                                  handlerDelegates: [backtraceObserver])
                    backtraceNotificationObserver.enableNotificationObserver()

                    NotificationCenter.default.post(name: UIDevice.orientationDidChangeNotification,
                                                    object: nil)

                    expect { self.readBreadcrumbText() }.toNot(contain("Orientation changed"))

                    backtraceObserver.mockOrientation = UIDeviceOrientation.landscapeLeft
                    NotificationCenter.default.post(name: UIDevice.orientationDidChangeNotification,
                                                    object: nil)

                    expect { self.readBreadcrumbText() }.to(contain("Orientation changed"))
                    expect { self.readBreadcrumbText() }.to(contain("\"orientation\":\"landscape\""))

                    backtraceObserver.mockOrientation = UIDeviceOrientation.portraitUpsideDown
                    NotificationCenter.default.post(name: UIDevice.orientationDidChangeNotification,
                                                    object: nil)

                    expect { self.readBreadcrumbText() }.to(contain("\"orientation\":\"portrait\""))
                }

                it("iOS battery state breadcrumb added") {
                    // On simulator, we don't expected an actual batteryLevel according to:
                    // https://stackoverflow.com/questions/11801523/ios-how-to-get-correctly-battery-level
                    // So, override and set it manually
                    class OverriddenBatteryNotificationObserver: BacktraceBatteryNotificationObserver {
                        var mockBatteryLevel: Float?
                        var mockBatteryState: UIDevice.BatteryState?

                        override var batteryLevel: Float { mockBatteryLevel ?? super.batteryLevel }
                        override var batteryState: UIDevice.BatteryState { mockBatteryState ?? super.batteryState }
                    }

                    let backtraceObserver = OverriddenBatteryNotificationObserver()

                    backtraceBreadcrumbs.enableBreadcrumbs()

                    let backtraceNotificationObserver = BacktraceNotificationObserver(breadcrumbs: backtraceBreadcrumbs,
                                                  handlerDelegates: [backtraceObserver])
                    backtraceNotificationObserver.enableNotificationObserver()

                    NotificationCenter.default.post(name: UIDevice.batteryLevelDidChangeNotification,
                                                    object: nil)
                    expect { self.readBreadcrumbText() }.to(contain("Unknown battery level"))

                    backtraceObserver.mockBatteryLevel = 0.25
                    backtraceObserver.mockBatteryState = UIDevice.BatteryState.charging
                    NotificationCenter.default.post(name: UIDevice.batteryLevelDidChangeNotification,
                                                    object: nil)
                    expect { self.readBreadcrumbText() }.to(contain("Charging battery level: 25.0%"))

                    backtraceObserver.mockBatteryLevel = 0.5
                    backtraceObserver.mockBatteryState = UIDevice.BatteryState.unplugged
                    NotificationCenter.default.post(name: UIDevice.batteryLevelDidChangeNotification,
                                                    object: nil)
                    expect { self.readBreadcrumbText() }.to(contain("Unplugged battery level: 50.0%"))

                    backtraceObserver.mockBatteryLevel = 1
                    backtraceObserver.mockBatteryState = UIDevice.BatteryState.full
                    NotificationCenter.default.post(name: UIDevice.batteryLevelDidChangeNotification,
                                                    object: nil)
                    expect { self.readBreadcrumbText() }.to(contain("Full battery level: 100.0%"))
                }

                it("iOS app state breadcrumb added") {
                    backtraceBreadcrumbs.enableBreadcrumbs()

                    NotificationCenter.default.post(name: Application.willEnterForegroundNotification,
                                                    object: nil)

                    expect { self.readBreadcrumbText() }.to(contain("Application will enter in foreground"))

                    NotificationCenter.default.post(name: Application.didEnterBackgroundNotification,
                                                    object: nil)

                    expect { self.readBreadcrumbText() }.to(contain("Application did enter in background"))
                }
            }
#elseif os(macOS)
            context("when macOS notifications update") {

                it("macOS memory warning breadcrumb added") {

                    class OverriddenMemoryNotificationObserver: BacktraceMemoryNotificationObserver {
                        var mockMemoryPressureEvent: DispatchSource.MemoryPressureEvent?

                        override var memoryPressureEvent: DispatchSource.MemoryPressureEvent? {
                            mockMemoryPressureEvent ?? super.memoryPressureEvent
                        }
                    }

                    let backtraceObserver = OverriddenMemoryNotificationObserver()

                    backtraceBreadcrumbs.enableBreadcrumbs()

                    let backtraceNotificationObserver = BacktraceNotificationObserver(breadcrumbs: backtraceBreadcrumbs,
                                                  handlerDelegates: [backtraceObserver])
                    backtraceNotificationObserver.enableNotificationObserver()

                    backtraceObserver.mockMemoryPressureEvent = .warning
                    backtraceObserver.memoryPressureEventHandler()

                    expect { self.readBreadcrumbText() }.toEventually(contain("Warning level memory pressure event"))

                    backtraceObserver.mockMemoryPressureEvent = .critical
                    backtraceObserver.memoryPressureEventHandler()

                    expect { self.readBreadcrumbText() }.toEventually(contain("Critical level memory pressure event"))
                }

                it("macOS battery state breadcrumb added") {
                    class OverriddenBatteryNotificationObserver: BacktraceBatteryNotificationObserver {

                        var isMockCharging: Bool?
                        var mockBatteryLevel: Int?

                        override var isCharging: Bool? {
                            return isMockCharging ?? super.isCharging
                        }

                        override var batteryLevel: Int? {
                            return mockBatteryLevel ?? super.batteryLevel
                        }
                    }

                    let backtraceObserver = OverriddenBatteryNotificationObserver()

                    backtraceBreadcrumbs.enableBreadcrumbs()

                    let backtraceNotificationObserver = BacktraceNotificationObserver(breadcrumbs: backtraceBreadcrumbs,
                                                  handlerDelegates: [backtraceObserver])
                    backtraceNotificationObserver.enableNotificationObserver()

                    backtraceObserver.isMockCharging = true
                    backtraceObserver.mockBatteryLevel = 50
                    backtraceObserver.powerSourceChanged()

                    expect { self.readBreadcrumbText() }.toEventually(contain("charging battery level : 50%"))

                    backtraceObserver.isMockCharging = false
                    backtraceObserver.mockBatteryLevel = 74
                    backtraceObserver.powerSourceChanged()

                    expect { self.readBreadcrumbText() }.toEventually(contain("unplugged battery level : 74%"))
                }
            }
#endif
        }
    }
}
