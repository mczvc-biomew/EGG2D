include(CMakeParseArguments)

# add a new target which is a EGG library
# ex: egg_add_library(egg-graphics
#                       SOURCES sprite.cpp image.cpp ...
#                       DEPENDS egg-window egg-system)
macro(egg_add_library target)

  # parse the arguments
  cmake_parse_arguments(THIS "STATIC" "" "SOURCES" ${ARGN})
  if (NOT "${THIS_UNPARSED_ARGUMENTS}" STREQUAL "")
    message(FATAL_ERROR "Extra unparsed arguments when calling EGG_add_library: ${THIS_UNPARSED_ARGUMENTS}")
  endif ()

  # create the target
  if (THIS_STATIC)
    add_library(${target} STATIC ${THIS_SOURCES})
  else ()
    add_library(${target} ${THIS_SOURCES})
  endif ()

  # define the export symbol of the module
  string(REPLACE "-" "_" NAME_UPPER "${target}")
  string(TOUPPER "${NAME_UPPER}" NAME_UPPER)
  set_target_properties(${target} PROPERTIES DEFINE_SYMBOL ${NAME_UPPER}_EXPORTS)

  # adjust the output file prefix/suffix to match our conventions
  if (BUILD_SHARED_LIBS AND NOT THIS_STATIC)
    if (EGG_OS_WINDOWS)
      # include the major version number in Windows shared library names (but not import library names)
      set_target_properties(${target} PROPERTIES DEBUG_POSTFIX -d)
      set_target_properties(${target} PROPERTIES SUFFIX "-${VERSION_MAJOR}${CMAKE_SHARED_LIBRARY_SUFFIX}")
    else ()
      set_target_properties(${target} PROPERTIES DEBUG_POSTFIX -d)
    endif ()
    if (EGG_OS_WINDOWS AND EGG_COMPILER_GCC)
      # on Windows/gcc get rid of "lib" prefix for shared libraries,
      # and transform the ".dll.a" suffix into ".a" for import libraries
      set_target_properties(${target} PROPERTIES PREFIX "")
      set_target_properties(${target} PROPERTIES IMPORT_SUFFIX ".a")
    endif ()
  else ()
    set_target_properties(${target} PROPERTIES DEBUG_POSTFIX -s-d)
    set_target_properties(${target} PROPERTIES RELEASE_POSTFIX -s)
    set_target_properties(${target} PROPERTIES MINSIZEREL_POSTFIX -s)
    set_target_properties(${target} PROPERTIES RELWITHDEBINFO_POSTFIX -s)
  endif ()

  # set the version and soversion of the target (for compatible systems -- mostly Linuxes)
  # except for Android which strips soversion suffixes
  if (NOT EGG_OS_ANDROID)
    set_target_properties(${target} PROPERTIES SOVERSION ${VERSION_MAJOR}.${VERSION_MINOR})
    set_target_properties(${target} PROPERTIES VERSION ${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH})
  endif ()

  # set the target's folder (for IDEs that support it, e.g. Visual Studio)
  set_target_properties(${target} PROPERTIES FOLDER "EGG")

  # set the target flags to use the appropriate C++ standard library
  egg_set_stdlib(${target})

  # For Visual Studio on Windows, export debug symbols (PDB files) to lib directory
  if (EGG_GENERATE_PDB)
    # PDB files are only generated in Debug and RelWithDebInfo configurations, find out which one
    if (${CMAKE_BUILD_TYPE} STREQUAL "Debug")
      set(EGG_PDB_POSTFIX "-d")
    else ()
      set(EGG_PDB_POSTFIX "")
    endif ()

    if (BUILD_SHARED_LIBS AND NOT THIS_STATIC)
      # DLLs export debug symbols in the linker PDB (the compiler PDB is an intermediate file)
      set_target_properties(${target} PROPERTIES
              PDB_NAME "${target}${EGG_PDB_POSTFIX}"
              PDB_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/lib")
    else ()
      # Static libraries have no linker PDBs, thus the compiler PDBs are relevant
      set_target_properties(${target} PROPERTIES
              COMPILE_PDB_NAME "${target}-s${EGG_PDB_POSTFIX}"
              COMPILE_PDB_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/lib")
    endif ()
  endif ()

  # if using gcc >= 4.0 or clang >= 3.0 on a non-Windows platform, we must hide public symbols by default
  # (exported ones are explicitly marked)
  if (NOT EGG_OS_WINDOWS
          AND ((EGG_COMPILER_GCC AND NOT EGG_GCC_VERSION VERSION_LESS "4")
          OR (EGG_COMPILER_CLANG AND NOT EGG_CLANG_VERSION VERSION_LESS "3")))
    set_target_properties(${target} PROPERTIES COMPILE_FLAGS -fvisibility=hidden)
  endif ()

  # build frameworks or dylibs
  if (EGG_OS_MACOSX AND BUILD_SHARED_LIBS AND NOT THIS_STATIC)
    if (EGG_BUILD_FRAMEWORKS)
      # adapt target to build frameworks instead of dylibs
      set_target_properties(${target} PROPERTIES
              FRAMEWORK TRUE
              FRAMEWORK_VERSION ${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}
              MACOSX_FRAMEWORK_IDENTIFIER org.EGG-dev.${target}
              MACOSX_FRAMEWORK_SHORT_VERSION_STRING ${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}
              MACOSX_FRAMEWORK_BUNDLE_VERSION ${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH})
    endif ()

    # adapt install directory to allow distributing dylibs/frameworks in user's frameworks/application bundle
    # but only if cmake rpath options aren't set
    if (NOT CMAKE_SKIP_RPATH AND NOT CMAKE_SKIP_INSTALL_RPATH
            AND NOT CMAKE_INSTALL_RPATH
            AND NOT CMAKE_INSTALL_RPATH_USE_LINK_PATH
            AND NOT CMAKE_INSTALL_NAME_DIR)
      set_target_properties(${target} PROPERTIES INSTALL_NAME_DIR "@rpath")
      if (NOT CMAKE_SKIP_BUILD_RPATH)
        if (CMAKE_VERSION VERSION_LESS 3.9)
          set_target_properties(${target} PROPERTIES BUILD_WITH_INSTALL_RPATH TRUE)
        else ()
          set_target_properties(${target} PROPERTIES BUILD_WITH_INSTALL_NAME_DIR TRUE)
        endif ()
      endif ()
    endif ()
  endif ()

  # enable automatic reference counting on iOS
  if (EGG_OS_IOS)
    set_target_properties(${target} PROPERTIES XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC YES)
  endif ()

  # EGG-activity library is our bootstrap activity and must not depend on stlport_shared
  # (otherwise Android will fail to load it)
  if (EGG_OS_ANDROID)
    if (${target} MATCHES "EGG-activity")
      set_target_properties(${target} PROPERTIES COMPILE_FLAGS -fpermissive)
      set_target_properties(${target} PROPERTIES LINK_FLAGS "-landroid -llog")
      set(CMAKE_CXX_CREATE_SHARED_LIBRARY ${CMAKE_CXX_CREATE_SHARED_LIBRARY_WITHOUT_STL})
    else ()
      set(CMAKE_CXX_CREATE_SHARED_LIBRARY ${CMAKE_CXX_CREATE_SHARED_LIBRARY_WITH_STL})
    endif ()
  endif ()

  # add the install rule
  install(TARGETS ${target} EXPORT EGGConfigExport
          RUNTIME DESTINATION bin COMPONENT bin
          LIBRARY DESTINATION lib${LIB_SUFFIX} COMPONENT bin
          ARCHIVE DESTINATION lib${LIB_SUFFIX} COMPONENT devel
          FRAMEWORK DESTINATION "." COMPONENT bin)

  # add <project>/include as public include directory
  target_include_directories(${target}
          PUBLIC $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include>
          PRIVATE ${PROJECT_SOURCE_DIR}/src)

  if (EGG_BUILD_FRAMEWORKS)
    target_include_directories(${target} INTERFACE $<INSTALL_INTERFACE:EGG.framework>)
  else ()
    target_include_directories(${target} INTERFACE $<INSTALL_INTERFACE:include>)
  endif ()

  # define EGG_STATIC if the build type is not set to 'shared'
  if (NOT BUILD_SHARED_LIBS)
    target_compile_definitions(${target} PUBLIC "EGG_STATIC")
  endif ()

endmacro()


# Find the requested package and make an INTERFACE library from it
# Usage: egg_find_package(wanted_target_name
#                          [INCLUDE "OPENGL_INCLUDE_DIR"]
#                          [LINK "OPENGL_gl_LIBRARY"])
function(egg_find_package)
  set(CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake/Modules/")
  list(GET ARGN 0 target)
  list(REMOVE_AT ARGN 0)

  if (TARGET ${target})
    message(FATAL_ERROR "Target '${target}' is already defined")
  endif ()

  cmake_parse_arguments(THIS "" "" "INCLUDE;LINK" ${ARGN})
  if (THIS_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR "Unknown arguments when calling EGG_import_library: ${THIS_UNPARSED_ARGUMENTS}")
  endif ()

  if (EGG_OS_IOS)
    find_host_package(${target} REQUIRED)
  else ()
    find_package(${target} REQUIRED)
  endif ()

  add_library(${target} INTERFACE)

  if (THIS_INCLUDE)
    foreach (include_dir IN LISTS "${THIS_INCLUDE}")
      if (NOT include_dir)
        message(FATAL_ERROR "No path given for include dir ${THIS_INCLUDE}")
      endif ()
      target_include_directories(${target} INTERFACE "$<BUILD_INTERFACE:${include_dir}>")
    endforeach ()
  endif ()

  if (THIS_LINK)
    foreach (link_item IN LISTS ${THIS_LINK})
      if (NOT link_item)
        message(FATAL_ERROR "Missing item in ${THIS_LINK}")
      endif ()
      target_link_libraries(${target} INTERFACE "$<BUILD_INTERFACE:${link_item}>")
    endforeach ()
  endif ()
  install(TARGETS ${target} EXPORT EGGConfigExport)
endfunction()

# Generate a EGGConfig.cmake file (and associated files) from the targets registered against
# the EXPORT name "EGGConfigExport" (EXPORT parameter of install(TARGETS))
function(egg_export_targets)
  # CMAKE_CURRENT_LIST_DIR or CMAKE_CURRENT_SOURCE_DIR not usable for files that are to be included like this one
  set(CURRENT_DIR "${PROJECT_SOURCE_DIR}/cmake")

  include(CMakePackageConfigHelpers)
  write_basic_package_version_file("${CMAKE_CURRENT_BINARY_DIR}/EGGConfigVersion.cmake"
          VERSION ${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}
          COMPATIBILITY SameMajorVersion)

  if (BUILD_SHARED_LIBS)
    set(config_name "Shared")
  else ()
    set(config_name "Static")
  endif ()
  set(targets_config_filename "EGG${config_name}Targets.cmake")

  export(EXPORT EGGConfigExport
          FILE "${CMAKE_CURRENT_BINARY_DIR}/${targets_config_filename}")

  set(config_package_location lib${LIB_SUFFIX}/cmake/EGG)

  configure_package_config_file("${CURRENT_DIR}/EGGConfig.cmake.in"
          "${CMAKE_CURRENT_BINARY_DIR}/EGGConfig.cmake"
          INSTALL_DESTINATION "${config_package_location}")


  install(EXPORT EGGConfigExport
          FILE ${targets_config_filename}
          DESTINATION ${config_package_location})

  install(FILES "${CMAKE_CURRENT_BINARY_DIR}/EGGConfig.cmake"
          "${CMAKE_CURRENT_BINARY_DIR}/EGGConfigVersion.cmake"
          DESTINATION ${config_package_location}
          COMPONENT devel)
endfunction()
