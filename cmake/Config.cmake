# Platform and compiler config for CMake.

# detect the os
if (${CMAKE_SYSTEM_NAME} STREQUAL "Windows")
  set(EGG_OS_WINDOWS 1)

  # don't use the OpenGL ES implementation on Windows
  set(OPENGL_ES 0)

  # detect the architecture (note: this test won't work for cross-compilation)
  include(CheckTypeSize)
  check_type_size(void* SIZEOF_VOID_PTR)
  if (${SIZEOF_VOID_PTR} STREQUAL "4")
    set(ARCH_32BITS 1)
  elseif (${SIZEOF_VOID_PTR} STREQUAL "8")
    set(ARCH_64BITS 1)
  else ()
    message(FATAL_ERROR "Unsupported architecture")
    return()
  endif ()
elseif (${CMAKE_SYSTEM_NAME} STREQUAL "Linux")
  set(EGG_OS_UNIX 1)
  if (ANDROID)
    set(EGG_OS_ANDROID 1)
    # use the OpenGL ES implementation on Android
    set(OPENGL_ES 1)
  else ()
    set(EGG_OS_LINUX 1)
    set(OPENGL_ES 0)
  endif ()
elseif (CMAKE_SYSTEM_NAME MATCHES "Darwin")
  if (IOS)
    set(EGG_OS_IOS 1)

    # use the OpenGL ES implementation on iOS
    set(OPENGL_ES 1)
  else ()
    set(EGG_OS_MACOSX 1)

    # don't use the OpenGL ES implementation on Mac OS X
    set(OPENGL_ES 0)

    # detect OS X version
    #
  endif ()
elseif (${CMAKE_SYSTEM_NAME} STREQUAL "Android")
  set(EGG_OS_ANDROID 1)

  # use the OpenGL ES implementation on Android
  set(OPENGL_ES 1)
elseif (${CYGWIN})
  message(FATAL_ERROR "Unfortunately EGG doesn't support Cygwin's 'hybrid' status between both Windows and Linux derivatives\nIf you insists on using the GCC, please use a standalone build of MinGW without the Cygwin environment instead.")
else ()
  message(FATAL_ERROR "Unsupported operating system or environment")
  return()
endif ()

set(EGG_PKGCONFIG_DIR "/lib${LIB_SUFFIX}/pkgconfig")


# detect the compiler and its version
if (CMAKE_CXX_COMPILER MATCHES "clang[+][+]" OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  # CMAKE_CXX_COMPILER_ID is an internal CMake variable subject to change,
  # but there is no other way to detect CLang at the moment
  set(EGG_COMPILER_CLANG 1)
  execute_process(COMMAND "${CMAKE_CXX_COMPILER}" "--version" OUTPUT_VARIABLE CLANG_VERSION_OUTPUT)
  string(REGEX REPLACE ".*clang version ([0-9]+\\.[0-9]+).*" "\\1" SFML_CLANG_VERSION "${CLANG_VERSION_OUTPUT}")
elseif (CMAKE_COMPILER_IS_GNUCXX)
  set(EGG_COMPILER_GCC 1)
  execute_process(COMMAND "${CMAKE_CXX_COMPILER}" "-dumpversion" OUTPUT_VARIABLE GCC_VERSION_OUTPUT)
  string(REGEX REPLACE "([0-9]+\\.[0-9]+).*" "\\1" SFML_GCC_VERSION "${GCC_VERSION_OUTPUT}")
  execute_process(COMMAND "${CMAKE_CXX_COMPILER}" "--version" OUTPUT_VARIABLE GCC_COMPILER_VERSION)
  string(REGEX MATCHALL ".*(tdm[64]*-[1-9]).*" SFML_COMPILER_GCC_TDM "${GCC_COMPILER_VERSION}")
  execute_process(COMMAND "${CMAKE_CXX_COMPILER}" "-dumpmachine" OUTPUT_VARIABLE GCC_MACHINE)
  string(STRIP "${GCC_MACHINE}" GCC_MACHINE)
  if (GCC_MACHINE MATCHES ".*w64.*")
    set(EGG_COMPILER_GCC_W64 1)
  endif ()
elseif (MSVC)
  set(EGG_COMPILER_MSVC 1)
  if (MSVC_VERSION EQUAL 1400)
    set(EGG_MSVC_VERSION 8)
  elseif (MSVC_VERSION EQUAL 1500)
    set(EGG_MSVC_VERSION 9)
  elseif (MSVC_VERSION EQUAL 1600)
    set(EGG_MSVC_VERSION 10)
  elseif (MSVC_VERSION EQUAL 1700)
    set(EGG_MSVC_VERSION 11)
  elseif (MSVC_VERSION EQUAL 1800)
    set(EGG_MSVC_VERSION 12)
  elseif (MSVC_VERSION EQUAL 1900)
    set(EGG_MSVC_VERSION 14)
  endif ()
else ()
  message(FATAL_ERROR "Unsupported compiler")
  return()
endif ()
    
