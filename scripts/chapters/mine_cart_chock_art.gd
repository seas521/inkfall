extends RefCounted
# Shared by the wheel chock, both hands and the airborne rock.
# Long uneven fracture faces must remain readable when crushed to black.
const SIZE:=1.5
# The silhouette remains fractured and asymmetric after the ink crush.
const OUTLINE=[Vector2(-13,6),Vector2(-12,-2),Vector2(-8,-4),Vector2(-9,-7),Vector2(-2,-10),Vector2(4,-9),Vector2(6,-6),Vector2(10,-5),Vector2(13,1),Vector2(12,4),Vector2(12,7),Vector2(7,9),Vector2(3,10),Vector2(-3,8),Vector2(-8,9)]
static func draw_stone(canvas:CanvasItem,at:Vector2,angle:float=0.0)->void:
 canvas.draw_set_transform(at,angle,Vector2.ONE*SIZE)
 var points:=PackedVector2Array(OUTLINE)
 canvas.draw_colored_polygon(points,Color(.004,.004,.004))
 canvas.draw_set_transform(Vector2.ZERO)
