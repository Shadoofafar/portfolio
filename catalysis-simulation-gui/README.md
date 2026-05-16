# Catalysis Simulation GUI — MATLAB Scientific Computing Tool

> **Code excerpts** from a MATLAB application developed during an MSc research internship for simulating template-directed autocatalytic reaction networks.

## Scientific Background

This simulator models **autocatalytic chemical reaction networks** in which template molecules (T) catalyze their own replication. The system tracks six species types:

| Symbol | Species | Description |
|--------|---------|-------------|
| **E** | Enzyme/activator | Catalytic molecules |
| **N** | Nutrient/substrate | Building block molecules |
| **T** | Template | Self-replicating molecules |
| **ENTT** | Ternary complex | E·N bound to a T·T duplex |
| **TT** | Template duplex | Two templates associated |
| **TTT** | Template triplex | Three templates associated |

The system supports both **batch** (closed) and **CSTR** (open, continuous stirred-tank reactor) operation modes.

## Architecture

```
CatalysisSimulationGUI.m          ← Main GUI (1,840 lines)
├── Pathway Builder               ← Define reaction pathways with (i,j,i',j',i'',j'') indices
├── CSTR Controls Panel           ← Configure inlet feeds, dilution rate, timing phases
├── Rij Selection Matrix          ← Toggle which R_{ij} species to plot
├── Keyboard Shortcuts            ← Power-user acceleration (a=add, r=run, w=select all...)
├── Save/Load Network             ← Persist configurations to .mat files
│
├── runNetwork.m                  ← Scenario orchestrator
│   ├── redundancy.m              ← Constraint propagation (eliminate redundant parameters)
│   ├── generateScenarios()       ← Cartesian grid over vectorized parameters
│   └── RunNetwork1.m             ← Core solver
│       ├── f3_second_order.m     ← ODE right-hand side (6D tensor kinetics)
│       └── ode15s (MATLAB)       ← Stiff ODE integrator
│
└── Plot_Results.m                ← Multi-scenario visualization with colorblind palette
```

## Key Technical Highlights

### 6D Tensor ODE System (`f3_second_order.m`)

The ODE right-hand side operates on **six-dimensional tensors** representing molecular species indexed by `(i, j, i', j', i'', j'')`. This is computationally challenging because:

- State vector size grows as `O(numE × numN)^3` — e.g., for 3 enzymes × 3 nutrients = 9 species, the TTT tensor alone has `9^3 = 729` elements
- Six nested loops compute reaction fluxes for each index combination
- MATLAB's `ode15s` (stiff solver) is used with tight tolerances (`RelTol = 1e-12`, `AbsTol = 1e-12`)

### Redundancy Detection (`redundancy.m`)

When multiple reaction pathways share the same species indices, their concentrations and rate constants must be consistent. The redundancy checker:

1. **Horizontal pass:** If `(i',j') == (i'',j'')` within a pathway, `cT_{i'j'}` automatically equals `cT_{i''j''}`
2. **Vertical pass:** If two pathways share the same `(i,j)` indices, their `E_i` and `N_j` concentrations are linked
3. **Cross-matching:** Detects `T_{i'j'} ↔ T_{i''j''}` equivalences across pathways
4. Visual feedback: redundant fields turn gray, first occurrences turn light blue

### CSTR Time-Phased Operation

```
t < preqtime              → Batch mode (D_eff = 0, no feed)
preqtime < t < preqtime+intime  → Feed ON (D_eff = D, C_in from user)
t > preqtime + intime     → Washout (D_eff = D, C_in = 0)
```

## Files in This Excerpt

| File | Lines | Description |
|------|-------|-------------|
| `CatalysisSimulationGUI.m` | 1,840 | Complete GUI with pathway builder, CSTR controls, Rij matrix |
| `f3_second_order.m` | 141 | ODE system — the mathematical core |
| `RunNetwork1.m` | 274 | Solver wrapper — assembles ICs, runs `ode15s`, exports results |
| `redundancy.m` | 143 | Parameter constraint propagation |
