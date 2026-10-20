import {readFileSync,writeFileSync,mkdirSync,copyFileSync,existsSync} from 'node:fs';
import {resolve,join} from 'node:path';
import {spawnSync} from 'node:child_process';

const dir=resolve(process.argv[2]||'artifacts/seedance-push-pull-8441');
const config=JSON.parse(readFileSync(join(dir,'config.json'),'utf8'));
const manifest=JSON.parse(readFileSync(join(dir,'manifest.json'),'utf8'));
manifest.clips=config.clips;
const checks=[];
function check(value,message){if(!value)throw Error(message);checks.push(message);}
check(manifest.frames.length===120,'120 consecutive master frames at 24fps');
for(const clip of config.clips){
  mkdirSync(join(dir,clip.name),{recursive:true});
  for(let i=clip.start;i<=clip.end;i++){
    const frame=manifest.frames[i];
    const b=frame.cleaned_source_bounds;
    check(b[0]>=3&&b[1]>=3&&b[2]<=957&&b[3]<=957,`${clip.name}/${i}: source silhouette intact`);
    const o=frame.output_bounds;
    check(o[0]>=3&&o[1]>=3&&o[2]<=381&&o[3]<=317,`${clip.name}/${i}: output safe border`);
    const src=join(dir,'master',`frame_${String(i).padStart(3,'0')}.png`);
    check(existsSync(src),`${clip.name}/${i}: no missing frame`);
    copyFileSync(src,join(dir,clip.name,`frame_${String(i-clip.start).padStart(3,'0')}.png`));
  }
}
writeFileSync(join(dir,'manifest.json'),JSON.stringify(manifest,null,2));
writeFileSync(join(dir,'manifest.js'),'window.MOTION_STUDY = '+JSON.stringify(manifest)+';\n');
function ffmpeg(args){const p=spawnSync('ffmpeg',['-y','-hide_banner','-loglevel','error',...args],{encoding:'utf8'});if(p.status!==0)throw Error(p.stderr);}
function panel(input,name,out){return `[${input}:v]tpad=stop_mode=clone:stop_duration=2,trim=duration=2.5,setpts=PTS-STARTPTS,split[${out}fg][${out}bg];[${out}bg]drawbox=color=0xb9bdb8:t=fill:replace=1[${out}base];[${out}base][${out}fg]overlay,drawbox=x=0:y=280:w=384:h=1:color=0x929a92:t=fill,drawbox=x=383:y=0:w=1:h=320:color=0x929a92:t=fill[${out}]`;}
const composite=panel(0,'PUSH','p')+';'+panel(1,'PULL','q')+';[p][q]hstack,scale=1152:480:flags=lanczos';
const inputs=['-framerate','24','-i',join(dir,'push/frame_%03d.png'),'-framerate','24','-i',join(dir,'pull/frame_%03d.png')];
ffmpeg([...inputs,'-filter_complex',composite,'-an','-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',join(dir,'push-pull-preview.mp4')]);
ffmpeg(['-i',join(dir,'push-pull-preview.mp4'),'-filter_complex','split[a][b];[a]palettegen=stats_mode=full[p];[b][p]paletteuse=dither=sierra2_4a','-loop','0',join(dir,'push-pull-preview.gif')]);
ffmpeg(['-ss','0.8','-i',join(dir,'push-pull-preview.mp4'),'-frames:v','1',join(dir,'preview-still.png')]);
for(const name of ['push','pull','pull_cycle']){
  ffmpeg(['-framerate','24','-i',join(dir,name,'frame_%03d.png'),'-filter_complex','split[fg][bg];[bg]drawbox=color=0xb9bdb8:t=fill:replace=1[base];[base][fg]overlay,split[a][b];[a]palettegen[p];[b][p]paletteuse=dither=sierra2_4a','-loop','0',join(dir,`${name}.gif`)]);
}
writeFileSync(join(dir,'checks.json'),JSON.stringify({passed:checks.length,checks},null,2));
console.log(`PASS: ${checks.length} checks; preview video and GIFs generated.`);
