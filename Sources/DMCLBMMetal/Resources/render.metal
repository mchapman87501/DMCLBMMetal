#include <metal_stdlib>
using namespace metal;

#include "shared_defs"

struct RenderParams {
    SizeT lattice_size;
    SizeT img_size;
    uint num_colors;
};

kernel void
render_density(
    constant RenderParams& params [[buffer(0)]],
    const device float4 *colors [[buffer(1)]],  // palette of colors
    const device SiteProps *site_props [[buffer(2)]],
    texture2d<float, access::write> img [[texture(0)]],
    const uint2 img_index [[thread_position_in_grid]]
)
{
    // Client is responsible for preserving aspect ratios.
    // Must manually invert the y axis.
    const uint w_latt = params.lattice_size.width;
    const uint h_latt = params.lattice_size.height;
    const uint w_img = params.img_size.width;
    const uint h_img = params.img_size.height;

    const uint x_latt = (img_index.x * w_latt) / w_img;
    const uint y_latt = (h_latt - 1) - (img_index.y * h_latt) / h_img;
    
    // Where to find my density.
    const uint rho_index = y_latt * w_latt + x_latt;
    const float rho = site_props[rho_index].rho;
    
    const float rho_min = 0.98;
    const float rho_max = 1.03;
    const float fract = (rho - rho_min) / (rho_max - rho_min);
    const float clipped = min(1.0, max(0.0, fract));
    
    const uint color_index = (params.num_colors - 1) * clipped;
    const float4 color = colors[color_index];
    img.write(color.rgba, img_index);
}

// Shaders for rendering foil shape:
typedef float2 WorldSize;

struct RastData {
    float4 position [[position]];
    float4 color;
};

vertex RastData
foil_vertex_shader(
    const uint index [[vertex_id]],
    constant WorldSize& world_size [[buffer(0)]],
    constant float4& color [[buffer(1)]],
    const device float2 *vertices [[buffer(2)]]
) {
    RastData result;

    result.position = float4(0.0, 0.0, 0.0, 1.0);

    // Map from 0..<world_size.x to -1.0...1.0.
    const device float2& vin(vertices[index]);
    result.position.x = -1.0 + 2.0 * vin.x / world_size.x;
    // And from 0..<world_size.y to -1.0...1.0
    result.position.y = -1.0 + 2.0 * vin.y / world_size.y;

    result.color = color;
    return result;
}

fragment float4
foil_fragment_shader(
    RastData in [[stage_in]],
    float2 point_coord [[point_coord]]
)
{
    return in.color;
}


struct TraceVData {
    float4 position [[position]];
    float4 color;
    float point_size [[point_size]];
};

vertex TraceVData
tracer_vertex_shader(
    const uint tracer_index [[vertex_id]],
    constant WorldSize& world_size [[buffer(0)]],
    constant float4& color [[buffer(1)]],
    const device TracerCoord *tracer_site_coords [[buffer(2)]]
) {
    TraceVData result;

    result.position = float4(0.0, 0.0, 0.0, 1.0);

    // Map tracer coordinates from 0..<world_size.x to -1.0...1.0.
    const device TracerCoord& tracer(tracer_site_coords[tracer_index]);
    
    result.position.x = -1.0 + 2.0 * tracer.x / world_size.x;
    // And from 0..<world_size.y to -1.0...1.0
    result.position.y = -1.0 + 2.0 * tracer.y / world_size.y;

    // Guesstimate a point size.
    result.point_size = 4.0;

    result.color = color;
    return result;
}

// Fragment shader for coloring points.
// https://developer.apple.com/forums/thread/43570
fragment float4
tracer_fragment_shader(
    TraceVData in [[stage_in]],
    float2 point_coord [[point_coord]]
)
{
    if (length(point_coord - float2(0.5)) > 0.5) {
        discard_fragment();
    }
    return in.color;
}

// For depicting the net force on each airfoil edge
struct EdgeForceRenderParams {
    WorldSize world_size;
    float4 color;
    uint edge_index;
};

struct EFRRasterData {
    float4 position [[position]];
    float4 color;
};

vertex EFRRasterData
edge_force_vertex_shader(
    const uint vertex_index [[vertex_id]],
    constant EdgeForceRenderParams& params [[buffer(0)]],
    const device float2 *edge_midpoints [[buffer(1)]],
    const device float2 *edge_normals [[buffer(2)]],
    const device float *edge_forces [[buffer(3)]],
    const device float2 *vertices [[buffer(4)]],
    const device float *tail_mask [[buffer(5)]]
)
{
    EFRRasterData result;

    const uint edge_index(params.edge_index);
    constant WorldSize& world_size(params.world_size);

    const device float2& vin(vertices[vertex_index]);
    
    result.position = float4(0.0, 0.0, 0.0, 1.0);
    // TODO rotations, scaling of arrow tail...
    // Ordinarily this would be done on CPU side, I think.
    // I'm trying to keep all buffer data in GPU memory, hence this
    // experiment.
    
    const float angle = atan2(edge_normals[edge_index].y, edge_normals[edge_index].x);
    const float cosa = cos(angle);
    const float sina = sin(angle);

    const float scale = 4.0;
    // Offset (unrotated) tail vertices by an amount proportional to the edge force.
    const float xin = scale * (vin.x + 0.2 * edge_forces[edge_index] * tail_mask[vertex_index]);
    const float yin = scale * vin.y;
    
    const float xrot = xin * cosa - yin * sina;
    const float yrot = xin * sina + yin * cosa;
    const float x = xrot + edge_midpoints[edge_index].x;
    const float y = yrot + edge_midpoints[edge_index].y;
    result.position.x = -1.0 + 2.0 * x / world_size.x;
    result.position.y = -1.0 + 2.0 * y / world_size.y;
    result.color = params.color;
    return result;
}

fragment float4
edge_force_fragment_shader(
    EFRRasterData in [[stage_in]],
    float2 point_coord [[point_coord]] // Necessary?
)
{
    return in.color;
}

// For compositing textures with alpha channels.
struct ClearParams {
    float4 color;
};

kernel void
clear(
    constant ClearParams& params [[buffer(0)]],
    texture2d<float, access::write> background [[texture(0)]],
    const uint2 img_index [[thread_position_in_grid]]
)
{
    background.write(params.color, img_index);
}

struct CompositeParams {
    float overlay_alpha;
};

kernel void
composite_textures(
    constant CompositeParams& params [[buffer(0)]],
    texture2d<float, access::read_write> background [[texture(0)]],
    texture2d<float, access::read> overlay [[texture(1)]],
    const uint2 img_index [[thread_position_in_grid]]
)
{
    const float4 back_color = background.read(img_index);
    float4 over_color = overlay.read(img_index);
    
    const float alpha = over_color.a * params.overlay_alpha;
    
    const float4 result = over_color * alpha + (1.0 - alpha) * back_color;
    background.write(result, img_index);
}
