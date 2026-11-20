# 双矿车矿室 · 静态场景分层

基于项目内已确认概念 `artifacts/mine-pair-hoist-v3/captive-cart-room-v1.png`，通过内置 imagegen 清理、拆层生成。

- `static-room-source.png`：清理人物、矿车和动态机关后的静态对位母版，仅作源资料。
- `architecture.png`：带真实 alpha 的近层岩体、平台、梯子、固定井架与工具工位。
- `depth.png`：独立后层矿壁、远廊、扎根后侧地面的木撑与井下暗巷。

设计坐标为 1671×941，映射到游戏左上原点 (-665,-3545)，角色尺寸不变。实际比例、前侧遮挡和源像素对位在 `scripts/chapters/mine_pair_static_art.gd` 统一维护；不能分别拉伸平台或单独移动树脚/支撑脚。

提示词、截图及对位说明：`artifacts/mine-pair-integration-v1/`。本批资源只覆盖静态环境，不包含将来独立制作的活动罩架、矿篮、卷筒、传动绳索、压力踏板。矿车仍复用原有 Polyfork 模型，授权沿用 `assets/art/polyfork/station-v1/CREDITS.md`。
