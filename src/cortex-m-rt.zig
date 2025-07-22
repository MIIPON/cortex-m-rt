const std = @import("std");
const builtin = @import("builtin");
const Feature = std.Target.arm.Feature;

const armv6m = builtin.cpu.features.isEnabled(@intFromEnum(Feature.v6m));
const armv7m = builtin.cpu.features.isEnabled(@intFromEnum(Feature.v7m));
const armv7em = builtin.cpu.features.isEnabled(@intFromEnum(Feature.v7em));
const armv8m = builtin.cpu.features.isEnabled(@intFromEnum(Feature.v8m));

const use_fpu = builtin.abi == .eabihf;

const _NUMS = if (armv6m) 32 else if (armv7m or armv7em) 240 else if (armv8m) 480 else @compileError("Unsupported ARM architecture");

pub const EntryFunction = *const fn () callconv(.c) noreturn;
pub const ExceptionHandler = *const fn () callconv(.c) void;
pub const InterruptHandler = *const fn () callconv(.c) void;

pub const Exceptions = exps: {
    if (armv6m) {
        break :exps enum {
            NonMaskableInt,
            HardFault,
            SVCall,
            PendSV,
            SysTick,
        };
    } else if (armv7m or armv7em) {
        break :exps enum {
            NonMaskableInt,
            HardFault,
            MemoryManagement,
            BusFault,
            UsageFault,
            SVCall,
            DebugMonitor,
            PendSV,
            SysTick,
        };
    } else if (armv8m) {
        break :exps enum {
            NonMaskableInt,
            HardFault,
            MemoryManagement,
            BusFault,
            UsageFault,
            SecureFault,
            SVCall,
            DebugMonitor,
            PendSV,
            SysTick,
        };
    } else @compileError("Unsupported ARM architecture");
};

// 默认复位入口函数
export fn defaultEntry() callconv(.c) void {
    { //初始化.data和.bss段
        const data_start = @extern([*]u8, .{ .name = "__data_start" });
        const data_end = @extern([*]u8, .{ .name = "__data_end" });
        const data_rom = @extern([*]u8, .{ .name = "__data_rom" });
        const data_len = @intFromPtr(data_end) - @intFromPtr(data_start);

        for (0..data_len) |i| {
            data_start[i] = data_rom[i];
        }

        const bss_start = @extern([*]u8, .{ .name = "__bss_start" });
        const bss_end = @extern([*]u8, .{ .name = "__bss_end" });
        const bss_len = @intFromPtr(bss_end) - @intFromPtr(bss_start);

        for (0..bss_len) |i| {
            bss_start[i] = 0;
        }
    }

    if (use_fpu) {
        asm volatile (
            \\ldr r0, = 0xe000ed88
            \\ldr r1, = (0b1111 << 20)
            \\ldr r2, [r0]
            \\orr r2, r2, r1
            \\str r2, [r0]
            \\dsb
            \\isb
        );
    }

    @extern(ExceptionHandler, .{ .name = "__preinit" })();
    @extern(EntryFunction, .{ .name = "main" })();
}

// 默认中断处理
export fn defaultHandler() callconv(.c) void {
    while (true) {}
}

// 默认系统初始化
export fn defaultInit() callconv(.c) void {}

export const __ENTRY linksection(".vector_table.entry") = @extern(ExceptionHandler, .{ .name = "__entry" });
export const __EXCEPTIONS linksection(".vector_table.exceptions") = [_]?ExceptionHandler{
    @extern(ExceptionHandler, .{ .name = "NonMaskableInt_Handler" }), // NonMaskableInt
    @extern(ExceptionHandler, .{ .name = "HardFault_Handler" }), // HardFault
    if (armv6m) null else @extern(ExceptionHandler, .{ .name = "MemoryManagement_Handler" }), // MemoryManagement
    if (armv6m) null else @extern(ExceptionHandler, .{ .name = "BusFault_Handler" }), // BusFault
    if (armv6m) null else @extern(ExceptionHandler, .{ .name = "UsageFault_Handler" }), // UsageFault
    if (armv8m) @extern(ExceptionHandler, .{ .name = "SecureFault_Handler" }) else null, // SecureFault
    null, // Reserved
    null, // Reserved
    null, // Reserved
    @extern(ExceptionHandler, .{ .name = "SVCall_Handler" }), // SVCall
    if (armv6m) null else @extern(ExceptionHandler, .{ .name = "DebugMonitor_Handler" }), // DebugMonitor
    null, // Reserved
    @extern(ExceptionHandler, .{ .name = "PendSV_Handler" }), // PendSV
    @extern(ExceptionHandler, .{ .name = "SysTick_Handler" }), // SysTick
};
const __INTERRUPTS = [_]?InterruptHandler{&defaultHandler} ** _NUMS;

// 中断向量表
pub fn interruptsVector(comptime devInts: ?*const [_NUMS]?InterruptHandler) void {
    if (devInts) |__interrupts| {
        @export(__interrupts, .{ .name = "__INTERRUPTS", .section = ".vector_table.interrupts" });
    } else {
        @export(&__INTERRUPTS, .{ .name = "__INTERRUPTS", .section = ".vector_table.interrupts" });
    }
}

// 设备入口函数
pub fn entry(comptime _entry: anytype) void {
    @export(_entry, .{ .name = "main" });
}
