"""Restore the task's Blender preview and existing MCP connection after crash recovery."""
import bpy
bpy.context.window.scene=bpy.data.scenes['BWAR_TF_family']
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA'
            area.spaces.active.shading.type='MATERIAL'
bpy.ops.blendermcp.start_server()
