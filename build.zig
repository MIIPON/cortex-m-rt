const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // 共享 cortex-m-rt 模块
    _ = b.addModule("rt", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/cortex-m-rt.zig"),
    });

    _ = b.addInstallFile(b.path("link.x"), "out/link.x");
}
