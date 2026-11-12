# Forest spider

Garden orb weaver by Polyfork (https://polyfork.dev/asset/garden-orb-weaver-base), CC BY 4.0.

License: https://creativecommons.org/licenses/by/4.0/

Changes: official geometry variant with legReach=1.1, legThickness=0.85, stance=1.08 and fullness=0.9. Further derivative reshaping extends the original leg bone chains by 1.25 in their horizontal spread, reduces tube radius to 0.34 (tarsi 0.26), raises hips/knees, and shrinks the abdomen. Mesh topology and skin weights are retained; bind matrices are rebuilt. Exact derivative values and true foot-tip anchors are recorded in hunter-rig.json.

The official remix has a skin but no clips. Native Walk / Idle / Run were copied from this same model's original GLB by named bones, preserving new rest translations. Runtime uses native Run/Walk with terrain-aware planted feet and custom hanging, rock-probing and impale poses. Materials replaced with unshaded black; orthographic transparent output retains the game's silhouette style. The viewport updates only while the encounter is in camera range. Baseline prebaked frames are retained for comparison and are no longer the runtime character.

The mesh and animation sources are retained beside the derivative. Reproduce with scripts/tools/shape_forest_spider.py and scripts/tools/build_forest_spider_model.py. scripts/tools/bake_forest_spider.gd documents the earlier baseline bake.
