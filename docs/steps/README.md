# Incremental delivery log

Every increment is vertically complete in the demo and the gem. Each record tracks changed behavior, tests and limitations.

| Step | Demo application | Gem | Status |
| --- | --- | --- | --- |
| [0000 - Bootable Engine](0000-engine-shell.md) | Rails host, engine mount, demo authentication | Isolated engine, HTML shell, themes | CI green; browser QA pending |
| [0001 - First associations](0001-first-associations.md) | Organization, Customer, Order, Payment | Resource registry, scoped CRUD and associations | CI green; browser QA pending |
| [0001.5 - External Links](0001-5-external-links.md) | Order deep links for Sumo Logic and GitHub Issues | Provider-aware resolver, link policies, secure URL generation | CI green; browser QA pending |
| [0001.6 - Context References](0001-6-context-references.md) | Order links Customer, Organization, fictional Jira issue and trace | Typed identities, scoped resolver and context DSL | CI green; browser QA pending |
| [0001.7 - Jira linking](../backlog/jira-integration.md) | Jira issue associated to Orders or investigations | Remote Issue Links adapter | Deferred to backlog |
| [0002 - Activity](0002-activity.md) | PaperTrail versioned Orders and seeded change | Optional PaperTrail adapter, protected read-only timeline | Feature branch; CI pending |
| 0003 - Jobs | ActiveJob/Solid Queue sample | Job inspector adapter | Planned |
| 0004 - Findings | Consistency rule | Findings and evidence UI | Planned |
