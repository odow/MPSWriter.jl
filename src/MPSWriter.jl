module MPSWriter

export writeMPS

function getrowsense{T1 <: Real, T2<: Real}(rowlb::Vector{T1}, rowub::Vector{T2})
    @assert length(rowlb) == length(rowub)
    row_sense = Array(Symbol, length(rowub))
    hasranged = false
    for r=1:length(rowlb)
        @assert rowlb[r] <= rowub[r]
    	if (rowlb[r] == -Inf && rowub[r] != Inf) || (rowlb[r] == typemin(eltype(rowlb)) && rowub[r] != typemax(eltype(rowub)))
    		row_sense[r] = :(<=) # LE constraint
    	elseif (rowlb[r] != -Inf && rowub[r] == Inf)  || (rowlb[r] != typemin(eltype(rowlb)) && rowub[r] == typemax(eltype(rowub)))
    		row_sense[r] = :(>=) # GE constraint
    	elseif rowlb[r] == rowub[r]
    		row_sense[r] = :(==) # Eq constraint
        elseif (rowlb[r] == -Inf && rowub[r] == Inf)
            error("Cannot have a constraint with no bounds")
    	else
            row_sense[r] = :ranged
            hasranged = true
    	end
    end
    row_sense, hasranged
end

function writerows!(io::IO, row_sense::Vector{Symbol})
    # Objective and constraint names
    println(io, "ROWS\n N  OBJ")
    sensechar = ' '
    for i in 1:length(row_sense)
        if row_sense[i] == :(<=)
            sensechar = 'L'
        elseif row_sense[i] == :(==)
            sensechar = 'E'
        elseif row_sense[i] == :(>=)
            sensechar = 'G'
        elseif row_sense[i] == :ranged
            sensechar = 'E'
        else
            error("Unknown row sense $(row_sense[i])")
        end
        println(io, " $sensechar  C$i")
    end
end

function writecolumns!(io::IO, A, colcat, c::Vector, sense::Symbol)
    @assert sense == :Min || sense == :Max
    @assert length(colcat) == length(c)

    A = convert(SparseMatrixCSC{Float64, Int32}, A)
    intgrpOPEN = false

    println(io, "COLUMNS")

    for col in 1:length(c)
    	if colcat != :nothing
	        colty = colcat[col]
	        if colty == :SemiCont || colty == :SemiInt
                error("The MPS file writer does not currently support semicontinuous or semi-integer variables")
            end
	        if (colty == :Bin || colty == :Int) && !_intgrpOPEN
	            println(io, "    MARKER    'MARKER'                 'INTORG'")
	            _intgrpOPEN = true
	        elseif (colty == :Cont || colty == :Fixed) && _intgrpOPEN
	            println(io, "    MARKER    'MARKER'                 'INTEND'")
	            _intgrpOPEN = false
	        end
	    end
    	if abs(c[col]) > 1e-10 # Non-zeros
    		# Flip signs for maximisation
            println(io, "    V$(rpad(col, 7))  $(rpad("OBJ", 8))  $((sense==:Max?-1:1)*c[col])")
	    end
        if length(A.colptr) > col
            for ind in A.colptr[col]:(A.colptr[col+1]-1)
            	if abs(A.nzval[ind]) > 1e-10 # Non-zero
    	            println(io, "    V$(rpad(col, 7))  C$(rpad(A.rowval[ind], 7))  $(A.nzval[ind])")
    	        end
            end
        end
    end
    if _intgrpOPEN
        println(io, "    MARKER    'MARKER'                 'INTEND'")
    end
end

function writerhs!(io::IO, rowlb, rowub, row_sense::Vector{Symbol})
    @assert length(rowlb) == length(rowub) == length(row_sense)
    println(io, "RHS")
    for c in 1:length(rowlb)
        println(io, "    rhs       C$(rpad(c, 7))  $(row_sense[c] == :(<=)?rowub[c]:rowlb[c])")
    end
end

function writeranges!(io::IO, rowlb, rowub, row_sense::Vector{Symbol})
    @assert length(rowlb) == length(rowub) == length(row_sense)
    println(io, "RANGES")
    for r=1:length(row_sense)
        if row_sense[r] == :ranged
            println(io, "    rhs       C$(rpad(r, 7))  $(rowub[r] - rowlb[r])")
        end
    end
end

function writebounds!(io::IO, collb, colub)
    @assert length(collb) == length(colub)
    println(io, "BOUNDS")
    for col in 1:length(collb)
        if colub[col] == Inf
            if collb[col] == -Inf
                println(io, boundstring("FR", col))
                continue
            else
                println(io, boundstring("PL", col))
            end
        else
            println(io, boundstring("UP", col, colub[col]))
        end
        if collb[col] == -Inf
            println(io, boundstring("MI", col))
        elseif collb[col] != 0
            println(io, boundstring("LO", col, collb[col]))
        end
    end
end

function boundstring(ty::ASCIIString, vidx::Int)
    @assert ty in ["FR", "MI", "PL"]
    " $ty BOUNDS    V$vidx"
end

function boundstring(ty::ASCIIString, vidx::Int, val::Real)
    @assert ty in ["LO", "UP"]
    " $ty BOUNDS    V$(rpad(vidx, 7))  $(val)"
end

immutable SOS
    order::Int
    indices::Vector{Int}
    weights::Vector
end

function addsos!(io::IO, sos::Vector{SOS}, maxvarindex::Int)
    for i=1:length(sos)
        @assert length(sos[i].indices) == length(sos[i].weights)
        println(io, "SOS\n S$(sos[i].order) SOS$(length(sos[i].indices))")
        for j=1:length(sos[i].indices)
            @assert sos[i].indices[j] > 0 && sos[i].indices[j] <= maxvarindex
            println(io, "    V$(rpad(sos[i].indices[j], 7))  $(sos[i].weights[j])")
        end
    end
end

function writemps(io::IO,
    A,                         # the constraint matrix
    collb::Vector,             # vector of variable lower bounds
    colub::Vector,             # vector of variable upper bounds
    c::Vector,                 # vector containing variable objective coefficients
    rowlb::Vector,             # constraint lower bounds
    rowub::Vector,             # constraint upper bounds
    sense::Symbol,             # model sense
    colcat::Vector,            # constraint types
    sos::Vector{SOS}=SOS[]     # SOS information
)
    # Max width (8) for names in fixed MPS format
    # TODO: replace names by alpha-numeric
    #   to enable more variables and constraints.
    #   Although to be honest no one should be using
    #   this with that many constraints/variables
    @assert length(c) <= 9999999
    @assert length(rowub) <= 9999999

    # Sanity checks
    @assert length(rowlb) == length(rowub)
    @assert length(collb) == length(colub) == length(c) == length(colcat)
    @assert sense == :Min || sense == :Max

    println(io, "NAME          MPSWriter_jl")

    row_sense, hasranged = getrowsense(rowlb, rowub)

    writerows!(io, rowsense)
    writecolumns!(io, A, colcat, c, sense)
    if hasranged
        writeranges!(io, rowlb, rowub, row_sense)
    end
    writebounds!(io, collb, colub)
    addsos!(io, sos, length(collb))
    println(io, "ENDATA")
end

function writemps(filename::AbstractString,
    A,                         # the constraint matrix
    collb::Vector,             # vector of variable lower bounds
    colub::Vector,             # vector of variable upper bounds
    c::Vector,                 # vector containing variable objective coefficients
    rowlb::Vector,             # constraint lower bounds
    rowub::Vector,             # constraint upper bounds
    sense::Symbol,             # model sense
    colcat::Vector,            # constraint types
    sos::Vector{SOS}=SOS[]     # SOS information
)
    open(filename, "w") do io
        writemps(io, A, collb, colub, c, rowlb, rowub, sense, colcat, sos)
    end
end

end # module
