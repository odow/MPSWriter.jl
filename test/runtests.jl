using MPSWriter, FactCheck

facts("getrowsense") do
    # LE, GE, Eq, Ranged
    row_sense, hasranged = MPSWriter.getrowsense([-Inf, 0.], [0., Inf])
    @fact row_sense --> [:(<=), :(>=)]
    @fact hasranged --> false

    row_sense, hasranged = MPSWriter.getrowsense([1., -1.], [1., 1.])
    @fact row_sense --> [:(==), :ranged]
    @fact hasranged --> true

    @fact_throws MPSWriter.getrowsense([1.], [1., 1.])
    @fact_throws MPSWriter.getrowsense([-Inf], [Inf])
end

facts("writecolumns!") do
    io = IOBuffer()

    MPSWriter.writecolumns!(io, [0. 0.]', [:Cont], [1.], :Min)
    @fact takebuf_string(io) --> "COLUMNS\n    V1        OBJ       1.0\n"

    MPSWriter.writecolumns!(io, [0. 0.]', [:Cont], [1.], :Max)
    @fact takebuf_string(io) --> "COLUMNS\n    V1        OBJ       -1.0\n"

    MPSWriter.writecolumns!(io, [0. 0.], [:Bin, :Cont], [3., 4.], :Max)
    @fact takebuf_string(io) --> "COLUMNS\n    MARKER    'MARKER'                 'INTORG'\n    V1        OBJ       -3.0\n    MARKER    'MARKER'                 'INTEND'\n    V2        OBJ       -4.0\n"

    MPSWriter.writecolumns!(io, [0. 0.], [:Fixed, :Int], [3., 4.], :Max)
    @fact takebuf_string(io) --> "COLUMNS\n    V1        OBJ       -3.0\n    MARKER    'MARKER'                 'INTORG'\n    V2        OBJ       -4.0\n    MARKER    'MARKER'                 'INTEND'\n"

    @fact_throws MPSWriter.writecolumns!(io, [0. 0.]', [:Cont], [1.], :badsense)
    @fact_throws MPSWriter.writecolumns!(io, [0. 0.]', [:badtype], [1.], :Min)
    @fact_throws MPSWriter.writecolumns!(io, [0. 0.]', [:Cont, :Cont], [1.], :Min)

    close(io)
end

facts("writecolumn!") do
    for Aty in [SparseMatrixCSC{Float64, Int}, Array{Float64, 2}]
        io = IOBuffer()
        A = convert(Aty, [1. 0.; 1.5 0.4])
        MPSWriter.writecolumn!(io, A, 1)
        @fact takebuf_string(io) --> "    V1        C1        1\n    V1        C2        1.5\n"
        MPSWriter.writecolumn!(io, A, 2)
        @fact takebuf_string(io) --> "    V2        C2        .4\n"
        close(io)
    end
end

facts("writerows!") do
    io = IOBuffer()
    MPSWriter.writerows!(io, [:(<=), :(>=), :(==), :ranged])
    s = takebuf_string(io)
    @fact s --> "ROWS\n N  OBJ\n L  C1\n G  C2\n E  C3\n E  C4\n"
    @fact_throws MPSWriter.writerows!(io, [:badsym])
    close(io)
end

facts("writerhs!") do
    io = IOBuffer()
    MPSWriter.writerhs!(io, [-Inf, -1., 0., 0.], [0., 1., 0., Inf], [:(<=), :ranged, :(==), :(>=)])
    s = takebuf_string(io)
    @fact s --> "RHS\n    rhs       C1        0\n    rhs       C2        -1\n    rhs       C3        0\n    rhs       C4        0\n"
    @fact_throws MPSWriter.writeMPS!(io, [-Inf], [0., 1], [:(<=), :(==)])
    close(io)
end

facts("writeranges!") do
    io = IOBuffer()
    MPSWriter.writeranges!(io, [-Inf, -2.5, 0., 1.], [1., 1., 1., 2.], [:(<=), :ranged, :ranged, :ranged])
    s = takebuf_string(io)
    @fact s --> "RANGES\n    rhs       C2        3.5\n    rhs       C3        1\n    rhs       C4        1\n"
    close(io)
end

facts("writebounds!") do
    io = IOBuffer()
    # (-Inf, Inf) = FR
    # (  * , Inf) = PL
    # (  * ,  x ) = UP
    # (-Inf,  * ) = MI
    # (  x ,  * ) = LO
    MPSWriter.writebounds!(io, [-Inf, 1., 0., -Inf], [Inf, Inf, Inf, 0.])

    s = takebuf_string(io)

    @fact s --> "BOUNDS\n FR BOUNDS    V1\n PL BOUNDS    V2\n LO BOUNDS    V2        1\n PL BOUNDS    V3\n UP BOUNDS    V4        0\n MI BOUNDS    V4\n"
    @fact_throws MPSWriter.writebounds!(io, [-Inf], [Inf, 0.])
    close(io)
end

facts("boundstring") do
    io = IOBuffer()
    MPSWriter. writebound!(io, "FR", 1)
    @fact takebuf_string(io) --> " FR BOUNDS    V1\n"
    MPSWriter. writebound!(io, "MI", 1)
    @fact takebuf_string(io) --> " MI BOUNDS    V1\n"
    MPSWriter. writebound!(io, "PL", 1)
    @fact takebuf_string(io) --> " PL BOUNDS    V1\n"

    @fact_throws MPSWriter. writebound!(io, "LO", 1)
    @fact_throws MPSWriter. writebound!(io, "UP", 1)
    @fact_throws MPSWriter. writebound!(io, "badstring", 1)
    @fact_throws MPSWriter. writebound!(io, "FR", 1, 1.)
    @fact_throws MPSWriter. writebound!(io, "MI", 1, 1.)
    @fact_throws MPSWriter. writebound!(io, "PL", 1, 1.)
    @fact_throws MPSWriter. writebound!(io, "badstring", 1)

    MPSWriter. writebound!(io, "LO", 1, 1.)
    @fact takebuf_string(io) --> " LO BOUNDS    V1        1\n"
    MPSWriter. writebound!(io, "UP", 1, 1.)
    @fact takebuf_string(io) --> " UP BOUNDS    V1        1\n"
    MPSWriter. writebound!(io, "LO", 100, 1.)
    @fact takebuf_string(io) --> " LO BOUNDS    V100      1\n"
    MPSWriter. writebound!(io, "UP", 100, 1.)
    @fact takebuf_string(io) --> " UP BOUNDS    V100      1\n"
    close(io)
end

facts("SOS") do
    sos = SOS(1, [1,2,3], [1.,2.,3.])
    @fact sos.order --> 1
    @fact sos.indices --> [1,2,3]
    @fact sos.weights --> [1., 2., 3.]

    io = IOBuffer()
    MPSWriter.writesos!(io, [SOS(1, [1,2,3], [1.,3.,2.]), SOS(2, [1,2,3], [2.,1.,3.])], 3)
    s = takebuf_string(io)
    @fact s --> "SOS\n S1 SOS1\n    V1        1\n    V2        3\n    V3        2\n S2 SOS2\n    V1        2\n    V2        1\n    V3        3\n"

    @fact_throws MPSWriter.writesos!(io, [SOS(1, [1,2,3], [1.,2.,3.])], 2)
    @fact_throws MPSWriter.writesos!(io, [SOS(1, [0,2,3], [1.,2.,3.])], 3)

    close(io)
end

facts("writemps") do
const MPSFILE = """NAME          TestModel
ROWS
 N  OBJ
 L  C1
 G  C2
 E  C3
 E  C4
 E  C5
COLUMNS
    V1        C1        1
    V1        OBJ       -1
    V2        C2        1
    V3        C3        1
    V4        C4        1
    V4        OBJ       -1
    MARKER    'MARKER'                 'INTORG'
    V5        OBJ       1
    MARKER    'MARKER'                 'INTEND'
    V6        C5        1
    V7        C5        1
    V8        C5        1
    MARKER    'MARKER'                 'INTORG'
    V9        OBJ       0
    MARKER    'MARKER'                 'INTEND'
RHS
    rhs       C1        1
    rhs       C2        2
    rhs       C3        3
    rhs       C4        4
    rhs       C5        1
RANGES
    rhs       C4        1
BOUNDS
 FR BOUNDS    V1
 FR BOUNDS    V2
 FR BOUNDS    V3
 FR BOUNDS    V4
 PL BOUNDS    V5
 LO BOUNDS    V5        5.5
 UP BOUNDS    V6        1
 UP BOUNDS    V7        1
 UP BOUNDS    V8        1
 UP BOUNDS    V9        1
SOS
 S2 SOS1
    V6        1
    V7        2
    V8        3
ENDATA
"""
    io = IOBuffer()
    writemps(io,
    [
    1 0 0 0 0 0 0 0 0;
    0 1 0 0 0 0 0 0 0;
    0 0 1 0 0 0 0 0 0;
    0 0 0 1 0 0 0 0 0;
    0 0 0 0 0 1 1 1 0
    ],
    [-Inf, -Inf, -Inf, -Inf, 5.5, 0, 0, 0, 0],
    [Inf, Inf, Inf, Inf, Inf, 1, 1, 1, 1],
    [1,0,0,1,-1,0,0,0,0],
    [-Inf, 2, 3, 4, 1],
    [1, Inf, 3, 5, 1],
    :Max,
    [:Cont, :Cont, :Cont, :Cont, :Int, :Cont, :Cont, :Cont, :Bin],
    SOS[SOS(2, [6,7,8], [1,2,3])],
    "TestModel"
    )
    @fact takebuf_string(io) --> MPSFILE
    close(io)
end

FactCheck.exitstatus()
