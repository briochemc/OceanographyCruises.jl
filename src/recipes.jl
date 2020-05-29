


convertdepth(depth::Real) = depth * u"m"
convertdepth(depth::Quantity{U, Unitful.𝐋, V}) where {U,V} = depth
convertdepth(x) = error("Not a valid depth")

"""
    plotscattertransect(t)

Plots a scatter of the discrete obs of `t` in (lat,depth) space.
"""
@userplot PlotScatterTransect
@recipe function f(p::PlotScatterTransect)
    transect, = p.args
    depths = reduce(vcat, pro.depths for pro in transect.profiles)
    values = reduce(vcat, pro.values for pro in transect.profiles)
    lats = reduce(vcat, pro.station.lat * ones(length(pro)) for pro in transect.profiles)
    station_distances = diff(transect)
    distances = reduce(vcat, [fill(d, length(pro)) for (d,pro) in zip(vcat(0.0u"km", cumsum(diff(transect))), transect.profiles)])
    @series begin
        seriestype := :scatter
        yflip := true
        marker_z --> values
        markershape --> :circle
        clims --> (0, 1) .* maximum(transect)
        label --> ""
        yguide --> "Depth"
        xguide --> "Distance"
        distances, convertdepth.(depths)
    end
end


"""
    plotcruisetrack(t)

Plots the cruise track of `t` in (lat,lon) space.
"""
@userplot PlotCruiseTrack
@recipe function f(p::CruiseTrackPlots, central_longitude=200°)
    wlon = central_longitude - 180°
    ct, = p.args
    ctlon, ctlat = [s.lon for s in ct.stations]°, [s.lat for s in ct.stations]°
    @series begin
        xguide --> ""
        yguide --> ""
        markershape --> :circle
        markersize --> 2
        color_palette --> :tab10
        markercolor --> 4
        markerstrokewidth --> 0
        [mod(ctlon[1] - wlon, 360°) + wlon], [ctlat[1]]
    end
    @series begin
        color_palette --> :tab10
        seriescolor --> 4
        xguide --> ""
        yguide --> ""
        title --> ct.name
        markershape --> :circle
        markersize --> 1
        markercolor --> :black
        titlefontsize --> 10
        mod.(ctlon .- wlon, 360°) .+ wlon, ctlat
    end 
end

