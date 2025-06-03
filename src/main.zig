//
// Copyright (C) 2025 Xiaopong Tran
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
const std = @import("std");
const ulid = @import("lib.zig").Ulid;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var help = false;
    var count: ?usize = null;
    var benchmark: ?usize = null;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "-h")) {
            help = true;
        } else if (std.mem.eql(u8, arg, "-n")) {
            if (benchmark != null) return error.CannotSpecifyBoth;
            i += 1;
            if (i >= args.len) return error.MissingArgument;
            count = try parsePositiveInt(args[i]);
        } else if (std.mem.eql(u8, arg, "-b")) {
            if (count != null) return error.CannotSpecifyBoth;
            i += 1;
            if (i >= args.len) return error.MissingArgument;
            benchmark = try parsePositiveInt(args[i]);
        } else {
            return error.InvalidArgument;
        }
    }

    if (help) {
        printHelp();
        return;
    }

    if (benchmark) |x| {
        try benchmarkUlidGeneration(x);
    } else if (count) |x| {
        try generateUlids(x);
    } else {
        try generateUlids(1);
    }
}

fn printHelp() void {
    const stdout = std.io.getStdOut().writer();
    stdout.writeAll(
        \\
        \\Usage: ulid-zig [options]
        \\
        \\Options:
        \\  -h           Show this help message
        \\  -n COUNT     Generate COUNT ULIDs (must be > 0)
        \\  -b COUNT     Benchmark with COUNT ULIDs (must be > 0)
        \\
        \\Cannot use -n and -b together. If no option is specified, one ULID is generated.
        \\
    ) catch return;
}

fn parsePositiveInt(str: []const u8) !usize {
    const num = try std.fmt.parseInt(usize, str, 10);
    if (num < 1) return error.InvalidNumber;
    return num;
}

fn generateUlids(count: usize) !void {
    const Ulid = ulid.Ulid;

    for (0..count) |_| {
        const id = try Ulid.init();
        const idStr = id.toString();
        std.debug.print("{s}\n", .{idStr});
    }
}

fn benchmarkUlidGeneration(count: usize) !void {
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

    i = 0;
    while (i < count) : (i += 1) {
        std.mem.doNotOptimizeAway(try Ulid.init());
    }

    const elapsed_ns = timer.lap();
    const elapsed_s = @as(f64, @floatFromInt(elapsed_ns)) / time.ns_per_s;

    const count_as_float = @as(f64, @floatFromInt(count));
    print("Generated {} ULIDs in {d:.3}s\n", .{ count, elapsed_s });
    print("Average: {d:.3}ns per ULID\n", .{@as(f64, @floatFromInt(elapsed_ns)) / count_as_float});
    print("Rate: {d:.2}M ULIDs/second\n", .{count_as_float / (elapsed_s * 1_000_000)});
}
