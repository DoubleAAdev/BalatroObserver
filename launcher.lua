-- Adds one local viewer shortcut above the draw pile. Opening requires a click.
return function(open_viewer)
    if not CardArea or not CardArea.draw then return end
    local pending, counter = nil, 0
    local status_path='balatro_observer/viewer-launch-status.txt'
    local function label(text)
        BalatroObserver.launch_label=text
        if G.deck and G.deck.children.bobs_viewer then
            G.deck.children.bobs_viewer:remove()
            G.deck.children.bobs_viewer=nil
        end
    end
    G.FUNCS.bobs_open_viewer = function()
        if pending then return true end
        -- LÖVE's browser opener is already known to work on the player's machine.
        if love.system.getOS()~='Windows' then return love.system.openURL('http://127.0.0.1:8765') end
        counter=counter+1
        local request=tostring(os.time())..'-'..counter
        love.filesystem.createDirectory('balatro_observer')
        label('Starting viewer...')
        pending={id=request,deadline=love.timer.getTime()+15}
        local ok, message = open_viewer(request,love.filesystem.getSaveDirectory()..'/'..status_path)
        BalatroObserver.launch_error = not ok and message or nil
        if not ok then pending=nil;label('Viewer needs Node.js') end
        return ok
    end
    BalatroObserver.poll_launch=function()
        if not pending then return end
        local response=love.filesystem.read(status_path)
        if response==pending.id..':ready' then
            pending=nil
            local ok=love.system.openURL('http://127.0.0.1:8765')
            label(ok and 'Balatro Observer' or 'Browser could not open')
        elseif response==pending.id..':error' or love.timer.getTime()>pending.deadline then
            pending=nil
            label('Viewer failed - retry')
        end
    end
    local previous_draw = CardArea.draw
    function CardArea:draw(...)
        previous_draw(self, ...)
        if self ~= G.deck or G.STAGE ~= G.STAGES.RUN then return end
        local ok = pcall(function()
            if not self.children.bobs_viewer then
                self.children.bobs_viewer = UIBox{
                    definition = {n=G.UIT.ROOT, config={align='cm',colour=G.C.CLEAR,padding=0.02}, nodes={
                        {n=G.UIT.R, config={align='cm',colour=G.C.BLUE,r=0.1,padding=0.08,
                            button='bobs_open_viewer',hover=true,shadow=true}, nodes={
                            {n=G.UIT.T,config={text=BalatroObserver.launch_label or 'Balatro Observer',scale=0.28,colour=G.C.WHITE,shadow=true}}
                        }}
                    }},
                    config={align='tm',offset={x=0,y=-0.55},major=self,parent=self}
                }
            end
            self.children.bobs_viewer:draw()
        end)
        BalatroObserver.launcher_ok = ok
    end
end
