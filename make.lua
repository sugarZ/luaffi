local lm = require "luamake"
local isWindows = lm.os == "windows"

if lm.arch == nil then
    lm.arch = "x86_64"
end
--lm.mode = "debug"

print(string.format("arch:%s, mode:%s", lm.arch, lm.mode))

local function dynasm(output, input, flags)
    lm:runlua ("dynasm_"..output) {
        script = "src/dynasm/dynasm.lua",
        args = {
            "-LNE",
            flags or {},
            "-o", "$out",
            "$in",
        },
        inputs = "src/"..input,
        outputs = "src/"..output,
    }
end

dynasm('call_x86.h', 'call_x86.dasc', {'-D', 'X32WIN'})
dynasm('call_x64.h', 'call_x86.dasc', {'-D', 'X64'})
dynasm('call_x64win.h', 'call_x86.dasc', {'-D', 'X64', '-D', 'X64WIN'})
dynasm('call_arm.h', 'call_arm.dasc')

lm:phony {
    inputs = {
        "src/call_x86.h",
        "src/call_x64.h",
        "src/call_x64win.h",
        "src/call_arm.h",
    },
    outputs = "src/call.c",
}

lm:source_set "source_lua" {
    sources = {
        "lua/onelua.c",
    },
    visibility = "default",
    macos = {
        defines = "LUA_USE_MACOSX",
    },
    linux = {
        defines = "LUA_USE_LINUX",
    },
    netbsd = {
        defines = "LUA_USE_LINUX",
    },
    freebsd = {
        defines = "LUA_USE_LINUX",
    },
    openbsd = {
        defines = "LUA_USE_LINUX",
    },
    android = {
        defines = "LUA_USE_LINUX",
    },
    msvc = {
        flags = "/wd4334",
    }
}

lm:shared_library 'lua54' {
    windows = {
        sources = {
            "lua/onelua.c",
        },
        defines = {
            "MAKE_LIB",
            "LUA_BUILD_AS_DLL",
             "_WIN32_WINNT=0x0601"
        }
    },
    linux = {
        sources = {
            "lua/onelua.c",
        },
        defines = {
            "LUA_USE_LINUX",
            "_BSD_SOURCE"
        }
    },
}

lm:executable "lua" {
    deps = "source_lua",
    macos = {
        defines = "LUA_USE_MACOSX",
        links = { "m", "dl" },
    },
    linux = {
        defines = "LUA_USE_LINUX",
        links = { "m", "dl" }
    },
    netbsd = {
        defines = "LUA_USE_LINUX",
        links = "m",
    },
    freebsd = {
        defines = "LUA_USE_LINUX",
        links = "m",
    },
    openbsd = {
        defines = "LUA_USE_LINUX",
        links = "m",
    },
    android = {
        defines = "LUA_USE_LINUX",
        links = { "m", "dl" },
    }
}

lm:shared_library "luaffi" {
    sources = {
        "src/*.c",
        "!src/test.c",
    },
    linux = {
        sources = {
            "lua/onelua.c",
        },
        defines = {"LUA_USE_LINUX", "_BSD_SOURCE"},
        flags = "-Wno-unused-function -Wno-unused-variable -Wno-unused-but-set-variable",
    },
    windows = {
        deps = "source_lua", -- 生成静态编译
        --deps = "lua54", -- 使用lua动态库
        includes = "./lua",
        defines = {
            "_WIN32_WINNT=0x0601",
            "LUA_FFI_BUILD_AS_DLL" -- 导出luaopen_luaffi函数
        }
    },
}

lm:shared_library "ffi_test_cdecl" {
    sources = "src/test.c",
    defines = "_CRT_SECURE_NO_WARNINGS",
}

if lm.arch == "x86" then
    lm:shared_library "ffi_test_stdcall" {
        sources = "src/test.c",
        defines = "_CRT_SECURE_NO_WARNINGS",
        flags = "/Gz",
    }
    lm:shared_library "ffi_test_fastcall" {
        sources = "src/test.c",
        defines = "_CRT_SECURE_NO_WARNINGS",
        flags = "/Gr",
    }
end

lm:rule "test" {
    args = { "$bin/lua", "test.lua"},
    description = "Run test.",
    pool = "console",
}

lm:build "test" {
    rule = "test",
    deps = {
        "lua",
        "luaffi",
        "ffi_test_cdecl",
        lm.arch == "x86" and "ffi_test_stdcall",
        lm.arch == "x86" and "ffi_test_fastcall",
    },
    outputs = "$obj/test.stamp"
}

