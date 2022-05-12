

mutable struct Vote
    weight :: Float64
    prefs  :: Array{Int}
end

mutable struct Candidate
    pos    :: Int
    sname  :: String
    fname  :: String
    party  :: String
    colour :: RGBA
    fate   :: Int
    votes  :: Array{Vote}
end

function rgb( r,g,b ) :: RGBA
    return RGBA( r/256, g/256, b/256, 1 )
end

# these are colour-picked from party websites FIXME expand this. 
const COLOURS = Dict([
    "SNP" => rgb(254, 242, 121), #"#fef279", 
    "CON" => rgb(10, 59, 124),# "#0a3b7c", 
    "LAB" => rgb( 253, 0, 69 ), 
    "LIB" => rgb(250, 160, 26 ),
    "ALB" => rgb(0, 94, 184 ),
    "GRN" => rgb(67, 176, 42 ),
    "UNU" => rgb(50, 50, 50 )]) # unused vote party in grey...

const OTHCOL = palette([:purple, :pink], 22)

const ELIMINATED = 1
const ELECTED = 2

#=
"CON" "Scottish Conservative and Unionist"=>"LAB",
"LAB" "Glasgow Labour"=>"LAB"
"Angela JONES" "Alba Party for independence"=>"ALB"
"Paul MCCABE" "Scottish National Party (SNP)"=>"SNP"
"Joe MCCAULEY" "Scottish Liberal Democrats"=>"LIB"
"Keith WARWICK" "Scottish Greens - Delivering For Our Community"=>"GRN"
=#

function guess_party( name :: AbstractString ) :: String
    s = uppercase(s)
    if contains( s, "SNP")
        return "SNP"
    elseif contains( s, "ALBA")
        return "ALBA"
    elseif contains( s, "GREEN")
        return "GRN"
    elseif contains( s, "LIBERAL")
        return "LIB"
    elseif contains( s, "LABOUR")
        return "LAB"
    elseif contains( s, "CONSERVATIVE")
        return "CON"
    # ... and so on
    end
    return ""
end

"""
colour of a party, or a random colour if I don't know it.
"""
function get_colour( party :: AbstractString )
    if haskey( COLOURS, party )
        return COLOURS[party]
    end
    return OTHCOL[rand(1:length(OTHCOL))]
end

"""
Henry Droop’s quota - which is “(total votes / (total seats + 1)) + 1”.
"""
function droop_quota( valid :: Real, seats :: Int ) :: Real
    return Int(trunc(valid/(seats+1))) + 1
end

"""
load from the gcc profiles files. need to add a party field to candidates
"""
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
    names = collect( ("R_$i" for i in 1:num_candidates))
    profiles = DataFrame( zeros(Int,num_raw_rows,num_candidates),names)
    counts = zeros(Float64, num_raw_rows )
    num_profiles = 0
    num_stages = -1
    for r in 2:num_raw_rows
        rs = strip(raw[r,1])
        println( "on row $r rs='$rs'")
        rsa = split( rs, " " )
        v = parse.(Int,rsa)
        counts[r-1] = popfirst!(v)
        # println("count ")
        profile_size = size(v)[1]-1
        println( "profile_size=$profile_size num_candidates=$num_candidates")
        @assert profile_size <= num_candidates
        if( profile_size == -1 )# && (v[1] == 0 ) # final row of data is a single '0' - break and then parse names
            break
        end
        # num_stages = max( num_stages, profile_size )
        num_profiles += 1
        @assert v[profile_size+1] == 0
        for n in 1:profile_size
            profiles[num_profiles,n] = v[n]
        end
    end
    candidates = Array{Candidate}(undef,0)
    n = 0
    DataFrames.pretty_table( profiles )
    for r in num_profiles+3:num_raw_rows-1
        n += 1
        c = split( raw[r,1], r" +") 
        push!( candidates, Candidate( n, c[2], c[1], c[3], get_colour(c[3]), 0, [] ) )
    end
    # unused dummy cand at end
    push!( candidates, Candidate(n+1, "Non-Transferred", "", "UNU", get_colour( "UNU"), 0, []))
    for i in 1:num_profiles
        p = profiles[i,1]
        println( "loading candidate $p ")
        prf = []
        for p in profiles[i,:]
            if p == 0
                break
            end
            push!(prf,p)
        end
        push!( candidates[p].votes, Vote( counts[i], prf ))
    end
    println( "num_candidates=$num_candidates num_seats=$num_seats candidates=$candidates")
    @assert num_candidates == size( candidates )[1]-1 # extra unused vote 
    wardname = strip(raw[num_raw_rows,1])
    num_votes = sum(counts)
    quota = droop_quota( num_votes, num_seats )
    return (
        candidates = candidates, 
        num_seats = num_seats, 
        quota = quota,
        wardname = wardname )
end

function countvotes( c::Candidate )::Real
    s = 0.0
    if c.fate == ELIMINATED
        return 0.0
    end
    for v in c.votes
        s += v.weight
    end
    # s
    round(s,digits=5)
end

"""
Transfers the votes of candidate `to` to other candidates `from`, the last of
which is a dummy 'untransferred votes' candidate.
"""
function transfer!( to :: Vector{Candidate}, from :: Candidate, weight :: Real )
    
    function nextdonee!(v :: Vote)
        # println("f on entry $(v.prefs)")
        n = size(v.prefs)[1]
        f = 0
        for i in 2:n            
            if to[v.prefs[i]].fate == 0
                f = i
                break
            end
        end
        if f == 0
            v.prefs = []
        else
            v.prefs = v.prefs[f:end]
        end
        # println( "f=$f prefs now $(v.prefs)")
    end

    init_votes = sum(countvotes.(to))
    for v in from.votes
        cv = deepcopy(v)
        cv2 = deepcopy(v)
        cv.weight *= weight
        v.weight *= (1-weight)
        cv2.weight = (weight == 1) ? cv2.weight : cv2.weight*weight
        nextdonee!(cv)
        if length(cv.prefs) > 0
            i = cv.prefs[1]
            if to[i].fate == 0
                @assert i != from.pos "i=$i pos=$(from.pos)"
                push!(to[i].votes, cv )
            else # unused vote
                push!( to[end].votes, cv2 )    
            end
        else # unused vote to unused votes party
            push!( to[end].votes, cv2 )
        end
    end
    final_votes = sum(countvotes.(to))
    @assert init_votes ≈ final_votes "redist shouln't change total votes but initial: $init_votes <> final: $final_votes"
end

function lowest( candidates :: Vector{Candidate})::Int
    minv = 9999999999999999
    pos = -1
    nc = size(candidates)[1] - 1 # allow for 
    for c in 1:nc
        v = countvotes(candidates[c])
        if v < minv && candidates[c].fate == 0
            minv = v
            pos = c
        end
    end
    return pos
end

function n_elected( candidates :: Vector{Candidate})::Int
    n = 0
    nc = size(candidates)[1] - 1 # allow for 
    for i in 1:nc
        if candidates[i].fate == ELECTED
            n += 1
        end
    end
    return n
end

function n_highest( candidates :: Vector{Candidate}, n :: Int ) AbstractVector{Int}
    nc = size(candidates)[1] - 1 # allow for 
    a = zeros(2,nc)
    for i in 1:nc
        a[1,i] = i
        a[2,i] = votes(candidates[i])
    end
    sort!(a,dims=2)
    return Int.(a[1,1:n])
end

"""
Runs the election, returning `seats` candidates. Modifies candidates in-place as votes are transferred at each stage
return: 
* candidates in final state; 
* matrix of votes at each stage;
* matrix of elected at each stage;
* mat of excluded at stage
all these are cand x stage
FIXME there's a lot of redundancy here
"""
function do_election!( 
    candidates :: Vector{Candidate}, 
    seats :: Int, 
    quota :: Real ) :: Tuple
    num_candidates = size(candidates)[1]-1
    nelect = 0
    lastcol = num_candidates
    # +1s here allow for unused votes (row) and possible extra round if too few elected (col)
    votes = zeros(num_candidates+1, num_candidates+1)
    elected = fill( false, num_candidates+1, num_candidates+1)
    excluded = fill( false, num_candidates+1, num_candidates+1)
    for stage in 1:num_candidates+1
        elected_this_stage = []
        for cand in 1:num_candidates
            tv = countvotes(candidates[cand])
            votes[cand,stage] = tv
            println( "can $cand votes $tv quota $quota")
            if tv > quota
                push!( elected_this_stage, cand )
            end
        end
        if stage <= num_candidates 
            if size( elected_this_stage)[1] > 0
                for e in elected_this_stage
                    elect = candidates[e]
                    elect.fate = ELECTED
                    tv = countvotes(candidates[e])
                    w = (tv-quota)/tv
                    elected[e,stage] = true
                    println( "elected $e $(elect.sname) with $tv votes stage $stage prop=$w")
                    transfer!( candidates, elect, w )
                end
            else
                l = lowest( candidates )
                excluded[l,stage] = true
                elim = candidates[l]
                println( "eliminating $(elim.sname)")
                transfer!( candidates, elim, 1.0 )
                elim.fate = ELIMINATED
            end
            nelect = n_elected( candidates )
            if nelect == seats
                break
            end
        else # possible last stage - add extra elected if < available seats
            n = seats - nelect
            if n > 0
                lastcol = stage
                toelect = n_highest( candidates, n )
                for e in toelect
                    candidates[e].fate = ELECTED
                    elected[e,stage] = true
                end
            end
        end # last stage
        # unused votes
        votes[end,stage+1] = countvotes(candidates[end])
    end # stages
    @assert sum(elected) == seats
    @assert sum(elected)+sum(excluded) == num_candidates # ignoring 'unused vote'
    @assert all((sum(votes[:,i]) ≈ sum(votes[:,1])) for i = 1:lastcol) # total votes constant over stages
    return candidates,votes[:,1:lastcol],elected[:,1:lastcol],excluded[:,1:lastcol]
end



