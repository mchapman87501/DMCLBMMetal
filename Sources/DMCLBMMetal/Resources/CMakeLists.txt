function(compile_metal BASE_NAME)
    add_custom_command(
        OUTPUT ${CMAKE_CURRENT_SOURCE_DIR}/${BASE_NAME}.air
        COMMAND
        xcrun -sdk macosx metal -o ${CMAKE_CURRENT_SOURCE_DIR}/${BASE_NAME}.air
        -c ${CMAKE_CURRENT_SOURCE_DIR}/${BASE_NAME}.metal
    )
    add_custom_target(${BASE_NAME}.air DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${BASE_NAME}.air)
endfunction()

set(METAL_MODULES compute render)
list(TRANSFORM METAL_MODULES APPEND .air OUTPUT_VARIABLE METAL_TARGETS)
list(TRANSFORM METAL_TARGETS PREPEND ${CMAKE_CURRENT_SOURCE_DIR}/ OUTPUT_VARIABLE METAL_OBJECTS)

foreach(metal_mod IN LISTS METAL_MODULES)
    compile_metal(${metal_mod})
endforeach()

add_custom_command(
    OUTPUT ${CMAKE_CURRENT_SOURCE_DIR}/default.metallib
    COMMAND
        xcrun -sdk macosx metallib -o ${CMAKE_CURRENT_SOURCE_DIR}/default.metallib
            ${METAL_OBJECTS}
    DEPENDS ${METAL_TARGETS}
)

add_custom_target(metallib
    DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/default.metallib
)