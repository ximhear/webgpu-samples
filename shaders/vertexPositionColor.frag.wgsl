@fragment
fn main(
  @location(0) fragUV: vec2f,
  @location(1) fragPosition: vec4f,
  @location(2) color: vec4f,
) -> @location(0) vec4f {
  return color;
}
