#version 120

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D noisetex;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform vec3 cameraPosition;
uniform vec3 sunPosition;
uniform float sunElevation;

uniform int isEyeInWater;
uniform float frameTime;

varying vec2 texcoord;
varying vec3 viewDir;
varying vec3 worldPos;

const float PI = 3.14159265;

float calcAO(vec2 uv, float depth) {
    float ao = 0.0;
    float radius = 0.05;
    int samples = 8;

    for (int i = 0; i < samples; i++) {
        float angle = (i / float(samples)) * 2.0 * PI;
        vec2 offset = vec2(cos(angle), sin(angle)) * radius;
        vec2 sampleUV = uv + offset;

        float sampleDepth = texture2D(depthtex0, sampleUV).r;
        float diff = depth - sampleDepth;
        ao += clamp(diff * 8.0, 0.0, 1.0);
    }

    return 1.0 - (ao / float(samples)) * 0.5;
}

float volumetricClouds(vec3 pos, vec3 viewDir) {
    float cloudDensity = 0.0;
    vec3 cloudPos = pos * 0.002;

    for (int i = 0; i < 4; i++) {
        float scale = pow(2.0, i);
        vec3 samplePos = cloudPos * scale;

        float noise = fract(sin(dot(samplePos, vec3(12.9898, 78.233, 45.164))) * 43758.5453);
        float noise2 = fract(sin(dot(samplePos + vec3(1.0, 0.0, 0.0), vec3(12.9898, 78.233, 45.164))) * 43758.5453);
        float noise3 = fract(sin(dot(samplePos + vec3(0.0, 1.0, 0.0), vec3(12.9898, 78.233, 45.164))) * 43758.5453);

        float fbm = (noise + noise2 + noise3) / 3.0;
        cloudDensity += fbm * (0.5 / (i + 1));
    }

    cloudDensity = cloudDensity * 1.5 - 0.5;
    cloudDensity = clamp(cloudDensity, 0.0, 1.0);
    cloudDensity *= cloudDensity * 0.3;

    float cloudHeight = smoothstep(80.0, 120.0, pos.y);
    cloudDensity *= cloudHeight * (1.0 - smoothstep(100.0, 120.0, pos.y));

    return cloudDensity;
}

void main() {
    vec4 color = texture2D(colortex0, texcoord);
    float depth = texture2D(depthtex0, texcoord).r;

    vec3 viewDir = normalize(vec3(texcoord * 2.0 - 1.0, 1.0));
    viewDir = (gbufferModelViewInverse * vec4(viewDir, 0.0)).xyz;

    vec3 worldPos = cameraPosition + viewDir * depth * 100.0;

    float ao = calcAO(texcoord, depth);
    color.rgb *= 0.7 + ao * 0.3;

    if (worldPos.y > 80.0 && worldPos.y < 120.0) {
        float cloudDensity = volumetricClouds(worldPos, viewDir);
        vec3 cloudColor = vec3(0.9, 0.92, 0.95);

        float sunLight = max(0.0, dot(normalize(sunPosition), vec3(0.0, 1.0, 0.0)));
        cloudColor *= (0.5 + sunLight * 0.5);

        color.rgb = mix(color.rgb, cloudColor, cloudDensity * 0.4);
    }

    float skyFactor = 1.0 - smoothstep(0.0, 0.3, depth);
    vec3 skyColor = mix(vec3(0.4, 0.6, 0.8), vec3(0.8, 0.7, 0.6), sunElevation);
    color.rgb = mix(color.rgb, skyColor, skyFactor * 0.3);

    vec2 eyePos = texcoord - 0.5;
    float eyeDist = length(eyePos);

    if (eyeDist < 0.15 && depth > 0.95) {
        float pupil = smoothstep(0.04, 0.1, eyeDist);
        float irisPattern = sin(eyeDist * 50.0 + texcoord.x * 30.0) * 0.5 + 0.5;
        irisPattern *= sin(eyeDist * 40.0 - texcoord.y * 25.0) * 0.5 + 0.5;
        irisPattern = clamp(irisPattern * 0.7 + 0.3, 0.0, 1.0);

        vec3 irisColor = vec3(0.3, 0.5, 0.7);
        vec3 eyeColor = mix(vec3(1.0, 1.0, 1.0), irisColor, irisPattern);
        eyeColor = mix(eyeColor, vec3(0.0, 0.0, 0.0), pupil * 0.5);

        float spec = pow(1.0 - eyeDist * 6.0, 4.0) * 0.5;
        eyeColor += vec3(1.0) * spec;

        color.rgb = mix(color.rgb, eyeColor, 0.8);
    }

    float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
    color.rgb = mix(color.rgb, vec3(gray), 0.1);

    color.rgb = pow(color.rgb, vec3(1.0 / 1.1));

    float bloom = max(max(color.r, color.g), color.b);
    if (bloom > 0.8) {
        color.rgb += vec3(bloom - 0.8) * 0.2;
    }

    gl_FragData[0] = color;
    gl_FragData[1] = vec4(0.0);
}