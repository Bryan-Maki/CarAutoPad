import Foundation

public enum TwilightState: Int, Equatable, Sendable {
    case day = 0
    case night = 1
}

public struct TwilightCalculator: Equatable, Sendable {
    public static let DAY = TwilightState.day
    public static let NIGHT = TwilightState.night

    public static let utc2000: Int64 = 946_728_000_000

    public static let altitudeCorrectionEarlyNight: Double = 0.017453293

    private static let degToRad: Double = Double.pi / 180.0
    private static let radToDeg: Double = 180.0 / Double.pi

    public let sunrise: Int64
    public let sunset: Int64
    public let state: TwilightState

    public init(sunrise: Int64, sunset: Int64, state: TwilightState) {
        self.sunrise = sunrise
        self.sunset = sunset
        self.state = state
    }

    public static func calculateTwilight(
        timeMillis: Int64,
        latitude: Double,
        longitude: Double,
        altitudeCorrection: Double = altitudeCorrectionEarlyNight
    ) -> TwilightCalculator {
        let daysSince2000 = Double(timeMillis - utc2000) / 86_400_000.0

        let meanAnomaly = 6.240059968 + daysSince2000 * 0.01720197

        let trueAnomaly = meanAnomaly
            + 0.0334196 * sin(meanAnomaly)
            + 0.000349066 * sin(2.0 * meanAnomaly)
            + 0.000005236 * sin(3.0 * meanAnomaly)

        let solarLng = trueAnomaly + 1.796593063 + Double.pi

        let arcLongitude = -longitude / 360.0
        let n = (daysSince2000 - 0.0009 - arcLongitude).rounded()
        let solarTransitJ2000 = n + 0.0009 + arcLongitude
            + 0.0053 * sin(meanAnomaly)
            - 0.0069 * sin(2.0 * solarLng)

        let solarDec = asin(sin(solarLng) * sin(0.40927971))

        let latRad = latitude * degToRad
        let cosHourAngle = (sin(altitudeCorrection) - sin(latRad) * sin(solarDec)) / (cos(latRad) * cos(solarDec))

        if cosHourAngle >= 1.0 {
            return TwilightCalculator(sunrise: -1, sunset: -1, state: .night)
        } else if cosHourAngle <= -1.0 {
            return TwilightCalculator(sunrise: -1, sunset: -1, state: .day)
        }

        let hourAngle = acos(cosHourAngle) / (2.0 * Double.pi)
        let sunset = Int64(((solarTransitJ2000 + hourAngle) * 86_400_000.0).rounded()) + utc2000
        let sunrise = Int64(((solarTransitJ2000 - hourAngle) * 86_400_000.0).rounded()) + utc2000

        let state: TwilightState = (sunrise < timeMillis && sunset > timeMillis) ? .day : .night
        return TwilightCalculator(sunrise: sunrise, sunset: sunset, state: state)
    }

    public static func isNight(
        date: Date = Date(),
        latitude: Double? = nil,
        longitude: Double? = nil,
        timeZone: TimeZone = .current
    ) -> Bool {
        let lat: Double
        let lon: Double
        if let userLat = latitude, let userLon = longitude {
            lat = userLat
            lon = userLon
        } else {
            let tzSeconds = Double(timeZone.secondsFromGMT(for: date))
            lon = (tzSeconds / 3600.0) * 15.0
            lat = 30.0
        }

        let timeMillis = Int64(date.timeIntervalSince1970 * 1000)
        let calc = calculateTwilight(timeMillis: timeMillis, latitude: lat, longitude: lon)
        return calc.state == .night
    }
}
