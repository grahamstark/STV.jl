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

MAX_STAGES = 50

export do_election,make_labels,make_sankey

mutable struct Candidate
    pos   :: Int
    sname :: String
    fname :: String
    party :: String
end

function rgb( r,g,b ) :: RGBA
    return RGBA( r/256, g/256, b/256, 1 )
end

const COLOURS = Dict([
    "SNP" => rgb(254, 242, 121), #"#fef279", 
    "CON" => rgb(10, 59, 124),# "#0a3b7c", 
    "LAB" => rgb( 253, 0, 69 ), 
    "LIB" => rgb(250, 160, 26 ),
    "ALB" => rgb(0, 94, 184 ),
    "GRN" => rgb(67, 176, 42 )])

const OTHCOL = palette([:purple, :pink], 22)

#
# FIXME this gives random colours for the same candidate if not a known one
#
function get_colour( party :: String )
    if haskey( COLOURS, party )
        return COLOURS[party]
    end
    return OTHCOL[rand(1:length(OTHCOL))]
end

"""
Henry Droop’s quota - which is “(total votes / (total seats + 1)) + 1”.
"""
function droop_quota( valid :: Int, seats :: Int ) :: Real
    return Int(trunc(valid/(seats+1))) + 1
end

function load_profiles( filename :: String ) :: NamedTuple
    t = XLSX.readtable( filename, 1, header=false )
    
    raw = DataFrame( t...)
    rs =  strip(raw[1,1])
    println( "top line $rs")
    num_candidates,num_seats = parse.(Int,split( rs, " " ))
    # format
    # row 1 is "7,3" : num_candidates, num_seats
    # rows .. 
    # count 1st pref 2nd pref ... always end 0
    # 0 (end of profiles)
    #
    # candidate names fname, sname(ALLCAPS) (no party info)
    # final row: ward name
    #
    num_raw_rows = size( raw )[1]
    names = collect( ("R_$i" for i in 1:MAX_STAGES))
    profiles = DataFrame( zeros(Int,num_raw_rows,MAX_STAGES),names)
    counts = zeros(Int, num_raw_rows )
    num_profiles = 0
    num_stages = -1
    for r in 2:num_raw_rows
        rs = strip(raw[r,1])
        # println( "on row $r rs='$rs'")
        rsa = split( rs, " " )
        # println( "rsa=$rsa")
        v = parse.(Int,rsa)
        profile_size = size(v)[1]
        if( profile_size == 1 ) && (v[1] == 0 ) # final row of data is a single '0' - break and then parse names
            break
        end
        num_stages = max( num_stages, profile_size )
        num_profiles += 1
        counts[num_profiles] = v[1]
        @assert v[profile_size] == 0
        for n in 2:profile_size
            profiles[num_profiles,n-1] = v[n]
        end
    end
    candidates = []
    n = 0
    for r in num_profiles+3:num_raw_rows-1
        n += 1
        name = split( raw[r,1], r" +")
        c = Candidate( n, name[2], name[1], name[3] )
        push!( candidates, c )
    end
    println( "num_candidates=$num_candidates num_seats=$num_seats candidates=$candidates")
    @assert num_candidates == size( candidates )[1]
    wardname = strip(raw[num_raw_rows,1])
    return (counts = counts[1:num_profiles], num_seats = num_seats, profiles=profiles[1:num_profiles,1:num_stages-1], candidates=candidates, wardname = wardname )
end

function find_next_donee( profiles :: DataFrameRow, ignored :: Set{Int} ) :: Int
    n = size(profiles)[1]
    for i in 2:n
        if ! ( profiles[i] in ignored )
            return profiles[i] == 0 ? -1 : profiles[i]
        end
    end
    return -1
end

function all_unelectable( excluded :: Matrix{Bool}, elected :: Matrix{Bool}) :: Set{Int}
    nr,nc = size(excluded)
    el = Set{Int}()
    for r in 1:nr
        if( any(elected[r,:]) || any(excluded[r,:]))
            push!( el, r )
        end
    end
    el
end

function index_of_lowest_vote( votes :: Matrix, ignored :: Set{Int} , stage :: Int )::Int
    minval = 9999999999999999999999999.99
    nr = size(votes)[2]
    nc = size(votes)[1]
    positions = []
    println( "index_of_lowest_vote entered nr=$nr nc=$nc stage=$stage")
    target_candidates = setdiff( 1:nc, ignored )
    for c in target_candidates 
        if votes[c,stage] < minval 
            minval = votes[c,stage]
        end
    end
    println( "got min as $minval")
    for c in target_candidates
        println( "on candidate $c stage $stage")
        if votes[c,stage] == minval 
            return c
        end
    end
    # println( "got positions as $positions")
    return -1
end

"""
FIXME this is slightly off compared to Glasgow 2017 ward level results.
"""
function distribute!( 
    votes::Matrix, 
    transfers :: AbstractArray,
    profiles::DataFrame, 
    prop::Real, 
    counts::Vector, 
    changed::Int, 
    num_candidates :: Int,
    ignored :: Set{Int},
    stage :: Int  )
    num_profiles = size(profiles)[1]
    for c in 1:num_candidates # initialise the next stage
        votes[c,stage] = votes[c,stage-1]
    end
    # transfers[:,:,stage+1] .= 0.0
    num_donated = 0
    for n in 1:num_profiles
        cand_num = profiles[n,1]
        if cand_num == changed                        
            donee = find_next_donee( profiles[n,:], ignored ) 
            donation = counts[n] * prop
            if (donee > 0)                
                votes[donee,stage] += donation
                transfers[cand_num,donee,stage] += donation
                println( "stage=$(stage); transferring $donation from donor $cand_num to donee $donee votes $(counts[n]) prop=$prop transfer now $(transfers[cand_num,donee,stage])")
            else
                # unallocated votes
                transfers[cand_num,end,stage] += donation
            end
            num_donated += counts[n]
        end # if this is the donor
    end # stage profiles
    println( "total donated for candidate $changed = $num_donated")
end

function do_election( fname :: String ) :: Tuple
    counts, seats, profiles, candidates, wardname = load_profiles( fname )
    num_candidates = size(candidates)[1]    
    num_profiles = size(profiles)[1]
    MAX_STAGES = size(profiles)[2]*2
    # println( "num_candidates=$num_candidates num_profiles=$num_profiles MAX_STAGES=$MAX_STAGES seats=$seats")
    transfers = zeros( num_candidates, num_candidates+1, MAX_STAGES ) # FIXME only 1 candidate needed transfers between candidates, one num_candidates x num_candidates for each stage
    votes = zeros( num_candidates, MAX_STAGES ) # votes in each stage
    valid = sum(counts)
    # println( "valid votes $valid")
    quota = droop_quota( valid, seats )
    # println( "quota=$quota")
    elected = fill(false, num_candidates, MAX_STAGES ) # elected at stage N
    prop = 0.0
    excluded = fill(false, num_candidates, MAX_STAGES ) # excluded at stage N
    # initial allocation
    for r in 1:num_profiles        
        cand_num = profiles[r,1] 
        if cand_num > 0 
            # println( "adding $(counts[r]) to candidate $cand_num")
            votes[cand_num,1] += counts[r]
        end
    end
    println( "stage 1 votes $(votes[:,1])")
    ignored = Set{Int}()
    stage = 1
    for i in 1:MAX_STAGES
        some_elected = false
        for c in setdiff(Set(1:num_candidates), ignored )
            if votes[c,stage] > quota
                elected[c,stage] = true
                some_elected = true
                prop = round((votes[c,stage]-quota)/votes[c,stage]); digits=5)
                println( "candidate $c elected! prop = $prop stage=$stage votes=$(votes[c,stage])")
                ignored = all_unelectable( elected, excluded )
                stage += 1
                votes[c,stage] = quota
                distribute!( votes, transfers, profiles, prop, counts, c, num_candidates, ignored, stage )
                #votes[c,stage-1] = quota
             end
        end
        println( "elected = $elected")
        println( "excluded = $excluded")
        println( "votes=$votes")
        if ! some_elected # remove lowest if no-one elected at this stage
            lowest = index_of_lowest_vote( votes, ignored, stage )
            println( "eliminating $lowest at stage $stage")
            excluded[lowest,stage] = true
            ignored = all_unelectable( elected, excluded )
            prop = votes[lowest,stage]/votes[lowest,1]
            println( "prop=$prop")
            println( "candidate $lowest excluded prop=$(prop)")
            stage += 1                
            distribute!( votes, transfers, profiles, prop, counts, lowest, num_candidates, ignored, stage )
            # votes[lowest,stage-1] = 0.0
        end
        if sum( elected ) == seats
            break
        end
    end
    ls = stage-1
    # FIXME SHOULDN'T NEED THIS - last stage we really need
    #=
    for s in 1:stage
        te = sum( elected[:,1:s] )
        println( "ls=$te")
        if te == seats
            ls = s
            break
        end
    end
    =#
    # fixme nor should THIS
    for s in 1:stage
        for c in 1:num_candidates
            if elected[c,s]
                votes[c,s+1:stage] .= quota
            end
        end
    end
    println( "all_elected = $ls")
    println( elected )
    # @assert all_elected == seats
    # @assert (sum( elected ) + sum( excluded )) == num_candidates
    return candidates,wardname,quota,votes[:,1:ls],transfers[:,:,1:ls],elected[:,1:ls],excluded[:,1:ls],seats,ls
end

function make_src_dest_weights( candidates, votes, transfers, elected, excluded, stages )
    src = []
    dest = []
    weights = []
    lookup = Dict()

    function addone( donor::Int, donee::Int, stage::Int )
        lookup[(stage,candidates[donor].sname)] = [candidates[donor].party,elected[donor,stage],excluded[donor,stage],votes[donor,stage]]
        lookup[(stage+1,candidates[donee].sname)] = [candidates[donee].party,elected[donee,stage],excluded[donee,stage],votes[donee,stage]]
        
        push!( src, (stage,candidates[donor].sname) ) #,candidates[donor].party,elected[donor,stage],excluded[donor,stage]])
        push!( dest,(stage+1,candidates[donee].sname) ) #candidates[donee].party,elected[donee,stage],excluded[donee,stage]])
        # weight - 
        if donor == donee
            push!( weights, votes[donee,stage])
        else
            push!( weights, transfers[donor,donee,stage+1])
        end
    end
 
    ncs = size( candidates )[1]
    ex = elected .| excluded
    for stage in 1:stages
        for cno in 1:ncs 
            if excluded[cno,stage] || elected[cno,stage] # distribute votes of cand
                for dno in 1:ncs  
                    println( "donating to $dno")
                    if ! (any(ex[dno,1:stage-1])||excluded[dno,stage]) # not aleady excluded or elected on previous stage
                        println("adding to dno stage $stage")
                        addone( cno, dno, stage ) 
                    end
                end
            else
                if ! any(excluded[cno,1:stage]) # this candidate carries on..    
                    addone( cno, cno, stage )
                end 
            end
        end # candidates
    end # stages
    @assert size( src ) == size( dest )
    # weights = ones( size( src ))
    return src[1:end], dest[1:end], weights[1:end], lookup
end

function make_labels( lookup::Dict, src::Vector, dest::Vector )::Tuple
    labels = []
    cols = []
    for n in unique(vcat(src,dest))
        # s = split(n,":")
        # i = n % 1000
        l = lookup[n]
        #println(l)
        elec = l[2] ? "\nElected stage $(n[1])" : ""
        elim = l[3] ? "\nEliminated stage $(n[1])" : ""
        votes = Int(round(l[4]))
        label = "$(n[2])($votes)$elec$elim"
            
        push!( labels, label )
        push!( cols, get_colour( l[1]))      

    end
    labels[1:end], cols[1:end]
end

"""

"""
function make_sankey( 
    wardname :: AbstractString, 
    candidates::Vector, 
    votes::Matrix, 
    transfers::AbstractArray, 
    elected::AbstractArray, 
    excluded::AbstractArray, 
    stages::Int )
    src,dest,weights,dict = make_src_dest_weights( candidates, votes, transfers, elected, excluded, stages )
    labels, colours = make_labels( dict, src, dest )
    # colours = make_colours( dict, src )
    p = sankey( src, dest, weights; 
        node_labels=labels, 
        edge_color=:gradient, 
        label_position=:bottom, 
        node_colors = colours,
        label_size=3,
        title=wardname,
        compact=false )
    return p
end

end