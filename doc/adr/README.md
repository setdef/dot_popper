<!--
  SPDX-FileCopyrightText: 2026 setdef
  SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
-->
# Decision log

Dot Popper's architecturally significant decisions, one per record, in the MADR format. Each says what was decided, the options that were weighed, why, what it costs, and what enforces it. How each area works is in the [design documents](../architecture.md#design-documents); code cites a decision here by number for why, and a design document by path for how.

| ADR | Decision | Status |
| --- | --- | --- |
| [0008](0008-native-features-live-outside-the-ruby-process.md) | Native features Lota lacks are reached outside the Ruby process | accepted |
| [0010](0010-pro-comes-only-from-proof.md) | Pro comes only from proof the game verifies, and a store build ignores developer settings | accepted |
| [0011](0011-pro-outlives-setdef.md) | Pro outlives setdef: license keys, one device at a time, and one test of setdef being gone | accepted |
| [0019](0019-clean-architecture-and-domain-driven-design-in-three-areas.md) | The code follows Clean Architecture and Domain-Driven Design, with the domain in three areas | accepted |

## Keeping the log

- A decision gets a record only if it resolves an architecturally significant requirement, and undoing it would cost on the scale of a layer of the code rewritten, every build remade, or what players already hold broken. Records are few, and one that no longer passes is deleted.
- What the game does for a player, what it sells and what it collects are product rules, however firm: they live in the design document for their subject, with the maintainer's words. So do one feature's design, the choice of a tool or a version, and how the project is developed and tested.
- A new decision gets the next number; numbers are never reused. The highest used so far is 0024.
- An accepted decision isn't rewritten: a new ADR supersedes it, and a fully superseded one is deleted (git keeps it).
- Record only the reasons a decision actually had. Alternatives found later are marked as later research, with their date.
- Detailed design, rules and numbers go in a design document under `doc/design/`, not here.
