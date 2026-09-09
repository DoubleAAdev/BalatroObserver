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
    // Readable references keep action records useful without expanding every card in every hand.
    static void NameReferences(object value, Dictionary<string,string> names){
        var map=value as Dictionary<string,object>;
        if(map!=null){
            if(map.ContainsKey("index") && map.ContainsKey("card")){
                string id=Convert.ToString(map["card"]);
                if(!names.ContainsKey(id))throw new InvalidDataException("Unknown card reference.");
                map["card"]=names[id];
            }
            foreach(var item in map.Values)NameReferences(item,names);
        }else{
            var list=value as System.Collections.IEnumerable;
            if(list!=null && !(value is string))foreach(var item in list)NameReferences(item,names);
        }
    }
    static Dictionary<string,object> CompactCards(Dictionary<string,object> cards, List<object> actions, List<object> observations){
        var compact=new Dictionary<string,object>();var names=new Dictionary<string,string>();
        foreach(var item in cards){
            var card=item.Value as Dictionary<string,object>;
            if(card==null)throw new InvalidDataException("Invalid card description.");
            object rank,suit,name,key;
            card.TryGetValue("rank",out rank);card.TryGetValue("suit",out suit);
            card.TryGetValue("name",out name);card.TryGetValue("key",out key);
            string label=rank!=null && suit!=null ? rank+" of "+suit : Convert.ToString(name ?? key ?? "Unknown card");
            string unique=label;int variant=1;
            while(compact.ContainsKey(unique))unique=label+" #"+(++variant);
            names[item.Key]=unique;
            var descriptor=new Dictionary<string,object>();
            foreach(var field in card){
                var map=field.Value as Dictionary<string,object>;
                if(field.Value==null || (map!=null && map.Count==0))continue;
                if(field.Key=="key" && Convert.ToString(field.Value)=="c_base")continue;
                if(field.Key=="set" && Convert.ToString(field.Value)=="Default")continue;
                if(field.Key=="perma_bonus" && Convert.ToDouble(field.Value)==0)continue;
                descriptor[field.Key]=field.Value;
            }
            compact[unique]=descriptor;
        }
        NameReferences(actions,names);NameReferences(observations,names);
        return compact;
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
        result["cards"]=CompactCards(cards,actions,observations);result["actions"]=actions;result["observations"]=observations;
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
                        if(route=="/health")body=Encoding.UTF8.GetBytes("{\"app\":\"BalatroActionRecorder\",\"version\":\"0.1.1\"}");
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
