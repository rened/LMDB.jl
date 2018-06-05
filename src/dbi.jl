"""
A handle for an individual database in the DB environment.
"""
mutable struct DBI
    handle::Cuint
    name::String
    DBI(dbi::Cuint, name::String) = new(dbi, name)
end

"Check if database is open"
isopen(dbi::DBI) = dbi.handle != zero(Cuint)

"Open a database in the environment"
function open(txn::Transaction, dbname::String = ""; flags::Cuint=zero(Cuint))
    cdbname = length(dbname) > 0 ? string(dbname) : convert(Cstring, Ptr{UInt8}(C_NULL))
    handle = Cuint[0]
    ret = ccall((:mdb_dbi_open, liblmdb), Cint,
                (Ptr{Nothing}, Cstring, Cuint, Ptr{Cuint}),
                 txn.handle, cdbname, flags, handle)
    (ret != 0) && throw(LMDBError(ret))
    return DBI(handle[1], dbname)
end

"Wrapper of DBI `open` for `do` construct"
function open(f::Function, txn::Transaction, dbname::String = ""; flags::Cuint=zero(Cuint))
    dbi = open(txn, dbname, flags=flags)
    tenv = env(txn)
    try
        f(dbi)
    finally
        close(tenv, dbi)
    end
end

"Close a database handle"
function close(env::Environment, dbi::DBI)
    if !isopen(env)
        warn("Environment is closed")
    end
    ccall((:mdb_dbi_close, liblmdb), Nothing, (Ptr{Nothing}, Cuint), env.handle, dbi.handle)
    dbi.handle = zero(Cuint)
    return
end

"Retrieve the DB flags for a database handle"
function flags(txn::Transaction, dbi::DBI)
    flags = Cuint[0]
    ret = ccall((:mdb_dbi_flags, liblmdb), Cint,
                (Ptr{Nothing}, Cuint, Ptr{Cuint}),
                 txn.handle, dbi.handle, flags)
    (ret != 0) && throw(LMDBError(ret))
    return flags[1]
end

"""Empty or delete+close a database.

If parameter `delete` is `false` DB will be emptied, otherwise
DB will be deleted from the environment and DB handle will be closed
"""
function drop(txn::Transaction, dbi::DBI; delete=false)
    del = delete ? int32(1) : int32(0)
    ret = ccall((:mdb_drop, liblmdb), Cint,
                (Ptr{Nothing}, Cuint, Cint),
                 txn.handle, dbi.handle, del)
    (ret != 0) && throw(LMDBError(ret))
    return ret
end

"Store items into a database"
function put!(txn::Transaction, dbi::DBI, key, val; flags::Cuint=zero(Cuint))
    mdb_key = MDBValue(key)
    mdb_val = MDBValue(val)

    ret = ccall((:mdb_put, liblmdb), Cint,
                (Ref{Nothing}, Cuint, Ref{MDBValue}, Ref{MDBValue}, Cuint),
                txn.handle, dbi.handle, mdb_key, mdb_val, flags)

    # println()
    # println()
    # println()
    # @show "putting", dbi, key, mdb_key, mdb_val

    # DEBUG RENE  Get value
    # mdb_key = MDBValue(key)
    # mdb_val = MDBValue()
    # ret = ccall((:mdb_get, liblmdb), Cint,
    #              (Ref{Nothing}, Cuint, Ref{MDBValue}, Ref{MDBValue}),
    #              txn.handle, dbi.handle, mdb_key, mdb_val)

    # @show "after putting", dbi, key, mdb_key, mdb_val
    # println()
    # println()

    (ret != 0) && throw(LMDBError(ret))
    return ret
end

"Delete items from a database"
function delete!(txn::Transaction, dbi::DBI, key, val)
    mdb_key = MDBValue(key)
    mdb_val = MDBValue(val)

    ret = ccall((:mdb_del, liblmdb), Cint,
                (Ref{Nothing}, Cuint, Ref{MDBValue}, Ref{MDBValue}),
                txn.handle, dbi.handle, mdb_key, mdb_val)

    (ret != 0) && throw(LMDBError(ret))
    return ret
end

"Get items from a database"
function get(txn::Transaction, dbi::DBI, key, ::Type{T}) where T
    # Setup parameters
    mdb_key = MDBValue(key)
    # @show "getting", dbi, key, mdb_key
    mdb_val = MDBValue()

    # Get value
    ret = ccall((:mdb_get, liblmdb), Cint,
                 (Ref{Nothing}, Cuint, Ref{MDBValue}, Ref{MDBValue}),
                 txn.handle, dbi.handle, mdb_key, mdb_val)
    (ret != 0) && throw(LMDBError(ret))

    # Convert to proper type
     # mdb_val = mdb_val_ref[]
    # @show mdb_val
    if T <: AbstractString
        return unsafe_string(convert(Ptr{UInt8}, mdb_val.data), mdb_val.size)
    else
        # @show mdb_val.size
        # @show sizeof(T)
        nvals = floor(Int, mdb_val.size/sizeof(T))
        value = unsafe_wrap(Array,convert(Ptr{T}, mdb_val.data), nvals)
        return length(value) == 1 ? value[1] : value
    end
end
