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
    try benchmarkUlidGeneration();
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

fn benchmarkUlidGeneration() !void {
    const time = std.time;
    const print = std.debug.print;
    const Ulid = ulid.Ulid;

    // Warm up
    print("Warming up ...\n", .{});
    const warmup = 100_000;
    var i: u32 = 0;
    while (i < warmup) : (i += 1) {
        _ = try Ulid.init();
    }

    print("Start running ...\n", .{});
    var timer = try time.Timer.start();

    const count = 100_000_000;
    i = 0;
    while (i < count) : (i += 1) {
        std.mem.doNotOptimizeAway(try Ulid.init());
    }

    const elapsed_ns = timer.lap();
    const elapsed_s = @as(f64, @floatFromInt(elapsed_ns)) / time.ns_per_s;

    print("Generated {} ULIDs in {d:.3}s\n", .{ count, elapsed_s });
    print("Average: {d:.3}ns per ULID\n", .{@as(f64, @floatFromInt(elapsed_ns)) / count});
    print("Rate: {d:.2}M ULIDs/second\n", .{count / (elapsed_s * 1_000_000)});
}
