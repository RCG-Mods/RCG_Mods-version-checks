# RCG Mods version checks

Update notices for every RCG Mods resource. One folder per product, each with a `version.json`; one shared Lua file
(`_module/rcg_version.lua`) inside each resource reads it on start and every few hours and prints a notice in the
server console when a newer version exists. Console only, never players.

| Folder | Resource |
|---|---|
| `RCG_decorations` | RCG_decorations |
| `RCG_terminal` | RCG_terminal |
| `RCG_megaphone` | rcg_megaphone |
| `RCG_trickortreat` | RCG_trickortreat |
| `RCG_IDSS` | RCG_IDSS |

Raw link each resource reads:

    https://raw.githubusercontent.com/RCG-Mods/RCG_Mods-version-checks/main/<Folder>/version.json

## Adding the check to a resource

1. Copy `_module/rcg_version.lua` unchanged into the resource (e.g. `server/rcg_version.lua`).
   Check: it is byte-identical to the one here (the same file in every resource; fix it here, then copy again).
2. In its `fxmanifest.lua`:
   - list it under `server_scripts` (after the config file, if the resource has a `Config`);
   - add `rcg_product '<Folder>'` next to `version`. This is the folder name here, NOT the resource name: owners
     rename resources. Without it the resource's current name is used.
   Check: `version` in the manifest is the version you are shipping.
3. Optional, in the resource's config: `Config.UpdateCheck = { enabled = true, url = '', hours = 6 }`
   (`enabled = false` = off for that resource; `url` = another file; leave '' for ours).
4. Add `<Folder>/version.json` here (copy another one; `latest` = the version you are shipping).

Server owners can turn it off for every RCG resource at once with `set rcg_updatecheck false` in `server.cfg`.

## Releasing an update

1. Bump `version` in the resource's `fxmanifest.lua`.
2. In `<Folder>/version.json`: set `latest` to the same version and add a release at the TOP of `releases`:

   ```json
   {
       "version": "0.2.0",
       "date": "2026-10-20",
       "severity": "important",
       "why": "One line on why it matters (optional).",
       "notes": ["What changed", "Another change"],
       "url": "https://... (optional: where to download it)"
   }
   ```

   `severity`: `important` (red), `recommended` (yellow) or `optional` (green).
3. Commit and push to `main`. Servers see it at their next check (GitHub's raw cache can take ~5 minutes).

Check: the JSON must stay valid (`python -m json.tool <Folder>/version.json`). A broken file is ignored silently, it
never breaks a server.

Common mistake: setting `latest` higher than what customers can download - every server then announces an update
that is not out yet. Push the json only once the new version is on Tebex / the store.
