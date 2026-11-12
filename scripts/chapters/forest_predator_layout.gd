extends RefCounted
# Independent of Scene1 to avoid a controller/art preload cycle.
const TREE_X:=-7310.0 # start + 2190, on the raised bank after the original spike pit
const PLANT_X:=-7030.0 # start + 2470, rooted on the normal lower ground
const TREE_SCALE:=0.50
const TREE_EMBED:=22.0 # bury the root fan in the bank, shared by art and rope anchor
const TREE_ROOT:=Vector2(236,907)
const BRANCH_TIP:=Vector2(554,394)
const ROPE_LENGTH:=146.0
const BASE_DEPTH:=0.0 # normal ground, not buried
const VIDEO_DISPLAY_SCALE:=0.82
const RISE_START:=-7515.0 # start + 1985
const RISE_TOP:=-7380.0 # start + 2120; broad crown extends behind the root spread
const BANK_EDGE:=-7140.0 # start + 2360
const BANK_BOTTOM:=-7060.0 # start + 2440
const BANK_HEIGHT:=90.0
const EXIT_RISE:=-7005.0 # start + 2495
const EXIT_TOP:=-6905.0 # start + 2595
const EXIT_BOTTOM:=-6820.0 # start + 2680
const EXIT_HEIGHT:=50.0
const MOUTH_LOCAL:=Vector2(-26,-148)
const RETRY_X:=-7210.0 # start + 2290, beside the suspended bait on high ground
