---
status: accepted
date: 2026-11-14
deciders: the maintainer (Kerrick Long) for Clean Architecture, Domain-Driven Design and the game's three areas; coding agents for this layer
---

# Use cases hold the rules that need two of the game's areas, and the composition root makes them

## Context and Problem Statement

The game's domain is in three areas, the maintainer's division ([ADR-0019](0019-clean-architecture-and-domain-driven-design-in-three-areas.md)): Gameplay and Metagame, Monetization, and Release Engineering. Some of the game's rules need two of them at once. A Free player with no games left is offered Pro instead of a game; a new achievement is shown at Game Over only to Pro, though it is earned and kept by anyone; friend groups hear of the achievements a player earned while Free once Pro arrives; a theme other than Classic, a friend group joined or created, and what the Achievements screen shows each depend on Pro.

These rules lived in the `Show`, the presentation's object that ties the screens to the core, beside what each screen draws, and the one way into a game was a private method there that a press on `Cabinet`'s Home could bypass. Where do the rules that need two areas live, who makes the objects that hold them, and how much of each rule may a screen decide?

## Decision Drivers

* The rules of play never know that Pro exists: `AGENTS.md` says "Pro never changes how the game plays or scores".
* Every way into a game spends exactly one free game ([ADR-0012](0012-free-games-20-then-3-a-day.md), [ADR-0016](0016-the-tutorial-is-a-layer-over-a-paused-game.md)), and nothing else may start one.
* Rules are tested without a window (`AGENTS.md`), and the typed core stays typed ([ADR-0004](0004-steep-checks-the-rules-strictly.md)).
* The presentation holds no rule and builds nothing of the game: the composition root puts the game together, and a screen carries out an answer it is given (Clean Architecture, as ADR-0019 adopts it).
* What a player sees, hears, scores or pays does not change.

## Considered Options

1. Use cases: one object for each thing a player does that needs two areas, in `lib/dot_popper/use_cases/`, each made with its collaborators by the composition root, which also subscribes it to what it hears. A screen calls a use case and carries out what it answers; an area that changes something another area cares about announces it.
2. Leave these rules in the `Show`, with the screens.
3. Put each rule in the area it mostly concerns, and tell that area about the other: `Cabinet` asks the free games before it starts a game, `Achievements` and the friend-group session ask `Entitlement` what to show and send.
4. Use cases only for starting a game, finishing one and buying Pro, with one Monetization question, "what does Pro unlock here?", in place of the three small ones for themes, friend groups and achievements.

## Decision Outcome

Chosen: option 1, because it alone keeps both areas ignorant of each other while giving each rule one home outside the screens. Option 3 fails the first driver: `Cabinet` would know that games are counted for a purchase, and the achievements would know Pro. Option 2 keeps the rules out of both areas, but in an object that is also every screen's state, where the one way into a game was a convention and the rules could be tested only through the screens. Option 4 has fewer objects, but leaves each screen to decide what a locked answer means, which is the part of the rule the fourth driver takes from the screens.

There are six use cases: `StartGame`, `FinishGame`, `BuyPro`, `UseTheme`, `JoinOrCreateFriendGroup` and `ViewAchievements`. The decision was first made on 2026-11-12 with three, made by the `Show`; two independent reviews of the code (2026-11-12 and 2026-11-13) found that the `Show` still held every area's objects, that screens still asked whether the player has Pro under other names, and that Game Over was right only by the order listeners were subscribed in. This record states the decision as it stands after that work.

Confidence: medium. Each use case is tested alone; two reviews compared a player's journeys and tens of thousands of the bot's frames, one across the composition root taking over the use cases and one from v0.9.20 to the trunk of 2026-11-14 on five systems, and found them identical but for one intended difference on the friend groups' code pad; the playtest releases v0.9.19 and v0.9.20 carry the layer. What stops a new two-area rule landing in a screen is two tests that read the built game and the code, which a name spelled at run time passes.

### Consequences

* Good, because the one way into a game is a class (`UseCases::StartGame`) holding the only object that can start one, so `Cabinet` starts a game only when asked, never on a press.
* Good, because each use case is tested alone, with memory stores and local fakes, and is checked by Steep with the core.
* Good, because Gameplay and Monetization meet only in a use case, or through an event one of them announces (`Entitlement::ProGranted`, `SetdefGone`, `SetdefHere`), so either can change without the other.
* Good, because the `Show` and its screens are handed no `Entitlement`, store or `FreeGames`, so a screen cannot decide what Pro allows from them.
* Bad, because there is one more layer to follow from a press to a rule, and each use case needs an RBS signature, with interfaces for the collaborators the core does not type.
* Bad, because three of the use cases hold little more than one question of Pro each, and a screen must ask one even for that.
* Bad, because the offer of Pro reaches the store only through `BuyPro`, which therefore passes on what the offer shows of the store (whether it sells, its price, its status, the key typed so far).
* Bad, because the answers a use case gives still tell Free from Pro (`:offer`, `BuyPro#offered?`, a count that is nil), so a screen can decide on them: Home and Game Over still ask whether a game is left and whether Pro is offered before Play, and only review stops more of it.
* Bad, because only starting a game is guarded: `Cabinet#finish` is public, so whatever holds the cabinet could have a game that was never played counted in Stats and sent to friend groups.
* Bad, because Ruby cannot forbid reflection: the guards are tests, and code that reaches a private object by a name built at run time passes them.
* Neutral, because an area told of another's event acts when it is told, on the game's thread: nothing waits, and nothing happens later than it did.

### Confirmation

`test/use_cases/` tests each use case without a window, and the `Steepfile` checks `lib/dot_popper/use_cases/*.rb`. `test/composition/root_test.rb` checks that the root subscribes the rules' listeners and that making a `Show` subscribes none. A cabinet has no method of its own that starts a game: it hands out its one `Cabinet::Starter` once (`test/cabinet_test.rb`), and `test/use_cases/start_game_test.rb` fails if any file but `UseCases::StartGame` and `composition/use_cases.rb`, in `lib/`, `script/`, `bin/`, `main.rb`, `conf.rb` or the Android kit, takes the Starter or reads it by reflection. `test/use_cases/pro_knowledge_test.rb` walks the game as the composition root builds it and fails if anything in the presentation holds what decides Pro, or if anything but the offer of Pro holds `BuyPro`; and, reading the code, fails if a file in `lib/` beyond Monetization's own code, the use cases and the composition root names Pro (`pro?`, `Entitlement`), or if the presentation or the shell calls `locked?` or `owned?` on a use case by name; neither sees a screen that decides on another of a use case's answers. `test/presentation/games_test.rb` checks that every way into a game asks `StartGame` once and starts nothing itself, and `test/presentation/show_test.rb` that Game Over shows a game's own numbers whatever order the listeners hear the rules in.

## More Information

Which use cases there are, what each takes and answers, and which events the areas announce are in [the architecture](../architecture.md#use-cases). The folders are not divided by area yet; revisit this record when they are.

This record restates the former ADR 0017, of 2026-11-12, with what changed after it. That record chose use cases over options 2 and 3 for three rules, and had the `Show` make them. Since then: three more follow the pattern (`UseTheme`, `JoinOrCreateFriendGroup`, `ViewAchievements`), kept apart rather than folded into one question (option 4); the composition root makes them all and subscribes every listener it makes, and nothing in the core, the use cases or the presentation subscribes itself; the `Show` and the screens are handed nothing that decides Pro; each use case answers what its screen carries out (`:offer`, `:go`, `:use`, a status), and its own `locked?` or `owned?` is private, though the answers still tell Free from Pro; `FinishGame` hears the rules' events itself and tells its own listeners each game it finishes; and only the `Cabinet::Starter` a cabinet hands out once can start a game.
