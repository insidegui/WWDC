/// Represents one of several durations for skipping backwards and forwards.
public enum BackForwardSkipDuration: TimeInterval {
    case fiveSeconds = 5
    case tenSeconds = 10
    case fifteenSeconds = 15
    case thirtySeconds = 30
    
    public init(seconds: TimeInterval) {
        switch seconds {
        case 5:
            self = .fiveSeconds
        case 10:
            self = .tenSeconds
        case 15:
            self = .fifteenSeconds
        case 30:
            self = .thirtySeconds
        default:
            assertionFailure("Expected a duration of `BackForwardSkipDuration`; received \(seconds)")
            self = .thirtySeconds
        }
    }
}
