Inkfall / Fog Bay static environment V90

Approved layout source:
artifacts/fog-bay-v89/concept/low-shoal-high-bank.png

Static scene:
res://scenes/debug/fog_bay_static_v90.tscn
Composition canvas: 1914 x 822. Each plate occupies the same canvas at (0,0).
Two generated sources differ by one pixel in width; the composition normalizes
these to the authored canvas. Native dimensions and hashes are in manifest.json.

Layer order:
00: luminous distant atmosphere and ghost forest (opaque)
10: calm static water and environment reflection (RGBA)
20: low left shoal, exposed grasses and submerged continuation (RGBA)
30: high right rock bank and rooted leaning tree (RGBA)
40: sharp near leaves and reeds (RGBA)

Current user direction:
Exposed player-plane shores, trees and roots are dark silhouette materials.
Submerged left-shoal soil retains its translucent gray depth and gentle fade;
shoal_material.gdshader darkens only the dry strip, never the entire shoal.
No visible bark or rock texture. Preserve the light water/fog hierarchy.
Foreground source art remains sharp. Optical softness is independently authored
with near_defocus.gdshader, a premultiplied, separable Gaussian presentation pass.
The static scene exposes foreground_defocus (zero gives the sharp master).
Right-bank underwater attenuation is a separate shore_immersion material; it
must become driven by the live water surface when gameplay integration begins.

No boat, actor, mast, wake, boat reflection or actor reflection is baked into
these assets. Their reflection must be derived dynamically from live transforms
and current animation frames, then distorted/attenuated by the same water field.
Do not place concept-art characters into the running game. Keep the chapter's
current character and animation assets.

This delivery is STATIC ART ONLY. It does not implement buoyancy, collision,
player movement, live reflection or scene streaming. Existing main chapter
entry and the rejected V89 interactive prototype are not replaced.

Native rendered validation:
artifacts/fog-bay-static-v90/review/composition.png
artifacts/fog-bay-static-v90/review/composition-sharp-source.png

Right-bank transition revision: preserve near-black volume with broad, low-contrast
form from right-bank-volume-source.png. This auxiliary image is sampled by the
material only; its fine rock/bark texture is suppressed. Water contact fades
gradually over y495..582 in the registered static composition.
