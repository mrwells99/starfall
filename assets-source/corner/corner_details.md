# Boundary shrine overlay

The owner requested restoration of the original art on every pillar. The covering star-chart plaque and cover repairs were removed from `tools/build_corner_details.py`; the regenerated runtime GLB now contains only the boundary medallion and six votive candles. Original pillar artwork is supplied by the existing authored cover scene.

The arena instances the shrine twice, rotated 180 degrees for the opposing wall. Each instance uses four material batches and 5,824 triangles. Root is world origin, UV0 repeats at two metres (runtime scale correction matches four metres), UV2 is packed. No collision, lights, cameras or animations are exported. Bounds and bytes are recorded in `corner_details.json`.

Rebuild with `blender -b -noaudio --python tools/build_corner_details.py`. Source preview PNGs from the earlier pillar-plaque study are historical and are not runtime assets.
