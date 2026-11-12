extends RefCounted

const ORIGIN:=Vector2(-2300,-3715)
const MERGE:=Vector2(-200,-3150)
# Rects are actual load-bearing tops. Art supplies thickness and supports.
const STATION:=[
	Rect2(0,0,430,120),Rect2(720,0,115,32),
	Rect2(1230,-60,155,100),Rect2(1410,40,120,75),
	Rect2(1590,140,130,75),Rect2(1775,240,120,75),
	Rect2(1950,340,130,75),Rect2(2110,440,125,65),Rect2(2250,520,100,45),
	Rect2(450,90,115,65),Rect2(590,185,110,65),
	Rect2(760,280,290,95),Rect2(1040,420,210,34),
	Rect2(1700,565,760,130),
]
const DESCENT:=[
	Vector2(-200,-3150),
	Vector2(225,-3055),
	Vector2(430,-2960),
	Vector2(630,-2865),
	Vector2(830,-2770),
	Vector2(1030,-2675),
	Vector2(1240,-2580),
	Vector2(1030,-2485),
	Vector2(820,-2390),
	Vector2(610,-2295),
	Vector2(400,-2200),
	Vector2(600,-2105),
	Vector2(800,-2010),
	Vector2(1000,-1915),
	Vector2(1210,-1820),
	Vector2(1000,-1725),
	Vector2(790,-1630),
	Vector2(580,-1535),
	Vector2(370,-1440),
	Vector2(570,-1345),
	Vector2(770,-1250),
	Vector2(970,-1155),
	Vector2(1180,-1060),
	Vector2(970,-965),
	Vector2(760,-870),
	Vector2(550,-775),
	Vector2(340,-680),
	Vector2(540,-585),
	Vector2(740,-490),
	Vector2(950,-395),
	Vector2(1160,-300),
	Vector2(950,-205),
	Vector2(740,-110),
	Vector2(530,-15),
	Vector2(320,80),
	Vector2(110,175),
	Vector2(-120,270),
]

const SAVES:=[0,6,10,14,18,22,26,30,34,36]
const FRAGILE:=[3,11,19,27,35]
const SWAYING:=[9,17,25,33]

static func ledge_width(index:int)->float:
	if index==6:return 330.0
	if index in SAVES:return 190.0
	return 92.0 if index%3==0 else 104.0
