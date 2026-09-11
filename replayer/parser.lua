-- Read only the original RLOG stream, never its copies inside network messages.
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
                    elseif op=='set_ante_key' then assert(tokens[1]:match('^%d+%.%d+$'),'Invalid ante key')
                    elseif op=='ready_blind' then assert(tokens[1]=='0' or tokens[1]=='1','Invalid ready state')
                    elseif op~='reroll' and op~='net_asteroid' then assert(tokens[1]=='0','Invalid action argument') end
                    last={n=tonumber(seq),op=op,args=tokens};current.actions[#current.actions+1]=last
                end
            elseif last then
                local name=line:match(':: MULTIPLAYER :: Client sent message: action:usedCard,card:(.*)$')
                if name and (last.op=='use' or last.op=='pack_pick') then last.name=name end
            end
        end
        assert(#runs>0,'No original MP_RLOG manifest found')
        for _,run in ipairs(runs) do assert(#run.actions>0,'Run contains no actions') end
        return runs
    end
    return M
end
