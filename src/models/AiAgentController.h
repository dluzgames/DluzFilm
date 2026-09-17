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
    Q_PROPERTY(QString omnirouterKey READ omnirouterKey WRITE setOmnirouterKey NOTIFY keysChanged)
    Q_PROPERTY(QString omnirouterUrl READ omnirouterUrl WRITE setOmnirouterUrl NOTIFY keysChanged)
    Q_PROPERTY(QString omnirouterModel READ omnirouterModel WRITE setOmnirouterModel NOTIFY keysChanged)
    Q_PROPERTY(QString model READ model WRITE setModel NOTIFY modelChanged)

    // Multi-Agent Role Assignment
    Q_PROPERTY(bool multiAgentEnabled READ isMultiAgentEnabled WRITE setMultiAgentEnabled NOTIFY multiAgentChanged)
    Q_PROPERTY(QString cutsAgentProvider READ cutsAgentProvider WRITE setCutsAgentProvider NOTIFY multiAgentChanged)
    Q_PROPERTY(QString cutsAgentModel READ cutsAgentModel WRITE setCutsAgentModel NOTIFY multiAgentChanged)
    Q_PROPERTY(QString hyperframesAgentProvider READ hyperframesAgentProvider WRITE setHyperframesAgentProvider NOTIFY multiAgentChanged)
    Q_PROPERTY(QString hyperframesAgentModel READ hyperframesAgentModel WRITE setHyperframesAgentModel NOTIFY multiAgentChanged)
    Q_PROPERTY(QString audioAgentProvider READ audioAgentProvider WRITE setAudioAgentProvider NOTIFY multiAgentChanged)
    Q_PROPERTY(QString audioAgentModel READ audioAgentModel WRITE setAudioAgentModel NOTIFY multiAgentChanged)
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

    QString omnirouterKey() const { return m_omnirouterKey; }
    void setOmnirouterKey(const QString &k);

    QString omnirouterUrl() const { return m_omnirouterUrl; }
    void setOmnirouterUrl(const QString &u);

    QString omnirouterModel() const { return m_omnirouterModel; }
    void setOmnirouterModel(const QString &m);

    QString model() const { return m_model; }
    void setModel(const QString &m);

    bool isMultiAgentEnabled() const { return m_multiAgentEnabled; }
    void setMultiAgentEnabled(bool enabled);

    QString cutsAgentProvider() const { return m_cutsAgentProvider; }
    void setCutsAgentProvider(const QString &p);
    QString cutsAgentModel() const { return m_cutsAgentModel; }
    void setCutsAgentModel(const QString &m);

    QString hyperframesAgentProvider() const { return m_hyperframesAgentProvider; }
    void setHyperframesAgentProvider(const QString &p);
    QString hyperframesAgentModel() const { return m_hyperframesAgentModel; }
    void setHyperframesAgentModel(const QString &m);

    QString audioAgentProvider() const { return m_audioAgentProvider; }
    void setAudioAgentProvider(const QString &p);
    QString audioAgentModel() const { return m_audioAgentModel; }
    void setAudioAgentModel(const QString &m);

    Q_INVOKABLE QString effectiveProviderForRole(const QString &role) const;
    Q_INVOKABLE QString effectiveModelForRole(const QString &role) const;
    Q_INVOKABLE QString effectiveApiKeyForProvider(const QString &provider) const;
    Q_INVOKABLE QString effectiveUrlForProvider(const QString &provider) const;

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

    // OmniFlash Clip Editing (Flow video transformation with preserved original voice)
    Q_INVOKABLE void editClipWithOmniFlash(int trackIndex, int clipIndex,
                                           const QString &clipPath,
                                           double inPoint, double duration,
                                           const QString &prompt,
                                           bool preserveAudio = true,
                                           bool replaceInPlace = true);

    // Quick Silence Remover trigger
    Q_INVOKABLE void runSilenceRemoval(double threshold = -30.0, double minDuration = 0.3, double padding = 0.08);

    // Dynamic Subtitles Generation (Word-by-word / MrBeast style)
    Q_INVOKABLE void generateDynamicSubtitles(int trackIndex, int clipIndex,
                                              const QString &clipPath,
                                              double inPoint, double duration,
                                              double timelineStart,
                                              const QString &lang = QStringLiteral("pt"),
                                              int wordsPerCue = 1,
                                              bool uppercase = true,
                                              const QString &presetId = QStringLiteral("karaoke-pop"));

    // Hard Mode - Autonomous Video Production from Link/Article
    Q_INVOKABLE void startHardModeProduction(const QString &articleUrlOrText,
                                             const QString &gameplayUrlOrPath = QString(),
                                             const QString &voiceEngine = QStringLiteral("omnivoice"),
                                             const QString &lang = QStringLiteral("pt"),
                                             const QString &aspectRatio = QStringLiteral("16:9"));
    Q_INVOKABLE bool applyTimelineManifest(const QString &manifestPath);

    // Timeline AI Video Editor (Whisper transcription + Contextual HyperFrames & Full Edit)
    Q_INVOKABLE void autoEditTimelineVideo(int trackIndex = -1, int clipIndex = -1);
    Q_INVOKABLE void analyzeVideoAndAddContextualHyperframes(int trackIndex = -1, int clipIndex = -1);
    Q_INVOKABLE bool applyTimelineEditManifest(const QString &manifestPath);

signals:
    void providerChanged();
    void keysChanged();
    void modelChanged();
    void multiAgentChanged();
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
    void omniFlashClipEditProgress(int percent, const QString &statusText);
    void omniFlashClipEditFinished(bool success, const QString &outputPath, const QString &message);
    void dynamicSubtitlesProgress(int percent, const QString &statusText);
    void dynamicSubtitlesFinished(bool success, const QString &srtPath, const QString &message);
    void hardModeProgress(int percent, const QString &statusText);
    void hardModeFinished(bool success, const QString &manifestPath, const QString &message);
    void timelineAiEditProgress(int percent, const QString &statusText);
    void timelineAiEditFinished(bool success, const QString &manifestPath, const QString &message);

private slots:
    void handleAiReply();

private:
    void loadSettings();
    void saveSettings();
    void setBusy(bool busy, const QString &msg = QString());
    void appendChatMessage(const QString &role, const QString &text, const QString &action = QString());
    QString buildSystemPrompt() const;
    void executeActionFromResponse(const QString &response, const QString &userPrompt = QString());
    QVariantMap findMainTimelineVideoClip(int preferredTrack = -1, int preferredClip = -1) const;

    AppController *m_controller = nullptr;
    QNetworkAccessManager m_nam;
    QNetworkReply *m_currentReply = nullptr;

    QString m_provider = QStringLiteral("gemini");
    QString m_geminiKey;
    QString m_openrouterKey;
    QString m_groqKey;
    QString m_opencodeKey;
    QString m_opencodeUrl = QStringLiteral("http://localhost:11434/v1");
    QString m_omnirouterKey = QStringLiteral("sk-b11bd45a7b59fb16-7nz0o8-1b1fc2d1");
    QString m_omnirouterUrl = QStringLiteral("https://9router.dluz.com.br/v1");
    QString m_omnirouterModel = QStringLiteral("gemini-2.5-flash");
    QString m_model;

    // Multi-Agent roles
    bool m_multiAgentEnabled = false;
    QString m_cutsAgentProvider = QStringLiteral("omnirouter");
    QString m_cutsAgentModel = QStringLiteral("gemini-2.5-flash");
    QString m_hyperframesAgentProvider = QStringLiteral("omnirouter");
    QString m_hyperframesAgentModel = QStringLiteral("gemini-2.5-flash");
    QString m_audioAgentProvider = QStringLiteral("omnirouter");
    QString m_audioAgentModel = QStringLiteral("gemini-2.5-flash");

    bool m_isBusy = false;
    QString m_statusMessage;
    QVariantList m_chatHistory;
    QString m_lastUserPrompt;
};
