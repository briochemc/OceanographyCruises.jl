using Test, OceanographyCruises, Unitful

st = Station(name="ALOHA", lat=22.75, lon=-158)
N = 10
stations = [Station(name=string(i), lat=i, lon=2i) for i in 1:N]
ct = CruiseTrack(stations=stations, name="TestCruiseTrack")
depths = [10, 50, 100, 200, 300, 400, 500, 700, 1000, 2000, 3000, 5000]

@testset "Station" begin
    println("Station example:")
    show(stdout, MIME("text/plain"), st)
    @test st isa Station
    @test st.name == "ALOHA"
    @test st.lon == -158
    @test st.lat == 22.75
end

@testset "CruiseTrack" begin
    println("CruiseTrack example:")
    show(stdout, MIME("text/plain"), ct)
    @test ct isa CruiseTrack
    @test ct.name == "TestCruiseTrack"
    @test latitudes(ct) == collect(1:N)
    @test longitudes(ct) == 2collect(1:N)
    @testset "lon/lat" for i in 1:N 
        st = ct.stations[i]
        @test st.lon == 2i
        @test st.lat == i
    end
end

@testset "DepthProfile" begin
    data = rand(length(depths))
    p = DepthProfile(station=st, depths=depths, data=data)
    println("profile without units:")
    show(stdout, MIME("text/plain"), p)
    p = DepthProfile(station=st, depths=depths, data=data * u"nM")
    println("profile with units:")
    show(stdout, MIME("text/plain"), p)
    @test p isa DepthProfile
    @test p.station == st
    @test p.data == data * u"nM"
    @test p.depths == depths
end

@testset "Transect" begin
    idepths = [rand(Bool, length(depths)) for i in 1:N]
    profiles = [DepthProfile(station=stations[i], depths=depths[idepths[i]], data=rand(12)[idepths[i]]) for i in 1:N]
    t = Transect(tracer="PO₄", cruise=ct.name, data=profiles)
    println("Transect example:")
    show(stdout, MIME("text/plain"), t)
    @test t isa Transect
    @test t.tracer == "PO₄"
    @test t.cruise == "TestCruiseTrack"
    @test t.data == profiles
end
