import Foundation

/// Very lightweight placeholder decoder for FreeStyle Libre raw blocks.
/// Real decoding requires CRC checks, historical trend extraction, calibration, etc.
enum LibreSensorDecoder {
    static func decode(blocks: [Data]) -> SensorReading {
        // Naive placeholder: derive a pseudo glucose value from bytes of first few blocks.
        var bytes: [UInt8] = []
        for b in blocks.prefix(3) { bytes.append(contentsOf: b) }
        let sum = bytes.reduce(0) { $0 + Int($1) }
        // Produce a mmol/L-ish number in plausible range 3.0 - 18.0
        let glucose = Double((sum % 150) + 30) / 10.0
        return SensorReading(timestamp: Date(), glucose: glucose, rawBlocks: blocks)
    }
}
