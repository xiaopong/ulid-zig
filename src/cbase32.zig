const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const UlidConstants = @import("ulid_constants.zig");

/// Crockford Base32 encoder/decoder
pub const CBase32 = struct {
    const Self = @This();

    const bits_per_char = 5;
    const bits_per_byte = 8;

    // Crockford Base32 alphabet (with I, L, O, U excluded)
    const alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";
    const decode_map = initDecodeMap();

    fn initDecodeMap() [256]u8 {
        var map = [_]u8{0xFF} ** 256;

        // Build decode map from alphabet
        for (alphabet, 0..) |c, i| {
            map[c] = @as(u8, @intCast(i));
            // Handle lowercase
            if (c >= 'A' and c <= 'Z') {
                map[c + 32] = @as(u8, @intCast(i));
            }
        }

        // Handle common mistakable characters
        map['o'] = 0; // 'o' → '0'
        map['O'] = 0;
        map['i'] = 1; // 'i' → '1'
        map['I'] = 1;
        map['l'] = 1; // 'l' → '1'
        map['L'] = 1;
        map['u'] = 0xFF; // 'u' is excluded
        map['U'] = 0xFF;

        return map;
    }

    // Each 5-bit block is encoded via the alphabet by its corresponding character:
    // 00000	0	00001	1	00010	2	00011	3
    // 00100	4	00101	5	00110	6	00111	7
    // 01000	8	01001	9	01010	A	01011	B
    // 01100	C	01101	D	01110	E	01111	F
    // 10000	G	10001	H	10010	J	10011	K
    // 10100	M	10101	N	10110	P	10111	Q
    // 11000	R	11001	S	11010	T	11011	V
    // 11100	W	11101	X	11110	Y	11111	Z

    // Shared core encoding logic
    fn encodeInternal(input: []const u8, output: []u8) void {
        var buffer: u64 = 0;
        var bits_left: u6 = 0;
        var out_pos: usize = 0;

        for (input) |byte| {
            buffer = (buffer << bits_per_byte) | byte;
            bits_left += bits_per_byte;

            while (bits_left >= bits_per_char) {
                bits_left -= bits_per_char;
                const index = @as(u5, @truncate(buffer >> bits_left));
                output[out_pos] = alphabet[index];
                out_pos += 1;
            }
        }

        if (bits_left > 0) {
            const index = @as(u5, @truncate(buffer << (bits_per_char - bits_left)));
            output[out_pos] = alphabet[index];
        }
    }

    /// Decodes Crockford Base32 string to binary data
    pub fn decodeInternal(str: []const u8, output: []u8) !void {
        var buffer: u16 = 0;
        var bits_left: u4 = 0;
        var out_idx: usize = 0;

        for (str) |c| {
            const value = decode_map[c];
            if (value == 0xFF) return error.InvalidCharacter;

            buffer = (buffer << bits_per_char) | value;
            bits_left += bits_per_char;

            if (bits_left >= bits_per_byte) {
                bits_left -= bits_per_byte;
                output[out_idx] = @as(u8, @truncate(buffer >> bits_left));
                out_idx += 1;
            }
        }

        // Check for non-zero leftover bits (invalid encoding)
        if (bits_left >= bits_per_char) return error.InvalidLength;
    }

    // Public functions

    /// Encodes binary data to Crockford Base32 string
    /// This function takes an allocator, so that it can encode input of any length. The caller is responsible
    /// to free the returned string after usage.
    pub fn encode(allocator: Allocator, data: []const u8) ![]const u8 {
        if (data.len == 0) return "";

        const output_len = (data.len * bits_per_byte + (bits_per_char - 1)) / bits_per_char;
        const output = try allocator.alloc(u8, output_len);
        errdefer allocator.free(output);

        encodeInternal(data, output);
        return output;
    }

    /// Optimized encoder for fixed 16-byte input → 26-char Base32 output (for ULID)
    pub fn encodeFixed16To26(input: []const u8) ![UlidConstants.ULID_STRING_LENGTH]u8 {
        if (input.len != UlidConstants.TOTAL_BYTES) return error.InvalidLength;

        var output: [UlidConstants.ULID_STRING_LENGTH]u8 = undefined;
        encodeInternal(input[0..], output[0..]);
        return output;
    }

    /// Decodes Crockford Base32 string to binary data
    /// This function takes an allocato, so that it can decode input of any length. The caller is responsible
    /// to free the returned decoded data after usage.
    pub fn decode(allocator: Allocator, str: []const u8) ![]const u8 {
        if (str.len == 0) return "";

        // Calculate output length (5 bits per input char → 8 bits per output byte)
        const output_len = (str.len * bits_per_char) / bits_per_byte;
        const output = try allocator.alloc(u8, output_len);
        errdefer allocator.free(output);

        try decodeInternal(str, output);
        return output;
    }

    // Optimized decoder for fixed 26-char string input -> 16-byte output (for ULID)
    pub fn decodeFixed26To16(str: []const u8) ![UlidConstants.TOTAL_BYTES]u8 {
        if (str.len != UlidConstants.ULID_STRING_LENGTH) return error.InvalidLength;

        var output: [UlidConstants.TOTAL_BYTES]u8 = undefined;
        try decodeInternal(str[0..], output[0..]);
        return output;
    }
};

pub usingnamespace CBase32;

test "CBase32 encode/decode roundtrip" {
    const allocator = testing.allocator;
    const test_cases = [_][]const u8{
        "",
        "a",
        "abc",
        "12345",
        "Hello, World!",
        "The quick brown fox jumps over the lazy dog",
        "\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09",
    };

    for (test_cases) |data| {
        const encoded = try CBase32.encode(allocator, data);
        defer allocator.free(encoded);

        const decoded = try CBase32.decode(allocator, encoded);
        defer allocator.free(decoded);

        try testing.expectEqualSlices(u8, data, decoded);
    }
}

test "CBase32 verify max encoding and decoding" {
    const allocator = std.testing.allocator;

    // 1. Test encoding
    const encoded = try CBase32.encode(allocator, "\xFF");
    defer allocator.free(encoded);
    try std.testing.expectEqualStrings("ZW", encoded);

    // 2. Test roundtrip decoding
    const decoded = try CBase32.decode(allocator, "ZW");
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "\xFF", decoded);

    // 3. Verify the full 4-byte case from earlier tests
    const encoded4 = try CBase32.encode(allocator, "\xFF\xFF\xFF\xFF");
    defer allocator.free(encoded4);
    try std.testing.expectEqualStrings("ZZZZZZR", encoded4);
}

test "CBase32 encode known values" {
    const allocator = testing.allocator;
    const test_cases = [_]struct { input: []const u8, expected: []const u8 }{
        .{ .input = "", .expected = "" },
        .{ .input = "f", .expected = "CR" },
        .{ .input = "fo", .expected = "CSQG" },
        .{ .input = "foo", .expected = "CSQPY" },
        .{ .input = "foob", .expected = "CSQPYRG" },
        .{ .input = "fooba", .expected = "CSQPYRK1" },
        .{ .input = "foobar", .expected = "CSQPYRK1E8" },
    };

    for (test_cases) |tc| {
        const encoded = try CBase32.encode(allocator, tc.input);
        defer allocator.free(encoded);

        try testing.expectEqualStrings(tc.expected, encoded);
    }
}

test "CBase32 decode known values" {
    const allocator = testing.allocator;
    const test_cases = [_]struct { input: []const u8, expected: []const u8 }{
        .{ .input = "", .expected = "" },
        .{ .input = "CR", .expected = "f" },
        .{ .input = "CSQG", .expected = "fo" },
        .{ .input = "CSQPY", .expected = "foo" },
        .{ .input = "CSQPYRG", .expected = "foob" },
        .{ .input = "CSQPYRK1", .expected = "fooba" },
        .{ .input = "CSQPYRK1E8", .expected = "foobar" },
    };

    for (test_cases) |tc| {
        const decoded = try CBase32.decode(allocator, tc.input);
        defer allocator.free(decoded);

        try testing.expectEqualStrings(tc.expected, decoded);
    }
}

test "CBase32 decode invalid characters" {
    const allocator = testing.allocator;
    const invalid_cases = [_][]const u8{
        "UUUU", // 'U' is excluded
        "ABCU", // Contains invalid 'U'
        "ABC!", // Contains non-alphabet character
    };

    for (invalid_cases) |input| {
        try testing.expectError(error.InvalidCharacter, CBase32.decode(allocator, input));
    }
}

test "CBase32 decode invalid length" {
    const allocator = testing.allocator;
    // Input lengths that would leave leftover bits (invalid)
    const invalid_cases = [_][]const u8{
        "A", // 5 bits → can't make full byte
        "AAA", // 15 bits → can't make full bytes (would leave 7 bits)
    };

    for (invalid_cases) |input| {
        try testing.expectError(error.InvalidLength, CBase32.decode(allocator, input));
    }
}

test "CBase32 decode with ambiguous characters" {
    const allocator = testing.allocator;
    const test_cases = [_]struct { input: []const u8, expected: []const u8 }{
        .{ .input = "Oo0oOoOo", .expected = "00000000" }, // 'O' and 'o' → '0'
        .{ .input = "IiLl1iIl", .expected = "11111111" }, // 'I', 'i', 'L', 'l' → '1'
    };

    for (test_cases) |tc| {
        const decoded = try CBase32.decode(allocator, tc.input);
        defer allocator.free(decoded);
        const encoded: []const u8 = try CBase32.encode(allocator, decoded);
        defer allocator.free(encoded);

        try testing.expectEqualStrings(tc.expected, encoded);
    }
}

test "CBase32 shared encoder functionality" {
    // Test generic encode()
    const allocator = std.testing.allocator;

    const input_slice = "1234567890123456";
    std.debug.assert(input_slice.len == 16);

    const generic_encoded = try CBase32.encode(allocator, input_slice);
    defer allocator.free(generic_encoded);

    // Test fixed encodeFixed16To26()
    const fixed_encoded = try CBase32.encodeFixed16To26(input_slice);

    // Should produce same result
    try std.testing.expectEqualStrings(generic_encoded, &fixed_encoded);
}

test "CBase32 encodeFixed16To26 with invalid length input" {
    const input = "123456789012345";
    std.debug.assert(input.len == 15);
    try std.testing.expectError(
        error.InvalidLength,
        CBase32.encodeFixed16To26(input),
    );
}

test "CBase32 shared decoder functionality" {
    const allocator = std.testing.allocator;

    const input = "64S36D1N6RVKGE9G64S36D1N6R";
    std.debug.assert(input.len == 26);

    const generic_decoded = try CBase32.decode(allocator, input);
    defer allocator.free(generic_decoded);

    const fixed_decoded = try CBase32.decodeFixed26To16(input);

    try std.testing.expectEqualSlices(u8, generic_decoded, fixed_decoded[0..]);
}

test "CBase32 decodeFixed26To16 with invalid input" {
    // Invalid character
    const input1 = "64S36D1N6RVKGE9G64S36D1N6!";
    std.debug.assert(input1.len == 26);
    try std.testing.expectError(
        error.InvalidCharacter,
        CBase32.decodeFixed26To16(input1),
    );

    // Invalid length (would leave leftover bits)
    const input2 = "64S36D1N6RVKGE9G64S36D1N6";
    std.debug.assert(input2.len == 25);
    try std.testing.expectError(
        error.InvalidLength,
        CBase32.decodeFixed26To16(input2), // 25 chars
    );
}
