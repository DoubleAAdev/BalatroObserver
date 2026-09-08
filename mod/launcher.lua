-- Viewer shortcut in the Steamodded mod settings. Opening requires a click.
return function(open_viewer, mod)
    if not G or not G.FUNCS then return end
    local pending, counter = nil, 0
    local status_path='balatro_observer/viewer-launch-status.txt'
    local function label(text)
        BalatroObserver.launch_label=text
    end
    -- Short reason shown under the button; the full text is in viewer-launch.log in the mod folder.
    local function detail(text)
        text = text or ''
        if #text > 90 then text = text:sub(1, 87) .. '...' end
        BalatroObserver.launch_error = text
    end
    G.FUNCS.bobs_open_viewer = function()
        if pending then return true end
        -- LÖVE's browser opener is already known to work on the player's machine.
        if love.system.getOS()~='Windows' then return love.system.openURL('http://127.0.0.1:8765') end
        counter=counter+1
        local request=tostring(os.time())..'-'..counter
        love.filesystem.createDirectory('balatro_observer')
        label('Starting viewer...'); detail('')
        pending={id=request,deadline=love.timer.getTime()+15}
        local ok, message = open_viewer(request,love.filesystem.getSaveDirectory()..'/'..status_path)
        if not ok then pending=nil; label('Viewer failed - retry'); detail(tostring(message)) end
        return ok
    end
    BalatroObserver.poll_launch=function()
        if not pending then return end
        -- Only this request's reply counts; a stale file from an earlier click is ignored.
        local response=love.filesystem.read(status_path) or ''
        local prefix=pending.id..':'
        if response==prefix..'ready' then
            pending=nil
            local ok=love.system.openURL('http://127.0.0.1:8765')
            label(ok and 'Balatro Observer' or 'Browser could not open'); detail('')
            return
        end
        local failed=response:sub(1,#prefix+5)==prefix..'error'
        local timed_out=love.timer.getTime()>pending.deadline
        if failed or timed_out then
            pending=nil
            label('Viewer failed - retry')
            detail(response:match('^[%w%-]+:error:(.+)$') or (timed_out and 'No reply from the launcher. See viewer-launch.log in the mod folder.' or 'See viewer-launch.log in the mod folder.'))
        end
    end
    BalatroObserver.launch_label='Open Balatro Observer'
    BalatroObserver.launch_error=''
    mod.config_tab=function()
        return {n=G.UIT.ROOT,config={align='cm',colour=G.C.CLEAR,padding=0.2},nodes={
            {n=G.UIT.R,config={align='cm',colour=G.C.BLUE,r=0.1,padding=0.15,
                button='bobs_open_viewer',hover=true,shadow=true},nodes={
                {n=G.UIT.T,config={ref_table=BalatroObserver,ref_value='launch_label',scale=0.4,colour=G.C.WHITE,shadow=true}}
            }},
            {n=G.UIT.R,config={align='cm',padding=0.08},nodes={
                {n=G.UIT.T,config={ref_table=BalatroObserver,ref_value='launch_error',scale=0.28,colour=G.C.WHITE}}
            }}
        }}
    end
end
