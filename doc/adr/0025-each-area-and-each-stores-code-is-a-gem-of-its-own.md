---
status: accepted
date: 2026-11-21
deciders: the maintainer (Kerrick Long), who required it; coding agents, for where the gems live and how the game takes them
---

# Each area of the domain, and each store's code, is a gem of its own inside the repository

## Context and Problem Statement

The domain is in three areas ([ADR-0019](0019-clean-architecture-and-domain-driven-design-in-three-areas.md)), and the code that sells Pro through one store is carried only by that store's builds ([PACKAGING.md](../../PACKAGING.md#what-goes-into-the-app)). On 20 November 2026 each area was a folder of one program, kept apart by a test that reads the code and by the type checker, and each store's code was a folder that packaging leaves out of every other build. That keeps one area from naming another, but a folder cannot be built, tested or released without the rest of the game: the game's loaders, its test helper and its one bundle reach all of it. What is the unit in which an area, and a store's code, is built, tested and released?

## Decision Drivers

* Independent deployability: each area can be built, tested and released apart from the others (Martin, *Clean Architecture*, 2017, on components).
* A build for sale carries only its own store's code ([ADR-0010](0010-pro-comes-only-from-proof.md)).
* Every route that builds an app keeps working: `lota fuse`, which builds from one `Gemfile` and its lock, and the phone builds, which write a `Gemfile` of their own.
* Nothing a player holds changes: save files, requests, and what each build trusts.
* Tests are fast and need no window (`AGENTS.md`).

## Considered Options

1. Each area is a gem in a folder of its own under `gems/` in the game's repository, with its own gemspec, tests and type check; the code the areas share is a gem that each area's gem names; each store's code becomes a gem in the same way. The game takes each by its path, and none is published.
2. The areas and each store's code stay folders of one program, kept apart by `test/areas_test.rb`, the type checker's targets and packaging's lists of what a build leaves out.
3. Each area is a gem published to a gem server, or kept in a repository of its own, and the game takes released versions.

## Decision Outcome

Chosen: option 1, the maintainer's decision. The refactorings he agreed in the November 2026 workshop asked for the gems. Coding agents then built option 2 and treated the gems as optional, because option 2 already keeps another store's code out of a build. He corrected that: "It was done because of independent deployability, a cornerstone of Martin's 2017 book." Option 2 fails that driver: nothing in it can be tested or released without the game.

The record holds no comparison in his words of option 1 with option 3. Whether the gems are ever published is not decided, and nothing in option 1 needs it or rules it out. Where the gems live (`gems/`, beside `lib/`, so the game stays at the repository's root), that the game takes them by path, and that the code the areas share is one gem, `dot_popper-shared`, were chosen by coding agents; the shared gem was preferred to a copy of that code in each area's gem (two HTTP clients to keep the same) and to leaving it in the game (then no area's gem loads alone).

Confidence: high that the decision is in force; low that the code meets it yet. Gameplay and Metagame (`gems/dot_popper-gameplay`), Monetization (`gems/dot_popper-monetization`) and the shared code (`gems/dot_popper-shared`) are gems, and each one's own tests pass in a Ruby that holds nothing else of the game; most of Monetization's tests need the test build's code and stay with the game. Release Engineering and each store's code are still folders. A gem taken by path, and one that names another, builds and plays on Linux, Windows, macOS, Android and iOS. No gem has been released apart from the game or used by another program, and how a build for sale will take only its own store's gem from one lock file is not yet designed.

### Consequences

* Good, because an area's tests run with only that area's gem and the shared one on the load path, so a reach outside the area fails there as well as in the guard.
* Good, because an area can be handed to another program as it is; setdef's server holds its own copies of rules and layouts the game also holds.
* Bad, because every route that builds an app had to learn each gem: the lock's path entries, the phone projects' Gemfiles, the lists of what an app leaves out of each gem, and, since `lota fuse` reads `conf.rb` with no bundle, each gem's `lib` put on the load path by hand wherever Ruby starts without Bundler. Each new gem repeats this.
* Bad, because every area's gem depends on the shared one, so a change there reaches all of them.
* Bad, because each gem brings a gemspec, a `Rakefile`, a `Steepfile` and a test helper, and `rake` runs each gem's tests and type check as well as the game's.
* Bad, for releases, because every gem is version 0.0.0 and taken by path: the repository's commit is the only statement of which versions work together.
* Neutral, because the game's own gems are the game: the privacy record's lists of the gems an app carries name other code only ([privacy](../design/privacy.md)).

### Confirmation

Each gem's own `rake test` and `rake steep` run in its folder, and the game's `rake` runs them. `test/areas_test.rb` reads every file of every gem under `gems/`, fails if one belongs to no area, and holds each to what its area may name; `test/area_loaders_test.rb` loads each area by itself, with no Bundler, and fails if it loads the shared code from outside its gem. `test/packaged_app_test.rb` fails if an app would carry a gem's tests or signatures, and `script/check_build.rb` checks a built app's own code, its gems among it. `test/privacy/declared_test.rb` holds the lists of shipped gems. CI builds and plays every app on every push, and the phone kits on a tag.

## More Information

How each build finds the gems is in [PACKAGING.md](../../PACKAGING.md#the-games-own-gems); what each part of the code may depend on is in [the architecture](../architecture.md#the-parts).
