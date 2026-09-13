#include <QGuiApplication>
#include <QQuickView>
#include <QQmlContext>
#include <QQmlEngine>
#include <QScreen>
#include <QDir>
#include <LayerShellQt/Window>

#include "quickframe_bridge.h"

int main(int argc, char *argv[]) {
    // Ensure Wayland platform is used on Hyprland
    if (!qEnvironmentVariableIsSet("QT_QPA_PLATFORM")) {
        qputenv("QT_QPA_PLATFORM", "wayland");
    }

    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("HyprQuickFrame"));
    app.setOrganizationName(QStringLiteral("MUHSIN-M-P"));
    app.setOrganizationDomain(QStringLiteral("github.com/MUHSIN-M-P"));

    QuickFrameBridge bridge;
    bridge.initTargetScreen();

    // Find the targeted QScreen
    QScreen* targetScreen = nullptr;
    for (auto* screen : QGuiApplication::screens()) {
        if (screen->name() == bridge.monitorName()) {
            targetScreen = screen;
            break;
        }
    }
    if (!targetScreen) {
        targetScreen = QGuiApplication::primaryScreen();
    }

    // Capture screen right away before overlay renders
    bridge.captureScreen();

    // Create LayerShell QQuickView
    QQuickView view;
    view.setColor(Qt::transparent);

    auto* lWindow = LayerShellQt::Window::get(&view);
    lWindow->setScope(QStringLiteral("hyprquickframe"));
    lWindow->setLayer(LayerShellQt::Window::LayerOverlay);
    lWindow->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityOnDemand);
    lWindow->setExclusiveZone(-1);
    lWindow->setAnchors({LayerShellQt::Window::AnchorTop, LayerShellQt::Window::AnchorBottom,
                        LayerShellQt::Window::AnchorLeft, LayerShellQt::Window::AnchorRight});
    if (targetScreen) {
        lWindow->setScreen(targetScreen);
        view.setScreen(targetScreen);
    }

    // Expose native bridge and screen context to QML
    view.engine()->rootContext()->setContextProperty(QStringLiteral("bridge"), &bridge);

    view.setResizeMode(QQuickView::SizeRootObjectToView);
    view.setSource(QUrl(QStringLiteral("qrc:/shell.qml")));

    view.show();

    return app.exec();
}
