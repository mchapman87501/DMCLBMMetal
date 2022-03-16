#include <metal_stdlib>
using namespace metal;

#include "shared_defs"

static constant vec<float, 9> dvx{0.0, 0.0, 1.0, 1.0, 1.0, 0.0, -1.0, -1.0, -1.0};
static constant vec<int, 9> idvx{0, 0, 1, 1, 1, 0, -1, -1, -1};
static constant vec<float, 9> dvy{0.0, 1.0, 1.0, 0.0, -1.0, -1.0, -1.0, 0.0, 1.0};
static constant vec<int, 9> idvy{0, 1, 1, 0, -1, -1, -1, 0, 1};

static constant float central = 4.0 / 9.0;
static constant float cardinal = 1.0 / 9.0;
static constant float diagonal = 1.0 / 36.0;
static constant vec<float, 9> bgk_weight = {
    central, cardinal, diagonal, cardinal, diagonal, cardinal, diagonal, cardinal, diagonal
};
static constant uint fields_per_site = 9;

// SiteType
typedef uint8_t SiteType;
static constant SiteType SITETYPE_FLUID = 0;
static constant SiteType SITETYPE_OBSTACLE = 1;
static constant SiteType SITETYPE_BOUNDARY = 2;

static constant vec<uint, 9> bounce_back_indices{0, 5, 6, 7, 8, 1, 2, 3, 4};

struct CollideParams {
    float omega;
};

kernel void
collide
(
    constant CollideParams& params [[buffer(0)]],
    device float *fields [[buffer(1)]],
    const device SiteType *site_types [[buffer(2)]],
    device SiteProps *site_props [[buffer(3)]],
    uint site_index [[thread_position_in_grid]]
) {
    const uint field_base = site_index * fields_per_site;
    const float omega = params.omega;
    // Compute site macro properties.
    float rho = 0.0;
    float uxSum = 0.0;
    float uySum = 0.0;
    for (uint i = 0; i < fields_per_site; i++) {
        const float val = fields[field_base + i];
        rho += val;
        uxSum += val * dvx[i];
        uySum += val * dvy[i];
    }
    
    const float ux = (rho > 0) ? (uxSum / rho) : 0.0;
    const float uy = (rho > 0) ? (uySum / rho) : 0.0;

    site_props[site_index].rho = rho;
    site_props[site_index].ux = ux;
    site_props[site_index].uy = uy;

    // Perform site collision.
    const SiteType site_type = site_types[site_index];

    if (site_type == SITETYPE_FLUID) {
        const float usqr = ux * ux + uy * uy;
        const auto cdotu = (ux * dvx) + (uy * dvy);
        const auto equil = rho * bgk_weight * (1.0 + cdotu * (3.0  + 4.5 * cdotu) - 1.5 * usqr);

        for (uint i = 0; i < fields_per_site; i++) {
            const uint field_index = field_base + i;
            const float dens = fields[field_index];
            const float new_dens = dens + omega * (equil[i] - dens);
            fields[field_index] = new_dens;
        }
    } else if (site_type == SITETYPE_OBSTACLE) {
        // Bounce back.
        vec<float, fields_per_site> new_sites;
        for (uint i = 0; i < fields_per_site; i++) {
            const uint src_site_index = bounce_back_indices[i];
            new_sites[i] = fields[field_base + src_site_index];
        }
        for (uint i = 0; i < fields_per_site; i++) {
            fields[field_base + i] = new_sites[i];
        }
    }
    // Do nothing with boundary sites.
}

struct StreamParams {
    SizeT lattice_size;
};

kernel void
stream(
    constant StreamParams& params [[buffer(0)]],
    const device float *fields [[buffer(1)]],
    device float *streaming_fields [[buffer(2)]],
    const device SiteType *site_types [[buffer(3)]],
    uint3 index [[thread_position_in_grid]]
) {
    constant SizeT& lattice_size(params.lattice_size);
    
    // Stream into this field from the appropriate neighboring field.
    const uint dest_site_index = (index.y * lattice_size.width) + index.x;
    const uint dest_field_index = dest_site_index * fields_per_site + index.z;

    // Notes: "-" is used because of backing out from destination to src.
    // Metal modulus operator result is undefined if either operand is < 0.
    // Hence this weirdness, to ensure src_x in 0..<width without
    // conditional logic.
    const int width = (int)lattice_size.width;
    const uint src_x = (uint)((width + ((int)index.x - idvx[index.z])) % width);
    
    const int height = (int)lattice_size.height;
    const uint src_y = (uint)((height + ((int)index.y - idvy[index.z])) % height);
    
    const uint src_site_index = (src_y * lattice_size.width) + src_x;
    const uint src_field_index = src_site_index * fields_per_site + index.z;
    
    const device SiteType& site_type(site_types[dest_site_index]);
    // Boundary nodes don't stream.  They just keep their current post-collision state.
    const uint i_src = (site_type == SITETYPE_BOUNDARY) ? dest_field_index : src_field_index;

    const float src_value = fields[i_src];
    // This fails to compile on macOS 12.3, Xcode 13.3, on a late-2015 27" iMac:
    streaming_fields[dest_field_index] = src_value;
}

typedef struct StreamParams TracerParams;

kernel void
move_tracers(
    constant TracerParams& params [[buffer(0)]],
    const device SiteProps *site_props [[buffer(1)]],
    device TracerCoord *tracer_site_coords [[buffer(2)]],
    uint tracer_index [[thread_position_in_grid]]
) {
    const device TracerCoord& tc(tracer_site_coords[tracer_index]);
    const float x = tc.x;
    const float y = tc.y;
    
    const uint x_site = x;
    const uint y_site = y;

    constant SizeT& lattice_size(params.lattice_size);
    const uint site_index = y_site * lattice_size.width + x_site;
    const float dx = site_props[site_index].ux;
    const float dy = site_props[site_index].uy;
    
    
    const float swidth = lattice_size.width;
    const float sheight = lattice_size.height;

    const float x_next = fmod(x + dx + swidth, swidth);
    const float y_next = fmod(y + dy + sheight, sheight);
    tracer_site_coords[tracer_index].x = x_next;
    tracer_site_coords[tracer_index].y = y_next;
}


// Approximate the forces on a foil edge by summing the
// densities of sites adjacent to the edge.  Using density
// as a proxy for pressure, the force on each edge is
// proportional to the pressure (density) divided by the
// edge length.
// Perhaps this belongs on the CPU...
struct EdgeSitesInfo {
    float edge_length;
    uint start_index;
    uint num_entries;
};

kernel void
calc_edge_force(
    const device SiteProps *site_props [[buffer(0)]],
    const device uint *all_edge_indices [[buffer(1)]],
    const device EdgeSitesInfo *edge_infos [[buffer(2)]],
    device float *edge_forces [[buffer(3)]],
    uint edge_index [[thread_position_in_grid]]
)
{
    // I would like to unnroll this: let each calc_edge_force call add one value to an edge_force calc.
    // But to do that safely would require support for atomic<float>.  At time of writing,
    // Metal does not support atomic<float>
    // rho_vals holds all densities in the lattice.
    // all_edge_indices holds the rho_vals indices for each edge,
    // contiguously.
    // edge_start_indices hold the index within all_edge_indices
    // where each edge starts.
    // num_edge_indices holds the number of all_edge_indices entries
    // for each edge.
    const device EdgeSitesInfo& info(edge_infos[edge_index]);

    float edge_sum = 0.0;
    uint all_edge_indices_index = info.start_index;
    const uint num_entries(info.num_entries);
    for (uint i = 0; i < num_entries; i++) {
        uint site_index = all_edge_indices[all_edge_indices_index];
        edge_sum += site_props[site_index].rho;
        all_edge_indices_index += 1;
    }
    const float rho_mean = edge_sum / ((float)num_entries);
    edge_forces[edge_index] = rho_mean * info.edge_length;
}
