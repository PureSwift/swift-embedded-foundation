//
//  ASCII.swift
//  FoundationEmbedded
//
//  Shared ASCII digit formatting for the date/time format styles.
//
//  The format styles build their output into a single caller-owned `[UInt8]`
//  that is decoded to a `String` once, instead of concatenating an
//  intermediate `String` per field. Concatenation cost grows with the number
//  of fields, and on a target without an allocator to spare it is the
//  difference between one buffer and a dozen transient strings.
//

/// The widest decimal representation of an `Int`, including a sign.
private let maximumDecimalWidth = 20

enum ASCII {

    /// Appends `value`'s decimal representation to `output`, zero-padded on the
    /// left to at least `width` bytes.
    ///
    /// - Note: Padding is applied to the whole representation, so a negative
    ///   value pads ahead of its own sign (`-5` at width 4 is `00-5`). That is
    ///   what the string-concatenation implementation this replaced produced;
    ///   the callers here only ever format non-negative fields.
    static func appendPadded(_ value: Int, width: Int, to output: inout [UInt8]) {
        withUnsafeTemporaryAllocation(of: UInt8.self, capacity: maximumDecimalWidth) { scratch in
            // Digits are generated least-significant first, so fill from the back.
            var start = maximumDecimalWidth
            var magnitude = value.magnitude
            repeat {
                start -= 1
                scratch[start] = UInt8(ascii: "0") + UInt8(magnitude % 10)
                magnitude /= 10
            } while magnitude != 0
            if value < 0 {
                start -= 1
                scratch[start] = UInt8(ascii: "-")
            }

            let written = maximumDecimalWidth - start
            if written < width {
                output.append(contentsOf: repeatElement(UInt8(ascii: "0"), count: width - written))
            }
            output.append(contentsOf: UnsafeBufferPointer(rebasing: scratch[start...]))
        }
    }
}
