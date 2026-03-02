## Embedded Development Discipline

### Resource Awareness
- **Memory is limited** — Consider RAM/ROM budget for every allocation. Avoid malloc, prefer static allocation
- **Stack depth** — Be extremely cautious with recursion; no deep call chains in ISRs
- **Peripherals are shared resources** — Register access must consider concurrency and interrupt safety
- **Timing constraints** — Interrupt response, communication timeouts, watchdog feeding must not be blocked

### Mandatory Checks Before Modification
- Involves interrupt handling? → Confirm whether `volatile` is needed, confirm critical section protection
- Involves peripheral registers? → Confirm register addresses and bit fields against the datasheet
- Involves memory layout? → Confirm linker script and section assignments
- Involves communication protocol? → Confirm endianness, alignment, timeout handling

### Prohibited
- No blocking functions in ISRs (printf, malloc, mutex lock)
- No assuming `sizeof(int)` — use fixed-width types like `uint32_t` explicitly
- No modifying register configurations without understanding the hardware behavior
- No ignoring compiler warnings — in embedded, warnings are often potential hardware issues

### Debugging Notes
- The problem may be hardware-related (power, signal integrity, EMI) — don't only look in software
- Timing-related bugs may not reproduce reliably — record reproduction conditions and frequency
- Optimization levels affect behavior — confirm whether behavior is consistent between -O0 and -O2
