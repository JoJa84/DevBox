# BRAND-RISK — "DevBox" trademark considerations

## The issue

Microsoft operates **Microsoft Dev Box** (Azure cloud developer workstation service, public since 2022) and has filed trademarks in the software developer tools space. Our product is a physical device preloaded with dev tools — close enough to Microsoft's product category that a reasonable consumer could be confused.

**Risk level: Medium.**
- Low-volume eBay listings are unlikely to draw attention.
- Amazon listings, especially at scale, are more exposed to brand-policing takedowns.
- A cease-and-desist is more likely than a lawsuit.

## What to watch for

- Visual identity that mimics Microsoft (Fluent-style icons, their blue palette, their typography choices).
- Taglines or descriptions that echo Microsoft's product page copy.
- Use of "Dev Box" as two words (matches Microsoft's usage exactly).

## Mitigations if we keep DevBox

1. **Compound name:** "DevBox Mobile" / "PocketDevBox" reads distinct enough to dodge most collisions.
2. **Visual distinction:** dark, minimal palette. No Microsoft-adjacent iconography.
3. **Description distance:** describe as "a refurbished Android phone with Claude Code preinstalled," not as "a dev box."
4. **Trademark search before 100 units:** if volume grows, pay a lawyer for a USPTO search. $300–$800.

## Alternate brand names (drop-in replacements)

1. **Loom** — short, weaves agent threads. My pick if we switch.
2. **Anvil** — forge metaphor, strong, dev-coded.
3. **Kiln** — fabrication in your pocket, more poetic.
4. **PocketFork** — literal git-fork-in-pocket, developer-native.
5. **Sidecar** — agent carried beside you.

Rename cost if we switch: ~15 min grep/replace across docs. No script or file path references the brand.

## Decision

Ship v0 beta under "DevBox." Monitor. Rename cheaply if signals turn.
