using System;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Collections.Generic;
using System.Web.Script.Serialization;

// Independent read-only localhost export server; never opens arbitrary client-supplied paths.
public static class ActionRecorderServer {
    static string root, directory;
    static readonly HashSet<string> tokens=new HashSet<string>{"play","discard","buy","sell","reroll","use","pack_pick","pack_skip","reorder","select_blind","skip_blind"};
    static JavaScriptSerializer Json(){return new JavaScriptSerializer{MaxJsonLength=134217728,RecursionLimit=64};}
    static bool ValidName(string name){return System.Text.RegularExpressions.Regex.IsMatch(name,@"\Arun-[0-9]+-[0-9]+-[0-9]+\.jsonl\z");}
    static string ReadJournal(string file){
        using(var stream=new FileStream(file,FileMode.Open,FileAccess.Read,FileShare.ReadWrite|FileShare.Delete)){
            // Snapshot the current byte length so an append cannot extend this request indefinitely.
            if(stream.Length>134217728)throw new InvalidDataException("Recording exceeds the 128 MB export limit; retain the original journal.");
            var data=new byte[(int)stream.Length];int count=0,n;
            while(count<data.Length && (n=stream.Read(data,count,data.Length-count))>0)count+=n;
            return Encoding.UTF8.GetString(data,0,count);
        }
    }
    public static string Export(string text){
        var result=new Dictionary<string,object>();
        var cards=new Dictionary<string,object>();var actions=new List<object>();var observations=new List<object>();
        int last=text.LastIndexOf('\n');if(last<0)throw new InvalidDataException("Recording header is incomplete.");
        bool partial=last!=text.Length-1;
        string[] lines=text.Substring(0,last).Split('\n');
        var header=Json().DeserializeObject(lines[0].TrimStart('\uFEFF')) as Dictionary<string,object>;
        if(header==null || !header.ContainsKey("schema_version") || Convert.ToInt32(header["schema_version"])!=1 || !header.ContainsKey("recording"))throw new InvalidDataException("Unsupported recording header.");
        result["schema_version"]=1;result["recording"]=header["recording"];result["index_base"]=1;
        for(int i=1;i<lines.Length;i++){
            if(String.IsNullOrWhiteSpace(lines[i]))continue;
            var record=Json().DeserializeObject(lines[i]) as Dictionary<string,object>;
            if(record==null)throw new InvalidDataException("Invalid journal record.");
            if(record.ContainsKey("cards")){
                var definitions=record["cards"] as Dictionary<string,object>;
                if(definitions==null)throw new InvalidDataException("Invalid card dictionary.");
                foreach(var item in definitions){if(cards.ContainsKey(item.Key))throw new InvalidDataException("Repeated card definition.");cards.Add(item.Key,item.Value);}
            }
            if(record.ContainsKey("action")){
                var action=record["action"] as Dictionary<string,object>;
                if(action==null || !action.ContainsKey("type") || !tokens.Contains(action["type"] as string) || !action.ContainsKey("n") || Convert.ToInt32(action["n"])!=actions.Count+1)throw new InvalidDataException("Invalid action sequence.");
                actions.Add(action);
            }else if(record.ContainsKey("observation"))observations.Add(record["observation"]);
            else throw new InvalidDataException("Unknown journal record.");
        }
        result["cards"]=cards;result["actions"]=actions;result["observations"]=observations;
        result["trailing_record_ignored"]=partial;
        return Json().Serialize(result);
    }
    static string ListRecordings(){
        var list=new List<object>();
        if(Directory.Exists(directory)){
            var files=new DirectoryInfo(directory).GetFiles("run-*.jsonl");
            Array.Sort(files,(a,b)=>b.LastWriteTimeUtc.CompareTo(a.LastWriteTimeUtc));
            foreach(var file in files)if(ValidName(file.Name))list.Add(new{file=file.Name,bytes=file.Length,updated=file.LastWriteTimeUtc.ToString("o")});
        }
        object status=null;
        try{status=Json().DeserializeObject(File.ReadAllText(Path.Combine(directory,"status.json")));}catch{}
        return Json().Serialize(new{recordings=list,status=status});
    }
    public static void Run(string releaseRoot,string stateDirectory,int port){
        root=releaseRoot;directory=stateDirectory;
        var listener=new TcpListener(IPAddress.Loopback,port);listener.Start();
        try{while(true){var client=listener.AcceptTcpClient();ThreadPool.QueueUserWorkItem(_=>Serve(client));}}
        finally{listener.Stop();}
    }
    static void Serve(TcpClient client){
        using(client){
            client.ReceiveTimeout=2000;client.SendTimeout=10000;
            try{
                var stream=client.GetStream();var header=new StringBuilder();int b;
                while(header.Length<8192 && (b=stream.ReadByte())>=0){header.Append((char)b);if(header.Length>=4 && header.ToString(header.Length-4,4)=="\r\n\r\n")break;}
                string[] first=header.ToString().Split(new[]{"\r\n"},StringSplitOptions.None)[0].Split(' ');
                int code=200;string mime="application/json; charset=utf-8",attachment=null;byte[] body;
                try{
                    if(first.Length!=3 || first[0]!="GET"){code=405;body=Encoding.UTF8.GetBytes("{\"error\":\"GET required\"}");}
                    else{
                        var uri=new Uri("http://127.0.0.1"+first[1]);string route=uri.AbsolutePath;
                        if(route=="/health")body=Encoding.UTF8.GetBytes("{\"app\":\"BalatroActionRecorder\",\"version\":\"0.1.0\"}");
                        else if(route=="/recordings")body=Encoding.UTF8.GetBytes(ListRecordings());
                        else if(route=="/export"){
                            var query=System.Web.HttpUtility.ParseQueryString(uri.Query);string file=query["file"]??"";
                            if(!ValidName(file))throw new InvalidDataException("Invalid recording filename.");
                            body=Encoding.UTF8.GetBytes(Export(ReadJournal(Path.Combine(directory,file))));attachment=file.Replace(".jsonl",".json");
                        }else if(route=="/" || route=="/recorder.css" || route=="/recorder.js"){
                            string file=route=="/"?"index.html":route.Substring(1);
                            mime=route=="/"?"text/html; charset=utf-8":route.EndsWith(".css")?"text/css; charset=utf-8":"text/javascript; charset=utf-8";
                            body=File.ReadAllBytes(Path.Combine(root,"viewer",file));
                        }else{code=404;body=Encoding.UTF8.GetBytes("{\"error\":\"Not found\"}");}
                    }
                }catch(FileNotFoundException){code=404;body=Encoding.UTF8.GetBytes("{\"error\":\"Recording not found\"}");}
                catch(Exception){code=422;body=Encoding.UTF8.GetBytes("{\"error\":\"Recording could not be exported. Keep the original journal; it may contain an incomplete or invalid record.\"}");}
                string response="HTTP/1.1 "+code+" "+(code==200?"OK":"Error")+"\r\nContent-Type: "+mime+"\r\nContent-Length: "+body.Length+"\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nConnection: close\r\n";
                if(attachment!=null)response+="Content-Disposition: attachment; filename=\""+attachment+"\"\r\n";
                var bytes=Encoding.ASCII.GetBytes(response+"\r\n");stream.Write(bytes,0,bytes.Length);stream.Write(body,0,body.Length);
            }catch{/* One disconnected browser must not stop recording exports. */}
        }
    }
}
