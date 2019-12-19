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
    date = st.date == Date(0) ? "" : "$st.date "
    return string(name, date, "($(latstring(st.lat)), $(lonstring(st.lon)))")
end
latstring(lat) = string(round(abs(lat)*10)/10, lat < 0 ? "S" : "N")
lonstring(lon) = string(round(abs(lon)*10)/10, lon < 0 ? "W" : "E")
    

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

"""
    DepthProfile

A depth profile at a given station.
"""
@default_kw struct DepthProfile{V}
    station::Station        | Station()
    depths::Vector{Float64} | Float64[]
    data::Vector{V}         | Float64[]
    DepthProfile(st,d,v::Vector{V}) where {V} = (length(d) ≠ length(v)) ? error("`depths` and `data` must have same length") : new{V}(st,d,v)
end
Base.length(p::DepthProfile) = length(p.depths)
Base.isempty(p::DepthProfile) = isempty(p.depths)
pretty_data(p::DepthProfile) = [p.depths p.data]
pretty_data(p::DepthProfile{V}) where {V <: Quantity} = [p.depths ustrip.(p.data)]
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

"""
    Transect

A transect of depth profiles for a given tracer.
"""
@default_kw struct Transect{V}
    tracer::String                | ""
    cruise::String                | ""
    data::Vector{DepthProfile{V}} | DepthProfile{Float64}[]
end
Base.length(t::Transect) = length(t.data)
function Base.show(io::IO, m::MIME"text/plain", t::Transect)
    println("Transect of $(t.tracer)")
    show(io, m, CruiseTrack(stations=[p.station for p in t.data], name=t.cruise))
end


export CruiseTrack, Station, DepthProfile, Transect

end # module
