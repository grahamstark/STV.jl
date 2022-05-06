using STV
using Test
using SankeyPlots
using Plots 

@testset "STV.jl" begin
    # Write your tests here.
    fname = "../docs/2017/PreferenceProfile_Report_Ward_7_Langside_05052017_163223.xlsx"
    candidates,wardname,quota,votes,transfers,elected,excluded,seats,stages = STV.do_election( fname )
end
