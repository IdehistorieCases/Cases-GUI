"""Behavior tests for the data-only negotiator persona configuration."""

import copy
import importlib
from pathlib import Path
import unittest


try:
    persona_presets = importlib.import_module("art_source.scripts.persona_presets")
except ModuleNotFoundError as error:
    if error.name != "art_source.scripts.persona_presets":
        raise
    persona_presets = None


PERSONA_IDS = ("senior_mediator", "younger_envoy", "scholarly_delegate")


def _valid_base_preset():
    profile = {
        section: {name: (bounds[0] + bounds[1]) / 2 for name, bounds in fields.items()}
        for section, fields in persona_presets.DIMENSION_LIMITS.items()
    }
    for section, styles in persona_presets.STYLE_FIELDS.items():
        profile.setdefault(section, {}).update({name: sorted(allowed)[0] for name, allowed in styles.items()})
    profile["palette"] = {name: (0.4, 0.4, 0.4) for name in persona_presets.PALETTE_FIELDS}
    return profile


class PersonaPresetTests(unittest.TestCase):
    def require_api(self, name):
        self.assertIsNotNone(
            persona_presets,
            "art_source.scripts.persona_presets is not implemented yet",
        )
        member = getattr(persona_presets, name, None)
        self.assertIsNotNone(member, f"persona_presets.{name} is missing")
        return member

    def test_default_preset_is_a_deep_copy(self):
        resolve_persona = self.require_api("resolve_persona")
        base = {"body": {"width": 1.0}, "palette": {"jacket": "navy"}}

        resolved = resolve_persona("default", base)

        self.assertEqual(resolved, base)
        self.assertIsNot(resolved, base)
        self.assertIsNot(resolved["body"], base["body"])
        resolved["body"]["width"] = 2.0
        self.assertEqual(base["body"]["width"], 1.0)

    def test_persona_resolution_deep_merges_without_mutating_base(self):
        resolve_persona = self.require_api("resolve_persona")
        base = {
            "body": {"legacy_depth": 0.8},
            "jacket": {"legacy_shape": "profiled"},
            "palette": {"legacy_accent": "brass"},
        }

        resolved = resolve_persona("senior_mediator", base)

        self.assertEqual(resolved["body"]["legacy_depth"], 0.8)
        self.assertEqual(resolved["jacket"]["legacy_shape"], "profiled")
        self.assertEqual(resolved["palette"]["legacy_accent"], "brass")
        self.assertIn("identity", resolved)
        self.assertIn("face", resolved)
        self.assertEqual(base["body"], {"legacy_depth": 0.8})
        self.assertIsNot(resolved["body"], base["body"])

    def test_all_three_personas_have_complete_sections(self):
        overrides = self.require_api("PERSONA_OVERRIDES")
        self.assertEqual(set(overrides), set(PERSONA_IDS))
        for persona_id in PERSONA_IDS:
            with self.subTest(persona=persona_id):
                profile = overrides[persona_id]
                for section in ("identity", "face", "body", "jacket", "palette"):
                    self.assertIn(section, profile)
                    self.assertIsInstance(profile[section], dict)

    def test_variant_outputs_are_unique_and_repo_relative(self):
        variant_output_paths = self.require_api("variant_output_paths")
        repo_root = Path("Z:/Cases-GUI")
        outputs = [variant_output_paths(repo_root, persona_id) for persona_id in PERSONA_IDS]

        for persona_id, paths in zip(PERSONA_IDS, outputs):
            with self.subTest(persona=persona_id):
                self.assertEqual(set(paths), {"glb", "blend", "render_dir"})
                self.assertEqual(paths["glb"], repo_root / "godot/assets/characters" / f"cases_suited_negotiator_{persona_id}.glb")
                self.assertEqual(paths["blend"], repo_root / "art_source/output/v3" / persona_id / f"{persona_id}.blend")
                self.assertEqual(paths["render_dir"], repo_root / "art_source/output/v3" / persona_id)

        for key in ("glb", "blend", "render_dir"):
            self.assertEqual(len({paths[key] for paths in outputs}), len(PERSONA_IDS))

    def test_variant_path_helper_rejects_default_and_unknown_ids(self):
        variant_output_paths = self.require_api("variant_output_paths")
        repo_root = Path("Z:/Cases-GUI")
        for persona_id in ("default", "not-a-persona"):
            with self.subTest(persona=persona_id):
                with self.assertRaises(ValueError):
                    variant_output_paths(repo_root, persona_id)


    def test_all_persona_profiles_pass_parameter_validation(self):
        overrides = self.require_api("PERSONA_OVERRIDES")
        validate = self.require_api("validate_persona_parameters")
        resolve = self.require_api("resolve_persona")
        base = _valid_base_preset()
        for persona_id, profile in overrides.items():
            with self.subTest(persona=persona_id):
                validate(resolve(persona_id, base))

    def test_parameter_validation_rejects_invalid_dimensions(self):
        validate = self.require_api("validate_persona_parameters")
        profile = self.require_api("resolve_persona")("senior_mediator", _valid_base_preset())
        invalid_values = (-0.01, float("nan"), float("inf"), 1.01, True)
        for value in invalid_values:
            with self.subTest(value=value):
                candidate = copy.deepcopy(profile)
                candidate["body"]["torso_width_reduction"] = value
                with self.assertRaises(ValueError):
                    validate(candidate)

    def test_parameter_validation_rejects_unknown_styles_and_keys(self):
        validate = self.require_api("validate_persona_parameters")
        profile = self.require_api("resolve_persona")("senior_mediator", _valid_base_preset())
        for section, key, value in (
            ("identity", "hair_style", "unknown_cut"),
            ("identity", "facial_hair", "unknown_style"),
            ("jacket", "front_style", "unsupported_construction"),
            ("body", "mystery_scale", 0.5),
        ):
            with self.subTest(section=section, key=key):
                candidate = copy.deepcopy(profile)
                candidate[section][key] = value
                with self.assertRaises(ValueError):
                    validate(candidate)

    def test_parameter_validation_rejects_malformed_and_out_of_range_colors(self):
        validate = self.require_api("validate_persona_parameters")
        profile = self.require_api("resolve_persona")("senior_mediator", _valid_base_preset())
        for color in ((0.1, 0.2), (0.1, 0.2, 0.3, 0.4), (0.1, -0.01, 0.3), (0.1, 0.2, 1.01), (0.1, float("nan"), 0.3)):
            with self.subTest(color=color):
                candidate = copy.deepcopy(profile)
                candidate["palette"]["jacket"] = color
                with self.assertRaises(ValueError):
                    validate(candidate)

    def test_parameter_validation_rejects_missing_dimensions_styles_and_colors(self):
        validate = self.require_api("validate_persona_parameters")
        profile = self.require_api("resolve_persona")("senior_mediator", _valid_base_preset())
        for section, key in (("jacket", "chest_half_width"), ("identity", "hair_style"), ("palette", "shirt")):
            with self.subTest(section=section, key=key):
                candidate = copy.deepcopy(profile)
                del candidate[section][key]
                with self.assertRaises(ValueError):
                    validate(candidate)


    def test_shared_face_transform_has_identity_profile(self):
        transform = self.require_api("transform_face_point")
        profile = {
            "head_width_scale": 1.0,
            "jaw_width_scale": 1.0,
            "cheek_fullness": 1.0,
            "face_height_scale": 1.0,
            "face_depth_scale": 1.0,
        }
        point = (0.041, -0.087, 1.699)
        self.assertEqual(transform(point, profile), point)

    def test_shared_face_transform_changes_jaw_without_moving_eye_height(self):
        transform = self.require_api("transform_face_point")
        profile = {
            "head_width_scale": 0.96,
            "jaw_width_scale": 1.10,
            "cheek_fullness": 1.0,
            "face_height_scale": 1.0,
            "face_depth_scale": 1.0,
        }
        jaw = transform((0.05, 0.0, 1.58), profile)
        eye = transform((0.05, -0.08, 1.70), profile)
        self.assertAlmostEqual(jaw[0], 0.055)
        self.assertAlmostEqual(eye[0], 0.0494)
        self.assertAlmostEqual(eye[2], 1.70)

    def test_resolved_profiles_declare_measurable_garment_fit(self):
        resolve = self.require_api("resolve_persona")
        validate = self.require_api("validate_persona_parameters")
        base = {
            "body": {"torso_width_reduction": 0.1, "shoulder_width_reduction": 0.1, "arm_width_reduction": 0.05, "neck_width_reduction": 0.1, "torso_depth_reduction": 0.08, "neck_depth_reduction": 0.06, "neck_length_scale": 0.92},
            "face": {"head_width_scale": 1.0, "jaw_width_scale": 1.0, "cheek_fullness": 1.0, "face_height_scale": 1.0, "face_depth_scale": 1.0},
            "identity": {"hair_style": "close_crop", "facial_hair": "moustache"},
            "jacket": {"hip_half_width": .196, "waist_half_width": .174, "chest_half_width": .21, "shoulder_half_width": .18, "depth_scale": .92, "front_opening_angle": .42, "front_style": "single_breasted", "fit_clearance": .005, "armhole_overlap": .028, "collar_half_width": .067, "collar_depth": .048, "sleeve_shoulder_radius": .045, "sleeve_elbow_radius": .036, "sleeve_forearm_radius": .032, "sleeve_wrist_radius": .024, "sleeve_root_inset": .115, "sleeve_root_ratio": .5, "sleeve_length": .92, "lapel_width_scale": .9},
            "waistcoat": {"width_scale": .94, "depth_scale": .88, "fit_clearance": .004},
            "shirt": {"width_scale": .62, "depth_scale": .64, "neckline_half_width": .048, "neckline_depth": .04, "fit_clearance": .002},
            "cuff": {"diameter": .048, "length": .034, "overlap": .012},
            "trousers": {"hip_radius": .078, "thigh_radius": .069, "knee_radius": .058, "calf_radius": .051, "ankle_radius": .04, "depth_scale": .86, "fit_clearance": .004},
            "shoe": {"length_scale": .96, "width_scale": .94, "heel_height": .012, "foot_overlap": .006},
            "fit": {"body_clearance": .004, "jacket_armhole_overlap": .028, "cuff_overlap": .012, "waistcoat_clearance": .004, "shirt_clearance": .002, "trouser_clearance": .004, "shoe_foot_overlap": .006},
            "palette": {key: (0.4, 0.4, 0.4) for key in ("jacket", "lapel", "trousers", "waistcoat", "shirt", "tie", "metal", "leather", "hair", "skin", "wood", "chair", "backdrop")},
        }
        resolved = resolve("senior_mediator", base)
        validate(resolved)
        self.assertEqual(set(resolved["fit"]), {"body_clearance", "jacket_armhole_overlap", "cuff_overlap", "waistcoat_clearance", "shirt_clearance", "trouser_clearance", "shoe_foot_overlap"})
        self.assertEqual(resolved["jacket"]["front_style"], "double_breasted")

    def test_persona_resolution_rejects_unknown_id(self):
        resolve_persona = self.require_api("resolve_persona")
        with self.assertRaises(ValueError):
            resolve_persona("not-a-persona", {})


if __name__ == "__main__":
    unittest.main()
