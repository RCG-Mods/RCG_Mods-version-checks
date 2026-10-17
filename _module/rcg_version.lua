-- RCG Mods update notice - ONE file shared by every RCG resource (master copy: github RCG-Mods/RCG_Mods-version-checks,
-- _module/rcg_version.lua; copy it unchanged into a resource and list it as a server_script).
--
-- On start (and every few hours) it reads <product>/version.json from that repo and, when it lists a version newer
-- than the one installed (fxmanifest.lua `version`), prints the release notes in the server console. Console only,
-- never players. It must never break the resource: no answer, a slow answer or bad JSON = silent (one dim line with
-- Config.Debug).
--
-- Which product: fxmanifest.lua `rcg_product 'RCG_terminal'` (the folder name in the repo). Not the resource's
-- name: owners rename resources. Missing = the resource's name.
-- Settings (all optional), the resource's own Config.UpdateCheck = { enabled = true, url = '', hours = 6 }:
--   enabled = false   off for this resource
--   url               another file instead of ours ('' = ours)
--   hours             how often
-- Convar `rcg_updatecheck false` (server.cfg: set rcg_updatecheck false) = off for EVERY RCG resource at once.

local REPO = 'https://raw.githubusercontent.com/RCG-Mods/RCG_Mods-version-checks/main/%s/version.json'
local FIRST_DELAY = 15000       -- ms after start, so the notice does not mix with the start logs
local EVERY_HOURS = 6
local TIMEOUT = 10000           -- ms; an answer later than this is ignored

local RES = GetCurrentResourceName()
local PRODUCT = GetResourceMetadata(RES, 'rcg_product', 0)
if type(PRODUCT) ~= 'string' or PRODUCT == '' then PRODUCT = RES end
local SEVERITY = {              -- colour + label; unknown severities read as optional
    important   = { '^1', 'IMPORTANT' },
    recommended = { '^3', 'recommended' },
    optional    = { '^2', 'optional' },
}

local function cfg()
    local c = type(Config) == 'table' and Config.UpdateCheck
    return type(c) == 'table' and c or {}
end

local function debug(msg)
    if type(Config) == 'table' and Config.Debug then print(('^8[%s] update check: %s^7'):format(RES, msg)) end
end

local function off()
    local v = GetConvar('rcg_updatecheck', 'true'):lower()
    return cfg().enabled == false or v == 'false' or v == '0' or v == 'off'
end

-- '1.10.0', 'v1.9.2', '2.0' -> { 1, 10, 0 }. Anything after '-' or '+' (1.2.0-beta) is ignored. nil = not a version.
local function parse(v)
    if type(v) == 'number' then v = tostring(v) end
    if type(v) ~= 'string' then return nil end
    v = v:match('^%s*[vV]?([%d%.]+)')
    if not v then return nil end
    local parts = {}
    for n in v:gmatch('%d+') do parts[#parts + 1] = tonumber(n) end
    return #parts > 0 and parts or nil
end

-- Compared part by part as numbers (1.10.0 > 1.9.2); missing parts count as 0 (1.2 == 1.2.0). -1 / 0 / 1.
local function compare(a, b)
    for i = 1, math.max(#a, #b) do
        local x, y = a[i] or 0, b[i] or 0
        if x ~= y then return x < y and -1 or 1 end
    end
    return 0
end

-- Releases newer than `installed`, newest first, each version once. Bad entries are skipped, not fatal.
local function newerReleases(data, installed)
    local list, seen = {}, {}
    if type(data.releases) == 'table' then
        for _, r in ipairs(data.releases) do
            local p = type(r) == 'table' and parse(r.version)
            if p and compare(p, installed) > 0 then
                local key = table.concat(p, '.')
                if not seen[key] then seen[key] = true; list[#list + 1] = { parts = p, r = r } end
            end
        end
    end
    -- `latest` newer but missing from the list: still worth one line
    local latest = parse(data.latest)
    if latest and compare(latest, installed) > 0 and not seen[table.concat(latest, '.')] then
        list[#list + 1] = { parts = latest, r = { version = data.latest } }
    end
    table.sort(list, function(a, b) return compare(a.parts, b.parts) > 0 end)
    return list
end

local function printNotice(data, list, installed)
    local top = list[1].r
    local name = RES == PRODUCT and RES or ('%s (%s)'):format(RES, PRODUCT)
    print(('^3==== [%s] update available: %s -> %s ====^7'):format(name, installed, tostring(top.version)))
    for _, e in ipairs(list) do
        local r = e.r
        local sev = SEVERITY[type(r.severity) == 'string' and r.severity:lower() or ''] or SEVERITY.optional
        local date = type(r.date) == 'string' and (' (' .. r.date .. ')') or ''
        print(('%s  %s%s - %s^7'):format(sev[1], tostring(r.version), date, sev[2]))
        if type(r.why) == 'string' and r.why ~= '' then print(('%s    Why it matters: %s^7'):format(sev[1], r.why)) end
        local notes = type(r.notes) == 'string' and { r.notes } or (type(r.notes) == 'table' and r.notes or {})
        for _, n in ipairs(notes) do
            if type(n) == 'string' or type(n) == 'number' then print('    - ' .. tostring(n)) end
        end
    end
    local url = type(top.url) == 'string' and top.url or data.url
    if type(url) == 'string' and url ~= '' then print(('^5  Download: %s^7'):format(url)) end
    print(('^3==== [%s] ====^7'):format(name))
end

-- Called with the raw answer; every check on the data is here so a bad file can only end in silence.
local function handle(status, body, installedText)
    if status ~= 200 or type(body) ~= 'string' or body == '' then return debug('no answer (status ' .. tostring(status) .. ')') end
    local ok, data = pcall(json.decode, body)
    if not ok or type(data) ~= 'table' then return debug('the file is not valid JSON') end
    if data.latest == nil and type(data.releases) ~= 'table' then return debug('the file has no "latest" or "releases"') end
    local installed = parse(installedText)
    if not installed then return debug('installed version unreadable: ' .. tostring(installedText)) end
    local list = newerReleases(data, installed)
    if #list == 0 then return debug(('up to date (%s)'):format(installedText)) end
    printNotice(data, list, installedText)
end

local busy = false              -- one request at a time; a hung one is released by the timeout
local function check()
    if off() then return end
    local url = (type(cfg().url) == 'string' and cfg().url ~= '') and cfg().url or REPO:format(PRODUCT)
    if not url:match('^https?://') then return debug('no URL set') end
    if busy then return end
    busy = true
    local done = false
    local installedText = GetResourceMetadata(RES, 'version', 0) or '?'
    SetTimeout(TIMEOUT, function()
        if not done then done = true; busy = false; debug(('no answer in %d s'):format(TIMEOUT // 1000)) end
    end)
    local ok, err = pcall(PerformHttpRequest, url, function(status, body)
        if done then return end     -- too late, the timeout already gave up on it
        done = true; busy = false
        local hok, herr = pcall(handle, status, body, installedText)
        if not hok then debug('error reading the answer: ' .. tostring(herr)) end
    end, 'GET', '', { ['Accept'] = 'application/json', ['Cache-Control'] = 'no-cache' })
    if not ok then done = true; busy = false; debug('request failed: ' .. tostring(err)) end
end

CreateThread(function()
    Wait(FIRST_DELAY)
    while true do
        check()
        local hours = tonumber(cfg().hours) or EVERY_HOURS
        Wait(math.max(1, hours) * 3600000)
    end
end)

-- For an offline test only (nothing uses it).
RCG_VersionCheck = { parse = parse, compare = compare, newer = newerReleases, handle = handle, check = check, product = PRODUCT }
