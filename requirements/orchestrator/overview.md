# orchestrator

Reentrant cycle stepper. A cycle record is what the PO opens; a job wakes, does the next legal graph step, writes the record, exits.

## Catalog

### group

orchestrator

### slices

process

### defs



## In scope

- Full graph: `req/` → saved delta vs `main` → `orchestrator/<slug>` → one worker PR per next subtask → review (merge or respawn) → `req/<slug>` → `main` only when every subtask has merged.
- `CYCLE.md` on `cycle/<slug>` is cockpit and machine state. Branches and PRs are actuators.
- Thin spec → `missing-req` plus `incomplete` on the record. Bots do not merge the requirement PR.

## Out of scope

- Changing freeze (human still approves the requirement PR).
- Changing a product RequirementSet’s tests (e.g. marketplace-scan-store).
- Graphical UI beyond `CYCLE.md`.
- Parallel worker swarm.

## Done when

- A pipeline runs the graph end-to-end. The PO can open `cycle/<slug>` and see: saved delta, orchestrator, worker PRs (merged or respawned), incomplete-requirement, and a requirement → `main` PR only after every subtask merged.
