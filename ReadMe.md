# OceanographyCruises.jl

*An interface for dealing with oceanographic cruises data*

<p>
  <a href="https://travis-ci.com/briochemc/OceanographyCruises.jl">
    <img src="https://img.shields.io/travis/com/briochemc/OceanographyCruises.jl/master?label=OSX/Linux/Windows&logo=travis&logoColor=white&style=flat-square">
  </a>
</p>
<p>
  <a href='https://coveralls.io/github/briochemc/OceanographyCruises.jl'>
    <img src="https://img.shields.io/coveralls/github/briochemc/OceanographyCruises.jl/master?label=Coverage&logo=coveralls&logoColor=white&style=flat-square">
  </a>
</p>

Create a `Station`,

```julia
julia> using OceanographyCruises

julia> st = Station(name="ALOHA", lat=22.75, lon=-158)
Station ALOHA (22.8N, 158.0W)
```

a `CruiseTrack` of stations,

```julia
julia> N = 10 ;

julia> stations = [Station(name=string(i), lat=i, lon=2i) for i in 1:N] ;

julia> ct = CruiseTrack(stations=stations, name="TestCruiseTrack")
Cruise TestCruiseTrack
┌─────────┬──────┬──────┬──────┐
│ Station │ Date │  Lat │  Lon │
├─────────┼──────┼──────┼──────┤
│       1 │      │  1.0 │  2.0 │
│       2 │      │  2.0 │  4.0 │
│       3 │      │  3.0 │  6.0 │
│       4 │      │  4.0 │  8.0 │
│       5 │      │  5.0 │ 10.0 │
│       6 │      │  6.0 │ 12.0 │
│       7 │      │  7.0 │ 14.0 │
│       8 │      │  8.0 │ 16.0 │
│       9 │      │  9.0 │ 18.0 │
│      10 │      │ 10.0 │ 20.0 │
└─────────┴──────┴──────┴──────┘
```

And make a `Transect` of `DepthProfiles` along that `CruiseTrack`

```julia
julia> depths = [10, 50, 100, 200, 300, 400, 500, 700, 1000, 2000, 3000, 5000] ;

julia> idepths = [rand(Bool, length(depths)) for i in 1:N] ;

julia> profiles = [DepthProfile(station=stations[i], depths=depths[idepths[i]], values=rand(12)[idepths[i]]) for i in 1:N] ;

julia> t = Transect(tracer="PO₄", cruise=ct.name, profiles=profiles)
Transect of PO₄
Cruise TestCruiseTrack
┌─────────┬──────┬──────┬──────┐
│ Station │ Date │  Lat │  Lon │
├─────────┼──────┼──────┼──────┤
│       1 │      │  1.0 │  2.0 │
│       2 │      │  2.0 │  4.0 │
│       3 │      │  3.0 │  6.0 │
│       4 │      │  4.0 │  8.0 │
│       5 │      │  5.0 │ 10.0 │
│       6 │      │  6.0 │ 12.0 │
│       7 │      │  7.0 │ 14.0 │
│       8 │      │  8.0 │ 16.0 │
│       9 │      │  9.0 │ 18.0 │
│      10 │      │ 10.0 │ 20.0 │
└─────────┴──────┴──────┴──────┘


julia> t.profiles[3]
Depth profile at Station 3 (3.0N, 6.0E)
┌────────┬────────────────────┐
│  Depth │              Value │
├────────┼────────────────────┤
│   50.0 │  0.519255214063679 │
│  300.0 │ 0.6289521421572468 │
│  500.0 │ 0.8564006614918445 │
│ 5000.0 │ 0.7610393670925686 │
└────────┴────────────────────┘
```
