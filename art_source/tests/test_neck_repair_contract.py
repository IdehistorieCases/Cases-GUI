"""Integration checks for retaining Quaternius head/neck geometry.

Run with Blender 4.2+:
    blender -b --python art_source/tests/test_neck_repair_contract.py -- <character.blend>
"""
import sys
import unittest

import bpy


def source_neck_component_sizes(mesh_object):
    mesh = mesh_object.data
    group_ids = {group.name: group.index for group in mesh_object.vertex_groups}
    head_group = group_ids["Head"]
    neck_group = group_ids["neck_01"]
    weights = []
    for vertex in mesh.vertices:
        by_group = {assignment.group: assignment.weight for assignment in vertex.groups}
        weights.append((by_group.get(head_group, 0.0), by_group.get(neck_group, 0.0)))

    edge_faces = {}
    for polygon in mesh.polygons:
        vertices = list(polygon.vertices)
        for first, second in zip(vertices, vertices[1:] + vertices[:1]):
            edge_faces.setdefault(tuple(sorted((first, second))), []).append(polygon.index)
    adjacent = {polygon.index: set() for polygon in mesh.polygons}
    for linked_faces in edge_faces.values():
        for face_index in linked_faces:
            adjacent[face_index].update(other for other in linked_faces if other != face_index)

    remaining = set(adjacent)
    retained = []
    while remaining:
        stack = [remaining.pop()]
        component = []
        while stack:
            current = stack.pop()
            component.append(current)
            neighbors = adjacent[current] & remaining
            remaining.difference_update(neighbors)
            stack.extend(neighbors)
        vertex_indices = {index for face_index in component for index in mesh.polygons[face_index].vertices}
        if not vertex_indices:
            continue
        head_mean = sum(weights[index][0] for index in vertex_indices) / len(vertex_indices)
        neck_mean = sum(weights[index][1] for index in vertex_indices) / len(vertex_indices)
        if len(component) >= 400 and head_mean >= 0.25 and neck_mean >= 0.20:
            retained.append(len(component))
    return retained


class NeckRepairArtifactTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        try:
            separator = sys.argv.index("--")
            blend_path = sys.argv[separator + 1]
        except (ValueError, IndexError):
            raise RuntimeError("Pass the Blender artifact path after --")
        if not bpy.ops.wm.open_mainfile(filepath=blend_path):
            raise RuntimeError(f"Could not open Blender artifact: {blend_path}")

    def test_original_quaternius_neck_component_is_retained(self):
        body = bpy.data.objects.get("OriginalQuaterniusBody")
        self.assertIsNotNone(body, "The trimmed Quaternius head skin is missing")
        self.assertTrue(
            source_neck_component_sizes(body),
            "The complete weighted Quaternius neck component is missing from visible skin",
        )

    def test_no_procedural_neck_loft_is_present(self):
        self.assertIsNone(
            bpy.data.objects.get("Anatomical neck transition"),
            "A replacement neck loft must not be generated alongside the source neck",
        )


if __name__ == "__main__":
    unittest.main(argv=[sys.argv[0]])