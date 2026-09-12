using System;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Collections.Generic;
using System.Web.Script.Serialization;

// Windows' bundled .NET Framework hosts the same read-only routes as the Node server (server/viewer-server.js).
// Compiled at runtime by start-viewer.ps1; releaseRoot is the mod folder holding the manifest, viewer/ and assets/.
public static class ObserverServer {
    static string root, directory, version;
    static int gamePid;
    static Dictionary<string, string[]> routes;
    static JavaScriptSerializer Json() { return new JavaScriptSerializer { MaxJsonLength = 16777216, RecursionLimit = 100 }; }
    static void Route(string url, string file, string type) { routes.Add(url, new [] { file, type }); }
    public static void Run(string releaseRoot, string stateDirectory, int port, int ownerPid=0) {
        gamePid=ownerPid;
        if(gamePid>0) {
            System.Diagnostics.Process game;
            try { game=System.Diagnostics.Process.GetProcessById(gamePid); var handle=game.Handle; }
            catch(ArgumentException) { return; }
            // Wait on this process handle, including crashes and forced exits, without a helper process.
            ThreadPool.QueueUserWorkItem(delegate { using(game) { game.WaitForExit(); Environment.Exit(0); } });
        }
        root = releaseRoot; directory = stateDirectory;
        version = (string)((Dictionary<string, object>)Json().DeserializeObject(File.ReadAllText(Path.Combine(root, "BalatroObserver.json"))))["version"];
        routes = new Dictionary<string, string[]>(StringComparer.Ordinal);
        // URLs are stable across releases; only the disk layout under the mod folder changes.
        Route("/", "viewer/observer.html", "text/html; charset=utf-8");
        Route("/observer.html", "viewer/observer.html", "text/html; charset=utf-8");
        Route("/observer.css", "viewer/observer.css", "text/css; charset=utf-8");
        Route("/credits", "THIRD_PARTY_NOTICES.md", "text/plain; charset=utf-8");
        foreach (string file in new [] { "observer.js", "joker-sprites.js", "score-preview.js" }) Route("/" + file, "viewer/" + file, "text/javascript; charset=utf-8");
        foreach (string file in new [] { "assets/wiki-art.js", "assets/calculator/balatro-sim.js", "assets/calculator/joker-ids.js" }) Route("/" + file, file, "text/javascript; charset=utf-8");
        foreach (string file in new [] { "8BitDeck_opt2.png", "Enhancers.png", "Editions.png", "Jokers.png" }) Route("/assets/" + file, "assets/" + file, "image/png");
        var types = new Dictionary<string,string> { {".png","image/png"}, {".gif","image/gif"}, {".jpg","image/jpeg"}, {".webp","image/webp"} };
        foreach (Dictionary<string,object> item in (object[])Json().DeserializeObject(File.ReadAllText(Path.Combine(root,"assets/wiki-art.json")))) {
            string file = (string)item["file"];
            if (!System.Text.RegularExpressions.Regex.IsMatch(file, @"^assets/wiki/[^/\\]+$") || !types.ContainsKey(Path.GetExtension(file))) throw new Exception("Invalid artwork path");
            Route("/" + file, file, types[Path.GetExtension(file)]);
        }
        var listener = new TcpListener(IPAddress.Loopback, port);
        listener.Start();
        try { while (true) { var client = listener.AcceptTcpClient(); ThreadPool.QueueUserWorkItem(delegate { Serve(client); }); } }
        finally { listener.Stop(); }
    }
    static bool Number(object value) { return value is int || value is long || value is decimal || (value is double && !Double.IsNaN((double)value) && !Double.IsInfinity((double)value)); }
    static string State() {
        Dictionary<string,object> newest = null;
        string raw = "null";
        foreach (int slot in new [] {0,1}) {
            try {
                string candidate = File.ReadAllText(Path.Combine(directory, "state-" + slot + ".json"), Encoding.UTF8);
                var s = Json().DeserializeObject(candidate) as Dictionary<string,object>;
                if (s == null || !s.ContainsKey("schema_version") || !Number(s["schema_version"]) || Convert.ToDouble(s["schema_version"]) != 1 || !s.ContainsKey("available") || !(s["available"] is bool) || !s.ContainsKey("session") || !(s["session"] is string) || !s.ContainsKey("observed_at") || !Number(s["observed_at"]) || !s.ContainsKey("sequence") || !Number(s["sequence"])) continue;
                bool newer = newest == null;
                if (!newer) {
                    double time = Convert.ToDouble(s["observed_at"]), previous = Convert.ToDouble(newest["observed_at"]);
                    newer = time > previous || (time == previous && ((string)s["session"] == (string)newest["session"] ? Convert.ToDouble(s["sequence"]) > Convert.ToDouble(newest["sequence"]) : String.CompareOrdinal((string)s["session"], (string)newest["session"]) > 0));
                }
                if (newer) { newest = s; raw = candidate; }
            } catch { /* A partial slot must not hide the other complete export. */ }
        }
        bool stale = newest == null || (DateTime.UtcNow - new DateTime(1970,1,1)).TotalSeconds - Convert.ToDouble(newest["observed_at"]) > 3;
        // Embed the original JSON: preserve arrays, numeric precision and mod_version.
        return "{\"state\":" + raw + ",\"stale\":" + (stale ? "true" : "false") + ",\"directory\":" + Json().Serialize(directory) + "}";
    }
    static void Serve(TcpClient client) {
        using (client) {
            client.ReceiveTimeout = 2000; client.SendTimeout = 2000;
            try {
                var stream = client.GetStream();
                var header = new StringBuilder(); int value;
                while (header.Length < 8192 && (value = stream.ReadByte()) >= 0) {
                    header.Append((char)value);
                    if (header.Length >= 4 && header.ToString(header.Length-4,4) == "\r\n\r\n") break;
                }
                string[] first = header.ToString().Split(new [] {"\r\n"}, StringSplitOptions.None)[0].Split(' ');
                int code = 200; string type = "text/plain; charset=utf-8"; byte[] body;
                if (first.Length != 3 || first[0] != "GET") { code = 405; body = Encoding.UTF8.GetBytes("Method not allowed"); }
                else {
                    string url = Uri.UnescapeDataString(first[1].Split('?')[0]);
                    if (url == "/health") { type = "application/json"; body = Encoding.UTF8.GetBytes(Json().Serialize(new {app="BalatroObserver", version=version, runtime="Windows PowerShell/.NET", gamePid=gamePid})); }
                    else if (url == "/state") { type = "application/json"; body = Encoding.UTF8.GetBytes(State()); }
                    else if (routes.ContainsKey(url)) { type = routes[url][1]; body = File.ReadAllBytes(Path.Combine(root,routes[url][0])); }
                    else { code = 404; body = Encoding.UTF8.GetBytes("Not found"); }
                }
                byte[] headers = Encoding.ASCII.GetBytes("HTTP/1.1 " + code + (code == 200 ? " OK" : code == 404 ? " Not Found" : " Method Not Allowed") + "\r\nContent-Type: " + type + "\r\nContent-Length: " + body.Length + "\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nConnection: close\r\n\r\n");
                stream.Write(headers,0,headers.Length); stream.Write(body,0,body.Length);
            } catch { /* A disconnected or malformed request cannot stop the server. */ }
        }
    }
}
