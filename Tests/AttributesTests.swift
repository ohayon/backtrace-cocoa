import XCTest

import Nimble
import Quick
@testable import Backtrace

final class AttributesTests: QuickSpec {
    // swiftlint:disable function_body_length
    override func spec() {
        describe("Components") {
            it("sets processor info") {
                let attributes = ProcessorInfo()
                expect { attributes.mutable }.toNot(beNil())
                expect { attributes.immutable }.toNot(beNil())
            }
            it("sets device info") {
                let attributes = Device()
                expect { attributes.mutable }.toNot(beNil())
                expect { attributes.immutable }.toNot(beNil())
            }
            it("sets screen info") {
                let attributes = ScreenInfo()
                expect { attributes.mutable }.toNot(beNil())
                expect { attributes.immutable }.toNot(beNil())
            }
            it("sets locale info") {
                let attributes = LocaleInfo()
                expect { attributes.mutable }.toNot(beNil())
                expect { attributes.immutable }.toNot(beNil())
            }
            it("sets network info") {
                let attributes = NetworkInfo()
                expect { attributes.mutable }.toNot(beNil())
                expect { attributes.immutable }.toNot(beNil())
            }
            it("sets lib info") {
                let attributes = LibInfo()
                expect { attributes.mutable }.toNot(beNil())
                expect { attributes.immutable }.toNot(beNil())
            }
            it("sets location info") {
                let attributes = LocationInfo()
                expect { attributes.mutable }.toNot(beNil())
                expect { attributes.immutable }.toNot(beNil())
            }
        }

        describe("Processor Info") {
            it("can disable hostname") {
                let attributes = ProcessorInfo()
                let hostname = attributes.immutable["hostname"] as? String
                expect { hostname }.to(beEmpty())
            }
            it("can enable hostname") {
                let attributes = ProcessorInfo(reportHostName: true)
                let hostname = attributes.immutable["hostname"] as? String
                expect { hostname }.toNot(beEmpty())
            }
        }

        describe("Fault information") {
            it("can override fault information") {
                let oldAttributeValue = "a"
                let newAttributeValue = "b"
                let attributes = AttributesProvider()
                attributes.set(faultMessage: oldAttributeValue)
                attributes.set(faultMessage: newAttributeValue)
                expect{ attributes.allAttributes["error.message"] as? String}.to(equal(newAttributeValue))
            }
        }

        describe("Metrics Info") {
            it("will NOT set application.version and application.session if metrics attributes are NOT enabled") {
                let attributes = MetricsInfo()
                expect { attributes.immutable["application.version"]}.to(beNil())
                expect { attributes.immutable["application.session"]}.to(beNil())
            }

            it("will set application.version and application.session if metrics attributes are enabled") {
                let attributes = MetricsInfo()
                MetricsInfo.enableMetrics()
                expect { attributes.immutable["application.version"]}.toNot(beNil())
                expect { attributes.immutable["application.session"]}.toNot(beNil())
                MetricsInfo.disableMetrics()
            }
        }

        describe("Device") {
            it("will set uname.sysname correctly depending on platform") {
                let attributes = Device()
                guard let sysname = attributes.immutable["uname.sysname"] as? String else {
                    fail("could not parse uname.sysname")
                    return
                }
#if os(iOS)
                expect { sysname }.to(equal("iOS"))
#elseif os(tvOS)
                expect { sysname }.to(equal("tvOS"))
#elseif os(macOS)
                expect { sysname }.to(equal("macOS"))
#else
                fail("unsupported platform")
#endif
            }
        }

        describe("Attributes Provider") {
            it("will NOT set application.version and application.session if metrics attributes are NOT enabled") {
                let attributes = AttributesProvider()
                expect { attributes.allAttributes["application.version"]}.to(beNil())
                expect { attributes.allAttributes["application.session"]}.to(beNil())
            }

            it("will set application.version and application.session if metrics attributes are enabled") {
                MetricsInfo.enableMetrics()
                let attributes = AttributesProvider()
                expect { attributes.allAttributes["application.version"]}.toNot(beNil())
                expect { attributes.allAttributes["application.session"]}.toNot(beNil())
                MetricsInfo.disableMetrics()
            }
        }

        describe("Version Provider") {
            it("will find the framework version correctly") {
                let attributes = AttributesProvider()

                expect { attributes.allAttributes["lang.version"] as? String }.toNot(beNil())
                expect { attributes.allAttributes["backtrace.version"] as? String }.toNot(beNil())
            }
        }

        describe("C API") {
            it("sets vm_statistics64 information") {
                expect { try Statistics.vmStatistics64() }.toNot(beNil())
            }

            it("sets processor_set_load_info information") {
                expect { try Statistics.processorSetLoadInfo() }.toNot(beNil())
            }

            it("sets [host_cpu_load_info] information") {
                expect { try Statistics.hostCpuLoadInfo() }.toNot(beNil())
            }

            it("sets mach_task_basic_info information") {
                expect { try Statistics.machTaskBasicInfo() }.toNot(beNil())
            }

            it("sets task_vm_info information") {
                expect { try Statistics.taskVmInfo() }.toNot(beNil())
            }

            it("sets task_events_info information") {
                expect { try Statistics.taskEventsInfo() }.toNot(beNil())
            }

            it("sets boottime information") {
                expect { try System.boottime() }.toNot(equal(0))
            }

            it("sets uptime information") {
                expect { try System.uptime() }.toNot(equal(0))
            }

            it("sets machine name information") {
                expect { try System.machine() }.toNot(beEmpty())
            }

            it("sets model name information") {
                expect { try System.model() }.toNot(beEmpty())
            }

            it("sets process start time information") {
                expect { try ProcessInfo.startTime() }.toNot(equal(0))
            }

            it("sets process age information") {
                expect {
                    sleep(1)
                    return try ProcessInfo.age()
                }.toNot(equal(0))
            }

            it("sets number of threads information") {
                expect { try ProcessInfo.numberOfThreads() }.toNot(equal(0))
            }
        }
    }
    // swiftlint:enable function_body_length
}
