// Alloy Physical Shader Framework
// Copyright 2013-2017 RUST LLC.
// http://www.alloy.rustltd.com/

import lib-pbr.glsl
import lib-pom.glsl

// Link Metal/Roughness MDL for Iray
//: metadata {
//:   "mdl":"mdl::alg::materials::physically_metallic_roughness::physically_metallic_roughness"
//: }

//- Show back faces as there may be holes in front faces.
//: state cull_face off

//- Enable alpha blending
//: state blend over

//- Channels needed for metal/rough workflow are bound here.
//: param auto channel_basecolor
uniform sampler2D basecolor_tex;
//: param auto channel_roughness
uniform sampler2D roughness_tex;
//: param auto channel_metallic
uniform sampler2D metallic_tex;
//: param auto channel_specularlevel
uniform sampler2D specularlevel_tex;
//: param auto channel_opacity
uniform sampler2D opacity_tex;

vec4 alloyComputeBRDF(V2F inputs, vec3 diffColor, vec3 specColor, float glossiness, float occlusion)
{  
  LocalVectors vectors = computeLocalFrame(inputs);

  // Gotanda's Specular occlusion approximation:
  // cf http://research.tri-ace.com/Data/cedec2011_RealtimePBR_Implementation_e.pptx pg59
  float ndv = abs(dot(vectors.eye, vectors.normal));
  float d = ndv + occlusion;
  float so = clamp((d * d) - 1.0 + occlusion, 0.0, 1.0);
  
  // Apply SP's shadow factor (always on rough, not on smooth).
  float shadow = getShadowFactor();
  vec3 diffuse = pbrComputeDiffuse(vectors.normal, vec3(1.0, 1.0, 1.0), shadow * occlusion);
  vec3 specular = pbrComputeSpecular(vectors, specColor, glossiness, shadow);
  
  return vec4(
      diffuse * diffColor +
      mix(diffuse * specColor, specular, so) +
      pbrComputeEmissive(emissive_tex, inputs.tex_coord),
      1.0);
}

//- Shader entry point.
vec4 shade(V2F inputs)
{
  // Apply parallax occlusion mapping if possible
  vec3 viewTS = worldSpaceToTangentSpace(getEyeVec(inputs.position), inputs);
  inputs.tex_coord += getParallaxOffset(inputs.tex_coord, viewTS);

  // Fetch material parameters, and conversion to the specular/glossiness model
  float glossiness = 1.0 - getRoughness(roughness_tex, inputs.tex_coord);
  vec3 baseColor = getBaseColor(basecolor_tex, inputs.tex_coord);
  float metallic = getMetallic(metallic_tex, inputs.tex_coord);
  float specularLevel = getSpecularLevel(specularlevel_tex, inputs.tex_coord);
  vec3 diffColor = generateDiffuseColor(baseColor, metallic);
  vec3 specColor = generateSpecularColor(specularLevel, baseColor, metallic);
  // Get detail (ambient occlusion) and global (shadow) occlusion factors
  float occlusion = getAO(inputs.tex_coord);// * getShadowFactor();

  // Feed parameters for a physically based BRDF integration
  return vec4(
    alloyComputeBRDF(inputs, diffColor, specColor, glossiness, occlusion).rgb,
    getOpacity(opacity_tex, inputs.tex_coord));
}

//- Entry point of the shadow pass.
void shadeShadow(V2F inputs)
{
}