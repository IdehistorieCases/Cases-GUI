"""Validated procedural presets for CASES seated negotiators.

This module deliberately avoids Blender imports so persona data is checked before
any scene edits or output-directory creation.
"""
from __future__ import annotations

import copy
import math
from pathlib import Path
from typing import Any


PERSONA_IDS = ("senior_mediator", "younger_envoy", "scholarly_delegate")
HAIR_STYLES = frozenset({"close_crop", "receding_silver", "side_part", "short_wavy"})
FACIAL_HAIR_STYLES = frozenset({"moustache", "clean_shaven", "neat_beard"})
JACKET_STYLES = frozenset({"single_breasted", "double_breasted"})

# Bounds are inclusive and expressed in source-rig meters except for scales,
# ratios, angles, and fractional shape controls.
DIMENSION_LIMITS: dict[str, dict[str, tuple[float, float]]] = {
    "face": {
        "head_width_scale": (0.82, 1.18),
        "jaw_width_scale": (0.78, 1.22),
        "cheek_fullness": (0.82, 1.18),
        "face_height_scale": (0.90, 1.10),
        "face_depth_scale": (0.82, 1.18),
    },
    "body": {
        "torso_width_reduction": (0.0, 0.25),
        "shoulder_width_reduction": (0.0, 0.25),
        "arm_width_reduction": (0.0, 0.25),
        "neck_width_reduction": (0.0, 0.25),
        "torso_depth_reduction": (0.0, 0.25),
        "neck_depth_reduction": (0.0, 0.25),
    },
    "jacket": {
        "hip_half_width": (0.14, 0.25), "waist_half_width": (0.13, 0.23),
        "chest_half_width": (0.16, 0.26), "shoulder_half_width": (0.14, 0.23),
        "depth_scale": (0.72, 1.18), "front_opening_angle": (0.12, 1.05),
        "collar_half_width": (0.04, 0.10), "collar_depth": (0.025, 0.075),
        "sleeve_shoulder_radius": (0.035, 0.075), "sleeve_elbow_radius": (0.028, 0.065),
        "sleeve_forearm_radius": (0.024, 0.055), "sleeve_wrist_radius": (0.018, 0.040),
        "sleeve_root_inset": (0.0, 0.18), "sleeve_root_ratio": (0.2, 0.85),
        "sleeve_length": (0.72, 1.10), "lapel_width_scale": (0.6, 1.25),
    },
    "waistcoat": {"width_scale": (0.75, 1.05), "depth_scale": (0.70, 1.05)},
    "shirt": {
        "width_scale": (0.50, 0.82), "depth_scale": (0.50, 0.88),
        "neckline_half_width": (0.035, 0.070), "neckline_depth": (0.025, 0.060),
    },
    "cuff": {"diameter": (0.038, 0.072), "length": (0.022, 0.060)},
    "trousers": {
        "hip_radius": (0.055, 0.105), "thigh_radius": (0.050, 0.095),
        "knee_radius": (0.040, 0.080), "calf_radius": (0.036, 0.070),
        "ankle_radius": (0.027, 0.055), "depth_scale": (0.68, 1.08),
    },
    "shoe": {"length_scale": (0.78, 1.12), "width_scale": (0.78, 1.12), "heel_height": (0.004, 0.030)},
    "fit": {
        "body_clearance": (0.001, 0.010),
        "jacket_armhole_overlap": (0.012, 0.045),
        "cuff_overlap": (0.006, 0.025),
        "waistcoat_clearance": (0.001, 0.010),
        "shirt_clearance": (0.001, 0.008),
        "trouser_clearance": (0.001, 0.010),
        "shoe_foot_overlap": (0.003, 0.018),
    },
}

STYLE_FIELDS = {
    "identity": {"hair_style": HAIR_STYLES, "facial_hair": FACIAL_HAIR_STYLES},
    "jacket": {"front_style": JACKET_STYLES},
}
PALETTE_FIELDS = frozenset({
    "jacket", "lapel", "trousers", "waistcoat", "shirt", "tie", "metal",
    "leather", "hair", "skin", "wood", "chair", "backdrop",
})
ALLOWED_SECTIONS = frozenset((*DIMENSION_LIMITS, "identity", "palette"))


def _palette(jacket, lapel, trousers, waistcoat, tie, hair, skin, leather=(0.10, 0.038, 0.018)):
    return {
        "jacket": jacket, "lapel": lapel, "trousers": trousers, "waistcoat": waistcoat,
        "shirt": (0.64, 0.62, 0.57), "tie": tie, "metal": (0.56, 0.38, 0.15),
        "leather": leather, "hair": hair, "skin": skin, "wood": (0.20, 0.092, 0.040),
        "chair": (0.20, 0.225, 0.15), "backdrop": (0.40, 0.41, 0.40),
    }


PERSONA_OVERRIDES: dict[str, dict[str, Any]] = {
    "senior_mediator": {
        "identity": {"hair_style": "receding_silver", "facial_hair": "clean_shaven"},
        "face": {"head_width_scale": 1.02, "jaw_width_scale": 1.10, "cheek_fullness": 1.04, "face_height_scale": 0.99, "face_depth_scale": 1.02},
        "body": {"torso_width_reduction": 0.07, "shoulder_width_reduction": 0.16, "arm_width_reduction": 0.04, "torso_depth_reduction": 0.07},
        "jacket": {"hip_half_width": 0.202, "waist_half_width": 0.182, "chest_half_width": 0.218, "shoulder_half_width": 0.181, "front_style": "double_breasted"},
        "fit": {"jacket_armhole_overlap": 0.028},
        "waistcoat": {"width_scale": 0.96, "depth_scale": 0.90},
        "palette": _palette((0.055, 0.061, 0.071), (0.075, 0.081, 0.088), (0.055, 0.061, 0.071), (0.075, 0.095, 0.061), (0.12, 0.13, 0.075), (0.56, 0.54, 0.49), (0.60, 0.40, 0.29)),
    },
    "younger_envoy": {
        "identity": {"hair_style": "side_part", "facial_hair": "clean_shaven"},
        "face": {"head_width_scale": 0.96, "jaw_width_scale": 0.91, "cheek_fullness": 0.94, "face_height_scale": 1.03, "face_depth_scale": 0.94},
        "body": {"torso_width_reduction": 0.10, "shoulder_width_reduction": 0.22, "arm_width_reduction": 0.10, "torso_depth_reduction": 0.10},
        "jacket": {"hip_half_width": 0.190, "waist_half_width": 0.164, "chest_half_width": 0.199, "shoulder_half_width": 0.158, "sleeve_shoulder_radius": 0.041, "sleeve_elbow_radius": 0.034, "sleeve_forearm_radius": 0.030, "sleeve_wrist_radius": 0.023, "front_style": "single_breasted"},
        "fit": {"jacket_armhole_overlap": 0.024},
        "waistcoat": {"width_scale": 0.91, "depth_scale": 0.85},
        "palette": _palette((0.035, 0.060, 0.103), (0.050, 0.076, 0.122), (0.035, 0.060, 0.103), (0.080, 0.070, 0.054), (0.29, 0.12, 0.047), (0.12, 0.075, 0.045), (0.72, 0.52, 0.40)),
    },
    "scholarly_delegate": {
        "identity": {"hair_style": "short_wavy", "facial_hair": "neat_beard"},
        "face": {"head_width_scale": 1.00, "jaw_width_scale": 0.99, "cheek_fullness": 1.09, "face_height_scale": 0.98, "face_depth_scale": 1.04},
        "body": {"torso_width_reduction": 0.08, "shoulder_width_reduction": 0.14, "arm_width_reduction": 0.05, "torso_depth_reduction": 0.08},
        "jacket": {"hip_half_width": 0.198, "waist_half_width": 0.173, "chest_half_width": 0.208, "shoulder_half_width": 0.174, "sleeve_shoulder_radius": 0.044, "sleeve_elbow_radius": 0.035, "sleeve_forearm_radius": 0.031, "sleeve_wrist_radius": 0.023, "front_style": "single_breasted"},
        "fit": {"jacket_armhole_overlap": 0.025},
        "waistcoat": {"width_scale": 0.94, "depth_scale": 0.88},
        "palette": _palette((0.075, 0.092, 0.060), (0.092, 0.111, 0.073), (0.075, 0.092, 0.060), (0.70, 0.65, 0.52), (0.17, 0.055, 0.052), (0.11, 0.075, 0.052), (0.68, 0.48, 0.36)),
    },
}


def _deep_merge(base: dict[str, Any], override: dict[str, Any]) -> dict[str, Any]:
    merged = copy.deepcopy(base)
    for key, value in override.items():
        if isinstance(value, dict) and isinstance(merged.get(key), dict):
            merged[key] = _deep_merge(merged[key], value)
        else:
            merged[key] = copy.deepcopy(value)
    return merged


def resolve_persona(persona_id: str, base_preset: dict[str, Any]) -> dict[str, Any]:
    """Return a fresh merged preset; validation is a separate preflight step."""
    if persona_id == "default":
        return copy.deepcopy(base_preset)
    if persona_id not in PERSONA_OVERRIDES:
        raise ValueError(f"Unknown persona id: {persona_id!r}")
    return _deep_merge(base_preset, PERSONA_OVERRIDES[persona_id])


def validate_persona_parameters(preset: dict[str, Any]) -> None:
    """Reject malformed persona data before Blender scene or output mutation."""
    if not isinstance(preset, dict):
        raise ValueError("Persona preset must be a dictionary")
    missing_sections = ALLOWED_SECTIONS - set(preset)
    if missing_sections:
        raise ValueError(f"Missing persona sections: {sorted(missing_sections)}")
    unknown_sections = set(preset) - ALLOWED_SECTIONS
    if unknown_sections:
        raise ValueError(f"Unknown persona sections: {sorted(unknown_sections)}")

    for section, fields in DIMENSION_LIMITS.items():
        values = preset.get(section, {})
        if not isinstance(values, dict):
            raise ValueError(f"{section} must be a dictionary")
        allowed = set(fields) | set(STYLE_FIELDS.get(section, {}))
        missing = allowed - set(values)
        if missing:
            raise ValueError(f"Missing {section} parameters: {sorted(missing)}")
        unknown = set(values) - allowed
        if unknown:
            raise ValueError(f"Unknown {section} parameters: {sorted(unknown)}")
        for key, value in values.items():
            if key in STYLE_FIELDS.get(section, {}):
                if value not in STYLE_FIELDS[section][key]:
                    raise ValueError(f"Unsupported {section}.{key}: {value!r}")
                continue
            if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
                raise ValueError(f"{section}.{key} must be a finite number")
            low, high = fields[key]
            if not low <= value <= high:
                raise ValueError(f"{section}.{key} must be between {low} and {high}")

    identity = preset.get("identity", {})
    if not isinstance(identity, dict):
        raise ValueError("identity must be a dictionary")
    missing_identity = set(STYLE_FIELDS["identity"]) - set(identity)
    if missing_identity:
        raise ValueError(f"Missing identity parameters: {sorted(missing_identity)}")
    unknown_identity = set(identity) - set(STYLE_FIELDS["identity"])
    if unknown_identity:
        raise ValueError(f"Unknown identity parameters: {sorted(unknown_identity)}")
    for key, allowed in STYLE_FIELDS["identity"].items():
        if key in identity and identity[key] not in allowed:
            raise ValueError(f"Unsupported identity.{key}: {identity[key]!r}")

    palette = preset.get("palette", {})
    if not isinstance(palette, dict):
        raise ValueError("palette must be a dictionary")
    missing_colors = PALETTE_FIELDS - set(palette)
    if missing_colors:
        raise ValueError(f"Missing palette colors: {sorted(missing_colors)}")
    unknown_colors = set(palette) - PALETTE_FIELDS
    if unknown_colors:
        raise ValueError(f"Unknown palette colors: {sorted(unknown_colors)}")
    for name, color in palette.items():
        if not isinstance(color, (tuple, list)) or len(color) != 3:
            raise ValueError(f"palette.{name} must be an RGB triple")
        if any(isinstance(channel, bool) or not isinstance(channel, (int, float)) or not math.isfinite(channel) or not 0.0 <= channel <= 1.0 for channel in color):
            raise ValueError(f"palette.{name} channels must be finite values in [0, 1]")


def transform_face_point(point: tuple[float, float, float], face_profile: dict[str, float]) -> tuple[float, float, float]:
    """Apply one shared head-shape mapping to a source-space face landmark."""
    x, y, z = point
    head_width = face_profile.get("head_width_scale", 1.0)
    jaw_width = face_profile.get("jaw_width_scale", head_width)
    cheeks = face_profile.get("cheek_fullness", 1.0)
    height = face_profile.get("face_height_scale", 1.0)
    depth = face_profile.get("face_depth_scale", 1.0)
    t = min(1.0, max(0.0, (z - 1.58) / 0.15))
    width = jaw_width * (1.0 - t) + head_width * t
    # Cheek fullness is strongest across the midface and fades at jaw and brow.
    cheek_weight = max(0.0, 1.0 - abs(t - 0.56) / 0.42)
    center_y = 0.025
    transformed_z = 1.58 + (z - 1.58) * height
    transformed_y = center_y + (y - center_y) * (depth * (1.0 + (cheeks - 1.0) * cheek_weight))
    return (x * width, transformed_y, transformed_z)


def variant_output_paths(repo_root: Path, persona_id: str) -> dict[str, Path]:
    """Map a variant id to paths that cannot alias the legacy default outputs."""
    if persona_id not in PERSONA_OVERRIDES:
        raise ValueError(f"Not a variant persona: {persona_id!r}")
    root = Path(repo_root)
    render_dir = root / "art_source" / "output" / "v3" / persona_id
    return {
        "glb": root / "godot" / "assets" / "characters" / f"cases_suited_negotiator_{persona_id}.glb",
        "blend": render_dir / f"{persona_id}.blend",
        "render_dir": render_dir,
    }
