"""
FIXME simplify this
Make the three vectors used by the sankey, plus a lookup with names and
stage info.
"""
function make_src_dest_weights( candidates, votes, elected, excluded, stages )
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
        println("addone: stage $stage donor $donor donee $donee")
        # push!( weights, votes[donee,stage])
        if stage == 1
            push!( weights, votes[donee,stage] ) 
        else 
            delta = votes[donee,stage+1]-votes[donee,stage]
            if donee == donor
                delta = max(0.0, delta)
            end
            push!( weights, delta )
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
    @assert size( src ) == size( dest ) == size( weights )
    # weights = ones( size( src ))
    return src[1:end], dest[1:end], weights[1:end], lookup
end

function make_labels( lookup::Dict, src::Vector, dest::Vector )::Tuple
    labels = []
    cols = []
    for n in unique(vcat(src,dest))
        l = lookup[n]
        println("lookup for $n = $l")
        elec = l[2] ? "\nElected stage $(n[1])" : ""
        elim = l[3] ? "\nEliminated stage $(n[1])" : ""
        votes = Int(round(l[4]))
        label = "$(n[2])($votes)$elec$elim"
        println( "made label as $label")  
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
    elected::AbstractArray, 
    excluded::AbstractArray, 
    stages::Int )
    src,dest,weights,dict = make_src_dest_weights( candidates[1:stages], votes[1:stages,:], elected[1:stages,:], excluded[1:stages,:], stages )
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