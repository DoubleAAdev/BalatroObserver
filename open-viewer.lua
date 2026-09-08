-- ShellExecute starts Node hidden and asynchronously; no shell command is constructed.
return function(mod_path)
    if love.system.getOS() ~= 'Windows' then
        return love.system.openURL('http://127.0.0.1:8765')
    end
    local ok, result = pcall(function()
        local ffi = require('ffi')
        ffi.cdef[[
            int MultiByteToWideChar(unsigned int, unsigned long, const char*, int, wchar_t*, int);
            void* ShellExecuteW(void*, const wchar_t*, const wchar_t*, const wchar_t*, const wchar_t*, int);
        ]]
        local shell = ffi.load('shell32')
        local kernel = ffi.load('kernel32')
        local function wide(s)
            local size = kernel.MultiByteToWideChar(65001, 0, s, -1, nil, 0)
            assert(size > 0, 'Invalid launcher path')
            local buffer = ffi.new('wchar_t[?]', size)
            assert(kernel.MultiByteToWideChar(65001, 0, s, -1, buffer, size) > 0)
            return buffer
        end
        assert(type(mod_path)=='string' and not mod_path:find('["\r\n]'), 'Invalid mod path')
        local script = mod_path:gsub('[/\\]+$', '')..'/start-viewer.js'
        local node = (os.getenv('ProgramFiles') or 'C:/Program Files')..'/nodejs/node.exe'
        local handle = shell.ShellExecuteW(nil,wide('open'),wide(node),wide('"'..script..'"'),wide(mod_path),0)
        local code = tonumber(ffi.cast('intptr_t',handle))
        if code<=32 then
            handle=shell.ShellExecuteW(nil,wide('open'),wide('node.exe'),wide('"'..script..'"'),wide(mod_path),0)
            code=tonumber(ffi.cast('intptr_t',handle))
        end
        assert(code>32, 'Install Node.js 18+ to open the viewer')
        return true
    end)
    if not ok then return false, tostring(result) end
    return result
end
