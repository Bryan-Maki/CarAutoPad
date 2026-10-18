import Foundation

public enum AuditRecoveryPolicy {

    public static func shouldRequestKeyframe(outcome: FragmentedMessageAudit.Outcome, channel: Int) -> Bool {
        guard UInt8(channel) == Channel.ID_VID else { return false }
        switch outcome {
        case .deltaChanged, .orphanedFragment, .truncatedRun:
            return true
        }
    }

    public static func shouldDiscardAssembledUnit(result: FragmentedMessageAudit.AuditResult) -> Bool {
        return UInt8(result.channel) == Channel.ID_VID && result.outcome == .deltaChanged
    }
}
