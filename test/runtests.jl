using STV
using Test

@testset "STV.jl" begin
    # Write your tests here.
    fname = "../docs/2017/PreferenceProfile_Report_Ward_7_Langside_05052017_163223.xlsx"
    STV.do_election( fname )
end
