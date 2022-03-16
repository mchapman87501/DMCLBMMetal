
project(DMCLBMMetal)

cmake_minimum_required(VERSION 3.22)

set(CXX_STANDARD_REQUIRED ON)
set(CXX_STANDARD 17)
set(CXX_EXTENSIONS ON)

add_subdirectory(Sources/DMCLBMMetal/Resources)

STRING(TOLOWER ${CMAKE_BUILD_TYPE} SWIFT_BUILD_CONFIG)

add_custom_command(
    OUTPUT ${CMAKE_SOURCE_DIR}/.build/
    COMMAND swift build -c ${SWIFT_BUILD_CONFIG}
    DEPENDS metallib
)

add_custom_target(DMCLBMMetal
DEPENDS ${CMAKE_SOURCE_DIR}/.build)
