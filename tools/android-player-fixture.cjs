'use strict';
// Local synthetic-media fixture only. Never imports production tokens or sources.
const http=require('node:http');
const fs=require('node:fs');
const path=require('node:path');
const file=path.resolve(__dirname,'../artifacts/performance/android-fixture.mp4');
const size=fs.statSync(file).size;
let requests=0,bytes=0,manifests=0,manifestStart=0;
http.createServer((req,res)=>{
 if(req.url==='/stats'){res.setHeader('Content-Type','application/json');res.end(JSON.stringify({requests,bytes,manifests}));return;}
 if(req.url==='/reset-hls'){manifestStart=Date.now();manifests=0;res.end('ok');return;}
 if(req.url.startsWith('/hls/')){
  const name=req.url.slice(5);
  if(!/^(index\.m3u8|init\.mp4|segment-\d{5}\.m4s)$/.test(name)){res.writeHead(404);res.end();return;}
  let data=fs.readFileSync(path.resolve(__dirname,'../artifacts/performance/android-hls-fixture',name));
  if(name==='index.m3u8'){
   manifests++;
   if(Date.now()-manifestStart<1800){
    const lines=data.toString().split('\n');
    const last=lines.findIndex(line=>line==='segment-00000.m4s');
    data=Buffer.from(lines.slice(0,last+1).join('\n')+'\n');
   }
  }
  res.writeHead(200,{'Content-Type':name.endsWith('.m3u8')?'application/vnd.apple.mpegurl':'video/mp4',
   'Cache-Control':'no-store','Content-Length':data.length});res.end(data);return;
 }
 if(req.url!=='/fixture.mp4'){res.writeHead(404);res.end();return;}
 requests++;
 const range=byteRange(req.headers.range,size);
 if(!range){res.writeHead(416);res.end();return;}
 const {start,end,partial}=range;
 res.writeHead(partial?206:200,{'Content-Type':'video/mp4','Content-Length':end-start+1,
  'Accept-Ranges':'bytes',...(partial?{'Content-Range':`bytes ${start}-${end}/${size}`}:{})});
 const stream=fs.createReadStream(file,{start,end});
 stream.on('data',chunk=>bytes+=chunk.length);stream.pipe(res);
 res.on('close',()=>stream.destroy());
}).listen(8766,'127.0.0.1',()=>console.log('Synthetic Android media fixture: 127.0.0.1:8766'));

function byteRange(value,length){
 if(!value)return {start:0,end:length-1,partial:false};
 const match=/^bytes=(\d*)-(\d*)$/.exec(value);
 if(!match||(!match[1]&&!match[2]))return null;
 const start=match[1]?Number(match[1]):Math.max(0,length-Number(match[2]));
 const end=match[1]&&match[2]?Math.min(Number(match[2]),length-1):length-1;
 if(!Number.isSafeInteger(start)||!Number.isSafeInteger(end)||start>end||start>=length)return null;
 return {start,end,partial:true};
}
