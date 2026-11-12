extends RefCounted

const Repairs=preload("res://scripts/actors/hood_eye_repairs.gd")
static var cache:Dictionary={}

static func texture_for(clip:String,frame:int,size:Vector2i)->Texture2D:
	var frames:Dictionary=Repairs.DATA.get(clip,{})
	var spans:Array=frames.get(str(frame),[])
	var key:String=clip+":"+str(frame) if not spans.is_empty() else "empty"
	if cache.has(key):return cache[key]
	var mask:=Image.create(size.x if not spans.is_empty() else 1,size.y if not spans.is_empty() else 1,false,Image.FORMAT_R8)
	mask.fill(Color.BLACK)
	for span in spans:
		mask.fill_rect(Rect2i(int(span[1]),int(span[0]),int(span[2])-int(span[1]),1),Color.WHITE)
	var texture:=ImageTexture.create_from_image(mask)
	cache[key]=texture
	return texture
