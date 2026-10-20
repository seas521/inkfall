shader_type canvas_item;
render_mode unshaded;
uniform float clock = 0.0;
uniform float seed = 0.0;
uniform bool smoke = false;
uniform float intensity = 1.0;
uniform bool monochrome = false;

float hash3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}
float volume_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),
		mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),
		mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),
		mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);
}
float density(vec3 p) {
	float h = p.y;
	float t = clock + seed;
	if (smoke) {
		// Overlapping advected cloud lobes instead of a thresholded luminous thread.
		float body = 0.0;
		for (int lobe=0;lobe<5;lobe++) {
			float id=float(lobe);
			float age=fract(t*0.20+id*0.20);
			float radius=0.24+age*0.30;
			vec3 center=vec3(sin(id*4.7+t*0.7)*0.19,age,sin(id*2.8+t*0.4)*0.13);
			vec3 offset=(p-center)/vec3(radius,0.17+age*0.09,radius);
			body+=exp(-dot(offset,offset)*1.6)*smoothstep(0.0,0.09,age)*(1.0-smoothstep(0.78,1.0,age));
		}
		float curl=volume_noise(p*vec3(4.0,8.0,4.0)-vec3(0,t*1.8,0));
		float boundary=(1.0-smoothstep(0.75,0.99,abs(p.x)))*smoothstep(0.0,0.035,h)*(1.0-smoothstep(0.90,1.0,h));
		return body*(0.60+0.60*curl)*boundary*3.0;
	}
	vec3 q = vec3(p.x, h, p.z);
	q.x += sin(h*8.0-t*3.5)*h*0.12;
	float n = volume_noise(q*vec3(4.1,6.5,3.8)-vec3(0,t*(smoke ? 1.5 : 4.8),0));
	n += 0.32*volume_noise(q*vec3(10.0,15.0,9.0)-vec3(t*0.4,t*7.0,0));
	// Four independent curved tongues, not one wide cone or round mound.
	float envelope = 0.0;
	for (int tongue=0;tongue<4;tongue++) {
		float id = float(tongue);
		float peak = 0.77+0.17*sin(t*2.7+id*2.4)+0.05*sin(t*6.1+id);
		float u = h/max(peak,0.1);
		float center = -0.66+id*0.44;
		center += sin(u*6.0-t*4.1+id*1.9)*0.16*pow(clamp(u,0.0,1.0),1.25);
		float width = (0.17+0.025*sin(t*3.3+id))*pow(max(0.001,1.0-u),0.65);
		float radial = length(vec2((p.x-center)/max(width,0.009),p.z/0.42));
		float tongue_body = (1.0-smoothstep(0.36,1.0,radial))*(1.0-smoothstep(0.86,1.0,u));
		envelope = max(envelope,tongue_body);
	}
	float edge = smoothstep(0.0,0.05,h)*(1.0-smoothstep(0.85,1.0,h));
	return envelope * edge * (0.45+0.70*smoothstep(0.2,0.88,n)) * 3.2;
}
void fragment() {
	vec3 p = vec3((UV.x-0.5)*2.0,1.0-UV.y,0.0);
	vec4 sum = vec4(0.0);
	// Front-to-back integration through an animated 3D density field.
	for (int i=0;i<20;i++) {
		p.z = -1.0 + (float(i)+0.5)*0.1;
		float d = density(p);
		float alpha = 1.0-exp(-d*0.15*intensity);
		vec3 color;
		if (smoke) {
			float shadow = exp(-density(p+vec3(-0.14,0.10,-0.16))*0.85);
			color = mix(vec3(0.08,0.14,0.055),vec3(0.46,0.57,0.24),shadow);
		} else {
			float heat = clamp(d*0.45+(1.0-p.y)*0.28,0.0,1.0);
			color = mix(vec3(0.55,0.07,0.012),vec3(1.0,0.40,0.035),smoothstep(0.0,0.55,heat));
			color = mix(color,vec3(1.0,0.93,0.62),smoothstep(0.48,0.94,heat));
		}
		if (monochrome) {
			float value = dot(color, vec3(0.299, 0.587, 0.114));
			color = vec3(value);
		}
		sum.rgb += (1.0-sum.a)*color*alpha;
		sum.a += (1.0-sum.a)*alpha;
	}
	COLOR = vec4(sum.rgb/max(sum.a,0.001),sum.a);
}
