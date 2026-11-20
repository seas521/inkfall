shader_type canvas_item;
render_mode unshaded;
uniform float scroll=0.;
uniform float camera_y=0.;
void fragment(){
 vec2 p=UV*vec2(1280.,720.);float x=p.x+scroll*.14;
 float opening=pow(.5+.5*sin(x*.0034+sin(x*.0009)*1.8-p.y*.0011),2.);
 float glow=exp(-pow((p.y-360.+camera_y*.1)/320.,2.));
 float canopy=smoothstep(0.,260.,p.y);
 float ground=1.-smoothstep(420.,740.,p.y);
 // Broad pools and weaker oblique openings are in the far air, behind
 // the branch silhouettes. No extra bright rim or flat light on near trees.
 float gap=pow(.5+.5*sin((x-p.y*.22)*.009+sin(x*.002)),4.);
 float v=(.075+(.27*opening+.065*gap*opening)*glow)*mix(.52,1.,canopy)*mix(.58,1.,ground);
 COLOR=vec4(vec3(v),1.);
}
