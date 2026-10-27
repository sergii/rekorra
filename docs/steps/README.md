# Incremental delivery log

Every increment is small and vertically complete.

A step documents **host model and fixtures**, **Rekorra core/DSL/UI**, **automated tests**, **validation status**, **known limitations**, and **next step**. A passed checkbox means a test ran successfully, not merely that code was written.

| Step | Demo application | Gem | Status |
| --- | --- | --- | --- |
| [0000 - Bootable Engine](0000-engine-shell.md) | Rails host, engine mount, demo authentication | Isolated engine, HTML shell, themes | Implemented, runtime verification pending |
| 0001 - First associations | Customer -> Order -> Payment | Resource registry, fields, scoped CRUD | Planned |
| 0002 - Activity | PaperTrail events | Activity adapter and timeline | Planned |
| 0003 - Jobs | ActiveJob/Solid Queue sample | Job inspector adapter | Planned |
| 0004 - Findings | Consistency rule | Findings and evidence UI | Planned |
