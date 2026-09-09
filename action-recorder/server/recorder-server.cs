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
    static string Clean(object value){return Convert.ToString(value,System.Globalization.CultureInfo.InvariantCulture).Replace("\r"," ").Replace("\n"," ");}
    static string Field(Dictionary<string,object> map,string key){object value;return map.TryGetValue(key,out value)?Clean(value):"";}
    static Dictionary<string,string> Properties(Dictionary<string,object> card){
        var result=new Dictionary<string,string>();
        foreach(var pair in card){
            if(pair.Key=="rank" || pair.Key=="suit" || pair.Key=="name" || pair.Key=="set")continue;
            if(pair.Key=="key" && Clean(pair.Value)=="c_base")continue;
            if(pair.Key=="perma_bonus" && Clean(pair.Value)=="0")continue;
            var nested=pair.Value as Dictionary<string,object>;
            if(nested!=null){foreach(var item in nested)if(item.Value!=null && !Object.Equals(item.Value,false))result[pair.Key+"."+item.Key]=Clean(item.Value);}
            else if(pair.Value!=null && !Object.Equals(pair.Value,false))result[pair.Key]=Clean(pair.Value);
        }
        return result;
    }
    sealed class History {
        public Dictionary<string,object> Cards=new Dictionary<string,object>();
        readonly Dictionary<string,Dictionary<string,string>> seen=new Dictionary<string,Dictionary<string,string>>();
        public string Card(object value,bool changeOnly){
            var reference=value as Dictionary<string,object>;
            if(reference==null)throw new InvalidDataException("Invalid card reference.");
            string slot=Field(reference,"index");
            if(reference.ContainsKey("hidden"))return changeOnly?null:"face-down card (slot "+slot+")";
            object definition;
            if(!Cards.TryGetValue(Field(reference,"card"),out definition))throw new InvalidDataException("Unknown card reference.");
            var card=definition as Dictionary<string,object>;
            if(card==null)throw new InvalidDataException("Invalid card description.");
            string id=Field(reference,"instance"),rank=Field(card,"rank"),suit=Field(card,"suit");
            string name=rank!="" && suit!=""?rank+" of "+suit:Field(card,"name");
            if(name=="")name=Field(card,"key");if(name=="")name="Unknown card";
            var current=Properties(card);current["identity"]=name;
            Dictionary<string,string> previous;bool known=seen.TryGetValue(id,out previous);
            if(changeOnly && !known)return null; // Old inventory snapshots are not a reason to list unrelated cards.
            var changes=new List<string>();
            foreach(var pair in current){string old;if((!known && pair.Key!="identity") || (known && (!previous.TryGetValue(pair.Key,out old) || old!=pair.Value)))changes.Add(pair.Key+"="+pair.Value);}
            if(known)foreach(var pair in previous)if(!current.ContainsKey(pair.Key))changes.Add(pair.Key+" removed");
            if(changeOnly && changes.Count==0)return null;
            seen[id]=current;
            return name+" [card "+id+", slot "+slot+"]"+(changes.Count>0?" ("+(known?"changed: ":"")+String.Join(", ",changes)+")":"");
        }
        public string List(object value,bool changeOnly){
            var items=value as object[];var result=new List<string>();
            if(items!=null)foreach(var item in items){string text=Card(item,changeOnly);if(text!=null)result.Add(text);}
            return String.Join("; ",result);
        }
    }
    public static string Export(string text){
        var output=new StringBuilder();var history=new History();int count=0;
        int last=text.LastIndexOf('\n');if(last<0)throw new InvalidDataException("Recording header is incomplete.");
        string[] lines=text.Substring(0,last).Split('\n');
        var header=Json().DeserializeObject(lines[0].TrimStart('\uFEFF')) as Dictionary<string,object>;
        if(header==null || !header.ContainsKey("schema_version") || Convert.ToInt32(header["schema_version"])!=1 || !header.ContainsKey("recording"))throw new InvalidDataException("Unsupported recording header.");
        var metadata=header["recording"] as Dictionary<string,object>;
        if(metadata==null)throw new InvalidDataException("Invalid recording metadata.");
        output.AppendLine("Balatro action log | "+Field(metadata,"id")+(Field(metadata,"partial")=="True"?" | resumed/partial run":""));
        for(int i=1;i<lines.Length;i++){
            if(String.IsNullOrWhiteSpace(lines[i]))continue;
            var record=Json().DeserializeObject(lines[i]) as Dictionary<string,object>;
            if(record==null)throw new InvalidDataException("Invalid journal record.");
            if(record.ContainsKey("cards")){
                var definitions=record["cards"] as Dictionary<string,object>;
                if(definitions==null)throw new InvalidDataException("Invalid card dictionary.");
                foreach(var item in definitions){if(history.Cards.ContainsKey(item.Key))throw new InvalidDataException("Repeated card definition.");history.Cards.Add(item.Key,item.Value);}
            }
            if(record.ContainsKey("action")){
                var action=record["action"] as Dictionary<string,object>;
                if(action==null || !tokens.Contains(Field(action,"type")) || !action.ContainsKey("n") || Convert.ToInt32(action["n"])!=++count)throw new InvalidDataException("Invalid action sequence.");
                output.Append(count+". "+Field(action,"type"));
                if(action.ContainsKey("area"))output.Append(" ["+Field(action,"area")+"]");
                if(action.ContainsKey("cards"))output.Append(": "+history.List(action["cards"],false));
                if(action.ContainsKey("targets")){string targets=history.List(action["targets"],false);if(targets!="")output.Append(" -> "+targets);}
                if(action.ContainsKey("blind")){var blind=action["blind"] as Dictionary<string,object>;if(blind!=null)output.Append(" "+Field(blind,"slot")+" "+Field(blind,"key")+(blind.ContainsKey("tag")?" -> "+Field(blind,"tag"):""));}
                if(action.ContainsKey("price"))output.Append(" | price="+Field(action,"price"));
                if(action.ContainsKey("use_after_buy"))output.Append(" | used immediately");
                if(action.ContainsKey("order"))output.Append(" | previous slots="+Json().Serialize(action["order"]));
                output.AppendLine();
            }else if(record.ContainsKey("observation")){
                var observation=record["observation"] as Dictionary<string,object>;
                if(observation==null || !observation.ContainsKey("areas"))throw new InvalidDataException("Invalid observation.");
                var areas=observation["areas"] as Dictionary<string,object>;
                if(areas==null)throw new InvalidDataException("Invalid observed areas.");
                foreach(var area in areas){string changes=history.List(area.Value,true);if(changes!="")output.AppendLine("   after action "+Field(observation,"after_action")+" | changed ["+Clean(area.Key)+"]: "+changes);}
            }else throw new InvalidDataException("Unknown journal record.");
        }
        if(last!=text.Length-1)output.AppendLine("Note: incomplete final journal entry ignored.");
        return output.ToString();
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
                        if(route=="/health")body=Encoding.UTF8.GetBytes("{\"app\":\"BalatroActionRecorder\",\"version\":\"0.2.0\"}");
                        else if(route=="/recordings")body=Encoding.UTF8.GetBytes(ListRecordings());
                        else if(route=="/export"){
                            var query=System.Web.HttpUtility.ParseQueryString(uri.Query);string file=query["file"]??"";
                            if(!ValidName(file))throw new InvalidDataException("Invalid recording filename.");
                            body=Encoding.UTF8.GetBytes(Export(ReadJournal(Path.Combine(directory,file))));attachment=file.Replace(".jsonl",".txt");mime="text/plain; charset=utf-8";
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
