import Foundation

@objc
public final class MLeaksFinderRunTimeConfig: NSObject {
    @objc(defaultConfig)
    static public let `default` = MLeaksFinderRunTimeConfig()

    @objc public var leaksFinderReportEnabled: Bool = false

    @objc public var pauseExecutionEnabled: Bool = true

    private override init() {
        super.init()
    }
}
