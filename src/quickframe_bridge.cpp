#include "quickframe_bridge.h"

#include <QGuiApplication>
#include <QScreen>
#include <QDir>
#include <QFile>
#include <QTemporaryFile>
#include <QDateTime>
#include <QStandardPaths>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDebug>

QuickFrameBridge::QuickFrameBridge(QObject* parent) : QObject(parent) {}

QuickFrameBridge::~QuickFrameBridge() {
    deleteTemp();
    if (m_detectProcess) {
        m_detectProcess->kill();
        m_detectProcess->deleteLater();
        m_detectProcess = nullptr;
    }
}

void QuickFrameBridge::initTargetScreen() {
    // Attempt to query focused monitor via hyprctl
    QProcess p;
    p.start(QStringLiteral("hyprctl"), {QStringLiteral("monitors"), QStringLiteral("-j")});
    if (p.waitForFinished(1000)) {
        auto doc = QJsonDocument::fromJson(p.readAllStandardOutput());
        if (doc.isArray()) {
            for (const auto& item : doc.array()) {
                auto obj = item.toObject();
                if (obj.value(QStringLiteral("focused")).toBool()) {
                    m_monitorName = obj.value(QStringLiteral("name")).toString();
                    m_monitorX = obj.value(QStringLiteral("x")).toInt();
                    m_monitorY = obj.value(QStringLiteral("y")).toInt();
                    m_screenWidth = obj.value(QStringLiteral("width")).toInt();
                    m_screenHeight = obj.value(QStringLiteral("height")).toInt();
                    m_monitorScale = obj.value(QStringLiteral("scale")).toDouble(1.0);
                    break;
                }
            }
        }
    }

    // Fallback if hyprctl not available or didn't find focused monitor
    if (m_monitorName.isEmpty()) {
        auto* screen = QGuiApplication::primaryScreen();
        if (screen) {
            m_monitorName = screen->name();
            m_monitorX = screen->geometry().x();
            m_monitorY = screen->geometry().y();
            m_screenWidth = screen->geometry().width();
            m_screenHeight = screen->geometry().height();
            m_monitorScale = screen->devicePixelRatio();
        }
    }

    emit monitorChanged();
    loadWindows();
}

void QuickFrameBridge::captureScreen() {
    QTemporaryFile tempFile(QDir::tempPath() + QStringLiteral("/hyprquickframe-XXXXXX.png"));
    tempFile.setAutoRemove(false);
    if (!tempFile.open()) {
        qWarning() << "Failed to create temporary screenshot file";
        return;
    }
    m_tempPath = tempFile.fileName();
    tempFile.close();

    // grim -g "<x>,<y> <w>x<h>" <tempPath>
    QString geom = QStringLiteral("%1,%2 %3x%4")
        .arg(m_monitorX).arg(m_monitorY)
        .arg(m_screenWidth).arg(m_screenHeight);

    QProcess grim;
    grim.start(QStringLiteral("grim"), {QStringLiteral("-g"), geom, m_tempPath});
    grim.waitForFinished(3000);

    emit tempPathChanged();
    emit captureFinished();

    startDetection();
}

void QuickFrameBridge::loadWindows() {
    QProcess p;
    p.start(QStringLiteral("hyprctl"), {QStringLiteral("clients"), QStringLiteral("-j")});
    if (p.waitForFinished(1000)) {
        auto doc = QJsonDocument::fromJson(p.readAllStandardOutput());
        if (doc.isArray()) {
            QVariantList list;
            for (const auto& item : doc.array()) {
                auto obj = item.toObject();
                QVariantMap win;
                win[QStringLiteral("title")] = obj.value(QStringLiteral("title")).toString();
                win[QStringLiteral("class")] = obj.value(QStringLiteral("class")).toString();

                QVariantMap ipcObj;
                ipcObj[QStringLiteral("x")] = m_monitorX;
                ipcObj[QStringLiteral("y")] = m_monitorY;

                QVariantList atList;
                auto atArr = obj.value(QStringLiteral("at")).toArray();
                atList.append(atArr.at(0).toInt());
                atList.append(atArr.at(1).toInt());
                ipcObj[QStringLiteral("at")] = atList;

                QVariantList sizeList;
                auto sizeArr = obj.value(QStringLiteral("size")).toArray();
                sizeList.append(sizeArr.at(0).toInt());
                sizeList.append(sizeArr.at(1).toInt());
                ipcObj[QStringLiteral("size")] = sizeList;

                win[QStringLiteral("lastIpcObject")] = ipcObj;
                list.append(win);
            }
            m_windows = list;
            emit windowsChanged();
        }
    }
}

void QuickFrameBridge::startDetection() {
    if (m_tempPath.isEmpty()) return;

    QString scriptPath;
    QString appDir = QCoreApplication::applicationDirPath();
    QString localPath = appDir + QStringLiteral("/src/detect_boxes.py");
    QString rootPath = appDir + QStringLiteral("/detect_boxes.py");
    QString userPath = QDir::homePath() + QStringLiteral("/.config/quickshell/HyprQuickFrame/src/detect_boxes.py");
    QString systemPath = QStringLiteral("/usr/local/share/hyprquickframe/detect_boxes.py");

    if (QFile::exists(localPath)) scriptPath = localPath;
    else if (QFile::exists(rootPath)) scriptPath = rootPath;
    else if (QFile::exists(userPath)) scriptPath = userPath;
    else if (QFile::exists(systemPath)) scriptPath = systemPath;
    else scriptPath = QStringLiteral("detect_boxes.py");

    if (m_detectProcess) {
        m_detectProcess->kill();
        m_detectProcess->deleteLater();
    }

    m_detectProcess = new QProcess(this);
    connect(m_detectProcess, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this](int exitCode, QProcess::ExitStatus) {
        if (exitCode == 0 && m_detectProcess) {
            auto out = m_detectProcess->readAllStandardOutput();
            auto doc = QJsonDocument::fromJson(out);
            if (doc.isArray()) {
                m_detectedBoxes = doc.toVariant().toList();
                emit detectedBoxesChanged();
            }
        }
    });

    m_detectProcess->start(QStringLiteral("python3"), {
        scriptPath,
        m_tempPath,
        QString::number(m_monitorScale, 'f', 2)
    });
}

void QuickFrameBridge::setTempPath(const QString& p) {
    if (m_tempPath != p) {
        m_tempPath = p;
        emit tempPathChanged();
    }
}

void QuickFrameBridge::setSaveToDisk(bool s) {
    if (m_saveToDisk != s) {
        m_saveToDisk = s;
        emit saveToDiskChanged();
    }
}

void QuickFrameBridge::setOcrMode(bool o) {
    if (m_ocrMode != o) {
        m_ocrMode = o;
        emit ocrModeChanged();
    }
}

void QuickFrameBridge::setMode(const QString& m) {
    if (m_mode != m) {
        m_mode = m;
        emit modeChanged();
    }
}

void QuickFrameBridge::executeAction(const QString& action, double x, double y, double width, double height) {
    int lx = qRound(x);
    int ly = qRound(y);
    int lw = qMax(1, qRound(width));
    int lh = qMax(1, qRound(height));
    int px = qRound(lx * m_monitorScale);
    int py = qRound(ly * m_monitorScale);
    int pw = qMax(1, qRound(lw * m_monitorScale));
    int ph = qMax(1, qRound(lh * m_monitorScale));
    QString crop = QStringLiteral("%1x%2+%3+%4").arg(pw).arg(ph).arg(px).arg(py);

    QString picsDir = qEnvironmentVariable("HQS_DIR");
    if (picsDir.isEmpty()) picsDir = qEnvironmentVariable("XDG_SCREENSHOTS_DIR");
    if (picsDir.isEmpty()) picsDir = qEnvironmentVariable("XDG_PICTURES_DIR");
    if (picsDir.isEmpty()) picsDir = QDir::homePath() + QStringLiteral("/Pictures");
    QDir().mkpath(picsDir);

    QString ts = QDateTime::currentDateTime().toString(QStringLiteral("yyyy-MM-dd_hh-mm-ss"));
    QString out = QStringLiteral("%1/screenshot-%2.png").arg(picsDir, ts);

    QString cmd;
    if (action == QStringLiteral("ocr")) {
        cmd = QStringLiteral(
            "tmp=$(mktemp --suffix=.png); "
            "pre=$(mktemp --suffix=.png); "
            "magick \"%1\" -crop \"%2\" +repage \"$tmp\" || exit 1; "
            "magick \"$tmp\" -resize 300% -colorspace Gray -sharpen 0x1 -bordercolor white -border 10x10 \"$pre\"; "
            "text=$(tesseract \"$pre\" stdout -l eng --psm 6 --oem 1 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'); "
            "rm -f \"$pre\"; "
            "if [ -n \"$text\" ]; then "
            "  printf '%%s' \"$text\" | wl-copy; "
            "  notify-send -a \"HyprQuickFrame\" \"OCR Text Copied\" \"$text\"; "
            "else "
            "  notify-send -a \"HyprQuickFrame\" \"OCR Text\" \"No text recognized in selection\" -u low; "
            "fi; "
            "%3"
            "rm -f \"$tmp\" \"%1\""
        ).arg(m_tempPath, crop, m_saveToDisk ? QStringLiteral("cp \"$tmp\" \"%1\"; ").arg(out) : QString());
    } else if (action == QStringLiteral("translate")) {
        cmd = QStringLiteral(
            "tmp=$(mktemp --suffix=.png); "
            "pre=$(mktemp --suffix=.png); "
            "magick \"%1\" -crop \"%2\" +repage \"$tmp\" || exit 1; "
            "magick \"$tmp\" -resize 300% -colorspace Gray -sharpen 0x1 -bordercolor white -border 10x10 \"$pre\"; "
            "text=$(tesseract \"$pre\" stdout -l eng --psm 6 --oem 1 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'); "
            "rm -f \"$pre\"; "
            "if [ -n \"$text\" ]; then "
            "  printf '%%s' \"$text\" | wl-copy; "
            "  notify-send -a \"HyprQuickFrame\" \"Google Lens\" \"Opening search for: $text\"; "
            "  python3 -c \"import urllib.parse, webbrowser, sys; webbrowser.open('https://www.google.com/search?q=' + urllib.parse.quote(sys.argv[1]))\" \"$text\"; "
            "else "
            "  notify-send -a \"HyprQuickFrame\" \"Google Lens\" \"No text recognized to translate\" -u low; "
            "fi; "
            "rm -f \"$tmp\" \"%1\""
        ).arg(m_tempPath, crop);
    } else if (action == QStringLiteral("save") || (action == QStringLiteral("default") && m_saveToDisk)) {
        cmd = QStringLiteral(
            "magick \"%1\" -crop \"%2\" +repage \"%3\" && "
            "wl-copy -t image/png < \"%3\" && "
            "notify-send -a \"HyprQuickFrame\" \"Screenshot Saved\" \"%3\" -i \"%3\" && "
            "rm -f \"%1\""
        ).arg(m_tempPath, crop, out);
    } else {
        cmd = QStringLiteral(
            "magick \"%1\" -crop \"%2\" +repage png:- | wl-copy -t image/png && "
            "notify-send -a \"HyprQuickFrame\" \"Screenshot Copied\" \"Copied to clipboard\" && "
            "rm -f \"%1\""
        ).arg(m_tempPath, crop);
    }

    QProcess::startDetached(QStringLiteral("sh"), {QStringLiteral("-c"), cmd});
    m_tempPath.clear(); // Handed over to shell command for deletion
    QCoreApplication::quit();
}

void QuickFrameBridge::cancel() {
    deleteTemp();
    QCoreApplication::quit();
}

void QuickFrameBridge::deleteTemp() {
    if (!m_tempPath.isEmpty()) {
        QFile::remove(m_tempPath);
        m_tempPath.clear();
    }
}
