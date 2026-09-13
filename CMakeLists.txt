cmake_minimum_required(VERSION 3.20)
project(hyprquickframe LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick)
find_package(LayerShellQt REQUIRED)

add_executable(hyprquickframe
    src/main.cpp
    src/quickframe_bridge.h
    src/quickframe_bridge.cpp
    resources.qrc
)

target_link_libraries(hyprquickframe PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    LayerShellQt::Interface
)

include(GNUInstallDirs)
install(TARGETS hyprquickframe DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES src/detect_boxes.py DESTINATION ${CMAKE_INSTALL_DATADIR}/hyprquickframe
    PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
