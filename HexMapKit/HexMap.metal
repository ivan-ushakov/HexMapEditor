//
//  HexMap.metal
//  HexMapKit
//
//  Created by  Ivan Ushakov on 28/11/2018.
//  Copyright © 2018  Ivan Ushakov. All rights reserved.
//

#include <metal_stdlib>

using namespace metal;

#include <SceneKit/scn_metal>

constexpr sampler sampler2d(coord::normalized, filter::linear, address::repeat);

constant float4 blue_color(64.0 / 255.0, 105.0 / 255.0, 255.0 / 255.0, 74.0 / 255.0);

struct MyNodeBuffer
{
    float4x4 modelTransform;
    float4x4 modelViewTransform;
    float4x4 modelViewProjectionTransform;
    float4x4 normalTransform;
};

struct TerrainVertexInput
{
    float3 position [[attribute(SCNVertexSemanticPosition)]];
    float3 normal [[attribute(SCNVertexSemanticNormal)]];
    float4 color [[attribute(SCNVertexSemanticColor)]];
};

struct TerrainVertexOutput
{
    float4 position [[position]];
    float4 normal;
    float4 light;
    float3 p;
    float3 terrain;
    float4 color;
};

struct Light
{
    packed_float3 position;
};

vertex TerrainVertexOutput terrainVertex(TerrainVertexInput in [[stage_in]],
                                         constant SCNSceneBuffer& scn_frame [[buffer(0)]],
                                         constant MyNodeBuffer& scn_node [[buffer(1)]],
                                         constant packed_float3* terrain [[buffer(2)]],
                                         constant Light& light [[buffer(3)]],
                                         uint vid [[vertex_id]])
{
    TerrainVertexOutput v;
    
    v.position = scn_node.modelViewProjectionTransform * float4(in.position, 1.0);
    v.normal = scn_node.normalTransform * float4(in.normal, 1.0);
    
    v.light = scn_node.modelTransform * float4(light.position, 1.0);
    v.p = (scn_node.modelTransform * float4(in.position, 1.0)).xyz;
    
    v.terrain = terrain[vid];
    v.color = in.color;
    
    return v;
}

fragment half4 terrainFragment(TerrainVertexOutput in [[stage_in]],
                               texture2d_array<float> terrainTexture [[texture(0)]],
                               texture2d<float> gridTexture [[texture(1)]])
{
    float2 uv = in.p.xz * 0.02;
    
    float4 c1 = terrainTexture.sample(sampler2d, uv, in.terrain[0]);
    float4 c2 = terrainTexture.sample(sampler2d, uv, in.terrain[1]);
    float4 c3 = terrainTexture.sample(sampler2d, uv, in.terrain[2]);
    
    float2 gridUV = in.p.xz;
    gridUV.x *= 1.0 / (4.0 * 8.66025404);
    gridUV.y *= 1.0 / (2.0 * 15.0);
    float4 grid = gridTexture.sample(sampler2d, gridUV);

    // lighting

    float4 diffuseColor = c1 * in.color[0] + c2 * in.color[1] + c3 * in.color[2];
    float4 lightDiffuse(1.0, 1.0, 1.0, 1.0);
    
    float3 lightP = float3(in.light);
    float3 normal = float3(in.normal);
    
    float nDotVP = max(0.0, dot(normalize(normal), normalize(lightP)));
    float4 diffuse = lightDiffuse * nDotVP;
    
    return half4(diffuseColor * grid * diffuse);
}

struct RiverVertexInput
{
    float3 position [[attribute(SCNVertexSemanticPosition)]];
    float2 texCoords [[attribute(SCNVertexSemanticTexcoord0)]];
};

struct RiverVertexOutput
{
    float4 position [[position]];
    float2 texCoords;
    float time;
};

vertex RiverVertexOutput riverVertex(RiverVertexInput in [[stage_in]],
                                     constant SCNSceneBuffer& scn_frame [[buffer(0)]],
                                     constant MyNodeBuffer& scn_node [[buffer(1)]])
{
    RiverVertexOutput v;
    
    v.position = scn_node.modelViewProjectionTransform * float4(in.position, 1.0);
    v.texCoords = in.texCoords;
    v.time = scn_frame.time;
    
    return v;
}

fragment half4 riverFragment(RiverVertexOutput in [[stage_in]],
                             texture2d<float> noiseTexture [[texture(0)]])
{
    float2 uv1 = in.texCoords;
    uv1.x = uv1.x * 0.0625 + in.time * 0.005;
    uv1.y -= in.time * 0.25;
    float4 noise1 = noiseTexture.sample(sampler2d, uv1);
    
    float2 uv2 = in.texCoords;
    uv2.x = uv2.x * 0.0625 - in.time * 0.0052;
    uv2.y -= in.time * 0.23;
    float4 noise2 = noiseTexture.sample(sampler2d, uv2);
    
    float4 color = saturate(blue_color + noise1.r * noise2.a);
    return half4(color);
}

static float f_foam(float shore, float2 worldXZ, float time, texture2d<float> noiseTexture) {
    shore = sqrt(shore) * 0.9;
    
    float2 noiseUV = worldXZ + time * 0.25;
    float4 noise = noiseTexture.sample(sampler2d, noiseUV * 0.015);
    
    float distortion1 = noise.x * (1 - shore);
    float foam1 = sin((shore + distortion1) * 10 - time);
    foam1 *= foam1;
    
    float distortion2 = noise.y * (1 - shore);
    float foam2 = sin((shore + distortion2) * 10 + time + 2);
    foam2 *= foam2 * 0.7;
    
    return max(foam1, foam2) * shore;
}

static float f_waves(float2 worldXZ, float time, texture2d<float> noiseTexture) {
    float2 uv1 = worldXZ;
    uv1.y += time;
    float4 noise1 = noiseTexture.sample(sampler2d, uv1 * 0.025);
    
    float2 uv2 = worldXZ;
    uv2.x += time;
    float4 noise2 = noiseTexture.sample(sampler2d, uv2 * 0.025);
    
    float blendWave = sin((worldXZ.x + worldXZ.y) * 0.1 + (noise1.y + noise2.z) + time);
    blendWave *= blendWave;
    
    float l1 = noise1.z + (noise1.w - noise1.z) * blendWave;
    float l2 = noise2.x + (noise2.y - noise2.x) * blendWave;
    float waves = l1 + l2;
    
    return smoothstep(0.75, 2.0, waves);
}

struct WaterVertexInput
{
    float3 position [[attribute(SCNVertexSemanticPosition)]];
};

struct WaterVertexOutput
{
    float4 position [[position]];
    float3 p;
    float time;
};

vertex WaterVertexOutput waterVertex(WaterVertexInput in [[stage_in]],
                                     constant SCNSceneBuffer& scn_frame [[buffer(0)]],
                                     constant MyNodeBuffer& scn_node [[buffer(1)]])
{
    WaterVertexOutput v;
    
    v.position = scn_node.modelViewProjectionTransform * float4(in.position, 1.0);
    v.p = v.position.xyz;
    v.time = scn_frame.time;
    
    return v;
}

fragment half4 waterFragment(WaterVertexOutput in [[stage_in]],
                             texture2d<float> noiseTexture [[texture(0)]])
{
    float waves = f_waves(in.p.xz, in.time, noiseTexture);
    float4 c = saturate(blue_color + waves);
    return half4(c);
}

struct WaterShoreVertexInput
{
    float3 position [[attribute(SCNVertexSemanticPosition)]];
    float2 texCoords [[attribute(SCNVertexSemanticTexcoord0)]];
};

struct WaterShoreVertexOutput
{
    float4 position [[position]];
    float3 p;
    float2 texCoords;
    float time;
};

vertex WaterShoreVertexOutput waterShoreVertex(WaterShoreVertexInput in [[stage_in]],
                                               constant SCNSceneBuffer& scn_frame [[buffer(0)]],
                                               constant MyNodeBuffer& scn_node [[buffer(1)]])
{
    WaterShoreVertexOutput v;
    
    v.position = scn_node.modelViewProjectionTransform * float4(in.position, 1.0);
    v.p = v.position.xyz;
    v.texCoords = in.texCoords;
    v.time = scn_frame.time;
    
    return v;
}

fragment half4 waterShoreFragment(WaterShoreVertexOutput in [[stage_in]],
                                  texture2d<float> noiseTexture [[texture(0)]])
{
    float shore = in.texCoords.y;
    float foam = f_foam(shore, in.p.xz, in.time, noiseTexture);
    float waves = f_waves(in.p.xz, in.time, noiseTexture);
    waves *= 1 - shore;
    
    float4 c = saturate(blue_color + max(foam, waves));
    return half4(c);
}
