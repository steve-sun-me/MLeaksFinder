import Foundation

@objc
public protocol MLeaksFinderLoggerType {
    func log(_ title: String, _ message: String)
}

@objc
public final class MLeaksFinderLogger: NSObject, MLeaksFinderLoggerType {
    public func log(_ title: String, _ message: String) {
        print("-------------------------------")
        print(title)
        print("-------------------------------")
        print(message)
        print("-------------------------------")

        if MLeaksFinderRunTimeConfig.default.pauseExecutionEnabled {
            raise(SIGINT)
        }
    }
}
