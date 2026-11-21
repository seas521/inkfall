# V81 上方森林：环境融合样片

基准是 `artifacts/checkpoint-v79-before-player-optics-20261121-170922/`，包括当时全部未提交代码和运行资源。V80 扩散与折射均被用户否决，已经从运行时彻底撤除。当前 Film 文件与 V79 完全相同。

## 依据与判断

- Playdead《The Lighting of INSIDE》：按构图人工安排反射光、遮挡等视觉层，所有细节共同支持既定光路。该文描述 INSIDE，不能当作 LIMBO 的实现说明。https://blog.playdead.com/articles/the_lighting_of_inside/lighting_of_inside.html
- Oliver Franzke《Dynamic 2D Character Lighting》：让动态角色读取与静态环境相匹配的局部／环境照明，避免角色浮在背景上。https://www.gamedeveloper.com/programming/dynamic-2d-character-lighting
- Unity 官方 2D 光照资料：侧视游戏可依赖背景和地面衬托人物；不必给角色描完整亮边。自动从整张精灵推算法线无法认识真实身体朝向。https://discussions.unity.com/t/2d-light-and-shadow-techniques-with-the-universal-render-pipeline/1641848

V79 的一个实际问题：角色材质先柔化 alpha，最终又乘原图 alpha，把自然过渡截回源轮廓；与周围草地和空气处理不完全一致。样片只在上方森林解除这层边缘裁回，保留原 RGB、面部、逐帧形体、尺寸和根点。

## 本版实现

`forest_environment_integration.gd` 管理森林专属呈现，其他区域与菜单关闭。入洞处按连续世界位置衰减，而非按输入控制器突然切换。

三处人工安排的林冠亮隙，对应苏醒后、兔子／食人花附近、林间开阔区。`forest_environment_integration.gdshader` 用同一世界空间开口函数驱动可见空气与角色／地面／道具的微弱漫反射。没有从人物 alpha 猜法线，不把身体切成左右两块，不重新开启 V57 已否决的旧光照通道。

共享玩法覆盖只选择真实形体；1024 样本的真实地面轮廓限制土层受光深度，避免整片地下刷灰。脚边只减弱新增的受光贡献，保留贴地关系。前侧光学空气受现有明亮空气限制，不覆盖极近黑色框景。

开阔处加入一片重叠、疏密和高度不一的低矮前侧草。草沿实际地面扎根，轻微遮住脚踝／小腿，不修改碰撞，不跟随人物，不遮住手部与头部。

新增合成层位于原 Film 之前。显式 BackBufferCopy 将合成结果交给 Film，避免 Godot 复用第一次 screen texture 而吞掉新增呈现。最终镜头保留 V79；没有折射、UV 位移、重影、镜头晃动或玻璃蒙版。

## 范围和边界

这是上方森林的定向美术样片，光路由人工布置，不是完整 GI、3D 体积光或通用动态阴影。材质法线与完整枝叶投影尚未制作；不宣称对任意森林构图自动正确。当前重点是可比较、可运行的融合方向，不扩展矿洞与谷底森林。

验收产物：`artifacts/forest-environment-v81/review/` 的同机位 V79／样片 HDR 原生截图，`walk/` 的真实按键行走取样。原生检查覆盖形体／脚点不变、森林启用、矿洞和 C 区归零，以及走过亮隙保持落地。截图和回滚不进入游戏资源。
