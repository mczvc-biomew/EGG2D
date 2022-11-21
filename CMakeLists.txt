cmake_minimum_required(VERSION 3.16.3)

macro(egg_set_option var default type docstring)
    if(NOT DEFINED ${var})
        set(${var} ${default})
    endif()
    set(${var} ${${var}} CACHE ${type} ${docstring} FORCE)
endmacro()

project(Egg2D)

# include the configuration file
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")
include(Config)
include(Macros)

# add the EGG header path
include_directories(include)

egg_set_option(CMAKE_BUILD_TYPE Release STRING "Choose the type of build (Debug or Release)")

message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")

# setup version numbers
set(VERSION_MAJOR 0)
set(VERSION_MINOR 1)
set(VERSION_PATCH 1)


if(NOT (EGG_OS_IOS OR EGG_OS_ANDROID))
    egg_set_option(BUILD_SHARED_LIBS FALSE BOOL "TRUE to build EGG as shared library, FALSE to build it as static library")
else()
    if(EGG_OS_IOS)
        set(BUILD_SHARED_LIBS FALSE)
    elseif(EGG_OS_ANDROID)
        set(BUILD_SHARED_LIBS TRUE)
    endif()
endif()

if (EGG_OS_WINDOWS OR EGG_OS_IOS)
    set(DEFAULT_INSTALL_MISC_DIR .)
elseif(EGG_OS_LINUX)
    set(DEFAULT_INSTALL_MISC_DIR share/EGG)
elseif(EGG_OS_MACOSX)
	set(DEFAULT_INSTALL_MISC_DIR /usr/local/share/EGG)
elseif(EGG_OS_ANDROID)
    set(DEFAULT_ISNTALL_MISC_DIR ${CMAKE_ANDROID_NDK}/sources/third_party/egg)
endif()

egg_set_option(EGG_MISC_INSTALL_PREFIX "${DEFAULT_INSTALL_MISC_DIR}" PATH "Prefix installation path for miscellaneous files")

set_property(GLOBAL PROPERTY USE_FOLDERS ON)
set_property(GLOBAL PROPERTY PREDEFINED_TARGETS_FOLDER "CMake")


if (OPENGL_ES)
  add_definitions(-DEGG_GLES2 -DGLES2)
endif()


add_subdirectory(src/EGG)


# on Linux, install pkg-config files by default
set(EGG_INSTALL_PKGCONFIG_DEFAULT FALSE)

if(EGG_OS_LINUX)
    set(EGG_INSTALL_PKGCONFIG_DEFAULT TRUE)
endif()

egg_set_option(EGG_INSTALL_PKGCONFIG_FILES ${EGG_INSTALL_PKGCONFIG_DEFAULT} BOOL "TRUE to automatically install pkg-config files so other projects can find EGG")

if(EGG_INSTALL_PKGCONFIG_FILES)
    egg_set_option(EGG_PKGCONFIG_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}/${EGG_PKGCONFIG_DIR}" PATH "Install directory for EGG's pkg-config .pc files")

    CONFIGURE_FILE(
        "tools/pkg-config/egg-all.pc.in"
        "tools/pkg-config/egg-all.pc"
        @ONLY)
    INSTALL(FILES "${CMAKE_CURRENT_BINARY_DIR}/tools/pkg-config/egg-all.pc"
            DESTINATION "${EGG_PKGCONFIG_INSTALL_PREFIX}")
endif()

# setup the install rules
if(NOT EGG_BUILD_FRAMEWORKS)
    install(DIRECTORY include
            DESTINATION .
            COMPONENT devel
            FILES_MATCHING PATTERN "*.hpp" PATTERN "*.h" PATTERN "*.inl")
    if(BUILD_STATIC_LIBS)
        set(EGG_STATIC_LIBRARIES TRUE)
    	install(DIRECTORY lib
    			DESTINATION .
    			COMPONENT devel)
	endif()
else()
    # find only "root" headers
    file(GLOB EGG_HEADERS RELATIVE ${PROJECT_SOURCE_DIR} "include/EGG/*")
	
    # if fact we have too fool cmake to copy all the headers in subdirectories
    # to do that we have to add the "root" headers to the PUBLIC_HEADER
    # then we can run a post script to copy the remaining headers
	
	# we need a dummy file in order to compile the framework
	add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/dummy.c
                       COMMAND touch ${CMAKE_CURRENT_BINARY_DIR}/dummy.c)
    set(EGG_SOURCES ${EGG_HEADERS})
    list(APPEND EGG_SOURCES ${CMAKE_CURRENT_BINARY_DIR}/dummy.c)
    
    # create EGG.framework
    add_library(EGG ${EGG_SOURCES})
    
    # set the target flags to use the appropriate C++ standard library
    #egg_set_stdlib(EGG)
    
    set_target_properties(EGG PROPERTIES
                          FRAMEWORK TRUE
                          FRAMEWORK_VERSION ${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}
                          PUBLIC_HEADER "${EGG_HEADERS}")
    
    # add the non-optional EGG headers
    add_custom_command(TARGET EGG POST_BUILD COMMAND cp -r
                       ${PROJECT_SOURCE_DIR}/include/EGG/egg2d.h
                       ${PROJECT_SOURCE_DIR}/include/EGG/glad/glad.h
                       $<TARGET_FILE_DIR:EGG>/)
    
    # adapt install directory to allow distributing dylibs/frameworks in user's framework/application bundle
    # NOTE: it's not required to link against EGG.framework
    set_target_properties(EGG PROPERTIES INSTALL_NAME_DIR "@rpath")
    if(NOT CMAKE_SKIP_BUILD_RPATH)
        if (CMAKE_VERSION VERSION_LESS 3.9)
            set_target_properties(${target} PROPERTIES BUILD_WITH_INSTALL_RPATH TRUE)
        else()
            set_target_properties(${target} PROPERTIES BUILD_WITH_INSTALL_NAME_DIR TRUE)
        endif()
    endif()
    
    # install rule
    install(TARGETS EGG 
            FRAMEWORK DESTINATION "."
            COMPONENT devel)
    
endif()

install(FILES license.md DESTINATION ${EGG_MISC_INSTALL_PREFIX})
install(FILES README.md DESTINATION ${EGG_MISC_INSTALL_PREFIX})


set(CMAKE_CXX_FLAGS "-Wall -Wextra -std=c++11")
set(CMAKE_CXX_FLAGS_DEBUG "-g")
set(CMAKE_CXX_FLAGS_RELEASE "-O3")


egg_export_targets()
   
