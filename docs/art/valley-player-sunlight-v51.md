# 谷底森林角色受光试作 v51

当前扩展版本见 `docs/art/valley-player-light-v52.md`；本文件保留 v51 试作记录。

改动前回滚点：`d6a24deb`。仅谷底森林启用，不改变 v43 模糊、场景曝光、碰撞及水体。

远景的林冠透光投影提取到 `assets/shaders/valley_light_field.gdshaderinc`，远景和角色共用相同的采样、镜头投影及缓慢雾气变化。远景图和构图不变。角色进入亮区时，右上方迎光的帽沿、肩背表面产生柔和灰白受光，背光面保持深黑；以世界像素计算宽度，使镜像转身和不同尺寸的动作帧不改变来光方向。默认关闭，仅实时谷底森林开启，离开谷底森林即关闭，不作用于矿洞预览或其他区域。

这是沿当前 2D 光场投影的局部受光近似，不是三维材质法线照明。保持克制的内部明度，避免整个人泛白或出现完整的发光描边。风扇、草皮等独立物件暂不接入，以先验收角色的阳光质感。

验证：`scripts/demos/c_zone_debug/forest_received_light_v51_review.gd` 固定相机对比阴影/光区的开启前后、反向朝向，并检查离开谷底森林关闭受光。原生 HDR 截图保存于本机 `artifacts/forest-received-light-v51/`，不提交图片产物。

回滚时恢复此提交之前的 `hood_frame_actor.gd`、`river_art.gd`、`valley_far_v42.gdshader`，不回滚去树、白色火焰等已经确认的改动。
