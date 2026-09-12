-- ShellExecute starts Windows PowerShell hidden and asynchronously; no shell command is constructed.
return function(mod_path, request, status_file)
    if love.system.getOS() ~= 'Windows' then
        return love.system.openURL('http://127.0.0.1:8765')
    end
    local ok, result = pcall(function()
        local ffi = require('ffi')
        ffi.cdef[[
            unsigned long GetCurrentProcessId(void);
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
        local script = mod_path:gsub('[/\\]+$', '')..'/server/start-viewer.ps1'
        -- Fail immediately with a reason instead of waiting out the launch timeout on an incomplete install.
        local present = io.open(script, 'rb')
        assert(present, 'server/start-viewer.ps1 is missing from the mod folder; reinstall the mod')
        present:close()
        assert(type(request)=='string' and request:match('^[%w%-]+$'), 'Invalid launch request')
        assert(type(status_file)=='string' and not status_file:find('["\r\n]'), 'Invalid status path')
        local arguments='-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'..script..'" -NoOpen -Request '..request..' -StatusFile "'..status_file..'"'
        arguments=arguments..' -GamePid '..tonumber(kernel.GetCurrentProcessId())
        local powershell = (os.getenv('SystemRoot') or 'C:/Windows')..'/System32/WindowsPowerShell/v1.0/powershell.exe'
        local handle = shell.ShellExecuteW(nil,wide('open'),wide(powershell),wide(arguments),wide(mod_path),0)
        local code = tonumber(ffi.cast('intptr_t',handle))
        assert(code>32, 'Windows PowerShell could not start the viewer')
        return true
    end)
    if not ok then return false, tostring(result) end
    return result
end
