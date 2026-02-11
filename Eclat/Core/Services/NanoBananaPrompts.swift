//
//  NanoBananaPrompts.swift
//  Eclat
//
//  Optimized prompts for Nano Banana Pro API - Hair-only editing with maximum preservation
//

import SwiftUI

// ✅ Objectif: l'utilisateur upload SA photo → on ne change RIEN (visage, corps, outfit, décor, lumière, couleurs)
// ➜ On modifie UNIQUEMENT les cheveux (zone hair-only) + on optimise le rendu (edges, hairline, brillance, volume, etc.)
// ➜ JSON prêt à envoyer à "Nano Banana Pro" via API (remplace {{UPLOAD_IMAGE_ID}} par ton id/fichier).

struct NanoBananaHairOnlyPrompt: Identifiable, Hashable {
    let id: String
    let name: String
    let json: String
}

enum NanoBananaWomenHairOnlyPrompts {

    // MARK: - Base template (strict preservation)
    private static func baseJSON(
        id: String,
        name: String,
        length: String,
        texture: String,
        hairEditObjectJSON: String
    ) -> String {
        """
        {
          "task": "image_edit_hair_only",
          "catalog": {
            "name": "\(name)",
            "base": "women_base",
            "length": "\(length)",
            "texture": "\(texture)",
            "mode": "user_upload_preserve_everything_except_hair"
          },
          "input": {
            "image": {
              "source": "user_upload",
              "image_id": "{{UPLOAD_IMAGE_ID}}"
            }
          },
          "preservation": {
            "identity_lock": "MAX",
            "face_lock": "MAX",
            "facial_features_lock": "MAX",
            "skin_tone_lock": "MAX (preserve original)",
            "ethnicity_lock": "MAX (preserve original)",
            "body_lock": "MAX",
            "outfit_lock": "MAX",
            "jewelry_lock": "MAX",
            "background_lock": "MAX",
            "lighting_lock": "MAX",
            "shadows_lock": "MAX",
            "camera_perspective_lock": "MAX",
            "lens_distortion_lock": "MAX",
            "color_grading_lock": "MAX",
            "contrast_lock": "MAX",
            "sharpness_lock": "MAX",
            "do_not_beautify_face": true,
            "do_not_change_makeup": true,
            "do_not_change_expression": true,
            "do_not_change_age": true
          },
          "edit_mask": {
            "region": "hair_only",
            "auto_mask": true,
            "include": [
              "all scalp hair",
              "bangs/fringe area",
              "part line region",
              "hairline + baby hairs",
              "updo/ponytail/bun volume (if applicable)"
            ],
            "exclude": [
              "face skin",
              "eyebrows",
              "eyes",
              "nose",
              "lips",
              "ears (keep shape/size identical)",
              "neck",
              "body",
              "clothing",
              "background"
            ],
            "hard_rule": "ANY pixel outside hair region must remain unchanged"
          },
          "hair_edit": \(hairEditObjectJSON),
          "rendering_optimizations": {
            "hairline_realism": "MAX (no wig look, no hard edge)",
            "edge_blending": "seamless feathered edges (1-3px), match original anti-aliasing",
            "strand_detail": "HIGH (individual strands + coherent hair sheets)",
            "scalp_part_realism": "HIGH (natural part line, no painted scalp)",
            "shadow_consistency": "match original shadows on forehead/temples/neck",
            "highlight_consistency": "match original lighting direction and specular intensity",
            "texture_consistency": "match original camera noise/grain (subtle) so edits disappear",
            "avoid_artifacts": [
              "no halo around hair",
              "no cutout edges",
              "no floating hair",
              "no melted strands",
              "no duplicated hair patterns",
              "no weird scalp patches"
            ]
          },
          "negative_constraints": [
            "DO NOT change face shape",
            "DO NOT change eyes, nose, lips, eyebrows",
            "DO NOT change skin texture, skin tone, ethnicity",
            "DO NOT change body shape",
            "DO NOT change outfit, neckline, logos, accessories",
            "DO NOT change background or add studio equipment",
            "DO NOT add props",
            "DO NOT change lighting or color grading",
            "NO text, NO watermark, NO overlays",
            "NO cartoon, NO CGI, NO uncanny valley",
            "NO extra limbs/fingers (keep everything same)"
          ]
        }
        """
    }

    // MARK: - Public list
    static let all: [NanoBananaHairOnlyPrompt] = [

        // 90s Supermodel Blowout
        .init(
            id: "hair_only_90s_supermodel_blowout_v1",
            name: "90s Supermodel Blowout",
            json: baseJSON(
                id: "hair_only_90s_supermodel_blowout_v1",
                name: "90s Supermodel Blowout",
                length: "Long",
                texture: "Wavy",
                hairEditObjectJSON: """
                {
                  "edit_scope": "hair_only",
                  "color_rule": "preserve_original_color_exactly",
                  "cut": "keep long length; add long layers + strong face-framing pieces",
                  "part": "soft middle part (preserve original part position if visible)",
                  "styling": "90s blowout: lifted roots, big bouncy volume, airy movement, ends softly flipped outward",
                  "finish": "healthy glossy (not wet), zero frizz, controlled flyaways",
                  "shape_targets": {
                    "crown_volume": "HIGH",
                    "side_volume": "MEDIUM-HIGH",
                    "ends_flip": "soft outward flip",
                    "symmetry": "balanced volume both sides"
                  },
                  "hairline": {
                    "preserve_original_hairline": true,
                    "baby_hairs": "keep natural baby hairs (do not erase)",
                    "blend_rule": "no sharp new hairline"
                  },
                  "quality_checks": [
                    "avoid helmet hair",
                    "avoid uniform curl pattern",
                    "ensure blowout movement visible"
                  ]
                }
                """
            )
        ),

        // Beach Waves
        .init(
            id: "hair_only_beach_waves_v1",
            name: "Beach Waves",
            json: baseJSON(
                id: "hair_only_beach_waves_v1",
                name: "Beach Waves",
                length: "Medium",
                texture: "Wavy",
                hairEditObjectJSON: """
                {
                  "edit_scope": "hair_only",
                  "color_rule": "preserve_original_color_exactly",
                  "cut": "medium layers (keep overall length around shoulders/collarbone if possible)",
                  "part": "natural (slightly off-center, keep original part vibe)",
                  "styling": "textured beach waves: irregular bends, slightly piecey separation, lived-in movement",
                  "finish": "matte-satin (NOT glossy, NOT oily), minimal frizz, a few natural flyaways allowed",
                  "shape_targets": {
                    "wave_start": "around cheekbone/jaw",
                    "wave_uniformity": "LOW (avoid perfect S-waves)",
                    "volume": "MEDIUM airy"
                  },
                  "hairline": {
                    "preserve_original_hairline": true,
                    "blend_rule": "keep forehead/temple shadows identical"
                  }
                }
                """
            )
        ),

        // Butterfly Cut
        .init(
            id: "hair_only_butterfly_cut_v1",
            name: "Butterfly Cut",
            json: baseJSON(
                id: "hair_only_butterfly_cut_v1",
                name: "Butterfly Cut",
                length: "Long",
                texture: "Wavy",
                hairEditObjectJSON: """
                {
                  "edit_scope": "hair_only",
                  "color_rule": "preserve_original_color_exactly",
                  "cut": "long butterfly layers: short-to-long cascading layers, heavy face-framing, airy graduation",
                  "part": "middle part (keep original line position)",
                  "styling": "bouncy blowout: lifted roots, airy volume, ends softly flipped, face-framing pieces curved outward",
                  "finish": "healthy shine (not wet), zero frizz",
                  "shape_targets": {
                    "crown_volume": "HIGH",
                    "face_framing": "MAX (cheekbone framing)",
                    "layer_definition": "CLEAR but natural"
                  },
                  "hairline": { "preserve_original_hairline": true }
                }
                """
            )
        ),

        // Curtain Bangs + Long Layers
        .init(
            id: "hair_only_curtain_bangs_long_layers_v1",
            name: "Curtain Bangs + Long Layers",
            json: baseJSON(
                id: "hair_only_curtain_bangs_long_layers_v1",
                name: "Curtain Bangs + Long Layers",
                length: "Long",
                texture: "Wavy",
                hairEditObjectJSON: """
                {
                  "edit_scope": "hair_only",
                  "color_rule": "preserve_original_color_exactly",
                  "cut": "long layers with blended curtain bangs (face-framing that splits in the center and sweeps to both sides)",
                  "bangs": "curtain fringe: shorter near center, lengthening toward cheekbones, seamless blend into layers",
                  "part": "middle part (curtain split), keep original part alignment",
                  "styling": "soft blowout waves: smooth roots, airy movement, curtain pieces curved away from face",
                  "finish": "soft glossy (not mirror), minimal flyaways",
                  "quality_checks": [
                    "bangs must not look pasted-on",
                    "avoid covering both eyes",
                    "blend bangs into side lengths seamlessly"
                  ],
                  "hairline": { "preserve_original_hairline": true }
                }
                """
            )
        ),

        // Sleek Straight Middle Part
        .init(
            id: "hair_only_sleek_straight_middle_part_v1",
            name: "Sleek Straight Middle Part",
            json: baseJSON(
                id: "hair_only_sleek_straight_middle_part_v1",
                name: "Sleek Straight Middle Part",
                length: "Long",
                texture: "Straight",
                hairEditObjectJSON: """
                {
                  "edit_scope": "hair_only",
                  "color_rule": "preserve_original_color_exactly",
                  "cut": "long with minimal layers (keep perimeter clean)",
                  "part": "precise middle part (match original scalp line position if visible)",
                  "styling": "ultra sleek straight: zero flyaways, aligned hair sheets, smooth crown",
                  "finish": "mirror-sleek but natural (NOT oily), high smoothness",
                  "shape_targets": {
                    "frizz": "ZERO",
                    "flyaways": "NEAR ZERO",
                    "root_lift": "LIGHT (avoid flat helmet)"
                  },
                  "hairline": {
                    "preserve_original_hairline": true,
                    "keep_baby_hairs": true
                  }
                }
                """
            )
        ),

        // Glass Hair
        .init(
            id: "hair_only_glass_hair_v1",
            name: "Glass Hair",
            json: baseJSON(
                id: "hair_only_glass_hair_v1",
                name: "Glass Hair",
                length: "Long",
                texture: "Straight",
                hairEditObjectJSON: """
                {
                  "edit_scope": "hair_only",
                  "color_rule": "preserve_original_color_exactly",
                  "cut": "long blunt or soft-layered (preserve existing length as much as possible)",
                  "part": "middle part (precise, clean line)",
                  "styling": "maximum shine glass-hair: ultra smooth, reflective highlight bands, perfectly aligned hair sheets",
                  "finish": "high-gloss reflective (NOT wet/oily), zero frizz",
                  "highlight_rules": {
                    "specular_bands": "continuous and coherent with original light direction",
                    "no_plastic": true
                  },
                  "hairline": { "preserve_original_hairline": true }
                }
                """
            )
        ),

        // Modern Shag
        .init(
            id: "hair_only_modern_shag_v1",
            name: "Modern Shag",
            json: baseJSON(
                id: "hair_only_modern_shag_v1",
                name: "Modern Shag",
                length: "Medium",
                texture: "Wavy",
                hairEditObjectJSON: """
                {
                  "edit_scope": "hair_only",
                  "color_rule": "preserve_original_color_exactly",
                  "cut": "modern shag: layered crown, textured mid-lengths, airy shape, piecey ends",
                  "part": "natural (keep original vibe)",
                  "styling": "messy-chic texture: soft volume, piecey definition, controlled movement (not frizzy)",
                  "finish": "matte-satin texture, natural separation",
                  "shape_targets": {
                    "crown_volume": "MEDIUM-HIGH",
                    "end_texture": "HIGH (piecey)",
                    "uniformity": "LOW (avoid perfect symmetry waves)"
                  },
                  "hairline": { "preserve_original_hairline": true }
                }
                """
            )
        ),

        // Bottleneck Bangs
        .init(
            id: "hair_only_bottleneck_bangs_v1",
            name: "Bottleneck Bangs",
            json: baseJSON(
                id: "hair_only_bottleneck_bangs_v1",
                name:  "Bottleneck Bangs",
                length: "Medium",
                texture: "Straight",
                hairEditObjectJSON: """
                {
                  "edit_scope": "hair_only",
                  "color_rule": "preserve_original_color_exactly",
                  "cut": "medium length with subtle layers",
                  "bangs": "bottleneck fringe: denser center, opens toward sides, blends into cheekbone-length pieces",
                  "part": "soft middle (keep original alignment)",
                  "styling": "smooth blowout with slight bend at ends; bangs curve gently and open at sides",
                  "finish": "satin smooth (not glass), minimal flyaways",
                  "quality_checks": [
                    "bang density must look natural",
                    "avoid a blunt straight bang line",
                    "do not cover both eyes"
                  ],
                  "hairline": { "preserve_original_hairline": true }
                }
                """
            )
        ),

        // Italian Bob
        .init(
            id: "hair_only_italian_bob_v1",
            name: "Italian Bob",
            json: baseJSON(
                id: "hair_only_italian_bob_v1",
                name: "Italian Bob",
                length: "Short",
                texture: "Wavy",
                hairEditObjectJSON: """
                {
                  "edit_scope": "hair_only",
                  "color_rule": "preserve_original_color_exactly",
                  "cut": "fuller bob with weight and volume; ends rounded; jaw-to-neck length",
                  "part": "side part (choose the side that matches original hair flow best)",
                  "styling": "luxe blowout volume: smooth roots, soft rounded bend, bouncy movement",
                  "finish": "healthy glossy (not wet), very controlled flyaways",
                  "shape_targets": {
                    "bob_weight": "FULL",
                    "volume": "MEDIUM-HIGH",
                    "end_roundness": "SOFT rounded"
                  },
                  "hairline": { "preserve_original_hairline": true }
                }
                """
            )
        ),

        // Hollywood Waves
        .init(
            id: "hair_only_hollywood_waves_v1",
            name: "Hollywood Waves",
            json: baseJSON(
                id: "hair_only_hollywood_waves_v1",
                name: "Hollywood Waves",
                length: "Long",
                texture: "Wavy",
                hairEditObjectJSON: """
                {
                  "edit_scope": "hair_only",
                  "color_rule": "preserve_original_color_exactly",
                  "cut": "long smooth layers (keep length)",
                  "part": "deep side part",
                  "styling": "polished Hollywood S-waves: uniform wave pattern, glossy and sculpted, red-carpet finish",
                  "finish": "polished glossy (not wet), zero frizz, immaculate wave definition",
                  "shape_targets": {
                    "wave_uniformity": "HIGH",
                    "wave_size": "MEDIUM-LARGE",
                    "shine": "MEDIUM-HIGH"
                  },
                  "hairline": { "preserve_original_hairline": true }
                }
                """
            )
        ),

        // High Sleek Ponytail
        .init(
            id: "hair_only_high_sleek_ponytail_v1",
            name: "High Sleek Ponytail",
            json: baseJSON(
                id: "hair_only_high_sleek_ponytail_v1",
                name: "High Sleek Ponytail",
                length: "Long",
                texture: "Straight",
                hairEditObjectJSON: """
                {
                  "edit_scope": "hair_only",
                  "color_rule": "preserve_original_color_exactly",
                  "style": "high sleek ponytail",
                  "placement": "high crown ponytail (snatched), keep head shape natural",
                  "crown": "ultra smooth scalp, zero bumps, minimal flyaways",
                  "ponytail_length": "preserve original length as much as possible",
                  "finish": "glossy (not wet), sleek hair sheets",
                  "tie_rule": "use a simple black hair tie OR wrap a small hair strand around tie (no logos, no accessories)",
                  "hairline": {
                    "preserve_original_hairline": true,
                    "baby_hairs": "keep natural baby hairs; do not erase"
                  }
                }
                """
            )
        ),

        // Defined Curls
        .init(
            id: "hair_only_defined_curls_v1",
            name: "Defined Curls",
            json: baseJSON(
                id: "hair_only_defined_curls_v1",
                name: "Defined Curls",
                length: "Medium",
                texture: "Curly",
                hairEditObjectJSON: """
                {
                  "edit_scope": "hair_only",
                  "color_rule": "preserve_original_color_exactly",
                  "cut": "medium curly cut with clean shape; balanced volume",
                  "part": "natural (keep original part vibe)",
                  "styling": "defined curls: clumped definition, consistent curl families, minimal frizz, soft bounce",
                  "finish": "hydrated satin (not greasy), realistic curl shine",
                  "curl_controls": {
                    "curl_tightness": "medium curls (not coils unless original is coily)",
                    "definition": "HIGH",
                    "frizz": "LOW",
                    "volume": "MEDIUM"
                  },
                  "hairline": {
                    "preserve_original_hairline": true,
                    "blend_rule": "no hard curl cutout edges on forehead"
                  }
                }
                """
            )
        ),

        // Slick Back Bun
        .init(
            id: "hair_only_slick_back_bun_v1",
            name: "Slick Back Bun",
            json: baseJSON(
                id: "hair_only_slick_back_bun_v1",
                name: "Slick Back Bun",
                length: "Medium",
                texture: "Straight",
                hairEditObjectJSON: """
                {
                  "edit_scope": "hair_only",
                  "color_rule": "preserve_original_color_exactly",
                  "style": "slick back bun",
                  "part": "none OR very subtle middle part (match what looks most natural with the original hairline)",
                  "styling": "hair slicked back tight and smooth into a compact bun; zero flyaways; clean edges",
                  "bun_placement": "low-to-mid bun at the back of head (natural, not oversized)",
                  "finish": "sleek satin (NOT wet/oily), smooth scalp",
                  "tie_rule": "simple black hair tie only (invisible), no decorative accessories",
                  "hairline": {
                    "preserve_original_hairline": true,
                    "baby_hairs": "keep natural baby hairs"
                  }
                }
                """
            )
        ),

        // Claw Clip Twist
        .init(
            id: "hair_only_claw_clip_twist_v1",
            name: "Claw Clip Twist",
            json: baseJSON(
                id: "hair_only_claw_clip_twist_v1",
                name: "Claw Clip Twist",
                length: "Medium",
                texture: "Wavy",
                hairEditObjectJSON: """
                {
                  "edit_scope": "hair_only",
                  "color_rule": "preserve_original_color_exactly",
                  "style": "twist secured with claw clip",
                  "twist": "classic French twist fold with ends tucked, relaxed but clean",
                  "clip_rule": "IF a clip is required, add ONLY a neutral matte black claw clip (small/medium), no decorative clip, no logos",
                  "styling": "effortless chic, soft texture; keep a few natural face-framing strands if the original photo already has them",
                  "finish": "matte-satin, minimal flyaways",
                  "hairline": { "preserve_original_hairline": true }
                }
                """
            )
        ),
        
        // Half-Up Half-Down
        .init(
            id: "hair_only_half_up_half_down_v1",
            name: "Half-Up Half-Down",
            json: baseJSON(
                id: "hair_only_half_up_half_down_v1",
                name: "Half-Up Half-Down",
                length: "Long",
                texture: "Wavy",
                hairEditObjectJSON: """
                {
                  "edit_scope": "hair_only",
                  "color_rule": "preserve_original_color_exactly",
                  "style": "romantic half-up half-down",
                  "top_section": "gather top crown section, secure at back of head with invisible tie or small clip",
                  "bottom_section": "leave remaining hair flowing down; soft waves or natural texture",
                  "part": "soft middle or natural part (keep original alignment)",
                  "styling": "effortless romantic: soft face-framing tendrils, relaxed but polished",
                  "finish": "soft satin shine (not wet), minimal flyaways",
                  "shape_targets": {
                    "crown_volume": "MEDIUM (lifted but natural)",
                    "face_framing": "soft pieces around temples/cheekbones",
                    "bottom_texture": "soft waves or natural flow"
                  },
                  "hairline": { "preserve_original_hairline": true }
                }
                """
            )
        ),
        
        // Wet Look
        .init(
            id: "hair_only_wet_look_v1",
            name: "Wet Look",
            json: baseJSON(
                id: "hair_only_wet_look_v1",
                name: "Wet Look",
                length: "Long",
                texture: "Straight",
                hairEditObjectJSON: """
                {
                  "edit_scope": "hair_only",
                  "color_rule": "preserve_original_color_exactly",
                  "style": "editorial wet look / slicked back",
                  "part": "slicked back from forehead OR deep side part (keep what looks best with face shape)",
                  "styling": "high-fashion wet effect: slicked close to scalp, hair appears freshly wet/gelled, smooth sheets",
                  "finish": "WET glossy (like fresh out of shower), high shine, zero frizz, sculptural definition",
                  "shape_targets": {
                    "scalp_visibility": "SOME (slicked tight)",
                    "hair_clumping": "wet clumps, not individual strand separation",
                    "root_lift": "FLAT (slicked down)"
                  },
                  "hairline": {
                    "preserve_original_hairline": true,
                    "baby_hairs": "slick down baby hairs for editorial look"
                  },
                  "quality_checks": [
                    "avoid helmet look - keep some natural movement",
                    "ensure wet effect looks intentional not greasy"
                  ]
                }
                """
            )
        ),
        
        // Bouncy Blowout
        .init(
            id: "hair_only_bouncy_blowout_v1",
            name: "Bouncy Blowout",
            json: baseJSON(
                id: "hair_only_bouncy_blowout_v1",
                name: "Bouncy Blowout",
                length: "Long",
                texture: "Wavy",
                hairEditObjectJSON: """
                {
                  "edit_scope": "hair_only",
                  "color_rule": "preserve_original_color_exactly",
                  "cut": "keep long length; add subtle layers for movement",
                  "part": "soft side part or natural part (keep original alignment)",
                  "styling": "salon-fresh bouncy blowout: lifted voluminous roots, smooth mid-lengths, soft bouncy curled ends",
                  "finish": "healthy glossy shine (not wet), zero frizz, full-bodied bounce",
                  "shape_targets": {
                    "root_volume": "HIGH (lifted at crown)",
                    "mid_length": "smooth and voluminous",
                    "ends": "bouncy curl/flip (not stiff)",
                    "overall_shape": "full, rounded, airy"
                  },
                  "hairline": {
                    "preserve_original_hairline": true,
                    "baby_hairs": "keep natural baby hairs"
                  },
                  "quality_checks": [
                    "avoid helmet hair",
                    "ensure bounce looks natural not curling-iron stiff",
                    "volume should look airy not heavy"
                  ]
                }
                """
            )
        ),
        
        // The Italian Bob
        .init(
            id: "hair_only_italian_bob_v2",
            name: "The Italian Bob",
            json: baseJSON(
                id: "hair_only_italian_bob_v2",
                name: "The Italian Bob",
                length: "Short",
                texture: "Wavy",
                hairEditObjectJSON: """
                {
                  "edit_scope": "hair_only",
                  "color_rule": "preserve_original_color_exactly",
                  "cut": "elegant Italian bob: jaw-to-chin length, fuller with weight and volume, soft rounded ends",
                  "bangs": "optional soft curtain fringe or no bangs (keep what suits face shape best)",
                  "part": "soft side part or natural part",
                  "styling": "luxe Italian blowout: smooth roots, soft rounded bend, bouncy movement, effortless sophistication",
                  "finish": "healthy glossy (not wet), very controlled flyaways",
                  "shape_targets": {
                    "bob_length": "jaw-to-chin",
                    "weight": "FULL rounded",
                    "volume": "MEDIUM-HIGH",
                    "texture": "soft waves with bounce"
                  },
                  "hairline": { "preserve_original_hairline": true },
                  "quality_checks": [
                    "ensure bob looks luxurious and bouncy",
                    "maintain soft wave texture",
                    "avoid flat or helmet-like appearance"
                  ]
                }
                """
            )
        ),
        
        // Soft Waves
        .init(
            id: "hair_only_soft_waves_v1",
            name: "Soft Waves",
            json: baseJSON(
                id: "hair_only_soft_waves_v1",
                name: "Soft Waves",
                length: "Long",
                texture: "Wavy",
                hairEditObjectJSON: """
                {
                  "edit_scope": "hair_only",
                  "color_rule": "preserve_original_color_exactly",
                  "cut": "keep long length with soft layers",
                  "part": "natural part (keep original alignment)",
                  "styling": "effortless soft waves: gentle S-curves, natural movement, relaxed romantic vibe",
                  "finish": "soft satin shine (not wet), minimal frizz, touchable texture",
                  "shape_targets": {
                    "wave_pattern": "loose, irregular S-waves",
                    "wave_start": "around cheekbone/jaw area",
                    "volume": "MEDIUM natural",
                    "uniformity": "LOW (avoid perfect uniform waves)"
                  },
                  "hairline": { "preserve_original_hairline": true },
                  "quality_checks": [
                    "waves should look natural not curling-iron perfect",
                    "maintain soft romantic feel"
                  ]
                }
                """
            )
        ),
        
        // Sleek Straight
        .init(
            id: "hair_only_sleek_straight_v1",
            name: "Sleek Straight",
            json: baseJSON(
                id: "hair_only_sleek_straight_v1",
                name: "Sleek Straight",
                length: "Long",
                texture: "Straight",
                hairEditObjectJSON: """
                {
                  "edit_scope": "hair_only",
                  "color_rule": "preserve_original_color_exactly",
                  "cut": "long with minimal layers (keep perimeter clean)",
                  "part": "natural part or middle part (keep original alignment)",
                  "styling": "sleek straight: smooth aligned hair sheets, zero flyaways, polished finish",
                  "finish": "healthy glossy (not wet), high smoothness, light at roots",
                  "shape_targets": {
                    "frizz": "ZERO",
                    "flyaways": "NEAR ZERO",
                    "root_lift": "LIGHT (avoid flat helmet)",
                    "alignment": "perfectly aligned strands"
                  },
                  "hairline": {
                    "preserve_original_hairline": true,
                    "keep_baby_hairs": true
                  }
                }
                """
            )
        ),
        
        // Wolf Cut
        .init(
            id: "hair_only_wolf_cut_v1",
            name: "Wolf Cut",
            json: baseJSON(
                id: "hair_only_wolf_cut_v1",
                name: "Wolf Cut",
                length: "Medium",
                texture: "Wavy",
                hairEditObjectJSON: """
                {
                  "edit_scope": "hair_only",
                  "color_rule": "preserve_original_color_exactly",
                  "cut": "wolf cut: heavy layered top with shaggy mid-lengths, face-framing pieces, textured ends",
                  "bangs": "optional curtain bangs or wispy fringe (keep what suits face shape)",
                  "part": "natural middle or slight off-center part",
                  "styling": "messy voluminous texture: lifted crown, shaggy movement, rebellious yet wearable",
                  "finish": "matte-satin texture (not glossy), natural piecey separation",
                  "shape_targets": {
                    "crown_volume": "HIGH (short layers on top)",
                    "face_framing": "strong cheekbone-length pieces",
                    "texture": "HIGH shaggy movement",
                    "uniformity": "LOW (intentionally messy)"
                  },
                  "hairline": { "preserve_original_hairline": true },
                  "quality_checks": [
                    "ensure layers create volume not flatness",
                    "maintain shaggy edgy vibe",
                    "avoid uniform curl pattern"
                  ]
                }
                """
            )
        ),
        
        // Wavy Lob
        .init(
            id: "hair_only_wavy_lob_v1",
            name: "Wavy Lob",
            json: baseJSON(
                id: "hair_only_wavy_lob_v1",
                name: "Wavy Lob",
                length: "Medium",
                texture: "Wavy",
                hairEditObjectJSON: """
                {
                  "edit_scope": "hair_only",
                  "color_rule": "preserve_original_color_exactly",
                  "cut": "long bob (lob): collarbone length, soft layers, textured ends",
                  "part": "natural or slight off-center part (keep original alignment)",
                  "styling": "effortless beach waves: loose S-curves, natural movement, lived-in texture",
                  "finish": "satin healthy shine (not wet), minimal frizz, touchable texture",
                  "shape_targets": {
                    "length": "collarbone/shoulder length",
                    "wave_pattern": "loose irregular S-waves",
                    "wave_start": "around cheekbone area",
                    "volume": "MEDIUM airy"
                  },
                  "hairline": { "preserve_original_hairline": true },
                  "quality_checks": [
                    "ensure waves look effortless not curled",
                    "maintain natural movement",
                    "lob length should hit at collarbone"
                  ]
                }
                """
            )
        )
    ]
    
    // MARK: - Helper to get prompt by hairstyle name
    static func prompt(for hairstyleName: String) -> NanoBananaHairOnlyPrompt? {
        all.first { $0.name == hairstyleName }
    }
}
