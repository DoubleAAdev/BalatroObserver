-- MP_RLOG is the action stream: it alone carries reorder permutations, ante
-- keys and readiness, and tells a pack pick from a shop use. The mirrored
-- "Client sent message" lines add the card each action touched, which the
-- driver matches against the live game so a drifted run still plays the same
-- cards. Copies of MP_RLOG lines inside network messages are never read.
return function(decode)
    local M={}
    local arities={play={1,1},discard={1,1},buy={2,2},sell={2,2},reroll={0,0},use={1,2},
        pack_pick={1,2},pack_skip={1,1},reorder={2,2},select_blind={1,1},skip_blind={1,1},
        open_pack={2,2},voucher={2,2},ready_blind={1,1},set_ante_key={1,1},net_asteroid={0,0}}
    function M.indices(text)
        assert(type(text)=='string' and text:match('^%d+[%.%d]*$') and not text:find('%.%.') and text:sub(-1)~='.', 'Invalid card positions')
        local out,seen={},{}
        for item in text:gmatch('%d+') do
            local n=tonumber(item);assert(n>=1 and n<=1000 and not seen[n],'Invalid or duplicate card position')
            seen[n]=true;out[#out+1]=n
        end
        return out
    end
    function M.parse(text)
        assert(type(text)=='string' and #text<=16*1024*1024,'Log exceeds 16 MB')
        local runs,current,last={},nil,nil
        for line in (text..'\n'):gmatch('(.-)\r?\n') do
            local payload=line:match('^MP_RLOG: (.*)$') or line:match(':: MULTIPLAYER :: MP_RLOG: (.*)$')
            if payload then
                if payload:match('^MANIFEST ') then
                    local manifest=decode(payload:sub(10))
                    assert(type(manifest)=='table','Invalid manifest')
                    for _,key in ipairs({'seed','deck','ruleset','gamemode'}) do assert(type(manifest[key])=='string' and #manifest[key]>0,'Manifest missing '..key) end
                    manifest.stake=manifest.stake or (manifest.lobby_config or {}).stake
                    assert(type(manifest.stake)=='number' and manifest.stake>=1 and manifest.stake%1==0,'Manifest missing stake')
                    current={manifest=manifest,actions={},complete=false};runs[#runs+1]=current;last=nil
                elseif payload:match('^END ') then
                    assert(current,'END without manifest');current.complete=true;last=nil
                elseif not payload:match('^CHK ') then
                    assert(current and not current.complete,'Action outside a run')
                    local seq,op,args=payload:match('^(%d+) ([%w_]+)%s*(.*)$')
                    assert(seq and tonumber(seq)==#current.actions+1,'Missing or duplicate action sequence')
                    assert(arities[op],'Unsupported action: '..tostring(op))
                    local tokens={};for token in args:gmatch('%S+') do tokens[#tokens+1]=token end
                    assert(#tokens>=arities[op][1] and #tokens<=arities[op][2],'Invalid arguments for '..op)
                    if op=='play' or op=='discard' then M.indices(tokens[1])
                    elseif op=='reorder' then assert(tonumber(tokens[1])==4 or tonumber(tokens[1])==6,'Invalid reorder area');M.indices(tokens[2])
                    elseif op=='buy' or op=='sell' or op=='open_pack' or op=='voucher' then
                        local area=tonumber(tokens[1]);assert(area and area>=1 and area<=7 and area%1==0,'Invalid area');assert(#M.indices(tokens[2])==1,'Invalid slot')
                    elseif op=='use' or op=='pack_pick' then assert(#M.indices(tokens[1])==1,'Invalid slot');if tokens[2] then M.indices(tokens[2]) end
                    -- Multiplayer writes tostring(math.random()); any finite
                    -- number is valid, including "0" and exponent notation.
                    elseif op=='set_ante_key' then assert(tonumber(tokens[1]),'Invalid ante key')
                    elseif op=='ready_blind' then assert(tokens[1]=='0' or tokens[1]=='1','Invalid ready state')
                    elseif op~='reroll' and op~='net_asteroid' then assert(tokens[1]=='0','Invalid action argument') end
                    last={n=tonumber(seq),op=op,args=tokens};current.actions[#current.actions+1]=last
                end
            elseif last and not last.name then
                -- MP_RLOG says which slot was acted on; the mirrored human line
                -- says which card was in it. The driver uses the name to find
                -- that card in the live game, so a shop whose order drifted is
                -- still played as the run played it. The first mirrored line
                -- after an action is that action's own.
                local human=line:match(':: MULTIPLAYER :: Client sent message: action:(.*)$')
                if human then
                    local name
                    if last.op=='use' or last.op=='pack_pick' then name=human:match('^usedCard,card:(.*)$')
                    elseif last.op=='sell' then name=human:match('^soldCard,card:(.*)$')
                    elseif last.op=='buy' or last.op=='open_pack' or last.op=='voucher' then name=human:match('^boughtCardFromShop,card:(.-),cost:') end
                    if name then last.name=name end
                end
            end
        end
        assert(#runs>0,'No original MP_RLOG manifest found')
        -- An abandoned lobby leaves a manifest with no moves; drop it instead of
        -- rejecting a log whose other runs are replayable.
        local playable={}
        for _,run in ipairs(runs) do if #run.actions>0 then playable[#playable+1]=run end end
        assert(#playable>0,'No MP_RLOG run contains actions')
        return playable
    end
    return M
end
