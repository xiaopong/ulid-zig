//
// Copyright (C) 2025 Xiaopong Tran
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
const std = @import("std");
const time = std.time;
const crypto = std.crypto;
const rand = crypto.random;
const math = std.math;
const base32 = @import("cbase32.zig");
const UlidConstants = @import("ulid_constants.zig");

pub const UlidError = error{
    InvalidUlidString,
    InvalidUlidSize,
    InvalidTimestamp,
};

pub const Ulid = struct {
    const MAX_TIMESTAMP = 0xFFFFFFFFFFFF; // 281474976710655 (48 bits)
    const MAX_TIMESTAMP_DATE = "10889-08-02T05:31:50.655Z"; // For documentation

    // Last random bytes to ensure monotonicity
    threadlocal var last_random: [UlidConstants.RANDOM_LENGTH]u8 = undefined;
    threadlocal var last_timestamp: u64 = 0;

    bytes: [UlidConstants.TOTAL_BYTES]u8,

    /// Creates a new ULID with the current timestamp and secure random data
    pub fn init() !Ulid {
        var ulid: Ulid = undefined;
        try ulid.generate();
        return ulid;
    }

    /// Creates a new ULID with the given timestamp and secure random data
    pub fn initWithTimestamp(timestamp: u64) !Ulid {
        var ulid: Ulid = undefined;
        try ulid.generateWithTimestamp(timestamp);
        return ulid;
    }

    /// Generates a new ULID with the current timestamp (monotonic safe)
    pub fn generate(self: *Ulid) !void {
        const now = @as(u64, @intCast(time.milliTimestamp())) + time.epoch.unix;
        try self.generateWithTimestamp(now);
    }

    /// Ensures monotonicity when timestamps are equal
    pub fn generateWithTimestamp(self: *Ulid, timestamp: u64) !void {
        if (timestamp > MAX_TIMESTAMP) {
            std.debug.print("Error: Tiemstamp exceeds ULID limit (>{s})\n", .{MAX_TIMESTAMP_DATE});
            return UlidError.InvalidTimestamp;
        }

        // Write timestamp (48 bits)
        self.bytes[0] = @truncate(timestamp >> 40);
        self.bytes[1] = @truncate(timestamp >> 32);
        self.bytes[2] = @truncate(timestamp >> 24);
        self.bytes[3] = @truncate(timestamp >> 16);
        self.bytes[4] = @truncate(timestamp >> 8);
        self.bytes[5] = @truncate(timestamp);

        // Check if we need to increment for monotonicity
        if (timestamp == last_timestamp) {
            // Increment the last random value (big-endian)
            var i: usize = UlidConstants.RANDOM_LENGTH;
            while (i > 0) {
                i -= 1;
                last_random[i] +%= 1;
                if (last_random[i] != 0) break;
            }
            @memcpy(self.bytes[UlidConstants.TIMESTAMP_LENGTH..], &last_random);
        } else {
            // Generate new random bytes
            rand.bytes(self.bytes[UlidConstants.TIMESTAMP_LENGTH..]);
            @memcpy(&last_random, self.bytes[UlidConstants.TIMESTAMP_LENGTH..]);
            last_timestamp = timestamp;
        }
    }

    /// Returns the ULID as a base32-encoded string
    pub fn toString(self: *const Ulid) [UlidConstants.ULID_STRING_LENGTH]u8 {
        return base32.encodeFixed16To26(&self.bytes) catch unreachable;
    }

    /// Creates a ULID from a fixed-size Base32 string (compile-time length checked)
    pub fn fromString(str: [UlidConstants.ULID_STRING_LENGTH]u8) Ulid {
        var ulid: Ulid = undefined;
        ulid.bytes = base32.decodeFixed26To16(&str) catch unreachable;
        return ulid;
    }

    /// Parses a ULID from a base32-encoded string
    pub fn fromStringSlice(str: []const u8) !Ulid {
        if (str.len != UlidConstants.ULID_STRING_LENGTH) return UlidError.InvalidUlidString;

        var ulid: Ulid = undefined;
        ulid.bytes = try base32.decodeFixed26To16(str);
        return ulid;
    }

    /// Returns the binary representation of the ULID
    pub fn toBytes(self: *const Ulid) [UlidConstants.TOTAL_BYTES]u8 {
        return self.bytes;
    }

    /// Creates a ULID from its binary representation
    pub fn fromBytes(bytes: [UlidConstants.TOTAL_BYTES]u8) Ulid {
        return Ulid{ .bytes = bytes };
    }

    pub fn fromBytesSlice(bytes: []const u8) !Ulid {
        if (bytes.len != UlidConstants.TOTAL_BYTES) return UlidError.InvalidUlidSize;
        return Ulid{ .bytes = bytes[0..UlidConstants.TOTAL_BYTES].* };
    }

    /// Returns the timestamp component of the ULID (milliseconds since Unix epoch)
    pub fn getTimestamp(self: *const Ulid) u64 {
        return (@as(u64, self.bytes[0]) << 40) |
            (@as(u64, self.bytes[1]) << 32) |
            (@as(u64, self.bytes[2]) << 24) |
            (@as(u64, self.bytes[3]) << 16) |
            (@as(u64, self.bytes[4]) << 8) |
            @as(u64, self.bytes[5]);
    }

    /// Compare two ULIDs (returns .lt, .eq, or .gt)
    pub fn compare(a: *const Ulid, b: *const Ulid) std.math.Order {
        return std.mem.order(u8, &a.bytes, &b.bytes);
    }
};

test "ULID monotonicity" {
    const now = @as(u64, @intCast(time.milliTimestamp())) + time.epoch.unix;

    // Generate multiple ULIDs with the same timestamp
    var ulid1 = try Ulid.initWithTimestamp(now);
    var ulid2 = try Ulid.initWithTimestamp(now);
    var ulid3 = try Ulid.initWithTimestamp(now);

    // They should all be monotonically increasing
    try std.testing.expect(ulid1.compare(&ulid2) == .lt);
    try std.testing.expect(ulid2.compare(&ulid3) == .lt);

    // Different timestamps should still work
    var ulid4 = try Ulid.initWithTimestamp(now + 1);
    try std.testing.expect(ulid3.compare(&ulid4) == .lt);
}

test "ULID binary serialization" {
    const ulid1 = try Ulid.init();
    const bytes = ulid1.toBytes();
    const ulid2 = Ulid.fromBytes(bytes);
    const ulid3 = try Ulid.fromBytesSlice(&bytes);

    try std.testing.expectEqual(ulid1.getTimestamp(), ulid2.getTimestamp());
    try std.testing.expectEqualSlices(u8, &ulid1.bytes, &ulid2.bytes);

    try std.testing.expectEqual(ulid1.getTimestamp(), ulid3.getTimestamp());
    try std.testing.expectEqualSlices(u8, &ulid1.bytes, &ulid3.bytes);

    const str1 = ulid1.toString();
    const str2 = ulid2.toString();
    try std.testing.expectEqualStrings(&str1, &str2);
}

test "ULID convert from string" {
    const ulid1 = try Ulid.init();
    const str = ulid1.toString();
    const ulid2 = Ulid.fromString(str);

    try std.testing.expectEqual(ulid1.getTimestamp(), ulid2.getTimestamp());
    try std.testing.expectEqualSlices(u8, &ulid1.bytes, &ulid2.bytes);

    const fixed_str = "06BJWVJCTA4DR034EW5R74F5ZW";
    const ulid3 = Ulid.fromString(fixed_str.*); // Note: .* converts string literal to array
    const str3 = ulid3.toString();
    try std.testing.expectEqualStrings(fixed_str, &str3);
}

test "ULID convert from string slice" {
    const fixed_str = "06BJWVJCTA4DR034EW5R74F5ZW";
    const ulid1 = try Ulid.fromStringSlice(fixed_str);
    const str = ulid1.toString();
    const ulid2 = Ulid.fromString(str);

    try std.testing.expectEqual(ulid1.getTimestamp(), ulid2.getTimestamp());
    try std.testing.expectEqualSlices(u8, &ulid1.bytes, &ulid2.bytes);
}

test "ULID edge cases" {
    // Test minimum timestamp
    var ulid1 = try Ulid.initWithTimestamp(0);
    try std.testing.expectEqual(0, ulid1.getTimestamp());

    // Test maximum timestamp (48 bits)
    const max_ts = math.maxInt(u48);
    var ulid2 = try Ulid.initWithTimestamp(max_ts);
    try std.testing.expectEqual(max_ts, ulid2.getTimestamp());

    // std.debug.print("ts: 0x{X:0>12}\n", .{max_ts});

    // Test timestamp overflow
    try std.testing.expectError(UlidError.InvalidTimestamp, Ulid.initWithTimestamp(max_ts + 1));
}
