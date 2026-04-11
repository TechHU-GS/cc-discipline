## RTL Discipline

### Hardware Mindset (not software mindset)
- **Every line of code is a circuit** — Before writing, think about what hardware structure it synthesizes to
- **Distinguish synthesis from simulation** — `initial`, `$display`, `#delay` are for testbench only, never in synthesizable code
- **Timing awareness** — When modifying any register logic, consider the impact on timing paths
- **Consistent reset strategy** — Don't mix synchronous/asynchronous reset in the same module without a clear reason

### Mandatory Checks Before Modification
- Confirm the fan-out of the signal being modified — Who is reading this signal?
- Confirm the clock domain — Is this a clock domain crossing (CDC)? Is a synchronizer needed?
- Confirm bit width — Do widths match? Are there implicit truncations or extensions?
- Confirm FSM states — When modifying a state machine, are all state transitions fully covered?

### Prohibited
- No latches in `always @(*)` unless explicitly intended with a comment
- No missing else / default branches in combinational logic
- No modifying interface signals (ports) without updating all instantiation sites
- No modifying critical path logic without understanding timing constraints

### Testbench Rules
- New features must have corresponding testbench cases
- After modifying RTL, run existing simulations before checking results
- Prefer assertions / checkers over visual waveform inspection
