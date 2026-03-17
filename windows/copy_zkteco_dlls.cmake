# Copia las DLLs de ZKTeco al directorio de salida junto al ejecutable
file(GLOB ZKTECO_DLLS "${CMAKE_SOURCE_DIR}/dll/*.dll")
install(FILES ${ZKTECO_DLLS} DESTINATION "${CMAKE_INSTALL_PREFIX}" COMPONENT Runtime)
