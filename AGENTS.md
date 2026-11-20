# volt-run: agent instructions
Extends the studio `AGENTS.md` (`../../AGENTS.md`). Authoritative plan: `../../studio/docs/VOLT-RUN-PLAN.md`; art direction: ADR-0003.
- All visuals and audio are procedural code. Adding any external asset requires a `LEDGER.csv` row (source, licence, tool, prompt).
- `sim.gd` is shared by the game and the fairness bot. Any physics change must keep `tools/test.sh` green.
- Tests and captures must use an isolated user-data dir (the scripts already do this).
- Ads: `ads.gd` stays a stub until the owner approves an SDK after the legal review (G4).
