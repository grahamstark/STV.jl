using STV
using Test

@testset "STV.jl" begin
    # Write your tests here.
    fname = "doc/";
    STV.do_election( fname )
end
