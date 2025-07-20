/* provide by rt */
EXTERN(__ENTRY); /* which link to section .vector_table.entry */
EXTERN(__EXCEPTIONS); /* which link to section .vector_table.exceptions */
EXTERN(__INTERRUPTS); /* which link to section .vector_table.interrupts */

/* provide by rt */
EXTERN(defaultEntry); /* default entry */
EXTERN(defaultHandler); /* default handler */
EXTERN(defaultInit); /* default pre initialize */

/* provide by device */
INCLUDE memory.x    /* MEMORY region */
INCLUDE device.x    /* INTERRUPTS weak function */

/* weak function, can be redefination */
PROVIDE(NonMaskableInt_Handler = defaultHandler);
PROVIDE(HardFault_Handler = defaultHandler);
PROVIDE(MemoryManagement_Handler = defaultHandler);
PROVIDE(BusFault_Handler = defaultHandler);
PROVIDE(UsageFault_Handler = defaultHandler);
PROVIDE(SVCall_Handler = defaultHandler);
PROVIDE(DebugMonitor_Handler = defaultHandler);
PROVIDE(SecureFault_Handler = defaultHandler);
PROVIDE(PendSV_Handler = defaultHandler);
PROVIDE(SysTick_Handler = defaultHandler);

PROVIDE(__preinit = defaultInit);
PROVIDE(__entry = defaultEntry);

/* define rt entry */
ENTRY(__entry);

SECTIONS
{
    PROVIDE(__ram_start = ORIGIN(RAM));
    PROVIDE(__ram_end = ORIGIN(RAM) + LENGTH(RAM));
    PROVIDE(__stack_top = __ram_end);

    .vector_table ORIGIN(FLASH) :
    {
        . = ALIGN(4);
        __vector_table = .;
        LONG(__stack_top & 0xfffffff8);
        KEEP(*(.vector_table.entry));
        KEEP(*(.vector_table.exceptions));
        KEEP(*(.vector_table.interrupts));
        . = ALIGN(4);
    } > FLASH

    PROVIDE(__text_start = ADDR(.vector_table) + SIZEOF(.vector_table));

    .text __text_start :
    {
        . = ALIGN(4);
        *(.text .text.*)
        . = ALIGN(4);
        __text_end = .;
    } > FLASH

    .rodata :
    {
        . = ALIGN(4);
        *(.rodata .rodata.*)
        . = ALIGN(4);
    } > FLASH

    .data :
    {
        . = ALIGN(4);
        __data_start = .;
        *(.data .data.*)
        . = ALIGN(4);
        __data_end = .;
    } > RAM AT > FLASH

    __data_rom = LOADADDR(.data);

    .bss : 
    {
        . = ALIGN(4);
        __bss_start = .;
        *(.bss .bss.*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > RAM

    /DISCARD/ : 
    {
        *(.ARM.exidx)
        *(.ARM.exidx.*)
        *(.ARM.extab.*)
    }
}

__ints_nums = SIZEOF(.vector_table) / 4;

ASSERT((__ints_nums == 48) || (__ints_nums == 256) || (__ints_nums == 496), "
ERROR(cortex-m-rt): Lack of __INTERRUPTS symbol at section .vector_table.interrupts!");
