using STV
using Test
using SankeyPlots
using Plots 

@testset "STV.jl" begin
    # Write your tests here.
    fname = "../docs/2017/PreferenceProfile_Report_Ward_7_Langside_05052017_163223.xlsx"
    candidates,wardname,quota,votes,transfers,elected,excluded,seats,stages = STV.do_election( fname )
    p = make_sankey( wardname, candidates, votes, transfers, elected, excluded, stages )
    #
    # NOTE!!! This doesn't yet replicate the 2017 results exactly. See, for instance, round 3 transfer Langside
    # from RUCHARDSON to COLLINS - they get 0.90695 I currently get 
end
