
set(proj python)

# Set dependency list
set(${proj}_DEPENDENCIES zlib)
if(NOT ${CMAKE_PROJECT_NAME}_USE_SYSTEM_python)
  list(APPEND ${proj}_DEPENDENCIES CTKAPPLAUNCHER)
endif()
if(Slicer_USE_PYTHONQT_WITH_TCL)
  if(WIN32)
    list(APPEND ${proj}_DEPENDENCIES tcl)
  else()
    list(APPEND ${proj}_DEPENDENCIES tcl tk)
  endif()
endif()
if(PYTHON_ENABLE_SSL)
  list(APPEND ${proj}_DEPENDENCIES OpenSSL)
endif()

# Include dependent projects if any
ExternalProject_Include_Dependencies(${proj} PROJECT_VAR proj DEPENDS_VAR ${proj}_DEPENDENCIES)

if(${CMAKE_PROJECT_NAME}_USE_SYSTEM_${proj})
  unset(PYTHON_INCLUDE_DIR CACHE)
  unset(PYTHON_LIBRARY CACHE)
  unset(PYTHON_EXECUTABLE CACHE)
  find_package(PythonLibs REQUIRED)
  find_package(PythonInterp REQUIRED)
  set(PYTHON_INCLUDE_DIR ${PYTHON_INCLUDE_DIRS})
  set(PYTHON_LIBRARY ${PYTHON_LIBRARIES})
  set(PYTHON_EXECUTABLE ${PYTHON_EXECUTABLE})
endif()

if((NOT DEFINED PYTHON_INCLUDE_DIRS
   OR NOT DEFINED PYTHON_LIBRARIES
   OR NOT DEFINED PYTHON_EXECUTABLE) AND NOT ${CMAKE_PROJECT_NAME}_USE_SYSTEM_${proj})

  set(python_SOURCE_DIR "${CMAKE_BINARY_DIR}/Python-2.7.3")

  set(EXTERNAL_PROJECT_OPTIONAL_ARGS)
  if(MSVC)
    list(APPEND EXTERNAL_PROJECT_OPTIONAL_ARGS
      PATCH_COMMAND ${CMAKE_COMMAND}
        -DMSVC_VERSION:STRING=${MSVC_VERSION}
        -DPYTHON_SRC_DIR:PATH=${python_SOURCE_DIR}
        -P ${CMAKE_CURRENT_LIST_DIR}/${proj}_patch.cmake
      )
  endif()

  ExternalProject_Add(python-source
    URL "http://www.python.org/ftp/python/2.7.3/Python-2.7.3.tgz"
    URL_MD5 "2cf641732ac23b18d139be077bd906cd"
    DOWNLOAD_DIR ${CMAKE_CURRENT_BINARY_DIR}
    SOURCE_DIR ${python_SOURCE_DIR}
    ${EXTERNAL_PROJECT_OPTIONAL_ARGS}
    CONFIGURE_COMMAND ""
    BUILD_COMMAND ""
    INSTALL_COMMAND ""
    )

  if(NOT DEFINED git_protocol)
    set(git_protocol "git")
  endif()

  set(EXTERNAL_PROJECT_OPTIONAL_CMAKE_ARGS CMAKE_ARGS)

  if(Slicer_USE_PYTHONQT_WITH_TCL)
    list(APPEND EXTERNAL_PROJECT_OPTIONAL_CMAKE_ARGS
      -DTCL_LIBRARY:FILEPATH=${TCL_LIBRARY}
      -DTCL_INCLUDE_PATH:PATH=${CMAKE_CURRENT_BINARY_DIR}/tcl-build/include
      -DTK_LIBRARY:FILEPATH=${TK_LIBRARY}
      -DTK_INCLUDE_PATH:PATH=${CMAKE_CURRENT_BINARY_DIR}/tcl-build/include
      )
  endif()

  if(PYTHON_ENABLE_SSL)
    list(APPEND EXTERNAL_PROJECT_OPTIONAL_CMAKE_ARGS
      -DOPENSSL_INCLUDE_DIR:PATH=${OPENSSL_INCLUDE_DIR}
      -DOPENSSL_LIBRARIES:STRING=${OPENSSL_LIBRARIES}
      )
  endif()

  set(EXTERNAL_PROJECT_OPTIONAL_CMAKE_CACHE_ARGS)

  # Force Python build to "Release".
  if(CMAKE_CONFIGURATION_TYPES)
    set(SAVED_CMAKE_CFG_INTDIR ${CMAKE_CFG_INTDIR})
    set(CMAKE_CFG_INTDIR "Release")
  else()
    list(APPEND EXTERNAL_PROJECT_OPTIONAL_CMAKE_CACHE_ARGS
      -DCMAKE_BUILD_TYPE:STRING=Release)
  endif()

  ExternalProject_Add(${proj}
    ${${proj}_EP_ARGS}
    GIT_REPOSITORY "${git_protocol}://github.com/davidsansome/python-cmake-buildsystem.git"
    GIT_TAG "82e14946e3640be603601623d9bd282b992f2d7c"
    SOURCE_DIR ${CMAKE_BINARY_DIR}/${proj}
    BINARY_DIR ${proj}-build
    CMAKE_CACHE_ARGS
      -DCMAKE_CXX_COMPILER:FILEPATH=${CMAKE_CXX_COMPILER}
      #-DCMAKE_CXX_FLAGS:STRING=${ep_common_cxx_flags} # Not used
      -DCMAKE_C_COMPILER:FILEPATH=${CMAKE_C_COMPILER}
      -DCMAKE_C_FLAGS:STRING=${ep_common_c_flags}
      -DCMAKE_INSTALL_PREFIX:PATH=${CMAKE_BINARY_DIR}/${proj}-install
      #-DBUILD_TESTING:BOOL=OFF
      -DBUILD_SHARED:BOOL=ON
      -DBUILD_STATIC:BOOL=OFF
      -DUSE_SYSTEM_LIBRARIES:BOOL=OFF
      -DZLIB_INCLUDE_DIR:PATH=${ZLIB_INCLUDE_DIR}
      -DZLIB_LIBRARY:FILEPATH=${ZLIB_LIBRARY}
      -DENABLE_TKINTER:BOOL=${Slicer_USE_PYTHONQT_WITH_TCL}
      -DENABLE_SSL:BOOL=${PYTHON_ENABLE_SSL}
      ${EXTERNAL_PROJECT_OPTIONAL_CMAKE_CACHE_ARGS}
      ${EXTERNAL_PROJECT_OPTIONAL_CMAKE_ARGS}
    DEPENDS
      python-source ${${proj}_DEPENDENCIES}
    )
  set(python_DIR ${CMAKE_BINARY_DIR}/${proj}-install)

  if(UNIX)
    set(python_IMPORT_SUFFIX so)
    if(APPLE)
      set(python_IMPORT_SUFFIX dylib)
    endif()
    set(slicer_PYTHON_SHARED_LIBRARY_DIR ${python_DIR}/lib)
    set(PYTHON_INCLUDE_DIR ${python_DIR}/include/python2.7)
    set(PYTHON_LIBRARY ${python_DIR}/lib/libpython2.7.${python_IMPORT_SUFFIX})
    set(PYTHON_EXECUTABLE ${python_DIR}/bin/customPython)
    set(slicer_PYTHON_REAL_EXECUTABLE ${python_DIR}/bin/python)
  elseif(WIN32)
    set(slicer_PYTHON_SHARED_LIBRARY_DIR ${python_DIR}/bin)
    set(PYTHON_INCLUDE_DIR ${python_DIR}/include)
    set(PYTHON_LIBRARY ${python_DIR}/libs/python27.lib)
    set(PYTHON_EXECUTABLE ${python_DIR}/bin/customPython.exe)
    set(slicer_PYTHON_REAL_EXECUTABLE ${python_DIR}/bin/python.exe)
  else()
    message(FATAL_ERROR "Unknown system !")
  endif()

  if(NOT ${CMAKE_PROJECT_NAME}_USE_SYSTEM_python)

    # Configure python launcher
    configure_file(
      SuperBuild/python_customPython_configure.cmake.in
      ${CMAKE_CURRENT_BINARY_DIR}/python_customPython_configure.cmake
      @ONLY)
    set(python_customPython_configure_args)

    if(PYTHON_ENABLE_SSL)
      set(python_customPython_configure_args -DOPENSSL_EXPORT_LIBRARY_DIR:PATH=${OPENSSL_EXPORT_LIBRARY_DIR})
    endif()

    ExternalProject_Add_Step(${proj} python_customPython_configure
      COMMAND ${CMAKE_COMMAND} ${python_customPython_configure_args}
        -P ${CMAKE_CURRENT_BINARY_DIR}/python_customPython_configure.cmake
      DEPENDEES install
      )

  endif()

  if(CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_CFG_INTDIR ${SAVED_CMAKE_CFG_INTDIR}) # Restore CMAKE_CFG_INTDIR
  endif()

else()
  ExternalProject_Add_Empty(${proj} DEPENDS ${${proj}_DEPENDENCIES})
endif()

mark_as_superbuild(
  VARS
    PYTHON_EXECUTABLE:FILEPATH
    PYTHON_INCLUDE_DIR:PATH
    PYTHON_LIBRARY:FILEPATH
  LABELS "FIND_PACKAGE"
  )

ExternalProject_Message(${proj} "PYTHON_EXECUTABLE:${PYTHON_EXECUTABLE}")
ExternalProject_Message(${proj} "PYTHON_INCLUDE_DIR:${PYTHON_INCLUDE_DIR}")
ExternalProject_Message(${proj} "PYTHON_LIBRARY:${PYTHON_LIBRARY}")

if(WIN32)
  set(PYTHON_DEBUG_LIBRARY ${PYTHON_LIBRARY})
  mark_as_superbuild(VARS PYTHON_DEBUG_LIBRARY LABELS "FIND_PACKAGE")
  ExternalProject_Message(${proj} "PYTHON_DEBUG_LIBRARY:${PYTHON_DEBUG_LIBRARY}")
endif()
