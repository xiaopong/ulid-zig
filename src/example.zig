//
// Copyright (C) 2025 Xiaopong Tran
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
const std = @import("std");
const base32 = @import("lib.zig").CBase32;
const ulid = @import("lib.zig").Ulid;

pub fn main() !void {
    try howToUseCBase32();
    try howToUseUlid();
}

fn howToUseCBase32() !void {
    const allocator = std.heap.page_allocator;
    const data = "hello";

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    const encoded = try base32.encode(allocator, data);
    defer allocator.free(encoded);

    const decoded = try base32.decode(allocator, encoded);
    defer allocator.free(decoded);

    try stdout.print("Original: {s}\n", .{data});
    try stdout.print("Encoded: {s}\n", .{encoded});
    try stdout.print("Decoded: {s}\n", .{decoded});
    try bw.flush();
}

fn howToUseUlid() !void {
    const Ulid = ulid.Ulid;
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    const id = try Ulid.init();
    const idStr = id.toString();

    try stdout.print("ulid: {s}\n", .{idStr});

    const parsed = Ulid.fromString(idStr);
    const ts = parsed.getTimestamp();
    try stdout.print("timestamp: {d}\n", .{ts});

    try bw.flush();
}
