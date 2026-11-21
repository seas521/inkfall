# 可采用的光照与镜头技术（2026-11-20）

这是公开资料与 Inkfall 工程决策的对应，不把 INSIDE 的公开实现归到 LIMBO 名下。游戏画面的观察仍见 `limbo-video-study.md`。

## 一手来源

- [Playdead: The Lighting of INSIDE](https://blog.playdead.com/articles/the_lighting_of_inside/lighting_of_inside.html)，Marek Bogdan，2016。作者说明其场景通过人工安排反射光、高光、遮挡等视觉层控制结果，后期也使用 light cookies；目标是让细节服务相机距离及玩法／叙事焦点。它证明精确的美术组织很重要，不证明“自动高级算法必然更像”。
- [Playdead: INSIDE publications](https://github.com/playdeadgames/publications/blob/master/INSIDE/readme.md) 与 [Temporal AA 源码](https://github.com/playdeadgames/temporal)。公开实现属于 INSIDE／Unity，不能直接当作 Godot 2D 即插即用组件。
- [GPU Gems 3，第28章：Practical Post-Process Depth of Field](https://developer.nvidia.com/gpugems/gpugems3/part-iv-image-effects/chapter-28-practical-post-process-depth-field)：焦外半径、邻域深度、前后景合成与跨层渗色的处理。当前项目可以先用稳定的分层覆盖作近似，但二值覆盖不是完整深度，也不能恢复被遮住的背景。
- [Godot 2D lights and shadows](https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html)：方向灯、点灯、遮挡体及 CanvasTexture 的法线／高光贴图。法线应来自真实制作的数据，不能把人物透明轮廓的梯度解释为身体朝向。
- [Playdead: LIMBO publications](https://blog.playdead.com/articles/limbo_presentations/limbo_publications.html)：本次查到的页面主要列出关卡和声音演讲；它没有为本文提供 LIMBO 的具体景深／人物受光 Shader，因此不作这种归因。

## 本轮采用与边界

1. **稳定空间层级＋连续焦点范围。** 物件先有固定深度身份，控制器切换不改变身份、不重置焦点；活动范围在世界坐标连续缓动。只有明确的远距传送／复活切点可重定位。区域标签保留作调试信息，不能作为清晰／模糊开关。
2. **覆盖引导的邻域采样。** 对实际玩法几何与背景间的模糊样本降低权重并重新归一化，减少亮背景污染黑轮廓。仍是二层覆盖近似；不是完整 CoC、双层深度剥离或重建遮挡背景。不能宣传成完整物理景深。
3. **同源环境光和材质响应。** 林冠、矿灯按世界位置、光向和有效距离贡献光；灯保留自己的遮挡响应，不能因附近存在太阳就给矿灯套林冠。角色保留完整暗剪影，接受环境光场的轻微漫反射变化。禁止用 alpha 邻域制作虚假身体法线，导致转身时明暗翻边、左右双色。
4. **真实几何上的低对比受光。** 草叶、船体等在自己的材质内接收光；土层深部和水域不生成屏幕灰色条带。离屏草皮需要还原实际世界坐标，并在相机移动的当帧同步。
5. **时间稳定。** 提升细绳／骨架的覆盖精度，保持连续阈值与镜头缓动。没有逐像素运动信息和遮挡拒绝前，不把前一帧直接混进当前帧冒充 TAA；逐帧动画尤其容易留下鬼影。

6. **共享投影遮挡和参与介质。** 320×180 HDR 缓存记录到达能量、可见度、空气密度、相函数。沿光源方向对实际静态墨色层、井架结构和地形轮廓作有限距离射线检查；角色、草叶、道具和空气读取同一结果。上层森林使用布置的太阳开口，C区沿用远景光场，矿洞使用真实灯具。不能反过来取依赖受光角色的焦点遮罩作遮挡输入，否则产生渲染循环。
7. **散射与透射分开。** 前侧有限空气段用 Beer–Lambert 透射与单次散射合成，密度是缓慢平流的多尺度噪声，方向性用 Henyey–Greenstein（g=.35）近似；只在真实亮部扩散，不给土层和水体画发亮条带。参考 [GPU Gems 3，第13章](https://developer.nvidia.com/gpugems/gpugems3/part-ii-light-and-shadows/chapter-13-volumetric-light-scattering-post-process) 的遮挡与散射关系及 [Sébastien Hillaire 的公开论文／Frostbite 2015演讲索引](https://sebh.github.io/publications/)。本项目并未照搬径向模糊、完整 froxel 或时间重投影。

**边界：** 当前为正交2D投影路径、有限624世界单位遮挡距离及可取得的静态遮罩；不能推断全部画外／纵深遮挡，也未覆盖全部动态遮挡体。空气使用每像素有限前侧段的解析近似，不是完整3D逐步积分、多次散射或GI。更完整的多层CoC、制作过的法线和时间重投影尚未接入。任何算法都要以原生连续画面和帧时间验收。
