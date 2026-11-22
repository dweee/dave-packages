# Appended by the Nix game derivation only (not native-prebuilt). llvm.org
# Clang -O2 on a single 80k–150k-line generated function is multi-hour.
# Typical shards stay -O2. Skip PCH: it was built at -O2.
function(mkw_tame_huge_translated_sources)
    set(limit 2700000)
    foreach(source IN LISTS ARGN)
        if(EXISTS "${source}")
            file(SIZE "${source}" bytes)
            if(bytes GREATER ${limit})
                set_source_files_properties("${source}" PROPERTIES
                    SKIP_PRECOMPILE_HEADERS ON
                    COMPILE_OPTIONS "-O0")
                message(STATUS "huge translated TU (${bytes} bytes): -O0 ${source}")
            endif()
        endif()
    endforeach()
endfunction()
mkw_tame_huge_translated_sources(
    ${MKW_BASE_COMMON_SHARDS}
    ${MKW_BASE_PORTABLE_SENSITIVE_SHARDS}
    ${MKW_RETRO_MOD_SHARDS}
    ${MKW_RETRO_PORTABLE_SENSITIVE_SHARDS})
