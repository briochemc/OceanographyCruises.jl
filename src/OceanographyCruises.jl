module OceanographyCruises

using StaticArrays, Dates
using FieldMetadata, FieldDefaults
using PrettyTables
using Unitful

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


"""
    Transects

A collection of transects for a given tracer.
"""
@default_kw struct Transects{V}
    tracer::String                 | ""
    cruises::Vector{String}        | ""
    transects::Vector{Transect{V}} | Transect{Float64}[]
end
function Base.show(io::IO, m::MIME"text/plain", ts::Transects)
    println("Transects of $(ts.tracer)")
    print("(Cruises ")
    [print("$c, ") for c in ts.cruises[1:end-1]]
    println("and $(last(ts.cruises)).)")
end
Base.:*(ts::Transects, q::Quantity) = Transects(ts.tracer, ts.cruises, ts.transects .* q)
Unitful.uconvert(u, ts::Transects) = Transects(ts.tracer, ts.cruises, uconvert.(u, ts.transects ))
# shift longitude for cruises that cross 0 to (-180,180)
shiftlon(ts::Transects; baselon=0) = Transects(ts.tracer, ts.cruises, shiftlon.(t.transects, baselon=baselon))
autoshift(ts::Transects) = Transects(ts.tracer, ts.cruises, autoshift.(ts.transects))




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
Base.maximum(t::Transect) = maximum(maximum(ustrip.(pro.values)) for pro in t.profiles)
Base.minimum(t::Transect) = minimum(minimum(ustrip.(pro.values)) for pro in t.profiles)

end # module
