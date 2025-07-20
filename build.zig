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

    buildExample(b);
}

pub fn buildExample(b: *std.Build) void {
    const query = std.Target.Query{
        .cpu_arch = .thumb,
        .os_tag = .freestanding,
        .abi = .eabihf,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m7 },
        .cpu_features_add = std.Target.arm.featureSet(&.{.vfp4d16}),
    };

    const target = b.resolveTargetQuery(query);
    const optimize = std.builtin.OptimizeMode.Debug;

    const module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/example.zig"),
        .link_libc = false,
        .sanitize_c = false,
        .strip = false,
        .single_threaded = true,
    });

    const elf = b.addExecutable(.{
        .name = "example.elf",
        .root_module = module,
    });
    elf.link_gc_sections = true;
    elf.link_data_sections = true;
    elf.link_function_sections = true;
    elf.linker_script = b.path("out/link.x");

    b.installArtifact(elf);
}
