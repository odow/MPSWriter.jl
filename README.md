# MPSWriter

[![Build Status](https://travis-ci.org/odow/MPSWriter.jl.svg?branch=master)](https://travis-ci.org/odow/MPSWriter.jl)

[![codecov](https://codecov.io/gh/odow/MPSWriter.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/odow/MPSWriter.jl)

This package is not registered. Use `Pkg.clone("https://github.com/odow/MPSWriter.jl")` to install.

The `MPSWriter.jl` package is a pure Julia light-weight implementation of an MPS
file writer.

The MPS format is not well standardised and various versions exist.

http://lpsolve.sourceforge.net/5.5/mps-format.htm

http://plato.asu.edu/cplex_mps.pdf

http://docs.mosek.com/7.1/capi/The_MPS_file_format.html


It has a single, user-facing, un-exported function.

```julia
MPSWriter.writemps(io::IO,
    A::AbstractMatrix,       # the constraint matrix
    collb::Vector,           # vector of variable lower bounds
    colub::Vector,           # vector of variable upper bounds
    c::Vector,               # vector containing variable objective coefficients
    rowlb::Vector,           # constraint lower bounds
    rowub::Vector,           # constraint upper bounds
    sense::Symbol,           # model sense
    colcat::Vector{Symbol},  # constraint types
    sos::Vector{MPSWriter.SOS},        # SOS information
    Q::AbstractMatrix,       #  Quadratic objective 0.5 * x' Q x
    modelname::AbstractString = "MPSWriter_jl",  # MPS model name
    colnames::Vector{String}  = ["V$i" for i in 1:length(c)],    # variable names
    rownames::Vector{String}  = ["C$i" for i in 1:length(rowub)] # constraint names
)
```

Limitations:
 - `sense` must be `:Min` or `:Max`
 - Only Integer (colcat = `:Int`), Binary (colcat = `:Bin`) and Continuous (colcat = `:Cont`)
    variables are supported.

`MPSWriter.SOS` is the immutable type
```julia
immutable SOS
    order::Int
    indices::Vector{Int}
    weights::Vector{Float64}
end
```
where the `order` is either `1` (for SOS of type I) or `2` (for SOS of type II).
The `indices` are a list of the indices of the columns in the constraint matrix
corresponding to the variables in the SOS set. `weights`defines an ordering on
the indices.
