---
status: accepted
date: 2026-11-14
deciders: the maintainer (Kerrick Long), who set the rule and chose to take a Lota that needs an unreleased Ruby; coding agents chose the tool
---

# `lota fuse` builds every desktop app, from a released Lota and Fledge and the Ruby that Lota needs

## Context and Problem Statement

Most players don't have Ruby, so Dot Popper ships as a self-contained app for macOS, Windows and Linux, and as playtest kits. Lota's maintainer stopped building Dot Popper's kits, and the maintainer asked that Dot Popper build its own artifacts with Lota, using only released tools. Lota 0.5 then required Ruby 4.1, which is not released, and the maintainer took it knowing so. Which tool builds the desktop apps, and from which Lota, Fledge and Ruby?

## Decision Drivers

* Only released tools, where a release exists: a Lota release gem, checked against that release's `SHA256SUMS`, and a tagged Fledge.
* The Ruby is the one that Lota release is built for, and every machine gets the same bytes of it.
* One way to build, so CI and a developer's machine make the same app.
* Each platform builds on its own runner, since Fledge builds only for the computer it runs on.

## Considered Options

1. `lota fuse`, Lota's documented way to share a game, which writes a Fledge project around the game and runs `fledge build` in it.
2. `bundle exec fledge build` from this repository's own `fledge.yml` and `bin/dot_popper` launcher.

## Decision Outcome

Chosen: option 1, because it is Lota's documented route and it did everything the Fledge build did, so there was no reason to keep a second way.

The Lota is a release (0.5.2) and the Fledge the tag that release's `lota fuse` builds with (v0.12.0). The Ruby is the one that Lota needs, pinned in `mise.toml`: until Ruby 4.1.0 is released, the preview 4.1.0-preview1 on Linux and macOS, and on Windows RubyInstaller's head build of 2026-11-10, the copy a Fledge release keeps, fetched by URL and checked against a pinned SHA-256, because RubyInstaller publishes no 4.1 preview and Lota's Windows gems are built on that build. The rule of released tools is kept for Lota and Fledge and set aside for the Ruby, by the maintainer's choice of that Lota; holding the game on the last Lota that ran on a released Ruby was the alternative, and he did not take it.

Confidence: high for the tool; the Package workflow builds and plays each desktop app with it on every push to `trunk`. Medium for the Ruby: the move was proven before it landed on Linux, Windows, macOS and Android, with a fused Windows app played, save files from the last release read byte for byte the same, and allocations per frame 9% higher, inside the 10% the project allows; no player has a build on it yet.

### Consequences

* Good, because the app is what Lota supports, and its notices (`NOTICES.txt`) and lockfile checks come with it.
* Good, because `lota fuse --exclude` keeps repository-only files (tests, docs, scripts, hosts) out of the app.
* Bad, because `lota fuse` builds no phone app: the iOS and Android builds still use Fledge directly, by Lota's phone guide, with `bin/dot_popper` and `fledge.yml`'s `programs:` entry.
* Bad, because `lota fuse` chooses the Fledge it builds with, so a Fledge upgrade for the desktop apps waits for a Lota release.
* Bad, because every build carries a Ruby that is not a release until Ruby 4.1.0 is: on Windows a dated head build that only a Fledge release keeps, which another day's head build cannot stand in for.
* Bad, because the Windows Ruby needs help the released ones did not: a folder named for its DLLs (`RUBY_DLL_PATH`), and CI's Windows jobs an action of their own to fetch and check it.
* Neutral, because `fledge.yml` still holds the version every build takes.

### Confirmation

`.github/actions/fuse/action.yml` is the one build step, used by `package.yml` and `kits.yml`; each built app plays itself for 20 seconds with no Ruby on its PATH before it is uploaded. The `Gemfile` refuses any Ruby but the pinned one (on Windows, by the head build's own version), and `.github/actions/windows-ruby` gives CI's Windows jobs the file `mise.toml` pins, failing if its SHA-256 differs.

## More Information

[PACKAGING.md](../../PACKAGING.md) describes the build, what goes into the app, and the playtest kits; `mise.toml` says where the Windows Ruby comes from and why. Revisit when Ruby 4.1.0 is released: the pins then name releases only, and the two costs above go.

This record restates the former ADR 0006, of 2026-11-05, which said every tool was a release; that held until the move to Lota 0.5 on 2026-11-14.
