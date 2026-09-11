local ffi=require('ffi')
local original_load=ffi.load
local mode='select'
local selected='C:/logs/שלום replay.log'
love={system={getOS=function()return 'Windows'end}}
ffi.load=function(name)
    if name=='user32' then return {GetActiveWindow=function()return nil end} end
    if name=='comdlg32' then return {
        GetOpenFileNameW=function(options)
            assert(options.lStructSize==(ffi.abi('64bit') and 152 or 88))
            assert(options.nMaxFile==32768 and options.Flags==0x81808)
            if mode~='select' then return 0 end
            local kernel=original_load('kernel32')
            assert(kernel.MultiByteToWideChar(65001,0,selected,-1,options.lpstrFile,options.nMaxFile)>0)
            return 1
        end,
        CommDlgExtendedError=function()return mode=='cancel' and 0 or 1 end
    } end
    return original_load(name)
end
local pick=dofile('replayer/file-picker.lua')
assert(pick()==selected)
mode='cancel';assert(pick()==nil)
mode='error';assert(not pcall(pick))
ffi.load=original_load
print('PASS: native picker structure, existing-file flags, UTF-8 filenames, cancellation and error handling')
