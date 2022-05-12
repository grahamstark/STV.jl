module STV
#
# Simulator of Glasgow's STV electoral system.
# see: https://www.electoral-reform.org.uk/voting-systems/types-of-voting-system/single-transferable-vote/
# see: https://glasgow.gov.uk/index.aspx?articleid=21080
# NOTE: There are small discrepencies here. 
#
using SankeyPlots
using XLSX
using DataFrames
using Plots
using CSV

export do_election!,make_labels,make_sankey

include( "stvelection.jl")
include( "sankeycharts.jl")

end