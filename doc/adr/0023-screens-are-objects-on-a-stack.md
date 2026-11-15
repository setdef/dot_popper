---
status: accepted
date: 2026-11-14
deciders: the maintainer (Kerrick Long) for Clean Architecture and Domain-Driven Design; coding agents for screens as objects on a stack, and this design
---

# Screens are objects on a stack, and the one on top answers every input

## Context and Problem Statement

The maintainer has decided that the game's code follows Clean Architecture and Domain-Driven Design ([ADR-0019](0019-clean-architecture-and-domain-driven-design-in-three-areas.md)). In the presentation, `Presentation::Show` was the state of every screen at once: a screen was not an object but a combination of a page symbol, flags for the offer of Pro, an achievement's dialog and the share preview, the friend groups' panel's own state and the game's. Which screen was on top was decided again in about fifteen if-chains, in different orders: what can be pressed, what Enter, Escape, Start and each gamepad button do, what a typed key does, what scrolls, which presses wait for their release, and what the renderer draws, some of them in `Shell::App` and `Shell::Renderer`. Adding a screen touched eight to ten places, and the chains disagreed in corners a player could reach: a controller's Y did nothing on the offer over Game Over, the new theme card let a controller and H act on Home under it, the offer and an achievement's dialog let the list hidden under them scroll, several screens popped a dot of Home's under their veil, and an announcement of a title change could pass unseen.

How do the presentation's screens hold their state and answer the player's input?

## Decision Drivers

* One place decides which screen is on top; every input, and the renderer, asks it.
* Each screen answers for itself what can be pressed and where, what each press does, its main and Back actions, each gamepad button, what scrolls and what a typed key does.
* Adding a screen names it in as few places as can be, and a test fails for each place left out.
* Nothing a player sees, hears, presses, scores or pays changes, except where the chains disagreed, each case decided and recorded.
* No Lota outside the shell; the presentation's tests need no window ([ADR-0005](0005-gui-scenarios-play-the-real-game.md) keeps the GUI scenarios for the window).
* No more work per frame than before.

## Considered Options

1. **A stack of screen objects.** One object per screen (`Presentation::Screens`), made once with the `Show`. A screen opened over another is pushed on a stack over the screen for the game's state (Home, the Tutorial, a game, Game Over), and only the one on top is closed. `Show#screen` is the top of the stack, or with none open the screen for the state; every input asks it, and the renderer draws the stack.
2. **Screen objects chosen from flags.** The same objects, with the `Show` keeping a flag for each and one if-chain in `Show#screen` choosing among them.
3. **Keep the flags and the chains**, and add tests that the chains agree.
4. **A graph of screens**, each naming the screens it may go to and from, as `Cabinet`'s states do for the game.

## Decision Outcome

Chosen: option 1, because it is the one in which no flag, no arm of a chain and no table of moves names each screen: a screen opens itself over the one in view, and Back closes it. Option 2 was the first step of this work, and kept a flag and an arm of `Show#screen` for every screen. Option 3 leaves every disagreement possible in a new chain, and adding a screen still touches every chain. Option 4 lists for each screen the screens under it, which the stack already knows, since every screen over Home or Game Over goes back to the one it was opened over.

When this was first decided, on 2026-11-13, its reason was that option 1 alone made adding a screen one object. It does not, and two independent reviews of the code showed how far short it fell. A screen is its class and its painter, a line in each of four lists (the presentation's load list, the table the screens are made from, `Screens::ALL`, the shell's load list, and the renderer's table of what paints each screen, `Shell::Renderer::PAINTS`), and a button on the screen it opens from. It touches no method of the `Show`: the `Show` tells every screen, open or not, each thing a screen may need to hear (a frame passing, a press let go, a hold stopped, a screen over Home opening or closing, a game starting, the window resized, the input in use), and names none of them.

Confidence: medium. When the stack was made, the tests that walk every screen at every size and play each input alone passed unchanged in what they check, and gallery screenshots taken before and after matched byte for byte where the galleries are repeatable. An independent review then pressed 40 inputs on 29 ways to a screen, on a computer, Android and iOS, Free and Pro, before and after the work that followed the first review, and found one difference that work meant (an achievement's dialog no longer lets the grid under it scroll); the same comparison across the work after that found none but generated license keys and renamed controls. Mutating the stack's rules, 13 of 15 changes fail a test and the other two change nothing; every deletion of a screen's answer that was tried fails one, and not all were tried. The playtest releases v0.9.19 and v0.9.20 carry the stack; what followed the first review is on the trunk only.

### Consequences

* Good, because each input is one call to the screen on top, so the chains can no longer disagree, and the corners where they did now agree, each by what a player would expect (recorded, with the books that decide each, in [screens](../design/screens.md#screens-as-objects)).
* Good, because a screen's state lives in its object (the dialog's achievement, the share preview's text, the offer's focus, Stats' hold and Undo, each list's scroll, the Tutorial's scene), and the `Show` keeps what is not a screen: the game's feedback, the stack, and the use cases it is given.
* Good, because Back returns to the screen under the one on top as it was, by closing the top of the stack, where a list of screens did it before.
* Bad, because the screens reach into the `Show` for what they share (the layout, the words, the effects), so the two know each other.
* Bad, because each screen is made once and reused, so a screen's state must be reset as it opens; a forgotten reset shows the last visit's state.
* Bad, because a screen is still named in four lists besides its own class, and the `Show` keeps a one-line method for each value a painter reads from a screen that does not yet hand its painter one value to draw.
* Bad, because two kinds of question ask the stack, and a caller must know which it wants: whether a screen is on top (`#stats?`, `#settings?` and their like), or whether it is open anywhere (`#offer?`, `#sharing?`, `#dialog`, the friend groups' `#open?`), since the offer opens over the friend groups and they are still open under it.
* Neutral, because the friend groups' pages are still the `GroupPanel`'s, inside one screen object, which tells the stack as they open and close and asks it whether they are open.
* Neutral, because several screens build their plans and words on each call, as the `Show` did before; allocations per frame are equal or lower on every screen.

### Confirmation

`test/presentation/stack_test.rb` holds the stack's rules in a table: what a push and a close do, what Home and a new game clear, and which questions ask the top and which the whole stack. `test/presentation/inputs_test.rb` fails if a control a screen declares (each screen's `#answers`) or a screen object is reached by no input, pressing each through `Presentation::InputHandler` as the game does. `test/presentation/screen_answers_test.rb` holds, in a table for each screen, what every press does there, and fails for a screen with no table. `test/presentation/screen_hooks_test.rb` fails if a screen does not hear what the `Show` tells every screen. `test/shell/renderer_screens_test.rb` fails for a screen the renderer cannot paint. `test/presentation/screen_plans_test.rb` walks every screen at every size. The GUI scenarios play the real game in a window.

## More Information

Which screens there are, what each answers, how the stack opens and closes them, what adding one touches, and each corner where the chains disagreed are in [screens](../design/screens.md#screens-as-objects); how each input reaches the screen on top is in [input](../design/input.md).

This record restates the former ADR 0018, of 2026-11-13, with what two reviews and the work after them changed: its reason for the outcome, which did not hold; the driver that nothing is made each frame, which was never true; the stack made a stack in fact, with its rules held by a test; the `Show` no longer calling particular screens; and a test for each place adding a screen touches.
