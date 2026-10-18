import Foundation

public enum AapMessageFraming {
    public static let FLAG_BIT_FIRST: UInt8 = 0x01
    public static let FLAG_BIT_LAST: UInt8 = 0x02
    public static let FLAG_BIT_CONTROL: UInt8 = 0x04
    public static let FLAG_BIT_ENCRYPTED: UInt8 = 0x08

    public static func isLast(_ flags: UInt8) -> Bool {
        return (flags & FLAG_BIT_LAST) != 0
    }

    public static func isLast(flags: UInt8) -> Bool {
        return isLast(flags)
    }

    public static func isLast(flags: Int) -> Bool {
        return isLast(UInt8(flags & 0xFF))
    }

    public static func carriesTotalLength(_ flags: UInt8) -> Bool {
        return carriesMessageType(flags) && !isLast(flags)
    }

    public static func carriesMessageType(_ flags: UInt8) -> Bool {
        return (flags & FLAG_BIT_FIRST) != 0
    }

    public static func completesMediaData(type: Int, flags: UInt8) -> Bool {
        return type == 0 && isLast(flags)
    }

    public static func carriesTotalLength(flags: Int) -> Bool {
        return carriesTotalLength(UInt8(flags & 0xFF))
    }

    public static func carriesMessageType(flags: Int) -> Bool {
        return carriesMessageType(UInt8(flags & 0xFF))
    }
}
