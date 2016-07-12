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
    @fact s --> "RHS\n    rhs       C1        0.0\n    rhs       C2        -1.0\n    rhs       C3        0.0\n    rhs       C4        0.0\n"
    @fact_throws MPSWriter.writeMPS!(io, [-Inf], [0., 1], [:(<=), :(==)])
    close(io)
end

facts("writeranges!") do
    io = IOBuffer()
    MPSWriter.writeranges!(io, [-Inf, -2.5, 0., 1.], [1., 1., 1., 2.], [:(<=), :ranged, :ranged, :ranged])
    s = takebuf_string(io)
    @fact s --> "RANGES\n    rhs       C2        3.5\n    rhs       C3        1.0\n    rhs       C4        1.0\n"
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

    @fact s --> "BOUNDS\n FR BOUNDS    V1\n PL BOUNDS    V2\n LO BOUNDS    V2        1.0\n PL BOUNDS    V3\n UP BOUNDS    V4        0.0\n MI BOUNDS    V4\n"
    @fact_throws MPSWriter.writebounds!(io, [-Inf], [Inf, 0.])
    close(io)
end

facts("boundstring") do
    @fact MPSWriter.boundstring("FR", 1) --> " FR BOUNDS    V1"
    @fact MPSWriter.boundstring("MI", 1) --> " MI BOUNDS    V1"
    @fact MPSWriter.boundstring("PL", 1) --> " PL BOUNDS    V1"
    @fact_throws MPSWriter.boundstring("LO", 1)
    @fact_throws MPSWriter.boundstring("UP", 1)
    @fact_throws MPSWriter.boundstring("badstring", 1)
    @fact_throws MPSWriter.boundstring("FR", 1, 1.)
    @fact_throws MPSWriter.boundstring("MI", 1, 1.)
    @fact_throws MPSWriter.boundstring("PL", 1, 1.)
    @fact_throws MPSWriter.boundstring("badstring", 1)
    @fact MPSWriter.boundstring("LO", 1, 1.) --> " LO BOUNDS    V1        1.0"
    @fact MPSWriter.boundstring("UP", 1, 1.) --> " UP BOUNDS    V1        1.0"
    @fact MPSWriter.boundstring("LO", 100, 1.) --> " LO BOUNDS    V100      1.0"
    @fact MPSWriter.boundstring("UP", 100, 1.) --> " UP BOUNDS    V100      1.0"
end

FactCheck.exitstatus()
