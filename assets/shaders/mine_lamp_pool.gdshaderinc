// Inverse lamp rotation: negative x displacement as the suspended shade tilts.
float mine_lamp_pool(vec2 point, vec2 bulb, float tilt) {
 vec2 d=point-bulb;
 float c=cos(tilt),s=sin(tilt);
 d=vec2(c*d.x+s*d.y,-s*d.x+c*d.y);
 float below=smoothstep(-8.0,14.0,d.y);
 float width=18.0+max(d.y,0.0)*0.70;
 float beam=exp(-pow(abs(d.x)/width,2.2));
 float falloff=exp(-max(d.y,0.0)/310.0);
 float bounce=0.065*exp(-dot(d/vec2(170.0,160.0),d/vec2(170.0,160.0)));
 return below*beam*falloff+bounce;
}

// The entrance shade spills farther across the working corner and the wall.
// Keep later mine lamps on their existing, narrower profiles.
float mine_entry_lamp_pool(vec2 point, vec2 bulb, float tilt) {
 vec2 d=point-bulb;
 float c=cos(tilt),s=sin(tilt);
 d=vec2(c*d.x+s*d.y,-s*d.x+c*d.y);
 float below=smoothstep(-12.0,24.0,d.y);
 float width=28.0+max(d.y,0.0)*0.95;
 float beam=exp(-pow(abs(d.x)/width,2.0))*exp(-max(d.y,0.0)/330.0);
 float scatter=0.20*exp(-pow(d.x/310.0,2.0))*exp(-pow((d.y-95.0)/215.0,2.0));
 scatter*=smoothstep(-40.0,30.0,d.y);
 return below*beam+scatter;
}

// Stable stopping bay: the same shade illuminates the wall behind the cart,
// both wheel contacts and the rear grip, with soft bounce rather than a disc.
float mine_stop_lamp_pool(vec2 point, vec2 bulb, float tilt) {
 vec2 d=point-bulb;
 float c=cos(tilt),s=sin(tilt);
 d=vec2(c*d.x+s*d.y,-s*d.x+c*d.y);
 float below=smoothstep(-14.0,24.0,d.y);
 float width=32.0+max(d.y,0.0)*0.90;
 float beam=below*exp(-pow(abs(d.x)/width,2.0))*exp(-max(d.y,0.0)/420.0);
 vec2 spread=(d-vec2(0.0,105.0))/vec2(245.0,205.0);
 float bounce=.20*exp(-dot(spread,spread))*smoothstep(-38.0,26.0,d.y);
 return beam+bounce;
}
