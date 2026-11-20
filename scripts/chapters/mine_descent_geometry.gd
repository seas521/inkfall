extends RefCounted

# Rendering and collision use the same atlas surface, in world coordinates.
const LEDGES = preload("res://assets/art/descent/mine-v1/cliff-ledges-v1.png")
const WALL = preload("res://assets/art/descent/mine-v4/rock-walls.png")
const UPPER_WALL=preload("res://assets/art/descent/rope-ladder/cliff-silhouette.png")
const LANDING := Vector2(-3545,-3870)
const LANDING_WIDTH := 280.0
static var ledge_image:Image
static var wall_image:Image
static var left_edge:PackedVector2Array
static var right_edge:PackedVector2Array

static func _images() -> void:
	if ledge_image != null: return
	ledge_image=LEDGES.get_image()
	if ledge_image.is_compressed(): ledge_image.decompress()
	wall_image=WALL.get_image()
	if wall_image.is_compressed(): wall_image.decompress()

static func _solid_top(cell:int, x:int) -> float:
	_images()
	x=clampi(cell*434+x,3,ledge_image.get_width()-4)
	for y in range(240,440):
		if ledge_image.get_pixel(x,y).a>0.8 and ledge_image.get_pixel(x-3,y+8).a>0.8 and ledge_image.get_pixel(x+3,y+8).a>0.8:
			return float(y)
	return 330.0

static func ledge(at:Vector2,width:float,side:float,cell:int)->Dictionary:
	var sy:=0.30
	var reference:=_solid_top(cell,270)
	var rect:=Rect2(Vector2(-width*0.5,-(reference-185.0)*sy),Vector2(width,370.0*sy))
	var top:=PackedVector2Array()
	for j in 19:
		var i:=j if side>0 else 18-j
		var sx:=50.0+float(i)*20.0
		top.append(at+Vector2(side*(sx/434.0-0.5)*width,(_solid_top(cell,int(sx))-reference)*sy))
	var polygon:=top.duplicate()
	polygon.append(top[-1]+Vector2(0,24))
	polygon.append(top[0]+Vector2(0,24))
	return {"at":at,"side":side,"rect":rect,"source":Rect2(cell*434,185,434,370),"top":top,"polygon":polygon}

static func surface_y(data:Dictionary,x:float)->float:
	var top:PackedVector2Array=data.top
	for i in range(top.size()-1):
		if x>=top[i].x and x<=top[i+1].x:
			return lerpf(top[i].y,top[i+1].y,inverse_lerp(top[i].x,top[i+1].x,x))
	return top[0].y if x<top[0].x else top[-1].y

static func wall_edge(right:bool)->PackedVector2Array:
	if right and not right_edge.is_empty(): return right_edge.duplicate()
	if not right and not left_edge.is_empty(): return left_edge.duplicate()
	_images()
	var edge:=PackedVector2Array()
	var upper:=UPPER_WALL.get_image()
	if upper.is_compressed():upper.decompress()
	for i in 101:
		var t:=float(i)/100.0
		var row:=int(lerpf(260,1020,t))
		var boundary:=1020 if right else 340
		if right:
			for x in range(700,1536):
				if wall_image.get_pixel(x,row).a>0.95:
					boundary=x
					break
		else:
			for x in range(650,0,-1):
				if wall_image.get_pixel(x,row).a>0.95:
					boundary=x
					break
		var y:=lerpf(-4010.0,-3250.0,t)
		var x:float=(-3120.0+(boundary-1020)*0.5) if right else (-3650.0+(boundary-340)*0.5)
		if not right:
			if y<-3860:
				var old_row:=clampi(int((y+4588.5)*2.0),0,1490)
				for sx in range(upper.get_width()-1,150,-1):
					if upper.get_pixel(sx,old_row).a>0.85:
						x=-3897.5+float(sx)*0.5
						break
			else:x=lerpf(-3503.0,x,smoothstep(-3860.0,-3780.0,y))
		edge.append(Vector2(x,y))
	if right: right_edge=edge.duplicate()
	else: left_edge=edge.duplicate()
	return edge

static func left_mass()->PackedVector2Array:
	var p:=wall_edge(false)
	p.append(Vector2(p[-1].x,900))
	p.append(Vector2(-6000,900))
	p.append(Vector2(-6000,p[0].y))
	return p

static func upper_right_mass()->PackedVector2Array:
	var p:=PackedVector2Array()
	for point in wall_edge(true):
		if point.y<=-3570:p.append(point)
	p.append(Vector2(4200,p[-1].y))
	p.append(Vector2(4200,-4350))
	p.append(Vector2(-3000,-4350))
	return p
