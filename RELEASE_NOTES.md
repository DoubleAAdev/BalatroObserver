# Balatro Observer 2.0.4

Fix the dashboard never showing data on macOS and Linux: the optional Node viewer server defaulted its state directory to `%APPDATA%`, which doesn't exist outside Windows, so it silently read from a nonexistent folder instead of LÖVE's real save directory. It now resolves the correct save location on each platform.

Restart Balatro to load the updated mod.
