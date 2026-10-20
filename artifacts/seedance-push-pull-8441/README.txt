8441 视频推拉抽帧候选（不接入正式关卡）

来源：2026-10-12 用户提供的 5 秒推/拉视频 8441。
采样：24 fps 连续抽取 120 帧。视频声明的 r_frame_rate=60 并非实际平均帧率；原流约为 24.12 fps。
master 为审计序列，包含原片裁坏区间，不能整体作为游戏动作。
source-keyed 为原尺寸抠图，保留原片位移和长杆，供对照检查。

交付片段（源帧零起算，两端均包含）：
push：8–37，共 30 帧。站立伸手、前倾、短步；避开了右边缘裁坏区间。
push_step：24–37，共 14 帧。只有短步片段，不作为完整循环验收。
pull：68–105，共 38 帧。后仰、退步，长杆已做遮罩去除。
pull_cycle：83–96，共 14 帧。连续循环候选，不倒放、不交叉淡化、不插造新帧。
release：106–119，共 14 帧。松手恢复片段。

统一规格：384×320 透明画布，固定根节点(192,280)，固定源地面846，统一缩放0.255。
与现有256×256角色对齐时，按根节点放置，不按画布中心或每帧包围盒对齐。
加宽透明画布只增加姿势活动空间，不缩小人物，也不恢复原片缺失像素。
横向校准使用config.json中显式的稀疏根位移轨迹，整组共用，不逐帧按包围盒居中。
拉杆遮罩从右端扫描细长尾部，遇到厚手部停止；握手边缘需人工视觉验收。

重要限制：
1. 推动片段尚不具备完整的无缝循环，不能将首尾硬接后称为完成。
2. 原视频中的头盔/表情变化原样保留，不重画角色。
3. 拉循环候选尚需结合箱体接触点及游戏实际位移调速验收。
4. 未伪造待机到后仰的缺失过渡。预览里的循环选项仅用于暴露接缝。
5. 正式C区、原角色动画和其他关卡未替换。

查看：preview.html 可本地打开；push-pull-preview.gif / .mp4 是连续原帧对照预览。
PNG序列可独立导入Godot。manifest.json记录源帧号、时间、边界和根节点位移。

复现：
ffmpeg -i INPUT.mp4 -vf fps=24 -start_number 0 RAW/frame_%03d.png
swiftc -O scripts/tools/extract_seedance_clip.swift -o /tmp/inkfall-seedance-extractor
/tmp/inkfall-seedance-extractor study RAW artifacts/seedance-push-pull-8441 artifacts/seedance-push-pull-8441/config.json
node scripts/tools/build_push_pull_review.mjs
