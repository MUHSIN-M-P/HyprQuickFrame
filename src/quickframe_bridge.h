#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QProcess>

class QuickFrameBridge : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString tempPath READ tempPath WRITE setTempPath NOTIFY tempPathChanged)
    Q_PROPERTY(double monitorScale READ monitorScale NOTIFY monitorChanged)
    Q_PROPERTY(QString monitorName READ monitorName NOTIFY monitorChanged)
    Q_PROPERTY(int screenWidth READ screenWidth NOTIFY monitorChanged)
    Q_PROPERTY(int screenHeight READ screenHeight NOTIFY monitorChanged)
    Q_PROPERTY(int monitorX READ monitorX NOTIFY monitorChanged)
    Q_PROPERTY(int monitorY READ monitorY NOTIFY monitorChanged)
    Q_PROPERTY(QVariantList detectedBoxes READ detectedBoxes NOTIFY detectedBoxesChanged)
    Q_PROPERTY(QVariantList windows READ windows NOTIFY windowsChanged)
    Q_PROPERTY(bool saveToDisk READ saveToDisk WRITE setSaveToDisk NOTIFY saveToDiskChanged)
    Q_PROPERTY(bool ocrMode READ ocrMode WRITE setOcrMode NOTIFY ocrModeChanged)
    Q_PROPERTY(QString mode READ mode WRITE setMode NOTIFY modeChanged)

public:
    explicit QuickFrameBridge(QObject* parent = nullptr);
    ~QuickFrameBridge() override;

    void initTargetScreen();
    void captureScreen();
    void startDetection();
    void loadWindows();

    QString tempPath() const { return m_tempPath; }
    double monitorScale() const { return m_monitorScale; }
    QString monitorName() const { return m_monitorName; }
    int screenWidth() const { return m_screenWidth; }
    int screenHeight() const { return m_screenHeight; }
    int monitorX() const { return m_monitorX; }
    int monitorY() const { return m_monitorY; }
    QVariantList detectedBoxes() const { return m_detectedBoxes; }
    QVariantList windows() const { return m_windows; }
    bool saveToDisk() const { return m_saveToDisk; }
    bool ocrMode() const { return m_ocrMode; }
    QString mode() const { return m_mode; }

    void setTempPath(const QString& p);
    void setSaveToDisk(bool s);
    void setOcrMode(bool o);
    void setMode(const QString& m);

    Q_INVOKABLE void executeAction(const QString& action, double x, double y, double width, double height);
    Q_INVOKABLE void cancel();
    Q_INVOKABLE void deleteTemp();

signals:
    void tempPathChanged();
    void monitorChanged();
    void detectedBoxesChanged();
    void windowsChanged();
    void saveToDiskChanged();
    void ocrModeChanged();
    void modeChanged();
    void captureFinished();

private:
    QString m_tempPath;
    double m_monitorScale{1.0};
    QString m_monitorName;
    int m_screenWidth{1920};
    int m_screenHeight{1080};
    int m_monitorX{0};
    int m_monitorY{0};
    QVariantList m_detectedBoxes;
    QVariantList m_windows;
    bool m_saveToDisk{true};
    bool m_ocrMode{false};
    QString m_mode{"region"};

    QProcess* m_detectProcess{nullptr};
};
