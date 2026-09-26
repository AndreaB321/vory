# FOLLOW-UP — second cut of the Bots grid

(The user's second motion brief, 2026-09-26. It amends `bot-motion-brief.md`: the named state
holds below may morph the silhouette; idle, guide and the working loops still do not.)

## What the demo got wrong

1. Thinking, using tool, approval, error, reconnecting, and streaming were the same face with a
   slightly different squint. A paused screenshot could not tell them apart.
2. Working bots rested about 4 seconds out of every 5. The page looked frozen.
3. Approval was a yellow triangle sitting there. It must become a rounded exclamation and HOLD.
4. Error was a permanent dash-face (asleep, not broken). Reconnecting never showed an eye sweep.
5. The white pill nearly disappeared on `#F2F2F7`.
6. Guide (Vory) lived the same life as "working · cloud".

Success test: pause on any frame and each labeled state is obvious without reading the caption.
Approval must read as "!" with the caption covered.

## What still must not change

- Never scale the body. Never bounce, hop, bloom, materialize, or pop. The square footprint stays put.
- Never destroy and recreate the glass view. Morph = one continuous path on the SAME view. Eyes
  may hide; the plate does not.
- Eyes stay near-black. No white cutouts. No rainbow orbits, no comet tails, no second character.
- Finish spin stays the 360° yaw (slow–fast–slow, ~1.15 s). It does not morph.
- Reduce Motion: skip the morph, jump to the end pose, body frozen, eyes may blink.
- Flat and glass are twins of the same path. Glass only adds refraction, specular rim, contact shadow.

## State holds — morph these, then HOLD until the state ends

Ease in 0.45–0.7 s, hold, morph back 0.4 s when the state ends.

| State | What changes | Hold |
|---|---|---|
| approval | Path becomes a bold rounded exclamation: thick vertical stem + separated dot, one path, inside the same square. Slight +8° roll. | Eyes hidden. This is the ask. |
| thinking | Same bounds, mass shifts into the lower half: a shorter heavier pebble. Not a smaller scale. | Eyes at 0.42, slow blink. |
| using tool | A small rounded stem grows out of the TOP of the body (lollipop / key), part of the path. | Eyes glance down-right and stay. |
| error | No "!". Eyes drop and close to dashes and STAY shut. Body rolls −4°. Crown highlight / rim dies. | Reads broken, not sleepy. |
| reconnecting | NO shape change. Eyes metronome left–right every 1.1 s, obvious at 78 pt. | Eyes open. |
| streaming | NO shape change. A rim sheen loops every 2.2 s. Eyes hold a squint (0.55). | Only "tokens arriving" motion. |
| idle | NO morph. Sleepy cloud keeps weighted lids. | Eyes only. |
| idle · curious | NO morph. Occasional blink, rare glance. | Eyes only. |
| guide (Vory) | NO morph and NOT a working routine. Blink, glance toward the speech bubble, one rim sheen, a tiny nod. Flat bottom planted. | Distinct from working · cloud. |
| working · * | NO morph. Body routine ~1.1 s, then rest **2 s**, not 4 s. Seeded. | Coin-turn remains the hero. |

White / light bots: 1 px inner stroke at 40 % `#D0D0D5` plus a crown highlight that stays visible
on `#F2F2F7`.

Working-block timing: 3.2 s blocks (~1.1 s stroke, ~2.1 s rest); `coinEase` unchanged. Animate
`morph` with a ~0.55 s ease-in-out on the same view, never by swapping views (that makes Liquid
Glass bloom).
