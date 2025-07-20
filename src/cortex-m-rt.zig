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

// export to linker scripts
export fn defaultEntry() callconv(.c) void {
    // Set the stack pointer to the top of the stack if requested
    asm volatile (
        \\ldr r0, = __stack_top
        \\msr msp, r0
    );

    // Set the vector table address if requested
    asm volatile (
        \\ldr r0, = 0xe000ed08
        \\ldr r1, = __vector_table
        \\str r1, [r0]
    );

    // Call the pre-initialization function
    asm volatile (
        \\bl __preinit  
    );

    // Initialize data and bss sections
    asm volatile (
        \\ldr r0, = __data_start
        \\ldr r1, = __data_end
        \\ldr r2, = __data_rom
        \\0:
        \\cmp r0, r1
        \\beq 1f
        \\ldm r1!,{r3}
        \\stm r0!,{r3}
        \\b 0b
        \\1:
        \\ldr r0, = __bss_start
        \\ldr r1, = __bss_end
        \\mov r2, #0
        \\0:
        \\cmp r0, r1
        \\beq 1f
        \\stm r0!, {r2}
        \\b 0b
        \\1:
    );

    // Enable FPU if requested
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

    // Call main function after setup
    asm volatile (
        \\bl main
        \\udf #0  // Undefined instruction to indicate end of execution
    );
}

// export to linker scripts
export fn defaultHandler() callconv(.c) void {
    // Default handler implementation
    while (true) {
        // Infinite loop to indicate an unhandled exception
    }
}

// export to linker scripts
export fn defaultInit() callconv(.c) void {
    // Default initialization code
}

// export to linker scripts
export const __ENTRY linksection(".vector_table.entry") = @extern(ExceptionHandler, .{ .name = "__entry" });
// export to linker scripts
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

// export to linker scripts
pub fn interruptsVector(comptime devInts: ?*const [_NUMS]?InterruptHandler) void {
    if (devInts) |__interrupts| {
        @export(__interrupts, .{ .name = "__INTERRUPTS", .section = ".vector_table.interrupts" });
    } else {
        @export(&__INTERRUPTS, .{ .name = "__INTERRUPTS", .section = ".vector_table.interrupts" });
    }
}

// export to linker scripts
pub fn entry(comptime _entry: anytype) void {
    @export(_entry, .{ .name = "main" });
}
