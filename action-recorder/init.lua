return function(mod, JSON)
    local function load(name) return assert(SMODS.load_file('action-recorder/'..name,mod.id))() end
    local recorder=load('mod/recorder.lua')(JSON,mod.version)
    local hooks=load('mod/hooks.lua')(recorder,JSON)
    BalatroActionRecorder=recorder
    hooks.install()
    local open_page=load('mod/open-viewer.lua')
    load('mod/launcher.lua')(function(request,status_file) return open_page(mod.path..'/action-recorder',request,status_file) end,mod)
    local original_start=Game.start_run
    if original_start then
        function Game:start_run(args,...)
            local function pack(...) return {n=select('#',...),...} end
            local result=pack(original_start(self,args,...))
            hooks.reset()
            local ok=pcall(recorder.begin,args and args.savetext~=nil)
            if not ok then recorder.ok=false end
            return unpack(result,1,result.n)
        end
    end
    local original_update=Game.update
    function Game:update(dt)
        local function pack(...) return {n=select('#',...),...} end
        local results=pack(original_update(self,dt))
        recorder.safe(hooks.reorders)
        recorder.safe(recorder.observe)
        if recorder.poll_launch then pcall(recorder.poll_launch) end
        return unpack(results,1,results.n)
    end
end
