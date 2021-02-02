module OceanographyCruises

using StaticArrays, Dates
using FieldMetadata, FieldDefaults
using PrettyTables
using Unitful
using Unitful: °
using Distances, TravelingSalesmanHeuristics
using RecipesBase, UnitfulRecipes

"""
    Station

Type containing `(lat,lon)` information.

(And optionally a `name` and a `date`).
"""
@default_kw struct Station <: FieldVector{2, Float64}
    lat::Float64   | NaN
    lon::Float64   | NaN
    name::String   | ""
    date::DateTime | Date(0)
end
pretty_data(st::Station) = [st.name (st.date == Date(0) ? "" : st.date) st.lat st.lon]
Base.show(io::IO, m::MIME"text/plain", st::Station) = println(io, string(st))
Base.show(io::IO, st::Station) = println(io, string(st))
function Base.string(st::Station)
    name = st.name == "" ? "Unnamed station " : "Station $(st.name) "
    date = st.date == Date(0) ? "" : "$(st.date) "
    return string(name, date, "($(latstring(st.lat)), $(lonstring(st.lon)))")
end
latstring(lat) = string(round(abs(lat)*10)/10, lat < 0 ? "S" : "N")
lonstring(lon) = string(round(abs(lon)*10)/10, lon < 0 ? "W" : "E")
# shift longitude for cruises that cross 0 to (-180,180)
shiftlon(lon; baselon=0) = mod(lon - baselon, 360) + baselon
shiftlon(st::Station; baselon=0) = Station(st.lat, shiftlon(st.lon, baselon=baselon), st.name, st.date)

"""
    CruiseTrack

Compact type containing cruise track information:
- cruise name
- stations
"""
@default_kw struct CruiseTrack
    name::String              | ""
    stations::Vector{Station} | Station[]
end
Base.length(ct::CruiseTrack) = length(ct.stations)
Base.isempty(ct::CruiseTrack) = isempty(ct.stations)
pretty_data(ct::CruiseTrack) = reduce(vcat, [pretty_data(st) for st in ct.stations])
function Base.show(io::IO, ::MIME"text/plain", ct::CruiseTrack)
    if isempty(ct)
        println("Empty cruise $(ct.name)")
    else
        println("Cruise $(ct.name)")
        pretty_table(pretty_data(ct), ["Station", "Date", "Lat", "Lon"])
    end
end
latitudes(ct::CruiseTrack) = [st.lat for st in ct.stations]
longitudes(ct::CruiseTrack) = [st.lon for st in ct.stations]
# shift longitude for cruises that cross 0 to (-180,180)
shiftlon(ct::CruiseTrack; baselon=0) = CruiseTrack(ct.name, shiftlon.(ct.stations, baselon=baselon))
function autoshift(ct::CruiseTrack)
    if any([0 ≤ st.lon < 90 for st in ct.stations]) && any([270 ≤ st.lon < 360 for st in ct.stations])
        shiftlon(ct, baselon=-180)
    else
        ct
    end
end


"""
    DepthProfile

A depth profile at a given station.
"""
@default_kw struct DepthProfile{V}
    station::Station        | Station()
    depths::Vector{Float64} | Float64[]
    values::Vector{V}       | Float64[]
    DepthProfile(st,d,v::Vector{V}) where {V} = (length(d) ≠ length(v)) ? error("`depths` and `values` must have same length") : new{V}(st,d,v)
end
Base.length(p::DepthProfile) = length(p.depths)
Base.isempty(p::DepthProfile) = isempty(p.depths)
pretty_data(p::DepthProfile) = [p.depths p.values]
pretty_data(p::DepthProfile{V}) where {V <: Quantity} = [p.depths ustrip.(p.values)]
function Base.show(io::IO, m::MIME"text/plain", p::DepthProfile)
    if isempty(p)
        println("Empty profile at ", string(p.station))
    else
        println("Depth profile at ", string(p.station))
        pretty_table(pretty_data(p), ["Depth", "Value"])
    end
end
function Base.show(io::IO, m::MIME"text/plain", p::DepthProfile{V}) where {V <: Quantity}
    if isempty(p)
        println("Empty profile at ", string(p.station))
    else
        println("Depth profile at ", string(p.station))
        pretty_table(pretty_data(p), ["Depth", "Value [$(unit(V))]"])
    end
end
Base.:*(pro::DepthProfile, q::Quantity) = DepthProfile(pro.station, pro.depths, pro.values .* q)
Base.:-(pro1::DepthProfile, pro2::DepthProfile) = DepthProfile(pro1.station, pro1.depths, pro1.values .- pro2.values)
Unitful.uconvert(u, pro::DepthProfile) = DepthProfile(pro.station, pro.depths, uconvert.(u, pro.values))
# shift longitude for cruises that cross 0 to (-180,180)
shiftlon(pro::DepthProfile; baselon=0) = DepthProfile(shiftlon(pro.station, baselon=baselon), pro.depths, pro.values)


"""
    Transect

A transect of depth profiles for a given tracer.
"""
@default_kw struct Transect{V}
    tracer::String                    | ""
    cruise::String                    | ""
    profiles::Vector{DepthProfile{V}} | DepthProfile{Float64}[]
end
Base.length(t::Transect) = length(t.profiles)
function Base.show(io::IO, m::MIME"text/plain", t::Transect)
    if isempty(t)
        println("Empty transect")
    else
        println("Transect of $(t.tracer)")
        show(io, m, CruiseTrack(t))
    end
end
CruiseTrack(t::Transect) = CruiseTrack(stations=[p.station for p in t.profiles], name=t.cruise)
Base.isempty(t::Transect) = isempty(t.profiles)
Base.:*(t::Transect, q::Quantity) = Transect(t.tracer, t.cruise, t.profiles .* q)
Base.:-(t1::Transect, t2::Transect) = Transect("$(t1.tracer)˟", t1.cruise, t1.profiles .- t2.profiles)
Unitful.uconvert(u, t::Transect) = Transect(t.tracer, t.cruise, uconvert.(u, t.profiles))
# shift longitude for cruises that cross 0 to (-180,180)
shiftlon(t::Transect; baselon=0) = Transect(t.tracer, t.cruise, shiftlon.(t.profiles, baselon=baselon))
function autoshift(t::Transect)
    if any([0 ≤ pro.station.lon < 90 for pro in t.profiles]) && any([270 ≤ pro.station.lon < 360 for pro in t.profiles])
        shiftlon(t, baselon=-180)
    else
        t
    end
end
latitudes(t::Transect) = [pro.station.lat for pro in t.profiles]
longitudes(t::Transect) = [pro.station.lon for pro in t.profiles]


"""
    Transects

A collection of transects for a given tracer.
"""
@default_kw struct Transects{V}
    tracer::String                 | ""
    cruises::Vector{String}        | String[]
    transects::Vector{Transect{V}} | Transect{Float64}[]
end
function Base.show(io::IO, m::MIME"text/plain", ts::Transects)
    println("Transects of $(ts.tracer)")
    print("(Cruises ")
    [print("$c, ") for c in ts.cruises[1:end-1]]
    println("and $(last(ts.cruises)).)")
end
Base.:*(ts::Transects, q::Quantity) = Transects(ts.tracer, ts.cruises, ts.transects .* q)
Base.:*(q::Quantity, ts::Transects) = ts * q
Base.:-(ts1::Transects, ts2::Transects) = Transects("$(ts1.tracer)˟", ts1.cruises, ts1.transects .- ts2.transects)
Unitful.uconvert(u, ts::Transects) = Transects(ts.tracer, ts.cruises, uconvert.(u, ts.transects ))
# shift longitude for cruises that cross 0 to (-180,180)
shiftlon(ts::Transects; baselon=0) = Transects(ts.tracer, ts.cruises, shiftlon.(t.transects, baselon=baselon))
autoshift(ts::Transects) = Transects(ts.tracer, ts.cruises, autoshift.(ts.transects))


import Base: sort, sortperm, getindex
getindex(ts::Transects, i::Int) = ts.transects[i]
"""
    sort(t::Transect)

Sorts the transect using a travelling salesman problem heuristic.
"""
sort(t::Transect; start=cruise_default_start(t)) = Transect(t.tracer, t.cruise, [t for t in t.profiles[sortperm(t; start=start)]])
sort(ct::CruiseTrack; start=cruise_default_start(ct)) = CruiseTrack(name=ct.name, stations=ct.stations[sortperm(ct; start=start)])
function sortperm(t::Union{CruiseTrack, Transect}; start=cruise_default_start(t))
    t = autoshift(t)
    n = length(t)
    lats = latitudes(t)
    lons = longitudes(t)
    pts = [lons lats]
    dist_mat = zeros(n+1, n+1)
    dist_mat[1:n,1:n] .= pairwise(Haversine(1), pts, dims=1)
    path, cost = solve_tsp(dist_mat)
    i = findall(path .== n+1)
    if length(i) == 1
        path = vcat(path[i[1]+1:end-1], path[1:i[1]-1])
    else
        path = path[2:end-1]
    end
    start == :south && pts[path[1],2] > pts[path[end],2] && reverse!(path)
    start == :west  && pts[path[1],1] > pts[path[end],1] && reverse!(path)
    return path
end
export sort, sortperm, getindex

function cruise_default_start(t)
    t = autoshift(t)
    extremalat = extrema(latitudes(t))
    extremalon = extrema(longitudes(t))
    Δlat = extremalat[2] - extremalat[1]
    Δlon = extremalon[2] - extremalon[1]
    Δlon > Δlat ? :west : :south
end

"""
    diff(t)

Computes the distance in km of each segment of the transect
"""
function Base.diff(t::Union{CruiseTrack,Transect})
    t = autoshift(t) # not sure this is needed since Haversine takes lat and lon?
    n = length(t)
    lats = latitudes(t)
    lons = longitudes(t)
    pts = [lons lats]
    return [Haversine(6371.0)(pts[i,:], pts[i+1,:]) for i in 1:n-1] * u"km"
end
export diff


function Base.range(departure::Station, arrival::Station; length::Int64, westmostlon=-180)
    lonstart = lonconvert(departure.lon, westmostlon)
    lonend = lonconvert(arrival.lon, westmostlon)
    lonstart - lonend >  180 && (lonend += 360)
    lonstart - lonend < -180 && (lonstart += 360)
    lats = range(departure.lat, arrival.lat, length=length)
    lons = range(lonstart, lonend, length=length)
    names = string.("$(departure.name) to $(arrival.name) ", 1:length)
    return [Station(lat=x[1], lon=lonconvert(x[2], westmostlon), name=x[3]) for x in zip(lats, lons, names)]
end

lonconvert(lon, westmostlon=-180) = mod(lon - westmostlon, 360) + westmostlon

export CruiseTrack, Station, DepthProfile, Transect, Transects
export latitudes, longitudes

Unitful.unit(t::Transect) = unit(t.profiles[1].values[1])

# nested functions
for f in (:maximum, :minimum)
    @eval begin
        import Base: $f
        """
            $($f)(t)

        Applies `$($f)` recursively.
        """
        $f(ts::Transects) = $f($f(t) for t in ts.transects)
        $f(t::Transect) = $f($f(pro) for pro in t.profiles)
        $f(pro::DepthProfile) = $f($f(v) for v in pro.values)
        export $f
    end
end

# recipe TODO split this file into a few different ones that make sens and include them all here
include("recipes.jl")

end # module
