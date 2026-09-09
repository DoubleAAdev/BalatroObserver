'use strict';
const $=id=>document.getElementById(id);
let recordings=[],busy=false;
function element(tag,text){const node=document.createElement(tag);node.textContent=text;return node;}
async function removeRun(file){
 if(busy||!confirm('Remove '+file+' from this list? Its recording file will be kept on disk.'))return;
 busy=true;$('export-latest').disabled=true;
 try{
  const response=await fetch('/remove?file='+encodeURIComponent(file),{method:'POST',headers:{'X-Recorder-Action':'remove'}});
  if(!response.ok)throw new Error('Could not remove this run. Try refreshing the list.');
  await refresh();$('status').textContent='Run removed from the list. Its file is kept on disk.';
 }catch(error){$('status').textContent=error.message;}
 finally{busy=false;$('export-latest').disabled=!recordings.length;}
}
async function download(file){
 if(busy)return;busy=true;$('export-latest').disabled=true;$('status').textContent='Preparing action log…';
 try{
  const response=await fetch('/export?file='+encodeURIComponent(file),{cache:'no-store'});
  if(!response.ok)throw new Error('Export failed. Keep the original recording and check the recorder server log.');
  const blob=await response.blob(),url=URL.createObjectURL(blob),link=document.createElement('a');
  link.href=url;link.download=file.replace(/\.jsonl$/,'.txt');document.body.append(link);link.click();link.remove();
  setTimeout(()=>URL.revokeObjectURL(url),30000);$('status').textContent='Action log downloaded.';
 }catch(error){$('status').textContent=error.message;}
 finally{busy=false;$('export-latest').disabled=!recordings.length;}
}
async function refresh(){
 try{
  const response=await fetch('/recordings',{cache:'no-store'});if(!response.ok)throw new Error('Unable to load recordings.');
  const data=await response.json();recordings=data.recordings;$('recordings').replaceChildren();
  for(const item of recordings){
   const row=element('article','');row.className='recording';const details=element('div','');
   details.append(element('h2',new Date(item.updated).toLocaleString()),element('p',item.file+' · '+(item.bytes/1024).toFixed(1)+' KB'));
   const button=element('button','Export log');button.onclick=()=>download(item.file);
   const remove=element('button','Remove');remove.className='secondary';remove.onclick=()=>removeRun(item.file);
   const controls=element('div','');controls.append(button,remove);row.append(details,controls);$('recordings').append(row);
  }
  $('empty').hidden=recordings.length>0;$('export-latest').disabled=busy||!recordings.length;$('status').textContent=recordings.length+' recording'+(recordings.length===1?'':'s')+' available.';
  if(data.status?.ok===false)$('status').textContent=data.status.message;
 }catch(error){$('status').textContent=error.message;}
}
$('refresh').onclick=refresh;$('export-latest').onclick=()=>recordings[0]&&download(recordings[0].file);refresh();
