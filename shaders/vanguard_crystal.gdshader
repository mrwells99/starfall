shader_type spatial;

// Cell scale controls the size of the internal facets/fissures.
// Default 31.0 matches the original character study crystal look
// (tight, high-frequency veining). Set lower (~3.0-6.0) for large
// internal facets that read as an angular crystal block from close range.
uniform float cell_scale : hint_range(1.0, 60.0) = 31.0;
// Global emission brightness; boosted for the hammer to push through
// the metal housing and land above the 1.35 bloom threshold.
uniform float emission_boost : hint_range(0.0, 6.0) = 1.0;
// Depth of the fissure band (larger = wider, softer glow bands).
uniform float fissure_softness : hint_range(0.005, 0.20) = 0.05;

varying vec3 crystal_position;

vec3 hash3(vec3 p){
    return fract(sin(vec3(dot(p,vec3(127.1,311.7,74.7)),
                          dot(p,vec3(269.5,183.3,246.1)),
                          dot(p,vec3(113.5,271.9,124.6))))*43758.5453);
}

void vertex(){ crystal_position = VERTEX; }

void fragment(){
    vec3 p = crystal_position * cell_scale;
    vec3 cell = floor(p);
    vec3 f = fract(p);
    float nearest = 9.0;
    float second = 9.0;
    for(int x=-1;x<=1;x++){
        for(int y=-1;y<=1;y++){
            for(int z=-1;z<=1;z++){
                vec3 o = vec3(float(x),float(y),float(z));
                vec3 d = o + hash3(cell + o) - f;
                float v = dot(d, d);
                if(v < nearest){ second = nearest; nearest = v; }
                else { second = min(second, v); }
            }
        }
    }
    float fissure = 1.0 - smoothstep(0.012, 0.012 + fissure_softness, second - nearest);
    // Base violet, deepened between facets so the fissures pop.
    vec3 deep   = vec3(0.030, 0.005, 0.10);
    vec3 mid    = vec3(0.32,  0.045, 0.68);
    vec3 hot    = vec3(0.95,  0.60,  1.00);
    vec3 albedo = mix(deep, mid, clamp(nearest, 0.0, 1.0));
    ALBEDO = albedo;
    METALLIC = 0.20;
    ROUGHNESS = 0.22;
    // Fissure-driven emission pulses very gently. Emission_boost lets the
    // hammer crystal punch well past the bloom threshold without altering
    // the surface albedo colour.
    vec3 core = albedo * 0.6;
    vec3 seam = mix(vec3(0.55,0.08,1.0), hot, fissure);
    EMISSION = (core + seam * fissure * (2.6 + sin(TIME*1.1)*0.15)) * emission_boost;
}
