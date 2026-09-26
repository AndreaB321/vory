# Vory bots — a brief for animation ideas

Vory is an iPhone app (iOS 26/27, SwiftUI with Liquid Glass) that is a remote control for a
self-hosted AI agent gateway. Every AI "profile" on the gateway is shown as a **bot**: a small
procedurally-drawn character with a body shape, a colour, two eyes and a finish. The bots are
the app's whole personality — there are no other illustrations. I want ideas for how they should
move. Please read how they work today, then suggest animations that fit the rules at the end.

## What a bot is made of

A bot is fully described by four values (`BotLookSpec`): `shape`, `eyes`, `hex` (colour) and
`finish` (`flat` or `glass`). Everything is drawn from code (SwiftUI `Path`/`Canvas`), so any
part can be animated by number: no sprite sheets, no Lottie.

**Body shapes (8):** `circle`, `blob` (a soft organic shape whose outline slowly morphs while the
bot works), `square` (rounded), `pill` (wide capsule), `triangle` (rounded corners), `hexagon`,
`cloud` (three bumps on top, flat bottom — this is also the app's own mascot "Vory", a blue
glass cloud), `drop` (a teardrop with the point at the top).

**Eye styles (8):** `classic` (two upright rounded rectangles), `tall`, `tiny` (two dots),
`round`, `wide` (short and wide), `curious` (one round, one tall — asymmetric), `bold` (big
uprights), `sleepy` (two closed-lid arcs, drawn as strokes). Eyes are near-black on every body.

**Colour:** any hex; there are 13 presets plus a custom colour. Note white bots exist, so
outlines/shadows matter.

**Finish:** `flat` paints the body as a solid colour with a subtle top highlight. `glass`
(Liquid Glass, iOS 26+) makes the body a tinted piece of real system glass — it refracts what is
behind it, has a specular rim and a soft shadow — with the eyes a second, darker piece of glass
sitting in front. Glass is live only on screen; in menus, the app switcher and widgets it is a
painted imitation of the same look. Glass cannot be re-created every frame cheaply, and
re-creating a glass view makes it "materialize" (bloom in), which we never want.

## What the bots already do

**Eyes (all bots, even idle ones):**
- Blink every ~4.3 s for 150 ms; every third blink is a double blink. Blink = the eye squashes
  vertically to a line.
- Glance to one side every ~7 s, held a moment, then back (eyes slide sideways together).
- Every bot has a different phase (seeded by shape + eyes + name) so a page of bots never
  blinks in unison.
- **Gaze**: when you scroll a list, all bots' eyes follow the scroll direction (up/down) and drift
  back to centre 450 ms after scrolling stops. Eased over 0.35 s.
- **Tilt** (opt-in BETA): the phone's gyroscope tilts the bot a few degrees in 3D, and past ~15°
  of tilt the eyes stop wandering and follow the phone instead.
- **Thinking**: while the bot is thinking hard, the eyes narrow to a squint (open ≈ 42 %).

**Body (only while the bot is working, i.e. mid-reply):**
Time is cut into 5-second blocks; each block picks one routine by `(block + seed) % 6`, plays
it in the first ~1 s of the block, and rests for the remainder. Routines:
1. **Full turn** — a 360° yaw about the vertical axis (a coin turn, `rotation3DEffect` with
   perspective 0), 1.15 s, eased "slow start, quick middle, slow stop".
2. **Glance turn** — a partial yaw of ±0.45 rad and back, 1 s.
3. **Head tilt** — a roll of ±4° once each way, 1.1 s.
4. **Nod** — two tiny dips of 2 % of the size, 0.8 s.
5. **Lean** — ~3.5° roll plus a 1.2 % sideways shift and back, 0.9 s.
6. **Rest** — nothing.
- **Finish spin**: the moment a reply finishes, the bot does one full turn wherever it is shown
  (chat header, chat list, Live Activity), whatever else is going on.
- The `blob` shape's outline slowly morphs while working ("breathing" of the silhouette).
- Nothing ever scales, and nothing leaves the bot's footprint (the header pill and list rows
  are laid out around it).

**Where bots appear (each place may deserve its own behaviour):**
- **Bots page**: a grid of cards — a 78-pt bot sitting on a glass pill with its name and model.
  Bots on this page play their routines while the page is being scrolled, and follow tilt.
- **Chats list**: 40-pt bots on each row (when "all bots" is shown); their eyes follow scroll.
- **Chat header**: a 52-pt bot sitting on a pill with its name; this one shows thinking/working
  state and the finish spin. Its status line below says "thinking…", "using tools", etc.
- **Beside reply bubbles**: a 28-pt bot at the bottom-left of the last bubble in a run of
  replies (like Messages/iMessage group chats).
- **Group chats**: several bots overlapped when the room is empty; each member's bot beside its
  message.
- **Toolbar profile button** (26 pt), **Settings profile picker**, **context-menu previews**:
  static painted renders.
- **Live Activity / Dynamic Island**: a Canvas-painted bot (no live glass, no timers, so
  animation there is limited to what a widget timeline can do) with phase glyphs
  (brain = thinking, bubble = streaming, wrench = tool, warning triangle = needs approval,
  yellow).
- **Notifications**: the bot's painted face as the sender avatar.
- **Onboarding tour & setup wizard**: "Vory" (the blue glass cloud) at the top with a typed
  speech bubble, doing looping demos.
- **App icon**: the Vory cloud in layered glass.

## Constraints (the owner's taste — please respect these)

- **Subtle.** Earlier versions had bots that hopped, bounced, bloomed and scaled; the owner
  called it "too much". Motion should be gentle, in place, quick but eased, and rare — a bot
  should feel alive, not busy.
- **No scaling, no pop/bloom, no bounce.** The bot must stay inside its own square.
- The 360° coin-turn is loved: slow ramp up, fast middle, slow stop, "one quick stroke".
- Idle bots should barely move (eyes only) — dozens can be on screen and they must be cheap.
- Every bot has its own timing (seeded), so a group never moves in unison.
- Animations must work for every shape (a triangle and a pill get the same routine) and for
  glass (3D rotations are fine; re-creating the view or changing its shape identity is not).
- Reduce Motion must fall back to still bodies (eyes may still blink).
- Bots often sit on a pill; anything that lifts them off it needs to look deliberate.

## What I'm looking for

Ideas for:
1. **Working routines** to add to or replace the six above (yaw/roll/offset/eye-only moves).
2. **State-specific moments**: thinking (currently squint), using a tool, waiting for approval
   (the bot needs a "yes" from the user — how should it ask?), an error, reconnecting, a reply
   arriving, being tapped.
3. **Idle life**: rare, tiny things an idle bot could do without looking busy.
4. **Group behaviour**: two to six bots together — reactions to each other, taking turns.
5. **Per-shape or per-eye flavour**: should the drop, cloud or curious-eyed bot move a little
   differently?
6. **Vory itself** (the mascot cloud) in the tour, setup wizard and "Check for updates".

For each idea: what moves (yaw, roll, x/y offset, eye openness, eye position, outline), the
duration and easing, how often it should happen, and where it should show. Keep it to
things a SwiftUI `TimelineView` + `rotation3DEffect` / `rotationEffect` / `offset` and Path
parameters can do.
