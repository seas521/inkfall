shader_type canvas_item;
uniform sampler2D forest : filter_linear_mipmap, repeat_disable;
uniform float scroll=0.0;
uniform float clock=0.0;
uniform float horizon=560.0;
uniform float level=.6;
uniform float shaft=0.0;
uniform float shaft_x=640.0;
uniform float reveal_edge=2.0;
float hash21(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 vec2 p=SCREEN_UV*vec2(1280.0,720.0);
 // The entire forest route fits inside this panorama: no repeated or
 // mirrored trees, no tiled ground edge, no independent tree-foot layers.
 vec2 uv=vec2((p.x+(scroll+10000.0)*.16+120.0)/3000.0,(p.y-horizon+890.0)/1000.0);
 vec3 art=textureLod(forest,clamp(uv,vec2(0),vec2(1)),.25).rgb;
 float l=dot(art,vec3(.299,.587,.114));
 l*=.87+.24*level;
 // Light belongs to the upper air; no bright band is drawn on the soil.
 float beam=exp(-pow((p.x-shaft_x+(p.y-horizon)*.2)/180.0,2.0));
 l+=shaft*.035*beam*(1.0-smoothstep(horizon-240.0,horizon-70.0,p.y));
 float columns=(noise(vec2((p.x+scroll)/1280.0*16.0,1.0))-.5)*.20+(noise(vec2((p.x+scroll)/1280.0*5.0,UV.y*3.0))-.5)*.14;
 float front=reveal_edge+(noise(vec2(UV.y*5.0,3.0))-.5)*.28+(UV.y-.5)*.18;
 float keep=1.0-smoothstep(front-.34,front+.34,SCREEN_UV.x+columns);
 COLOR=vec4(vec3(l),keep);
}
