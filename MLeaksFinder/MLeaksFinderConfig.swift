import Foundation

@objc
public final class MLeaksFinderConfig: NSObject {
    @objc(defaultConfig)
    static public let `default` = MLeaksFinderConfig()

    @objc public var leaksFinderReportEnabled: Bool = false

    private override init() {
        super.init()
    }
}
