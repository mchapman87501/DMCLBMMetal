import AppKit
import DMCLBMMetal
import DMCMovieWriter
import Foundation

func createFoil(width: Int, height: Int) -> AirFoil {
    let xFoil = 0.4 * Double(width)
    let yFoil = 0.4 * Double(height)
    let wFoil = Double(width) / 3.0
    let alphaRad = 6.0 * .pi / 180.0
    return AirFoil(x: xFoil, y: yFoil, width: wFoil, alphaRad: alphaRad)
}

func installFoil(
    foil: AirFoil, width: Int, height: Int, siteTypes: inout SiteTypeData)
{
    let numSites = width * height
    for index in 0..<numSites {
        let y = index / width
        let x = index % width
        if foil.shape.contains(x: x, y: y) {
            siteTypes[index] = .obstacle
        }
    }
}

func addBoundaryEdge(
    x: Int, width: Int, height: Int, siteTypes: inout SiteTypeData)
{
    for y in 0..<height {
        let index = y * width + x
        siteTypes[index] = .boundary
    }
}

func addBoundaryEdge(
    y: Int, width: Int, height: Int, siteTypes: inout SiteTypeData)
{
    let rowBaseIndex = y * width
    for x in 0..<width {
        siteTypes[rowBaseIndex + x] = .boundary
    }
}

func initSiteTypes(foil: AirFoil, width: Int, height: Int) -> SiteTypeData {
    let numSites = width * height
    var siteTypes = SiteTypeData(repeating: .fluid, count: numSites)
    installFoil(foil: foil, width: width, height: height, siteTypes: &siteTypes)

    addBoundaryEdge(x: 0, width: width, height: height, siteTypes: &siteTypes)
    addBoundaryEdge(
        x: width - 1, width: width, height: height, siteTypes: &siteTypes)

    addBoundaryEdge(y: 0, width: width, height: height, siteTypes: &siteTypes)
    addBoundaryEdge(
        y: height - 1, width: width, height: height, siteTypes: &siteTypes)

    return siteTypes
}

func initFields(width: Int, height: Int, windSpeed: Double) -> FieldData {
    // Mimic Daniel Schroeder's initial conditions, without understanding them.
    // He credits several others:
    // https://physics.weber.edu/schroeder/fluids/LatticeBoltzmannDemo.java.txt

    let v = windSpeed
    let vSqr = v * v
    let baseline = 1.0 - 1.5 * vSqr
    let easterly = 1.0 + 3.0 * v + 3.0 * vSqr
    let westerly = 1.0 - 3.0 * v + 3.0 * vSqr
    let wNone = 4.0 / 9.0
    let wCardinal = 1.0 / 9.0 // North, east, west, south
    let wOrdinal = 1.0 / 36.0 // Northeast, etc.

    func getRho(dir: Direction) -> Double {
        switch dir {
        case .none:
            return wNone * baseline

        case .n:
            return wCardinal * baseline

        case .e:
            return wCardinal * easterly

        case .w:
            return wCardinal * westerly

        case .s:
            return wCardinal * baseline

        case .ne, .se:
            return wOrdinal * easterly

        case .nw, .sw:
            return wOrdinal * westerly
        }
    }

    let fieldSites = Direction.allCases.map { Float(getRho(dir: $0)) }

    let numSites = width * height

    var result = FieldData()
    for _ in 0..<numSites {
        for i in 0..<fieldsPerSite {
            result.append(fieldSites[i])
        }
    }
    return result
}

struct Scenario {
    let temperature: Double
    let windSpeed: Double
    let viscosity: Double

    var omega: Double {
        1.0 / (3.0 * viscosity + 0.5)
    }

    func description() -> String {
        String(
            format: """
            Temperature: %.2f
            Viscosity: %.4f
            Wind speed: %.2f
            """, temperature, viscosity, windSpeed)
    }
}

func scaledWindSpeed(scenario: Scenario) -> Double {
    // Thermal velocity v varies as the square root of temperature.
    // T = K * v**2
    // If I remember correctly, using Boltzmann's equations, at 20°C v should
    // be about 400 m/s.
    // 20 = K * (400 * 400)
    let K = 1.0 / 8000.0
    let thermalSpeed = sqrt(scenario.temperature / K)

    // The lattice spacing and simulation time steps are scaled
    // so that lattice discrete speeds are <= 1.
    // That is, maximum lattice spacing ∆x and simulation time step ∆t are chosen so that
    // c = ∆x/∆t = 1.
    // Absent wind, the thermal velocity v = dx/dt needs to be scaled by
    // some constant K2 so that c = 1 = K2 * v.
    // Similarly, in the presence of wind velocity u, c = 1 = K2 * (v + u)
    // Hm... but it also needs to be scaled so that the maximum lattice speed component
    // in initNodeDensities, i.e., 1.0 + 3.0 * u + 3.0 * uSqr
    // is <= 1.414?
    // 3.0 * u**2 + 3.0*u + 1.0 <= sqrt(2)
    // u = sqrt(sqrt(2) + 1.25) - 1.5
    // scale2 = u / windSpeed
    // So... use a fudge factor to hide my incorrect reasoning...
    let K2 = 1.0 / (1.6 * (thermalSpeed + scenario.windSpeed))

    return K2 * scenario.windSpeed
}

func main() {
    // Simulation dimensions:
    let width = 1280
    let height = 720

    let foil = createFoil(width: width, height: height)

    let scenario = Scenario(temperature: 20.0, windSpeed: 90.0, viscosity: 0.04)
    let sws = scaledWindSpeed(scenario: scenario)
    let fields = initFields(width: width, height: height, windSpeed: sws)

    let siteTypes = initSiteTypes(foil: foil, width: width, height: height)
    let tracers = Tracers(
        shape: foil.shape, latticeWidth: width, latticeHeight: height,
        spacing: 20)

    let movieURL = URL(fileURLWithPath: "movie.mov")

    guard
        let movieWriter = try? DMCMovieWriter(
            outpath: movieURL, width: width, height: height)
    else {
        print("Could not create movie writer.")
        return
    }

    let lattice = Lattice(
        fields: fields, width: width, height: height, siteTypes: siteTypes,
        tracers: tracers, omega: scenario.omega)
    let edgeForceCalc = EdgeForceCalc(lattice: lattice, shape: foil.shape)

    guard
        let worldWriter = try? WorldWriter(
            lattice: lattice, edgeForceCalc: edgeForceCalc, width: width,
            height: height,
            foil: foil, writingTo: movieWriter, title: scenario.description())
    else {
        print("Could not create world writer.")
        return
    }

    try! worldWriter.showTitle(scenario.description())

    let stepsPerFrame = 10
    let fps = 30 // frames per second

    let warmupSeconds = 15
    let warmupFrames = fps * warmupSeconds

    let seconds = 30

    StopWatch().time("Metal") {
        for _ in 0..<warmupFrames {
            lattice.stepOneFrame(
                stepsPerFrame: stepsPerFrame, moveTracers: false)
        }

        for sec in 1...seconds {
            for frame in 1...fps {
                lattice.stepOneFrame(
                    stepsPerFrame: stepsPerFrame, moveTracers: true)
                edgeForceCalc.calculate()

                // Cheap way to ramp up / down.
                let alpha: Double = {
                    if sec == 1 {
                        return Double(frame) / Double(fps)
                    }
                    if sec == seconds {
                        return Double(fps - frame) / Double(fps)
                    }
                    return 1.0
                }()
                try worldWriter.writeNextFrame(alpha: alpha)
            }
        }
    }

    try! movieWriter.finish()
}

main()
