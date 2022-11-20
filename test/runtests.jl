using STV
using Test
using SankeyPlots
using Plots 

@testset "STV.jl" begin
    # Write your tests here.
    # fname = "../docs/2017/PreferenceProfile_Report_Ward_7_Langside_05052017_163223.xlsx"
    fname = "../docs/Linn/Ward-1-Linn-reports-for-publication/PreferenceProfile_V0001_Ward-1-Linn_18112022_002249.blt"
    candidates,wardname,quota,votes,transfers,elected,excluded,seats,stages = STV.do_election( fname )
    p = make_sankey( wardname, candidates, votes, transfers, elected, excluded, stages )
end
