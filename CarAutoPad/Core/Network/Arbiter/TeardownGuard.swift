import Foundation

public enum TeardownGuard {
    public static func runThenClose(
        teardown: () throws -> Void,
        close: () throws -> Void,
        onError: ((String, Error) -> Void)? = nil
    ) {
        do {
            try teardown()
        } catch {
            onError?("teardown", error)
        }

        do {
            try close()
        } catch {
            onError?("close", error)
        }
    }
}
