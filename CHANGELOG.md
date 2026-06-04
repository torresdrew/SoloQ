# Changelog

## Unreleased

- Hid the rat applicant-list overlay while applicant evaluation is disabled.
- Added an always-on rat overlay that covers Blizzard's applicant list while SoloQ is active in the Mythic+ applicant viewer.
- Added a panel checkbox and dropdown for playing a selected ready sound when a complete proposed group becomes available.

## v0.1.0

First release.

- Side panel in Blizzard's application viewer for the group leader on an active Mythic+ listing.
- Scores solo applicants against a single minimum Mythic+ rating and flags them to invite or decline.
- One-click **Invite** / **Decline** actions (kept click-driven to respect Blizzard's protected-function rules).
- **Proposed group builder** — fills a full tank / healer / three-DPS composition around your own role and current party; **Invite Group** lights up when the group is complete.
- Optional **Bloodlust/Heroism** and **Battle Res** requirements for the proposed group.
- Queued applicant groups are included when every member passes the score gate.
- **SoloQ: Prep Key** button on the Group Finder to prepare your owned keystone listing, with the hero_rat icon.
- Slash commands: `/soloq` (toggle the panel), `/soloq reset`, `/soloq debug`.
- Supports Retail game versions 12.0.7 and 12.0.5.
