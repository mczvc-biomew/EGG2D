# include the EGG specific macros
include(${PROJECT_SOURCE_DIR}/cmake/Macros.cmake)

set(egg_glad egg2d.c
        glad.c)

set(LIBRARY_OUTPUT_PATH "${PROJECT_BINARY_DIR}/lib")

configure_file(glow_image.pcm ${CMAKE_CURRENT_BINARY_DIR}/glow_image.pcm COPYONLY)

if (WIN32)
else ()
  find_package(OpenGL REQUIRED COMPONENTS OpenGL)
  find_package(SDL2 REQUIRED)
  find_package(SDL2_image REQUIRED)

  add_library(EGG2D STATIC ${egg_glad})

  include_directories(${SDL_IMAGE_INCLUDE_DIR} ${OPENGL_INCLUDE_DIRS})
  target_link_libraries(EGG2D ${SDL2_LIBRARIES} SDL2_image ${OPENGL_LIBRARIES})
endif ()

install(TARGETS EGG2D EXPORT EGGConfigExport
        LIBRARY DESTINATION lib${LIB_SUFFIX} COMPONENT bin
        ARCHIVE DESTINATION lib${LIB_SUFFIX} COMPONENT devel
        FRAMEWORK DESTINATION "." COMPONENT bin)
