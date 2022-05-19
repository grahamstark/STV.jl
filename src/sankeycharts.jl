

"""
FIXME simplify this
Make the three vectors used by the sankey, plus a lookup with names and
stage info.
"""
function make_src_dest_weights( 
    candidates, votes, transfers ) # elected, excluded, stages )
    stages = size( votes )[2]
    ncs = size( candidates )[1]-1
    
    src = []
    dest = []
    weights = []
    #labels = []
    #colours = []
    lookup = Dict()

    function addone( donor::Int, donee::Int, stage::Int )
        nextstage = min(stages, stage+1)
        lookup[(stage,candidates[donor].sname)] = (candidate=candidates[donor],votes=votes[donor,stage])
        lookup[(stage+1,candidates[donee].sname)] = (candidate=candidates[donee],votes=votes[donee,nextstage])
        
        push!( src, (stage,candidates[donor].sname) ) #,candidates[donor].party,elected[donor,stage],excluded[donor,stage]])
        push!( dest,(stage+1,candidates[donee].sname) ) #candidates[donee].party,elected[donee,stage],excluded[donee,stage]])
        # weight - 
        println("addone: stage $stage donor $donor donee $donee")
        # push!( weights, votes[donee,stage])
        if donor == donee
            push!( weights, votes[donee,stage] ) 
        else 
            push!( weights, transfers[donor,donee,nextstage] )
        end
    end
 
    # ex = elected .| excluded
    for stage in 1:stages
        println("stage $stage")
        for cno in 1:ncs
            can = candidates[cno] 
            println("can $(can.sname)")
            if( can.stage == stage ) && ( stage < stages )# distribute votes of cand
                for dno in 1:ncs  
                    don = candidates[dno]
                    println( "donating to $dno")
                    if( don.stage > stage ) || (don.fate == ELECTED) # ! (any(ex[dno,1:stage-1])||excluded[dno,stage]) # not aleady excluded or elected on previous stage
                        println("adding to dno $stage")
                        addone( cno, dno, stage ) 
                    end
                end
                # push!( colours, get_colour( can.party ))
            else
                if (can.fate == ELECTED) || can.stage >= stage 
                    # elected at any stage or eliminated at a later stage 
                    
                    println("adding 1:1 for $(can.sname)")
                    if (can.fate == ELIMINATED) && (stage == stages )
                        #                         
                    else
                        addone( cno, cno, stage )
                        # push!( colours, get_colour( can.party ))
                        # push!( labels, make_label( ))
                    end
                end 
            end
        end # candidates
    end # stages
    @assert size( src ) == size( dest ) == size( weights )
    # weights = ones( size( src ))
    
    return src, dest, weights, lookup #labels, colours
end

function make_labels( lookup::Dict, src::Vector, dest::Vector )::Tuple
    labels = []
    cols = []
    
    for n in unique(vcat(src,dest))
        #if (i==1) || ((i > 1) && (src[i-1] != src[i]))
         #   n = src[i]
            l = lookup[n]
            println("lookup for $n = $l")
            stage = n[1]
            cand = l.candidate
            party = n[1] == 1 ? "$(cand.party): " : ""
            elec = ""
            if cand.fate == ELECTED && cand.stage == stage  
                elec = "\nElected stage $(cand.stage)"
            end
            elim = ""
            if cand.fate == ELIMINATED && cand.stage == stage
                elim = "\nEliminated stage $(cand.stage)"
            end
            votes = Int(round(l[2]))
            label = "$(party)$(cand.sname)($votes)$(elec)$(elim)"
            println( "for node $n, made label as |$label|")  
            push!( labels, label )
            push!( cols, get_colour( cand.party))
        # end
    end
    for i in eachindex(labels)
        println("$i=$(labels[i])")
    end
    labels, cols
end

"""

"""
function make_sankey( 
    wardname :: AbstractString, 
    candidates::AbstractVector, 
    votes::    AbstractMatrix, 
    transfers::AbstractArray ) 
    # elected::AbstractArray, 
    # excluded::AbstractArray, 
    # stages::Int )
    src,dest,weights,dict = make_src_dest_weights( 
        candidates, votes, transfers ) #  elected, excluded, stages )
    labels, colours = make_labels( dict, src, dest )
    # colours = make_colours( dict, src )
    p = sankey( src, dest, weights; 
        node_labels=labels, 
        edge_color=:gradient, 
        label_position=:bottom, 
        node_colors = colours,
        label_size=5,
        title=wardname,
        size=(1200,800),
        compact=false )
    return p
end