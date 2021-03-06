####
# By default, you will build a binary with the maximum of compatibility that your current version can provide.
# You may want to produce an optimized (or exotic) binary instead of a standard one.
# To do so, overload the following options :
# 
# SOLARUS_ARCH represent the build (multi-)architecture.
# SOLARUS_SYSROOT represent the path to the OSX SDK.
# SOLARUS_DEPLOYMENT represent the oldest OSX version supported.
#
# Some options set to the cache also need the FORCE parameter for obscure reasons.
#
# Exportable to XCode.
####

# Get the current OSX version as X.X.X and X.X form
execute_process(COMMAND sw_vers -productVersion
  OUTPUT_VARIABLE SOLARUS_CURRENT_OSX_VERSION
  OUTPUT_STRIP_TRAILING_WHITESPACE)
string(REGEX REPLACE "([0-9]+)\\.([0-9]+)\\.([0-9]+)\\[ \t\r\n]*" "\\1.\\2.\\3" SOLARUS_CURRENT_OSX_VERSION_LONG ${SOLARUS_CURRENT_OSX_VERSION})
string(REGEX REPLACE "([0-9]+)\\.([0-9]+).*" "\\1.\\2" SOLARUS_CURRENT_OSX_VERSION_SHORT ${SOLARUS_CURRENT_OSX_VERSION_LONG})

# Build architectures
if(NOT SOLARUS_ARCH)
  if(NOT ${SOLARUS_CURRENT_OSX_VERSION_LONG} VERSION_LESS "10.4.4")
    set(SOLARUS_ARCH "${SOLARUS_ARCH}i386;")
  endif()
  # LuaJIT needs additional linker flag with the 64bit build.
  # CMake can't set arch-specific flag with Makefile and Ninja generators for now,
  # so make a 32bit-only build if LuaJit and i386 are requested without XCode generator.
  if(XCODE OR NOT SOLARUS_USE_LUAJIT OR NOT SOLARUS_ARCH MATCHES "i386")
    if(NOT ${SOLARUS_CURRENT_OSX_VERSION_LONG} VERSION_LESS "10.5")
      set(SOLARUS_ARCH "${SOLARUS_ARCH}x86_64;")
    endif()
  endif()
endif()
set(CMAKE_OSX_ARCHITECTURES "${SOLARUS_ARCH}" CACHE STRING "Build architecture" FORCE)

# SDK version
if(NOT SOLARUS_SYSROOT)
  # Default SDKs, in order from the earlier naming convention to the older one
  if(EXISTS /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX${SOLARUS_CURRENT_OSX_VERSION_SHORT}.sdk)
    set(SOLARUS_SYSROOT "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX${SOLARUS_CURRENT_OSX_VERSION_SHORT}.sdk")
  elseif(EXISTS /Developer/SDKs/MacOSX${SOLARUS_CURRENT_OSX_VERSION_SHORT}.sdk)
    set(SOLARUS_SYSROOT "/Developer/SDKs/MacOSX${SOLARUS_CURRENT_OSX_VERSION_SHORT}.sdk")
  elseif(EXISTS /Developer/SDKs/MacOSX${SOLARUS_CURRENT_OSX_VERSION_SHORT}u.sdk)
    set(SOLARUS_SYSROOT "/Developer/SDKs/MacOSX${SOLARUS_CURRENT_OSX_VERSION_SHORT}u.sdk")
  elseif(EXISTS /Developer/SDKs/MacOSX${SOLARUS_CURRENT_OSX_VERSION_LONG}.sdk)
    set(SOLARUS_SYSROOT "/Developer/SDKs/MacOSX${SOLARUS_CURRENT_OSX_VERSION_LONG}.sdk")
  else()
    message(WARNING "No ${SOLARUS_CURRENT_OSX_VERSION_SHORT} or ${SOLARUS_CURRENT_OSX_VERSION_LONG} SDK found, force deployment version to default.")
  endif()
endif()
set(CMAKE_OSX_SYSROOT "${SOLARUS_SYSROOT}" CACHE STRING "Build SDK" FORCE)

# Deployment version
if(NOT SOLARUS_DEPLOYMENT AND DEFINED SOLARUS_SYSROOT)
  if(NOT ${SOLARUS_CURRENT_OSX_VERSION_LONG} VERSION_LESS "10.6")
    set(SOLARUS_DEPLOYMENT "10.6")
  else()
    set(SOLARUS_DEPLOYMENT "10.2")
  endif()
endif()
set(CMAKE_OSX_DEPLOYMENT_TARGET "${SOLARUS_DEPLOYMENT}" CACHE STRING "Oldest OS version supported" FORCE)

# Compatibility options
if(SOLARUS_CURRENT_OSX_VERSION_SHORT VERSION_EQUAL "10.6" AND SOLARUS_DEPLOYMENT VERSION_LESS "10.6")
  if(NOT CMAKE_EXE_LINKER_FLAGS MATCHES "-Wl,-no_compact_linkedit")
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,-no_compact_linkedit" CACHE STRING "Disable 10.6+ features if deploy on older version" FORCE)
  endif()
endif()

if(NOT CMAKE_CXX_FLAGS MATCHES "-force_cpusubtype_ALL")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -force_cpusubtype_ALL" CACHE STRING "Force all cpu subtypes, to avoid trouble with some old architectures" FORCE)
endif()

if(SOLARUS_USE_LUAJIT AND SOLARUS_ARCH MATCHES "x86_64")
  if(XCODE)
    set_property(TARGET solarus PROPERTY
      "XCODE_ATTRIBUTE_LINKER_FLAGS[arch=x86_64]" "-pagezero_size 10000 -image_base 100000000"
    )
  elseif(NOT CMAKE_EXE_LINKER_FLAGS MATCHES "-pagezero_size 10000 -image_base 100000000")
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -pagezero_size 10000 -image_base 100000000" CACHE STRING "According to LuaJit doc, OSX needs to link with additional flags if 64bit build is requested" FORCE)
  endif()
endif()

# TODO try to build on 10.6+ with following flags and run on 10.5
# set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,-syslibroot,${CMAKE_OSX_SYSROOT}" CACHE STRING "Link with SDK")
# set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fstack-protector" CACHE STRING "Emit extra code to check for buffer overflows on function with vulnerable objects")
# set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fstack-protector-all" CACHE STRING "Emit extra code to check for buffer overflows on all functions")
