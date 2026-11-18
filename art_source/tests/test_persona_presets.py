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
        for persona_id, profile in overrides.items():
            with self.subTest(persona=persona_id):
                validate(copy.deepcopy(profile))

    def test_parameter_validation_rejects_invalid_dimensions(self):
        validate = self.require_api("validate_persona_parameters")
        profile = copy.deepcopy(self.require_api("PERSONA_OVERRIDES")["senior_mediator"])
        invalid_values = (-0.01, float("nan"), float("inf"), 1.01, True)
        for value in invalid_values:
            with self.subTest(value=value):
                candidate = copy.deepcopy(profile)
                candidate["body"]["torso_width_reduction"] = value
                with self.assertRaises(ValueError):
                    validate(candidate)

    def test_parameter_validation_rejects_unknown_styles_and_keys(self):
        validate = self.require_api("validate_persona_parameters")
        profile = copy.deepcopy(self.require_api("PERSONA_OVERRIDES")["senior_mediator"])
        for section, key, value in (
            ("identity", "hair_style", "unknown_cut"),
            ("identity", "facial_hair", "unknown_style"),
            ("body", "mystery_scale", 0.5),
        ):
            with self.subTest(section=section, key=key):
                candidate = copy.deepcopy(profile)
                candidate[section][key] = value
                with self.assertRaises(ValueError):
                    validate(candidate)

    def test_parameter_validation_rejects_malformed_and_out_of_range_colors(self):
        validate = self.require_api("validate_persona_parameters")
        profile = copy.deepcopy(self.require_api("PERSONA_OVERRIDES")["senior_mediator"])
        for color in ((0.1, 0.2), (0.1, 0.2, 0.3, 0.4), (0.1, -0.01, 0.3), (0.1, 0.2, 1.01), (0.1, float("nan"), 0.3)):
            with self.subTest(color=color):
                candidate = copy.deepcopy(profile)
                candidate["palette"]["jacket"] = color
                with self.assertRaises(ValueError):
                    validate(candidate)

    def test_persona_resolution_rejects_unknown_id(self):
        resolve_persona = self.require_api("resolve_persona")
        with self.assertRaises(ValueError):
            resolve_persona("not-a-persona", {})


if __name__ == "__main__":
    unittest.main()
