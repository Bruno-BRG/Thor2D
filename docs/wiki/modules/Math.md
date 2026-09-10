# thor2d.Math

LOVE equivalent: `love.math`. Sources: `math.odin`, `random.odin`, `love_gaps.odin`.

## Description

Vectors, transforms, Bezier, triangulation, deterministic RNG (`New_Random_Generator`, `Get_Random_Seed/Set_Random_State`, `Random_Normal`), noise, lerp, sRGB helpers.

Transform object API on `Transform_2D` (LOVE `love.math.newTransform` methods): `Clone_Transform`, `Transform_Set_Transformation` (pivot baked exactly; shear returns `.Unsupported`), `Transform_Apply`/`Transform_Combine` (multiply), `Transform_Inverse`. Angles are degrees, matching `Transform_Point` (LOVE uses radians). Exact for shear-free transforms; see `math.odin` for the TRS projection note.

v0.10 additions: `Transform_Get_Matrix` / `Transform_Set_Matrix` (LOVE `Transform:getMatrix/setMatrix`, exact round-trip via a raw-matrix override that `Transform_Point`/`Transform_Point_Inverse` honor; `Transform_Combine`/`Transform_Inverse` stay exact when an override is present; any TRS edit clears the override), `Transform_Clear_Matrix`, `Transform_Has_Matrix`. Noise dimensions `Random_Noise_1D/3D/4D` (same lattice-hash construction and `[-1, 1]` range as `Random_Noise_2D`, no smoothing). Bezier completion `Bezier_Render` (uniform sampling), `Bezier_Segment` (de Casteljau sub-curve, same degree), `Bezier_Control_Points` (live view) / `Bezier_Set_Control_Points` (replace) / `Bezier_Degree`.

## Functions

See [Api_Reference](../Api_Reference.md) for the full procedure index, and [Porting_From_LOVE](../guides/Porting_From_LOVE.md) for the LOVE mapping table.

## See Also

[Graphics](Graphics.md)
