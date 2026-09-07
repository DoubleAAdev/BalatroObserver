local mod = SMODS.current_mod
local function load(name) return assert(SMODS.load_file(name, mod.id))() end
local JSON = load('json.lua')
local observer = load('observer.lua')(JSON)
BalatroObserver = {snapshot = function() return observer.snapshot(G) end}

-- Alternate complete files so a consumer can recover from an interrupted write.
-- Each file is a self-contained JSON record; readers select the greatest sequence.
local directory = 'balatro_observer'
local sequence, elapsed = 0, 0
local session = tostring(os.time()) .. '-' .. tostring(math.floor(love.timer.getTime() * 1000))
local previous_update = Game.update
function Game:update(dt)
    previous_update(self, dt)
    elapsed = elapsed + dt
    if elapsed < 0.2 then return end
    elapsed = 0
    local ok = pcall(function()
        local state = observer.snapshot(G)
        sequence = sequence + 1
        state.session, state.sequence = session, sequence
        state.observed_at = os.time()
        local encoded = JSON.encode(state)
        assert(love.filesystem.createDirectory(directory))
        assert(love.filesystem.write(directory .. '/state-' .. (sequence % 2) .. '.json', encoded))
    end)
    -- Never serialize error text: another mod's error may contain private game state.
    BalatroObserver.last_export_ok = ok
end
