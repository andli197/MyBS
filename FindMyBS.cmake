cmake_minimum_required(VERSION 2.8)
project(MyBS)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED YES)
set(CMAKE_CXX_FLAGS "-g -Wall")

option(MyBS_DEBUG_MESSAGE "Display debug messages" OFF)
# option(MyBS_RUN_TESTS_IN_BUILD_STEP "Run the test suite last in the build step" ON)

macro(GenerateProtobuf)
  find_package(Protobuf REQUIRED)

  if (PROTOBUF_FOUND)
    message("protobuf found")
  else()
    message(FATAL_ERROR "Unable to locate protobuf on system")
  endif()

  file(GLOB proto_files ${CMAKE_CURRENT_SOURCE_DIR}/resource/*.proto)
  if (EXISTS ${proto_files})
    PROTOBUF_GENERATE_CPP(PROTO_SOURCES PROTO_HEADERS ${proto_files})
    SET_SOURCE_FILES_PROPERTIES(${PROTO_SOURCES} ${PROTO_HEADERS} PROPERTIES GENERATED TRUE)

    if (MyBS_DEBUG_MESSAGE)
       message("PROTO_SOURCES=${PROTO_SOURCES}")
       message("PROTO_HEADERS=${PROTO_HEADERS}")
    endif()
  endif()
endmacro()

function(fetch_googletest _download_module_path _download_root)
  set(GOOGLETEST_DOWNLOAD_ROOT ${_download_root})
  configure_file(
    ${_download_module_path}/googletest-download.cmake
    ${_download_root}/CMakeLists.txt
    @ONLY
    )
  unset(GOOGLETEST_DOWNLOAD_ROOT)

  execute_process(
    COMMAND
    "${CMAKE_COMMAND}" -G "${CMAKE_GENERATOR}" .
    WORKING_DIRECTORY
    ${_download_root}
    )
  execute_process(
    COMMAND
    "${CMAKE_COMMAND}" --build .
    WORKING_DIRECTORY
    ${_download_root}
    )

  # adds the targers: gtest, gtest_main, gmock, gmock_main
  add_subdirectory(
    ${_download_root}/googletest-src
    ${_download_root}/googletest-build
    )
endfunction()

if ("$ENV{MyBSStatus}" STREQUAL "")
  fetch_googletest(
    ${LindbladBuildPath}
    ${PROJECT_BINARY_DIR}/googletest)
  
  enable_testing()
  set(ENV{MyBSStatus} "Initialized")
else()
  message(STATUS "Build system already initialized!")
endif()

macro(bs_add)
  set(options )
  set(oneValueArgs NAME)
  set(multiValueArgs SOURCES LIBS)
  cmake_parse_arguments(MyBS "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  GenerateProtobuf()
  set(MyBS_LIBS ${BS_ADD_LIBS} ${PROTOBUF_LIBRARIES})
  set(MyBS_INCLUDE ${PROTOBUF_INCLUDE_DIRS} ${CMAKE_CURRENT_LIST_DIR}/include)
  set(MyBS_SOURCES ${BS_ADD_SOURCES} ${PROTO_SOURCES})

  if (MyBS_DEBUG_MESSAGE)
     message("NAME=" ${BS_ADD_NAME})
     message("SOURCES=" ${BS_ADD_SOURCES})
     message("LIBS=" ${BS_ADD_LIBS})
  endif()
  
  add_library(
    ${BS_ADD_NAME}
    "")
  target_sources(
    ${BS_ADD_NAME}
    PRIVATE
    ${BS_ADD_SOURCES}
    PUBLIC
    ${BS_ADD_INCLUDE})
  target_include_directories(
    ${BS_ADD_NAME}
    PUBLIC
    ${CMAKE_CURRENT_LIST_DIR}/include
    ${PROTOBUF_INCLUDE_DIRS}
    ${CMAKE_CURRENT_BINARY_DIR})
  target_link_libraries(
    ${BS_ADD_NAME}
    PUBLIC
    ${PROTOBUF_LIBRARIES}
    ${BS_ADD_LIBS})

  bs_add_tests(
    LIBS
    ${BS_ADD_NAME}
    ${BS_ADD_LIBS})
endmacro()

macro(bs_add_tests)
  set(options )
  set(oneValeArgs )
  set(multiValueArgs LIBS)
  cmake_parse_arguments(BS_ADD_TESTS "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  file(GLOB SOURCES ${CMAKE_CURRENT_LIST_DIR}/test/test.*.cpp)
  foreach(test_file ${SOURCES})
    get_filename_component(TEST_FILE_NAME ${test_file} NAME)
    string(REPLACE ".cpp" "" TEST_NAME ${TEST_FILE_NAME})
    BS_TEST(NAME ${TEST_NAME} FILES ${test_file} LIBS ${BS_ADD_TESTS_LIBS})
  endforeach(test_file)
endmacro()

macro(bs_test)
  set(options )
  set(oneValueArgs NAME FILES)
  set(multiValueArgs LIBS)
  cmake_parse_arguments(BS_TEST "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  add_executable(${BS_TEST_NAME} ${BS_TEST_FILES})
  if (${PROTO_HEADERS})
     target_include_directories(${BS_TEST_NAME} ${PROTO_HEADERS})
  endif()
  target_link_libraries(${BS_TEST_NAME} gtest_main gmock ${BS_TEST_LIBS})
  add_test(NAME "${BS_TEST_NAME}" COMMAND "${CMAKE_BUILD_DIR}/${BS_TEST_NAME}")
endmacro()
