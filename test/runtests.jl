println("\n\n\n---")

tests = ["common", "env", "dbi", "cur"]

for t in tests
    fp = "$t.jl"
    println("* running $fp ...")
    include(fp)
end

println("done!")
