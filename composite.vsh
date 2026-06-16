#version 120

varying vec2 texcoord;
varying vec3 viewDir;
varying vec3 worldPos;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;

void main() {
    gl_Position = ftransform();
    texcoord = gl_MultiTexCoord0.xy;

    viewDir = normalize((gbufferModelViewInverse * vec4(0.0, 0.0, -1.0, 0.0)).xyz);

    worldPos = cameraPosition + viewDir * 10.0;
}