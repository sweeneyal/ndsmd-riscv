

void initialize_ivt()
{
    __asm__(
        ""
    );
}

void _startup()
{
    /*
    When we are in this function, the processor has just left a reset state,
    meaning the global processor reset signal has been deasserted and we are
    starting to run instructions that initialize the memory space of the 
    program.

    This means, above all else, we need to ensure that the default memory space
    is loaded first, by clearing any changes made by the application program. 
    Namely, resetting the interrupt vector table, reloading the program into
    memory (likely copying the program)
    */

    // initialize interrupt vector table

    // load program into memory

    // start program
    main();

    // program termination catch loop
    while (1);
}