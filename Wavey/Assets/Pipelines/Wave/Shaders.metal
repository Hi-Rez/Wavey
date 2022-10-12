typedef struct {
    float4 color; // color
    float2x2 orientationTransform;
    float2 orientationOffset;
    float amplitude;
    float frequency;
    float speed;
    float time;
} WaveUniforms;

typedef struct {
    float4 position [[position]];
    float4 originalPosition [[center_no_perspective]];
    float3 depthDisplacementFalloff [[flat]];
    float2 uv;
    float2 viewportSize [[flat]];
} CustomVertexData;

vertex CustomVertexData waveVertex( Vertex in [[stage_in]],
                                   constant VertexUniforms &vertexUniforms [[ buffer( VertexBufferVertexUniforms ) ]],
                                   constant WaveUniforms &uniforms [[ buffer( VertexBufferMaterialUniforms ) ]] ) {
    CustomVertexData out;
    
    const float distance = saturate(0.5 - length(in.position.xy));
    const float fallOff = saturate(smoothstep(0.0, 0.5, distance));
    const float displacement = uniforms.amplitude * sin(distance * uniforms.frequency + uniforms.speed * uniforms.time);
    
    float4 position = in.position;
    position.z += fallOff * displacement;

    out.position = vertexUniforms.modelViewProjectionMatrix * position;
    out.originalPosition = vertexUniforms.modelViewProjectionMatrix * in.position;
    
    const float3 viewPosition = float3(vertexUniforms.modelViewMatrix * in.position);
    out.depthDisplacementFalloff = float3(-viewPosition.z, displacement, fallOff);
    out.uv = in.uv;
    out.viewportSize = vertexUniforms.viewport.zw;
    return out;
}

fragment float4 waveFragment(CustomVertexData in [[stage_in]],
                             constant WaveUniforms &uniforms [[ buffer( FragmentBufferMaterialUniforms ) ]],
                             texture2d<float, access::sample> depthTexture [[ texture( FragmentTextureCustom0 ) ]],
                             texture2d<float, access::sample> cameraTexture [[ texture( FragmentTextureCustom1 ) ]] )
{
    constexpr sampler s = sampler(min_filter::linear, mag_filter::linear);
    const float2 uv = in.position.xy / in.viewportSize;
    const float2 depthUV = uniforms.orientationTransform * uv + uniforms.orientationOffset;
    const float arDepth = depthTexture.sample(s, depthUV).r;
    
    
    float2 cuv = 0.5 * ((in.originalPosition.xy/in.originalPosition.w) + 1.0);
    cuv.y = 1.0 - cuv.y;
    
    float4 cameraSample = cameraTexture.sample(s, cuv);
    const float displacement = in.depthDisplacementFalloff.y;
    const float fallOff = in.depthDisplacementFalloff.z;
    
    //0.0175 = depth offset to prevent z-fighting
    const float alpha = step((in.depthDisplacementFalloff.x - abs(displacement * fallOff)), (arDepth + 0.0175));
    cameraSample.a *= alpha;
    
    return cameraSample;
}
