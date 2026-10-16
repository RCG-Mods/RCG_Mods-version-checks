# RCG Mods version checks

One folder per resource, each with a `version.json`. The resources read it on start and every few hours and print a
notice in the server console when a newer version exists. Console only, never players.

Raw link read by each resource:

    https://raw.githubusercontent.com/RCG-Mods/RCG_Mods-version-checks/main/<Resource>/version.json

## Releasing an update

1. Bump `version` in the resource's `fxmanifest.lua`.
2. In `<Resource>/version.json`: set `latest` to the same version and add a release at the TOP of `releases`:

   ```json
   {
       "version": "0.2.0",
       "date": "2026-10-20",
       "severity": "important",
       "why": "One line on why it matters (optional).",
       "notes": ["What changed", "Another change"]
   }
   ```

   `severity`: `important` (red), `recommended` (yellow) or `optional` (green).
3. Commit and push to `main`. Servers see it at their next check (GitHub's raw cache can take ~5 minutes).

Check: the JSON must stay valid (`python -m json.tool <Resource>/version.json`). A broken file is ignored silently,
it never breaks a server.
