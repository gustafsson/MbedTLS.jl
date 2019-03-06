using BinaryProvider, Libdl

# Parse some basic command-line arguments
const verbose = "--verbose" in ARGS
const prefix = Prefix(get([a for a in ARGS if a != "--verbose"], 1, joinpath(@__DIR__, "usr")))
products = [
    LibraryProduct(prefix, String["libmbedx509"], :libmbedx509),
    LibraryProduct(prefix, String["libmbedcrypto"], :libmbedcrypto),
    LibraryProduct(prefix, String["libmbedtls"], :libmbedtls),
]

const juliaprefix = joinpath(Sys.BINDIR, "..")

juliaproducts = Product[
    LibraryProduct(juliaprefix, "libmbedx509", :libmbedx509),
    LibraryProduct(juliaprefix, "libmbedcrypto", :libmbedcrypto),
    LibraryProduct(juliaprefix, "libmbedtls", :libmbedtls)
]

# Download binaries from hosted location
bin_prefix = "https://github.com/JuliaWeb/MbedTLSBuilder/releases/download/v0.20.0"

# Listing of files generated by BinaryBuilder:
download_info = Dict(
    Linux(:aarch64, libc=:glibc) => ("$bin_prefix/MbedTLS.v2.6.1.aarch64-linux-gnu.tar.gz", "b5c6aa8f367f6d4a1d940381c30740e1daa9653104423412a078f2f41862bccc"),
    Linux(:aarch64, libc=:musl) => ("$bin_prefix/MbedTLS.v2.6.1.aarch64-linux-musl.tar.gz", "56c22a9246c42baed29337049925ecb932b84fabfcd4904ba19e974579ef9c9c"),
    Linux(:armv7l, libc=:glibc, call_abi=:eabihf) => ("$bin_prefix/MbedTLS.v2.6.1.arm-linux-gnueabihf.tar.gz", "05755bc4a886e5b020776e23a3778db811312a284c42418924c94c2150288970"),
    Linux(:armv7l, libc=:musl, call_abi=:eabihf) => ("$bin_prefix/MbedTLS.v2.6.1.arm-linux-musleabihf.tar.gz", "982ba365a4d8551b4629abbab428b3bec0a997823b834b59f867e3316b5e711c"),
    Linux(:i686, libc=:glibc) => ("$bin_prefix/MbedTLS.v2.6.1.i686-linux-gnu.tar.gz", "97e7651ba4d162b5cd0ef53e0d364a7f6dc5e5b8d35fd89d7df9e10863de77b8"),
    Linux(:i686, libc=:musl) => ("$bin_prefix/MbedTLS.v2.6.1.i686-linux-musl.tar.gz", "4430e4a32ddd6932057498d4f21e307c1d06ef4ddbbf0224ed68f5a617c16b08"),
    Windows(:i686) => ("$bin_prefix/MbedTLS.v2.6.1.i686-w64-mingw32.tar.gz", "30cccba8debbf30d61002ca3fb6de325ff9919b4229329b7cb1a4f3b4175e555"),
    Linux(:powerpc64le, libc=:glibc) => ("$bin_prefix/MbedTLS.v2.6.1.powerpc64le-linux-gnu.tar.gz", "b2dfc9887701376329f2a59cda0d813a2e412c934b7c233b1278c90b3fd7c7a5"),
    MacOS(:x86_64) => ("$bin_prefix/MbedTLS.v2.6.1.x86_64-apple-darwin14.tar.gz", "245779d96eb8dc2c929f77210eab02d2ba4e7cd078f2f936c46339daae62e3a0"),
    Linux(:x86_64, libc=:glibc) => ("$bin_prefix/MbedTLS.v2.6.1.x86_64-linux-gnu.tar.gz", "b667e285de1bb797882d0a253ba31869d22dc73250ad91da094bfe7ca220363c"),
    Linux(:x86_64, libc=:musl) => ("$bin_prefix/MbedTLS.v2.6.1.x86_64-linux-musl.tar.gz", "9bf7484b274e3cd7c1dd93e6f7957c734b720ed77f2f8348e63f67bbcc016ae7"),
    FreeBSD(:x86_64) => ("$bin_prefix/MbedTLS.v2.6.1.x86_64-unknown-freebsd11.1.tar.gz", "3d333991f9a72e9538b6b2915c87990028400ebdd5714ff6f21d2602135536c2"),
    Windows(:x86_64) => ("$bin_prefix/MbedTLS.v2.6.1.x86_64-w64-mingw32.tar.gz", "371b01c03217caf5b021113df6807485d916553f983b9ebb21c0c601c270d22b"),
)

# First, check to see if we're all satisfied
gpl = haskey(ENV, "USE_GPL_MBEDTLS")
forcebuild = parse(Bool, get(ENV, "FORCE_BUILD", "false")) || gpl
done = false
if any(!satisfied(p; verbose=verbose) for p in products) || forcebuild
    if haskey(download_info, platform_key()) && !forcebuild
        # Download and install binaries
        url, tarball_hash = download_info[platform_key()]
        install(url, tarball_hash; prefix=prefix, force=true, verbose=verbose)
        done = all(satisfied(p; verbose=verbose) for p in products)
        done && @info "using prebuilt binaries"
    end
    if !done && all(satisfied(p; verbose=verbose) for p in juliaproducts) && !forcebuild
        @info "using julia-shippied binaries"
        products = juliaproducts
    elseif !done || forcebuild
        @info "attempting source build"
        VERSION = "2.6.0"
        url, hash = haskey(ENV, "USE_GPL_MBEDTLS") ?
            ("https://tls.mbed.org/download/mbedtls-$VERSION-gpl.tgz", "a99959d7360def22f9108d2d487c9de384fe76c349697176b1f22370080d5810") :
            ("https://tls.mbed.org/download/mbedtls-$VERSION-apache.tgz", "99bc9d4212d3d885eeb96273bcde8ecc649a481404b8d7ea7bb26397c9909687")
        download_verify(url, hash, joinpath(@__DIR__, "mbedtls.tgz"), force=true, verbose=true)
        unpack(joinpath(@__DIR__, "mbedtls.tgz"), @__DIR__; verbose=true)
        withenv("VERSION"=>VERSION) do
            run(Cmd(`./build.sh`, dir=@__DIR__))
        end
        if any(!satisfied(p; verbose=verbose) for p in products)
            error("attempted to build mbedtls shared libraries, but they couldn't be located (deps/usr/lib)")
        end
    end
end

write_deps_file(joinpath(@__DIR__, "deps.jl"), products, verbose=verbose)
