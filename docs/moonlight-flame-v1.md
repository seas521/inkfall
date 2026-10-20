# 月光角色 / Blender 火焰 · 第一版

- 角色保留现有动作和碰撞；着色器将衣料映射为蓝灰阴影、灰蓝中间色、柔和月白高光，不重新生成动作图集。
- 光晕是独立加色 Sprite2D，放在角色身后，不经过角色的透明边缘剔除着色器；尺寸不随动作图集缩放变化。
- 接触阴影查询角色正下方最近的真实平台，包含 C 的移动台阶和升降梯。180 像素以内投影，随离地高度变淡变软，没有承接面时不画阴影。
- 火焰由 Blender 后台创建弯曲立体焰体，分外焰、中层、亮芯，渲染八帧透明图集；引擎 14fps 播放并随原喷发强度控制高度。图集不改变伤害范围或时间。
- 这是风格化 3D 火焰烘焙，不是流体模拟。游戏仍是 Godot 2D，不需要运行时启动 Blender。

文件：assets/art/level01/flame-volume-atlas.png；assets/art/source/flame-volume.blend；assets/art/source/render_flame.py。

检查：GDScript 静态语法、图片透明通道、非绘制主逻辑未改；Blender 后台渲染成功。未启动 Godot，未实机验收 Shader、帧动画和光晕观感。
