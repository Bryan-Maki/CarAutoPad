import Foundation

public enum ConnectionAdmission {
    public static func admits(inFlight: Bool, userInitiated: Bool) -> Bool {
        if !inFlight { return true }
        return userInitiated
    }
}
