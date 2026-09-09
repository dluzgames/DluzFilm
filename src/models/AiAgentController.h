#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QJsonObject>
#include <QJsonArray>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrl>

class AppController;

class AiAgentController : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString provider READ provider WRITE setProvider NOTIFY providerChanged)
    Q_PROPERTY(QString geminiKey READ geminiKey WRITE setGeminiKey NOTIFY keysChanged)
    Q_PROPERTY(QString openrouterKey READ openrouterKey WRITE setOpenrouterKey NOTIFY keysChanged)
    Q_PROPERTY(QString groqKey READ groqKey WRITE setGroqKey NOTIFY keysChanged)
    Q_PROPERTY(QString opencodeKey READ opencodeKey WRITE setOpencodeKey NOTIFY keysChanged)
    Q_PROPERTY(QString opencodeUrl READ opencodeUrl WRITE setOpencodeUrl NOTIFY keysChanged)
    Q_PROPERTY(QString model READ model WRITE setModel NOTIFY modelChanged)
    Q_PROPERTY(bool codexAvailable READ isCodexAvailable NOTIFY codexAvailableChanged)
    Q_PROPERTY(bool antigravityAvailable READ isAntigravityAvailable NOTIFY antigravityAvailableChanged)
    Q_PROPERTY(bool opencodeCliAvailable READ isOpencodeCliAvailable NOTIFY opencodeCliAvailableChanged)
    Q_PROPERTY(bool isBusy READ isBusy NOTIFY isBusyChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusMessageChanged)
    Q_PROPERTY(QVariantList chatHistory READ chatHistory NOTIFY chatHistoryChanged)

public:
    explicit AiAgentController(AppController *controller, QObject *parent = nullptr);
    ~AiAgentController() override;

    QString provider() const { return m_provider; }
    void setProvider(const QString &p);

    QString geminiKey() const { return m_geminiKey; }
    void setGeminiKey(const QString &k);

    QString openrouterKey() const { return m_openrouterKey; }
    void setOpenrouterKey(const QString &k);

    QString groqKey() const { return m_groqKey; }
    void setGroqKey(const QString &k);

    QString opencodeKey() const { return m_opencodeKey; }
    void setOpencodeKey(const QString &k);

    QString opencodeUrl() const { return m_opencodeUrl; }
    void setOpencodeUrl(const QString &u);

    QString model() const { return m_model; }
    void setModel(const QString &m);

    bool isBusy() const { return m_isBusy; }
    QString statusMessage() const { return m_statusMessage; }
    QVariantList chatHistory() const { return m_chatHistory; }

    bool isCodexAvailable() const;
    Q_INVOKABLE QString codexExecutablePath() const;

    bool isAntigravityAvailable() const;
    Q_INVOKABLE QString antigravityExecutablePath() const;

    bool isOpencodeCliAvailable() const;
    Q_INVOKABLE QString opencodeExecutablePath() const;

    Q_INVOKABLE void sendMessage(const QString &prompt);
    Q_INVOKABLE void clearChat();
    Q_INVOKABLE void copyToClipboard(const QString &text);

    // HyperFrames creation and rendering
    Q_INVOKABLE void createHyperframes(const QString &title, const QString &subtitle,
                                       const QString &templateType = QStringLiteral("lower_third"),
                                       const QString &customHtml = QString());

    // Voice cloning with OmniVoice (CUDA) or Edge-TTS
    Q_INVOKABLE void synthesizeVoice(const QString &text,
                                     const QString &engine = QStringLiteral("omnivoice"),
                                     const QString &lang = QStringLiteral("pt"),
                                     const QString &voicePath = QString());

    // Video Dubbing & Auto-subtitles (Whisper + OmniVoice / Edge-TTS)
    Q_INVOKABLE void dubVideo(const QString &videoPath,
                              const QString &targetLang = QStringLiteral("en"),
                              const QString &engine = QStringLiteral("omnivoice"),
                              bool generateSubs = true,
                              bool burnSubs = false,
                              double bgmVolume = 0.15);

    Q_INVOKABLE QString selectedVideoClipPath() const;

    // OmniFlash AI Video generation
    Q_INVOKABLE void generateOmniFlash(const QString &prompt,
                                       const QString &aspectRatio = QStringLiteral("16:9"));

    // Quick Silence Remover trigger
    Q_INVOKABLE void runSilenceRemoval(double threshold = -30.0, double minDuration = 0.3, double padding = 0.08);

signals:
    void providerChanged();
    void keysChanged();
    void modelChanged();
    void codexAvailableChanged();
    void antigravityAvailableChanged();
    void opencodeCliAvailableChanged();
    void isBusyChanged();
    void statusMessageChanged();
    void chatHistoryChanged();
    void hyperframesFinished(bool success, const QString &outputPath, const QString &message);
    void voiceSynthesisFinished(bool success, const QString &outputPath, const QString &message);
    void videoDubbingFinished(bool success, const QString &videoPath, const QString &srtPath, const QString &message);
    void omniFlashFinished(bool success, const QString &outputPath, const QString &message);

private slots:
    void handleAiReply();

private:
    void loadSettings();
    void saveSettings();
    void setBusy(bool busy, const QString &msg = QString());
    void appendChatMessage(const QString &role, const QString &text, const QString &action = QString());
    QString buildSystemPrompt() const;
    void executeActionFromResponse(const QString &response, const QString &userPrompt = QString());

    AppController *m_controller = nullptr;
    QNetworkAccessManager m_nam;
    QNetworkReply *m_currentReply = nullptr;

    QString m_provider = QStringLiteral("gemini");
    QString m_geminiKey;
    QString m_openrouterKey;
    QString m_groqKey;
    QString m_opencodeKey;
    QString m_opencodeUrl = QStringLiteral("http://localhost:11434/v1");
    QString m_model;
    bool m_isBusy = false;
    QString m_statusMessage;
    QVariantList m_chatHistory;
    QString m_lastUserPrompt;
};
