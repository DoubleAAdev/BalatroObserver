-- Adds one local viewer shortcut above the draw pile. Opening requires a click.
return function()
    if not CardArea or not CardArea.draw then return end
    G.FUNCS.bobs_open_viewer = function()
        return love.system.openURL('http://127.0.0.1:8765')
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
                            {n=G.UIT.T,config={text='Balatro Observer',scale=0.28,colour=G.C.WHITE,shadow=true}}
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
