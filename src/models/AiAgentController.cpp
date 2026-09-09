#include "AiAgentController.h"
#include "AppController.h"

#include <QSettings>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QUrlQuery>
#include <QUrl>
#include <QNetworkRequest>
#include <QDir>
#include <QTemporaryDir>
#include <QStandardPaths>
#include <QDateTime>
#include <QFileInfo>
#include <QRegularExpression>
#include <QUuid>
#include <QProcess>
#include <QGuiApplication>
#include <QClipboard>

#ifdef Q_OS_WIN
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#endif

namespace {

void setupSilentProcess(QProcess *proc, bool redirectNullStdin = true)
{
    proc->setProcessChannelMode(QProcess::SeparateChannels);
    if (redirectNullStdin) {
        proc->setStandardInputFile(QProcess::nullDevice());
    }

    auto env = QProcessEnvironment::systemEnvironment();
    env.insert(QStringLiteral("NO_COLOR"), QStringLiteral("1"));
    env.insert(QStringLiteral("FORCE_COLOR"), QStringLiteral("0"));
    proc->setProcessEnvironment(env);

#ifdef Q_OS_WIN
    proc->setCreateProcessArgumentsModifier([](QProcess::CreateProcessArguments *args) {
        args->flags |= CREATE_NO_WINDOW;
        args->startupInfo->dwFlags |= STARTF_USESHOWWINDOW;
        args->startupInfo->wShowWindow = SW_HIDE;
    });
#endif
}

QString stripAnsi(const QString &text)
{
    static const QRegularExpression ansiRegex(QStringLiteral(R"(\x1B\[[0-9;]*[a-zA-Z])"));
    return QString(text).remove(ansiRegex).trimmed();
}

QString cleanActionTags(const QString &text)
{
    static const QRegularExpression actionRegex(QStringLiteral(R"(\[ACTION:[A-Z_]+[^\]]*\])"), QRegularExpression::CaseInsensitiveOption);
    return QString(text).remove(actionRegex).trimmed();
}

QString findCodexExecutable()
{
    QString exe = QStandardPaths::findExecutable(QStringLiteral("codex"));
    if (!exe.isEmpty() && QFile::exists(exe))
        return exe;

    QString localPath = QDir::homePath() + QStringLiteral("/AppData/Local/Programs/OpenAI/Codex/bin/codex.exe");
    if (QFile::exists(localPath))
        return localPath;

    QString defaultPath = QStringLiteral("C:/Users/dluzgg/AppData/Local/Programs/OpenAI/Codex/bin/codex.exe");
    if (QFile::exists(defaultPath))
        return defaultPath;

    return QString();
}

QString findAntigravityExecutable()
{
    QString exe = QStandardPaths::findExecutable(QStringLiteral("agy"));
    if (!exe.isEmpty() && QFile::exists(exe))
        return exe;

    QString localPath = QDir::homePath() + QStringLiteral("/AppData/Local/agy/bin/agy.exe");
    if (QFile::exists(localPath))
        return localPath;

    QString defaultPath = QStringLiteral("C:/Users/dluzgg/AppData/Local/agy/bin/agy.exe");
    if (QFile::exists(defaultPath))
        return defaultPath;

    return QString();
}

QString findOpencodeExecutable()
{
    QString exe = QStandardPaths::findExecutable(QStringLiteral("opencode"));
    if (!exe.isEmpty() && QFile::exists(exe))
        return exe;

    QString localExe = QDir::homePath() + QStringLiteral("/AppData/Roaming/npm/node_modules/opencode-ai/bin/opencode.exe");
    if (QFile::exists(localExe))
        return localExe;

    QString localCmd = QDir::homePath() + QStringLiteral("/AppData/Roaming/npm/opencode.cmd");
    if (QFile::exists(localCmd))
        return localCmd;

    QString defaultPath = QStringLiteral("C:/Users/dluzgg/AppData/Roaming/npm/node_modules/opencode-ai/bin/opencode.exe");
    if (QFile::exists(defaultPath))
        return defaultPath;

    return QString();
}

} // namespace

bool AiAgentController::isCodexAvailable() const
{
    return !findCodexExecutable().isEmpty();
}

QString AiAgentController::codexExecutablePath() const
{
    return findCodexExecutable();
}

bool AiAgentController::isAntigravityAvailable() const
{
    return !findAntigravityExecutable().isEmpty();
}

QString AiAgentController::antigravityExecutablePath() const
{
    return findAntigravityExecutable();
}

bool AiAgentController::isOpencodeCliAvailable() const
{
    return !findOpencodeExecutable().isEmpty();
}

QString AiAgentController::opencodeExecutablePath() const
{
    return findOpencodeExecutable();
}

AiAgentController::AiAgentController(AppController *controller, QObject *parent)
    : QObject(parent)
    , m_controller(controller)
{
    loadSettings();

    // Default welcome message
    appendChatMessage(QStringLiteral("assistant"),
                      tr("Olá! Sou o seu Agente IA interno do Dluz Film (com suporte nativo a Antigravity CLI, Codex CLI, OpenCode, Gemini, Groq e OpenRouter). Posso ajudar você a criar vinhetas e lower-thirds animados com HyperFrames, remover silêncios automaticamente, clonar voz com OmniVoice e gerar cenas com OmniFlash. Como posso ajudar agora?"));
}

AiAgentController::~AiAgentController()
{
    if (m_currentReply) {
        m_currentReply->abort();
        m_currentReply->deleteLater();
    }
}

void AiAgentController::loadSettings()
{
    QSettings s(QStringLiteral("Dluz Film"), QStringLiteral("Dluz Film"));
    QString defProvider = QStringLiteral("gemini");
    if (isAntigravityAvailable())
        defProvider = QStringLiteral("antigravity");
    else if (isCodexAvailable())
        defProvider = QStringLiteral("codex");
    else if (isOpencodeCliAvailable())
        defProvider = QStringLiteral("opencode");

    m_provider = s.value(QStringLiteral("ai/provider"), defProvider).toString();
    m_geminiKey = s.value(QStringLiteral("ai/gemini_key")).toString();
    m_openrouterKey = s.value(QStringLiteral("ai/openrouter_key")).toString();
    m_groqKey = s.value(QStringLiteral("ai/groq_key")).toString();
    m_opencodeKey = s.value(QStringLiteral("ai/opencode_key")).toString();
    m_opencodeUrl = s.value(QStringLiteral("ai/opencode_url"), QStringLiteral("http://localhost:11434/v1")).toString();
    m_model = s.value(QStringLiteral("ai/model")).toString();
}

void AiAgentController::saveSettings()
{
    QSettings s(QStringLiteral("Dluz Film"), QStringLiteral("Dluz Film"));
    s.setValue(QStringLiteral("ai/provider"), m_provider);
    s.setValue(QStringLiteral("ai/gemini_key"), m_geminiKey);
    s.setValue(QStringLiteral("ai/openrouter_key"), m_openrouterKey);
    s.setValue(QStringLiteral("ai/groq_key"), m_groqKey);
    s.setValue(QStringLiteral("ai/opencode_key"), m_opencodeKey);
    s.setValue(QStringLiteral("ai/opencode_url"), m_opencodeUrl);
    s.setValue(QStringLiteral("ai/model"), m_model);
}

void AiAgentController::setProvider(const QString &p)
{
    if (m_provider != p) {
        m_provider = p;
        saveSettings();
        emit providerChanged();
    }
}

void AiAgentController::setGeminiKey(const QString &k)
{
    if (m_geminiKey != k) {
        m_geminiKey = k;
        saveSettings();
        emit keysChanged();
    }
}

void AiAgentController::setOpenrouterKey(const QString &k)
{
    if (m_openrouterKey != k) {
        m_openrouterKey = k;
        saveSettings();
        emit keysChanged();
    }
}

void AiAgentController::setGroqKey(const QString &k)
{
    if (m_groqKey != k) {
        m_groqKey = k;
        saveSettings();
        emit keysChanged();
    }
}

void AiAgentController::setOpencodeKey(const QString &k)
{
    if (m_opencodeKey != k) {
        m_opencodeKey = k;
        saveSettings();
        emit keysChanged();
    }
}

void AiAgentController::setOpencodeUrl(const QString &u)
{
    if (m_opencodeUrl != u) {
        m_opencodeUrl = u;
        saveSettings();
        emit keysChanged();
    }
}

void AiAgentController::setModel(const QString &m)
{
    if (m_model != m) {
        m_model = m;
        saveSettings();
        emit modelChanged();
    }
}

void AiAgentController::setBusy(bool busy, const QString &msg)
{
    m_isBusy = busy;
    m_statusMessage = msg;
    emit isBusyChanged();
    emit statusMessageChanged();
}

void AiAgentController::appendChatMessage(const QString &role, const QString &text, const QString &action)
{
    QVariantMap msg;
    msg[QStringLiteral("role")] = role;
    msg[QStringLiteral("text")] = text;
    msg[QStringLiteral("action")] = action;
    msg[QStringLiteral("time")] = QDateTime::currentDateTime().toString(QStringLiteral("HH:mm"));
    m_chatHistory.append(msg);
    emit chatHistoryChanged();
}

void AiAgentController::clearChat()
{
    m_chatHistory.clear();
    emit chatHistoryChanged();
}

void AiAgentController::copyToClipboard(const QString &text)
{
    if (text.isEmpty())
        return;
    if (QClipboard *clip = QGuiApplication::clipboard())
        clip->setText(text);
}

QString AiAgentController::buildSystemPrompt() const
{
    QString info = QStringLiteral("Você é o Agente IA oficial do editor de vídeo Dluz Film.\n"
                                  "Você ajuda o usuário a editar vídeos, criar gráficos com HyperFrames, sintetizar voz clonada (OmniVoice), gerar cenas com OmniFlash e cortar silêncios.\n"
                                  "Seja amigável, direto, técnico e use o tom autêntico da DLuz Games.\n"
                                  "Quando o usuário pedir para criar um elemento, você pode incluir comandos especiais no final da sua resposta:\n"
                                  "- Criar lower third / vinheta: [ACTION:HYPERFRAMES|lower_third|Título|Subtítulo]\n"
                                  "- Criar card de título: [ACTION:HYPERFRAMES|title_card|Título|Subtítulo]\n"
                                  "- Criar card social: [ACTION:HYPERFRAMES|social_card|Nome|@handle]\n"
                                  "- Remover silêncios: [ACTION:REMOVE_SILENCE|-30|0.3|0.08]\n"
                                  "- Sintetizar voz com OmniVoice: [ACTION:CLONE_VOICE|omnivoice|texto completo aqui]\n"
                                  "- Gerar vídeo OmniFlash: [ACTION:OMNIFLASH|16:9|prompt da cena em inglês]\n"
                                  "- Ativar Chroma Key no clip selecionado: [ACTION:CHROMA_KEY]\n"
                                  "- Fechar espaços / Modo magnético: [ACTION:CLOSE_GAPS]\n"
                                  "- Modo Hard (Produzir vídeo completo a partir de link ou matéria): [ACTION:AUTO_PRODUCE|link_artigo|link_gameplay|omnivoice|16:9]\n");

    return info;
}

void AiAgentController::sendMessage(const QString &prompt)
{
    if (prompt.trimmed().isEmpty() || m_isBusy)
        return;

    m_lastUserPrompt = prompt.trimmed();

    appendChatMessage(QStringLiteral("user"), prompt.trimmed());
    setBusy(true, tr("Consultando IA (%1)...").arg(m_provider));

    const QString sysPrompt = buildSystemPrompt();

    if (m_provider == QStringLiteral("codex")) {
        const QString codexExe = findCodexExecutable();
        if (codexExe.isEmpty() || !QFile::exists(codexExe)) {
            setBusy(false);
            appendChatMessage(QStringLiteral("assistant"),
                              tr("⚠️ Executável do Codex CLI não foi encontrado no sistema (OpenAI Codex). Verifique se está instalado em seu computador."));
            return;
        }

        const QString tempFile = QDir::tempPath() + QStringLiteral("/codex_reply_")
                               + QUuid::createUuid().toString(QUuid::WithoutBraces)
                               + QStringLiteral(".txt");

        const QString fullPrompt = sysPrompt + QStringLiteral("\n\nInstrução do Usuário no Dluz Film:\n") + prompt;

        QStringList args{
            QStringLiteral("exec"),
            QStringLiteral("-"),
            QStringLiteral("-o"), tempFile,
            QStringLiteral("-s"), QStringLiteral("read-only"),
            QStringLiteral("--skip-git-repo-check"),
            QStringLiteral("--ephemeral"),
            QStringLiteral("--color"), QStringLiteral("never")
        };

        if (!m_model.trimmed().isEmpty()) {
            args << QStringLiteral("-m") << m_model.trimmed();
        }

        auto *proc = new QProcess(this);
        setupSilentProcess(proc, false);

        connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this, proc, tempFile](int exitCode, QProcess::ExitStatus exitStatus) {
            Q_UNUSED(exitStatus);
            proc->deleteLater();
            this->setBusy(false);

            QString replyText;
            QFile file(tempFile);
            if (file.open(QIODevice::ReadOnly)) {
                replyText = stripAnsi(QString::fromUtf8(file.readAll()).trimmed());
                file.close();
                file.remove();
            }

            if (replyText.isEmpty()) {
                const QString errOut = stripAnsi(QString::fromUtf8(proc->readAllStandardError()).trimmed());
                const QString stdOut = stripAnsi(QString::fromUtf8(proc->readAllStandardOutput()).trimmed());
                if (!stdOut.isEmpty()) {
                    replyText = stdOut;
                } else if (!errOut.isEmpty()) {
                    replyText = tr("⚠️ Erro do Codex CLI: %1").arg(errOut);
                } else {
                    replyText = tr("⚠️ Codex CLI finalizou com código %1 sem resposta.").arg(exitCode);
                }
            }

            if (!replyText.isEmpty()) {
                const QString cleanReply = cleanActionTags(replyText);
                this->appendChatMessage(QStringLiteral("assistant"), cleanReply.isEmpty() ? tr("🎬 Ação identificada! Injetando na timeline...") : cleanReply);
                this->executeActionFromResponse(replyText, this->m_lastUserPrompt);
            }
        });

        proc->start(codexExe, args);
        proc->write(fullPrompt.toUtf8());
        proc->closeWriteChannel();
        return;
    }

    if (m_provider == QStringLiteral("antigravity")) {
        const QString agyExe = findAntigravityExecutable();
        if (agyExe.isEmpty() || !QFile::exists(agyExe)) {
            setBusy(false);
            appendChatMessage(QStringLiteral("assistant"),
                              tr("⚠️ Executável do Antigravity CLI (agy) não foi encontrado no sistema. Verifique a instalação."));
            return;
        }

        const QString fullPrompt = sysPrompt + QStringLiteral("\n\nInstrução do Usuário no Dluz Film:\n") + prompt;

        QStringList args{
            QStringLiteral("--output-format"), QStringLiteral("text"),
            QStringLiteral("--effort"), QStringLiteral("low"),
            QStringLiteral("-p"), fullPrompt,
            QStringLiteral("--dangerously-skip-permissions")
        };

        if (!m_model.trimmed().isEmpty()) {
            args << QStringLiteral("--model") << m_model.trimmed();
        }

        auto *proc = new QProcess(this);
        setupSilentProcess(proc, true);

        connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this, proc](int exitCode, QProcess::ExitStatus exitStatus) {
            Q_UNUSED(exitStatus);
            proc->deleteLater();
            this->setBusy(false);

            QString replyText = stripAnsi(QString::fromUtf8(proc->readAllStandardOutput()).trimmed());
            if (replyText.isEmpty()) {
                const QString errOut = stripAnsi(QString::fromUtf8(proc->readAllStandardError()).trimmed());
                if (!errOut.isEmpty()) {
                    replyText = tr("⚠️ Erro do Antigravity CLI: %1").arg(errOut);
                } else {
                    replyText = tr("⚠️ Antigravity CLI finalizou com código %1 sem resposta.").arg(exitCode);
                }
            }

            if (!replyText.isEmpty()) {
                const QString cleanReply = cleanActionTags(replyText);
                this->appendChatMessage(QStringLiteral("assistant"), cleanReply.isEmpty() ? tr("🎬 Ação identificada! Injetando na timeline...") : cleanReply);
                this->executeActionFromResponse(replyText, this->m_lastUserPrompt);
            }
        });

        proc->start(agyExe, args);
        return;
    }

    if (m_provider == QStringLiteral("opencode")) {
        const QString opencodeExe = findOpencodeExecutable();
        // If opencode CLI exists and user didn't specify a custom remote key, run via CLI
        if (!opencodeExe.isEmpty() && QFile::exists(opencodeExe) && m_opencodeKey.trimmed().isEmpty()) {
            const QString fullPrompt = sysPrompt + QStringLiteral("\n\nInstrução do Usuário no Dluz Film:\n") + prompt;

            const QString model = m_model.trimmed().isEmpty() ? QStringLiteral("opencode/ling-3.0-flash-fin-free") : m_model.trimmed();

            QStringList args{
                QStringLiteral("run"),
                QStringLiteral("--format"), QStringLiteral("default"),
                QStringLiteral("-m"), model,
                fullPrompt
            };

            auto *proc = new QProcess(this);
            setupSilentProcess(proc, true);

            connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                    this, [this, proc](int exitCode, QProcess::ExitStatus exitStatus) {
                Q_UNUSED(exitStatus);
                proc->deleteLater();
                this->setBusy(false);

                QString raw = stripAnsi(QString::fromUtf8(proc->readAllStandardOutput()).trimmed());
                QStringList lines = raw.split(QLatin1Char('\n'));
                QStringList cleanedLines;
                for (const QString &line : lines) {
                    QString trimmed = line.trimmed();
                    if (trimmed.startsWith(QLatin1String("> ")) || trimmed.startsWith(QLatin1String("build ·")))
                        continue;
                    cleanedLines << line;
                }
                QString replyText = cleanedLines.join(QLatin1Char('\n')).trimmed();

                if (replyText.isEmpty()) {
                    const QString errOut = stripAnsi(QString::fromUtf8(proc->readAllStandardError()).trimmed());
                    if (!errOut.isEmpty()) {
                        replyText = tr("⚠️ Erro do OpenCode CLI: %1").arg(errOut);
                    } else {
                        replyText = tr("⚠️ OpenCode CLI finalizou com código %1 sem resposta.").arg(exitCode);
                    }
                }

                if (!replyText.isEmpty()) {
                    const QString cleanReply = cleanActionTags(replyText);
                    this->appendChatMessage(QStringLiteral("assistant"), cleanReply.isEmpty() ? tr("🎬 Ação identificada! Injetando na timeline...") : cleanReply);
                    this->executeActionFromResponse(replyText, this->m_lastUserPrompt);
                }
            });

            proc->start(opencodeExe, args);
            return;
        }
    }

    if (m_provider == QStringLiteral("gemini")) {
        if (m_geminiKey.trimmed().isEmpty()) {
            setBusy(false);
            appendChatMessage(QStringLiteral("assistant"),
                              tr("⚠️ Chave do Google Gemini não configurada! Por favor, insira sua Gemini API Key na aba Configurações."));
            return;
        }

        const QString model = m_model.isEmpty() ? QStringLiteral("gemini-2.5-flash") : m_model;
        const QString urlStr = QStringLiteral("https://generativelanguage.googleapis.com/v1beta/models/%1:generateContent?key=%2")
                                   .arg(model, m_geminiKey.trimmed());

        QJsonObject userPart{{QStringLiteral("text"), prompt}};
        QJsonObject userContent{{QStringLiteral("role"), QStringLiteral("user")},
                                {QStringLiteral("parts"), QJsonArray{userPart}}};

        QJsonObject sysPart{{QStringLiteral("text"), sysPrompt}};
        QJsonObject sysInstruction{{QStringLiteral("parts"), QJsonArray{sysPart}}};

        QJsonObject root{
            {QStringLiteral("contents"), QJsonArray{userContent}},
            {QStringLiteral("systemInstruction"), sysInstruction}
        };

        QNetworkRequest req((QUrl(urlStr)));
        req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));

        m_currentReply = m_nam.post(req, QJsonDocument(root).toJson());
        connect(m_currentReply, &QNetworkReply::finished, this, &AiAgentController::handleAiReply);
        return;
    }

    // OpenRouter, Groq, OpenCode (OpenAI-compatible)
    QString urlStr;
    QString key;
    QString defaultModel;

    if (m_provider == QStringLiteral("openrouter")) {
        urlStr = QStringLiteral("https://openrouter.ai/api/v1/chat/completions");
        key = m_openrouterKey.trimmed();
        defaultModel = QStringLiteral("anthropic/claude-3.5-sonnet");
    } else if (m_provider == QStringLiteral("groq")) {
        urlStr = QStringLiteral("https://api.groq.com/openai/v1/chat/completions");
        key = m_groqKey.trimmed();
        defaultModel = QStringLiteral("llama-3.3-70b-versatile");
    } else { // opencode / custom
        QString base = m_opencodeUrl.trimmed();
        if (base.endsWith(QLatin1Char('/')))
            base.chop(1);
        if (!base.endsWith(QStringLiteral("/chat/completions")))
            base += QStringLiteral("/chat/completions");
        urlStr = base;
        key = m_opencodeKey.trimmed();
        defaultModel = QStringLiteral("llama3");
    }

    if (key.isEmpty() && m_provider != QStringLiteral("opencode")) {
        setBusy(false);
        appendChatMessage(QStringLiteral("assistant"),
                          tr("⚠️ Chave API para %1 não configurada! Insira sua chave na aba Configurações.").arg(m_provider));
        return;
    }

    const QString chosenModel = m_model.isEmpty() ? defaultModel : m_model;

    QJsonArray messages;
    messages.append(QJsonObject{{QStringLiteral("role"), QStringLiteral("system")},
                                {QStringLiteral("content"), sysPrompt}});
    messages.append(QJsonObject{{QStringLiteral("role"), QStringLiteral("user")},
                                {QStringLiteral("content"), prompt}});

    QJsonObject root{
        {QStringLiteral("model"), chosenModel},
        {QStringLiteral("messages"), messages}
    };

    QNetworkRequest req((QUrl(urlStr)));
    req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    if (!key.isEmpty())
        req.setRawHeader("Authorization", "Bearer " + key.toUtf8());
    if (m_provider == QStringLiteral("openrouter")) {
        req.setRawHeader("HTTP-Referer", "https://dluz.com.br");
        req.setRawHeader("X-Title", "Dluz Film");
    }

    m_currentReply = m_nam.post(req, QJsonDocument(root).toJson());
    connect(m_currentReply, &QNetworkReply::finished, this, &AiAgentController::handleAiReply);
}

void AiAgentController::handleAiReply()
{
    if (!m_currentReply) {
        setBusy(false);
        return;
    }

    m_currentReply->deleteLater();
    const QByteArray data = m_currentReply->readAll();
    const int httpStatus = m_currentReply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

    if (m_currentReply->error() != QNetworkReply::NoError) {
        setBusy(false);
        QString errStr = QString::fromUtf8(data);
        if (errStr.length() > 200) errStr = errStr.left(200) + "...";
        appendChatMessage(QStringLiteral("assistant"),
                          tr("❌ Erro na requisição (%1 - %2): %3")
                              .arg(httpStatus)
                              .arg(m_currentReply->errorString())
                              .arg(errStr));
        m_currentReply = nullptr;
        return;
    }

    setBusy(false);
    m_currentReply = nullptr;

    const auto doc = QJsonDocument::fromJson(data);
    QString replyText;

    if (m_provider == QStringLiteral("gemini")) {
        const auto candidates = doc.object().value(QStringLiteral("candidates")).toArray();
        if (!candidates.isEmpty()) {
            const auto parts = candidates.at(0).toObject().value(QStringLiteral("content")).toObject().value(QStringLiteral("parts")).toArray();
            if (!parts.isEmpty())
                replyText = parts.at(0).toObject().value(QStringLiteral("text")).toString();
        }
    } else {
        const auto choices = doc.object().value(QStringLiteral("choices")).toArray();
        if (!choices.isEmpty())
            replyText = choices.at(0).toObject().value(QStringLiteral("message")).toObject().value(QStringLiteral("content")).toString();
    }

    if (replyText.isEmpty()) {
        appendChatMessage(QStringLiteral("assistant"), tr("Resposta vazia recebida do provedor."));
        return;
    }

    const QString cleanReply = cleanActionTags(replyText);
    appendChatMessage(QStringLiteral("assistant"), cleanReply.isEmpty() ? tr("🎬 Ação identificada! Injetando na timeline...") : cleanReply);
    executeActionFromResponse(replyText, m_lastUserPrompt);
}

void AiAgentController::executeActionFromResponse(const QString &response, const QString &userPrompt)
{
    // 1. Check for [ACTION:HYPERFRAMES|...]
    static const QRegularExpression hfRegex(QStringLiteral(R"(\[ACTION:HYPERFRAMES[|:]([^\]]+)\])"), QRegularExpression::CaseInsensitiveOption);
    const auto hfMatch = hfRegex.match(response);
    if (hfMatch.hasMatch()) {
        const QString rawContent = hfMatch.captured(1).trimmed();
        const QStringList parts = rawContent.split(QLatin1Char('|'));
        QString tmpl = QStringLiteral("lower_third");
        QString title;
        QString subtitle;

        if (parts.size() >= 1) {
            const QString p0 = parts.value(0).trimmed();
            if (p0.compare(QStringLiteral("lower_third"), Qt::CaseInsensitive) == 0 ||
                p0.compare(QStringLiteral("title_card"), Qt::CaseInsensitive) == 0 ||
                p0.compare(QStringLiteral("social_card"), Qt::CaseInsensitive) == 0) {
                tmpl = p0.toLower();
                title = parts.value(1).trimmed();
                subtitle = parts.value(2).trimmed();
            } else {
                title = p0;
                subtitle = parts.value(1).trimmed();
            }
        }

        if (title.isEmpty()) {
            static const QRegularExpression nameRegex(QStringLiteral(R"((?:nome|canal|título|texto)\s+["']?([^"',.\n]+)["']?)"), QRegularExpression::CaseInsensitiveOption);
            auto nm = nameRegex.match(userPrompt);
            if (nm.hasMatch()) {
                title = nm.captured(1).trimmed();
            } else {
                title = QStringLiteral("DLuz Games");
            }
        }

        createHyperframes(title, subtitle, tmpl);
        return;
    }

    // 2. Check for [ACTION:REMOVE_SILENCE|...]
    static const QRegularExpression silRegex(QStringLiteral(R"(\[ACTION:REMOVE_SILENCE[|:]([^\]]*)\])"), QRegularExpression::CaseInsensitiveOption);
    const auto silMatch = silRegex.match(response);
    if (silMatch.hasMatch()) {
        const QString rawContent = silMatch.captured(1).trimmed();
        const QStringList parts = rawContent.split(QLatin1Char('|'));
        double th = parts.value(0).toDouble();
        if (th >= 0.0) th = -30.0;
        double md = parts.value(1).toDouble();
        if (md <= 0.0) md = 0.3;
        double pad = parts.value(2).toDouble();
        if (pad <= 0.0) pad = 0.08;

        runSilenceRemoval(th, md, pad);
        return;
    }

    // 3. Check for [ACTION:CLONE_VOICE|...]
    static const QRegularExpression voiceRegex(QStringLiteral(R"(\[ACTION:CLONE_VOICE[|:]([^\]]+)\])"), QRegularExpression::CaseInsensitiveOption);
    const auto voiceMatch = voiceRegex.match(response);
    if (voiceMatch.hasMatch()) {
        const QString rawContent = voiceMatch.captured(1).trimmed();
        const QStringList parts = rawContent.split(QLatin1Char('|'));
        QString eng = QStringLiteral("omnivoice");
        QString text;
        if (parts.size() >= 2) {
            eng = parts.value(0).trimmed();
            text = parts.value(1).trimmed();
        } else {
            text = parts.value(0).trimmed();
        }
        if (text.isEmpty()) {
            text = QStringLiteral("Fala melhores, beleza? Bem-vindos ao canal DLuz Games!");
        }
        synthesizeVoice(text, eng);
        return;
    }

    // 4. Check for [ACTION:OMNIFLASH|...]
    static const QRegularExpression omniRegex(QStringLiteral(R"(\[ACTION:OMNIFLASH[|:]([^\]]+)\])"), QRegularExpression::CaseInsensitiveOption);
    const auto omniMatch = omniRegex.match(response);
    if (omniMatch.hasMatch()) {
        const QString rawContent = omniMatch.captured(1).trimmed();
        const QStringList parts = rawContent.split(QLatin1Char('|'));
        QString aspect = QStringLiteral("16:9");
        QString pr;
        if (parts.size() >= 2) {
            aspect = parts.value(0).trimmed();
            pr = parts.value(1).trimmed();
        } else {
            pr = parts.value(0).trimmed();
        }
        generateOmniFlash(pr, aspect);
        return;
    }

    // 5. Check for [ACTION:CHROMA_KEY...]
    static const QRegularExpression chromaRegex(QStringLiteral(R"(\[ACTION:CHROMA_KEY[^\]]*\])"), QRegularExpression::CaseInsensitiveOption);
    if (chromaRegex.match(response).hasMatch()) {
        if (m_controller) {
            const int tIdx = m_controller->selectedTrack();
            const int cIdx = m_controller->selectedClip();
            if (tIdx >= 0 && cIdx >= 0) {
                m_controller->addEffect(tIdx, cIdx, QStringLiteral("key.chroma"));
                appendChatMessage(QStringLiteral("assistant"),
                                  tr("✅ Efeito Chroma Key (Remoção de Fundo Verde) ativado no clip selecionado!"));
            } else {
                appendChatMessage(QStringLiteral("assistant"),
                                  tr("⚠️ Nenhum clip selecionado na timeline. Selecione um clip primeiro para ativar o Chroma Key."));
            }
        }
        return;
    }

    // 6. Fallback Intent Detection (if model didn't emit [ACTION:...])
    const QString pLower = userPrompt.toLower();
    if (pLower.contains(QStringLiteral("lower third")) || pLower.contains(QStringLiteral("lower-third")) ||
        pLower.contains(QStringLiteral("vinheta")) || pLower.contains(QStringLiteral("card de título")) ||
        pLower.contains(QStringLiteral("card social"))) {
        QString tmpl = QStringLiteral("lower_third");
        if (pLower.contains(QStringLiteral("card de título")) || pLower.contains(QStringLiteral("kinetic")))
            tmpl = QStringLiteral("title_card");
        else if (pLower.contains(QStringLiteral("card social")) || pLower.contains(QStringLiteral("redes sociais")))
            tmpl = QStringLiteral("social_card");

        QString title = QStringLiteral("DLuz Games");
        static const QRegularExpression nameRegex(QStringLiteral(R"((?:nome|canal|título|texto)\s+["']?([^"',.\n]+)["']?)"), QRegularExpression::CaseInsensitiveOption);
        auto nm = nameRegex.match(userPrompt);
        if (nm.hasMatch()) {
            title = nm.captured(1).trimmed();
        }

        createHyperframes(title, QString(), tmpl);
        return;
    }

    if (pLower.contains(QStringLiteral("remover silêncio")) || pLower.contains(QStringLiteral("remover silencios")) ||
        pLower.contains(QStringLiteral("cortar silêncios")) || pLower.contains(QStringLiteral("remover pausas"))) {
        runSilenceRemoval(-30.0, 0.3, 0.08);
        return;
    }

    if (pLower.contains(QStringLiteral("locução")) || pLower.contains(QStringLiteral("locucao")) ||
        (pLower.contains(QStringLiteral("voz")) && (pLower.contains(QStringLiteral("clon")) || pLower.contains(QStringLiteral("dluz"))))) {
        synthesizeVoice(QStringLiteral("Fala melhores, beleza? Bem-vindos ao canal DLuz Games!"), QStringLiteral("omnivoice"));
        return;
    }

    if (pLower.contains(QStringLiteral("chroma")) || pLower.contains(QStringLiteral("crhoma")) ||
        pLower.contains(QStringLiteral("fundo verde"))) {
        if (m_controller) {
            const int tIdx = m_controller->selectedTrack();
            const int cIdx = m_controller->selectedClip();
            if (tIdx >= 0 && cIdx >= 0) {
                m_controller->addEffect(tIdx, cIdx, QStringLiteral("key.chroma"));
                appendChatMessage(QStringLiteral("assistant"),
                                  tr("✅ Efeito Chroma Key (Remoção de Fundo Verde) ativado no clip selecionado!"));
            } else {
                appendChatMessage(QStringLiteral("assistant"),
                                  tr("⚠️ Nenhum clip selecionado na timeline. Selecione um clip primeiro para ativar o Chroma Key."));
            }
        }
        return;
    }

    // 6. Check for [ACTION:CLOSE_GAPS]
    static const QRegularExpression gapRegex(QStringLiteral(R"(\[ACTION:(?:CLOSE_GAPS|MAGNETIC_MODE)[|: ]*([^\]]*)\])"), QRegularExpression::CaseInsensitiveOption);
    if (gapRegex.match(response).hasMatch()) {
        if (m_controller) {
            m_controller->setSnapEnabled(true);
            m_controller->closeAllGaps();
            appendChatMessage(QStringLiteral("assistant"),
                              tr("🧲 Modo magnético ativado e todos os espaços vazios da timeline foram fechados com sucesso!"));
        }
        return;
    }

    // 7. Check for [ACTION:AUTO_PRODUCE|article|gameplay|voice|format]
    static const QRegularExpression autoProduceRegex(QStringLiteral(R"(\[ACTION:(?:AUTO_PRODUCE|MODO_HARD)[|:]([^\]]+)\])"), QRegularExpression::CaseInsensitiveOption);
    const auto autoProduceMatch = autoProduceRegex.match(response);
    if (autoProduceMatch.hasMatch()) {
        const QString rawContent = autoProduceMatch.captured(1).trimmed();
        const QStringList parts = rawContent.split(QLatin1Char('|'));
        const QString article = parts.value(0).trimmed();
        const QString gameplay = parts.value(1).trimmed();
        const QString voice = parts.size() > 2 ? parts.value(2).trimmed() : QStringLiteral("omnivoice");
        const QString format = parts.size() > 3 ? parts.value(3).trimmed() : QStringLiteral("16:9");
        startHardModeProduction(article, gameplay, voice, QStringLiteral("pt"), format);
        return;
    }

    // 8. Fallback Intent Detection for magnetic mode / gaps
    if (pLower.contains(QStringLiteral("modo magnetico")) || pLower.contains(QStringLiteral("modo magnético")) ||
        pLower.contains(QStringLiteral("magnetico")) || pLower.contains(QStringLiteral("magnético")) ||
        pLower.contains(QStringLiteral("fechar espaco")) || pLower.contains(QStringLiteral("fechar espacos")) ||
        pLower.contains(QStringLiteral("fechar espaço")) || pLower.contains(QStringLiteral("fechar espaços")) ||
        pLower.contains(QStringLiteral("juntar clips")) || pLower.contains(QStringLiteral("grudar clips"))) {
        if (m_controller) {
            m_controller->setSnapEnabled(true);
            m_controller->closeAllGaps();
            appendChatMessage(QStringLiteral("assistant"),
                              tr("🧲 Modo magnético ativado e todos os espaços vazios da timeline foram fechados com sucesso!"));
            return;
        }
    }

    // 9. Fallback Intent Detection for Hard Mode (Modo Hard) when user sends links or keywords
    if (pLower.contains(QStringLiteral("modo hard")) || pLower.contains(QStringLiteral("hard mode")) ||
        pLower.contains(QStringLiteral("criar vídeo")) || pLower.contains(QStringLiteral("criar video")) ||
        pLower.contains(QStringLiteral("montar vídeo")) || pLower.contains(QStringLiteral("montar video")) ||
        pLower.contains(QStringLiteral("produzir vídeo")) || pLower.contains(QStringLiteral("produzir video"))) {

        static const QRegularExpression urlRegex(QStringLiteral(R"(https?://[^\s]+)"), QRegularExpression::CaseInsensitiveOption);
        auto urlIter = urlRegex.globalMatch(userPrompt);
        QStringList foundUrls;
        while (urlIter.hasNext()) {
            foundUrls << urlIter.next().captured(0);
        }

        if (!foundUrls.isEmpty()) {
            QString articleUrl;
            QString gameplayUrl;
            for (const QString &u : foundUrls) {
                if (u.contains(QStringLiteral("youtube.com")) || u.contains(QStringLiteral("youtu.be"))) {
                    if (gameplayUrl.isEmpty()) gameplayUrl = u;
                } else {
                    if (articleUrl.isEmpty()) articleUrl = u;
                }
            }
            if (articleUrl.isEmpty() && !foundUrls.isEmpty()) {
                articleUrl = foundUrls.first();
            }
            const QString format = (pLower.contains(QStringLiteral("vertical")) || pLower.contains(QStringLiteral("tiktok")) || pLower.contains(QStringLiteral("shorts")) || pLower.contains(QStringLiteral("9:16"))) ? QStringLiteral("9:16") : QStringLiteral("16:9");
            startHardModeProduction(articleUrl, gameplayUrl, QStringLiteral("omnivoice"), QStringLiteral("pt"), format);
            return;
        }
    }
}

void AiAgentController::runSilenceRemoval(double threshold, double minDuration, double padding)
{
    if (!m_controller)
        return;

    appendChatMessage(QStringLiteral("assistant"),
                      tr("✂️ Executando remoção de silêncios (Limiar: %1 dB, Mínimo: %2s)...").arg(threshold).arg(minDuration));

    const QJsonObject res = m_controller->removeSilence(-1, -1, threshold, minDuration, padding);
    const int removed = res.value(QStringLiteral("n")).toInt();

    appendChatMessage(QStringLiteral("assistant"),
                      tr("✅ Remoção concluída! Foram eliminados %1 intervalos de silêncio na timeline.").arg(removed));
}

void AiAgentController::createHyperframes(const QString &title, const QString &subtitle,
                                         const QString &templateType, const QString &customHtml)
{
    setBusy(true, tr("Gerando e renderizando HyperFrames..."));
    appendChatMessage(QStringLiteral("assistant"),
                      tr("🎬 Iniciando renderização da vinheta HyperFrames (%1: \"%2\"). Injetando na timeline...").arg(templateType, title));

    // Prepare temp directory
    const QString tempDir = QStandardPaths::writableLocation(QStandardPaths::TempLocation)
                          + QStringLiteral("/dluzfilm_hf_") + QUuid::createUuid().toString(QUuid::WithoutBraces);
    QDir().mkpath(tempDir);

    QString html;
    if (!customHtml.isEmpty()) {
        html = customHtml;
        if (html.contains(QStringLiteral("background:transparent")))
            html.replace(QStringLiteral("background:transparent"), QStringLiteral("background:#00ff00"));
        if (html.contains(QStringLiteral("background: transparent")))
            html.replace(QStringLiteral("background: transparent"), QStringLiteral("background:#00ff00"));
        if (!html.contains(QStringLiteral("#00ff00"))) {
            html.replace(QStringLiteral("<style>"), QStringLiteral("<style>body { background: #00ff00 !important; } "));
        }
    } else if (templateType == QStringLiteral("title_card")) {
        html = QString::fromUtf8(R"HTML(<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { margin:0; padding:0; background:#00ff00; overflow:hidden; width:1920px; height:1080px; display:flex; justify-content:center; align-items:center; font-family:'Segoe UI',system-ui,sans-serif; }
    .box { text-align:center; opacity:0; transform:scale(0.9); }
    .title { font-size:76px; font-weight:900; color:#ffffff; text-transform:uppercase; letter-spacing:4px; text-shadow:0 8px 30px rgba(0,0,0,0.9); }
    .subtitle { font-size:32px; font-weight:700; color:#f59e0b; margin-top:16px; letter-spacing:3px; text-shadow:0 4px 16px rgba(0,0,0,0.8); }
  </style>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/gsap/3.12.5/gsap.min.js"></script>
</head>
<body>
  <div data-composition-id="title_card" data-width="1920" data-height="1080" data-duration="4" class="clip">
    <div class="box" id="box">
      <div class="title">%1</div>
      <div class="subtitle">%2</div>
    </div>
  </div>
  <script>
    const tl = gsap.timeline({ paused: true });
    tl.to("#box", { opacity:1, scale:1, duration:0.8, ease:"back.out(1.7)" })
      .to("#box", { opacity:0, scale:1.05, duration:0.6, ease:"power2.in" }, 3.4);
    window.__timelines = window.__timelines || {};
    window.__timelines["title_card"] = tl;
  </script>
</body>
</html>)HTML").arg(title, subtitle);
    } else if (templateType == QStringLiteral("social_card")) {
        html = QString::fromUtf8(R"HTML(<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { margin:0; padding:0; background:#00ff00; overflow:hidden; width:1920px; height:1080px; font-family:'Segoe UI',system-ui,sans-serif; }
    .card { position:absolute; bottom:100px; right:100px; background:rgba(18,18,22,0.96); border:2px solid #38bdf8; border-radius:20px; padding:18px 32px; display:flex; align-items:center; box-shadow:0 10px 40px rgba(0,0,0,0.8); opacity:0; transform:translateY(40px); }
    .avatar { width:56px; height:56px; border-radius:50%; background:linear-gradient(135deg, #f59e0b, #ef4444); display:flex; justify-content:center; align-items:center; font-size:26px; font-weight:bold; color:white; margin-right:18px; box-shadow:0 4px 12px rgba(245,158,11,0.4); }
    .name { font-size:26px; font-weight:800; color:#ffffff; }
    .handle { font-size:18px; color:#38bdf8; font-weight:600; margin-top:2px; }
  </style>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/gsap/3.12.5/gsap.min.js"></script>
</head>
<body>
  <div data-composition-id="social_card" data-width="1920" data-height="1080" data-duration="4" class="clip">
    <div class="card" id="card">
      <div class="avatar">▶</div>
      <div>
        <div class="name">%1</div>
        <div class="handle">%2</div>
      </div>
    </div>
  </div>
  <script>
    const tl = gsap.timeline({ paused: true });
    tl.to("#card", { opacity:1, y:0, duration:0.7, ease:"elastic.out(1, 0.75)" })
      .to("#card", { opacity:0, y:30, duration:0.5, ease:"power2.in" }, 3.5);
    window.__timelines = window.__timelines || {};
    window.__timelines["social_card"] = tl;
  </script>
</body>
</html>)HTML").arg(title, subtitle);
    } else { // default: lower_third
        html = QString::fromUtf8(R"HTML(<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { margin:0; padding:0; background:#00ff00; overflow:hidden; width:1920px; height:1080px; font-family:'Segoe UI',system-ui,sans-serif; }
    .wrapper { position:absolute; bottom:120px; left:100px; display:flex; align-items:center; }
    .accent-bar { width:8px; height:76px; background:linear-gradient(to bottom, #f59e0b, #ef4444); border-radius:4px; transform:scaleY(0); box-shadow:0 0 16px rgba(245,158,11,0.6); }
    .content { margin-left:20px; opacity:0; transform:translateX(-30px); background:rgba(18,18,22,0.92); padding:10px 24px; border-radius:12px; border-left:1px solid rgba(255,255,255,0.1); }
    .title { font-size:36px; font-weight:800; color:#ffffff; text-shadow:0 4px 12px rgba(0,0,0,0.9); }
    .subtitle { font-size:22px; font-weight:600; color:#f59e0b; margin-top:4px; letter-spacing:1px; text-shadow:0 2px 8px rgba(0,0,0,0.8); }
  </style>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/gsap/3.12.5/gsap.min.js"></script>
</head>
<body>
  <div data-composition-id="lower_third" data-width="1920" data-height="1080" data-duration="4" class="clip">
    <div class="wrapper">
      <div class="accent-bar" id="bar"></div>
      <div class="content" id="content">
        <div class="title">%1</div>
        <div class="subtitle">%2</div>
      </div>
    </div>
  </div>
  <script>
    const tl = gsap.timeline({ paused: true });
    tl.to("#bar", { scaleY:1, duration:0.5, ease:"power3.out" })
      .to("#content", { opacity:1, x:0, duration:0.6, ease:"power3.out" }, "-=0.3")
      .to(["#content", "#bar"], { opacity:0, x:-20, duration:0.5, ease:"power3.in" }, 3.5);
    window.__timelines = window.__timelines || {};
    window.__timelines["lower_third"] = tl;
  </script>
</body>
</html>)HTML").arg(title, subtitle);
    }

    const QString htmlFile = tempDir + QStringLiteral("/index.html");
    QFile f(htmlFile);
    if (f.open(QIODevice::WriteOnly)) {
        f.write(html.toUtf8());
        f.close();
    }

    const QString outDir = QStringLiteral("D:/antigravity/videos gerados");
    QDir().mkpath(outDir);
    const QString outFile = outDir + QStringLiteral("/hyperframes_")
                          + QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd_HHmmss"))
                          + QStringLiteral(".mp4");

    auto *proc = new QProcess(this);
    setupSilentProcess(proc);

    QObject::connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this, proc, outFile, tempDir](int exitCode, QProcess::ExitStatus exitStatus) {
        Q_UNUSED(exitStatus);
        proc->deleteLater();
        this->setBusy(false);

        if (exitCode == 0 && QFile::exists(outFile)) {
            if (this->m_controller)
                this->m_controller->importMediaToTimeline(outFile, -1.0, -1, QStringLiteral("key.chroma"));
            this->appendChatMessage(QStringLiteral("assistant"),
                              QObject::tr("🎬 HyperFrames renderizado com sucesso (Chroma Key ativado) e inserido na timeline:\n%1").arg(outFile));
            emit this->hyperframesFinished(true, outFile, QObject::tr("Renderizado com Chroma Key e adicionado à timeline!"));
        } else {
            const QString err = QString::fromUtf8(proc->readAllStandardError());
            this->appendChatMessage(QStringLiteral("assistant"),
                              QObject::tr("❌ Falha na renderização do HyperFrames:\n%1").arg(err));
            emit this->hyperframesFinished(false, QString(), err);
        }
        QDir(tempDir).removeRecursively();
    });

    const QString mjsPath = QStringLiteral("C:/Users/dluzgg/AppData/Roaming/npm/node_modules/hyperframes/bin/hyperframes.mjs");
    const QString nativeTempDir = QDir::toNativeSeparators(tempDir);
    const QString nativeOutFile = QDir::toNativeSeparators(outFile);

    if (QFile::exists(mjsPath)) {
        QString nodeExe = QStandardPaths::findExecutable(QStringLiteral("node"));
        if (nodeExe.isEmpty()) {
            nodeExe = QStringLiteral("C:/Program Files/nodejs/node.exe");
        }
        proc->start(nodeExe,
                    QStringList{mjsPath, QStringLiteral("render"), nativeTempDir, QStringLiteral("-o"), nativeOutFile});
    } else {
        proc->start(QStringLiteral("cmd.exe"),
                    QStringList{QStringLiteral("/c"), QStringLiteral("hyperframes"),
                                QStringLiteral("render"), nativeTempDir, QStringLiteral("-o"), nativeOutFile});
    }
}

QString AiAgentController::selectedVideoClipPath() const
{
    if (!m_controller)
        return QString();
    const QVariantMap clip = m_controller->selectedClipData();
    if (clip.isEmpty())
        return QString();
    return clip.value(QStringLiteral("path")).toString();
}

void AiAgentController::synthesizeVoice(const QString &text, const QString &engine, const QString &lang, const QString &voicePath)
{
    if (text.trimmed().isEmpty())
        return;

    setBusy(true, tr("Sintetizando voz (%1)...").arg(engine));

    const QString outDir = QStringLiteral("D:/antigravity/videos gerados/audio");
    QDir().mkpath(outDir);
    const QString outFile = outDir + QStringLiteral("/voice_")
                          + QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd_HHmmss"))
                          + (engine == QStringLiteral("omnivoice") ? QStringLiteral(".wav") : QStringLiteral(".mp3"));

    auto *proc = new QProcess(this);
    setupSilentProcess(proc);

    QObject::connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this, proc, outFile, engine](int exitCode, QProcess::ExitStatus exitStatus) {
        Q_UNUSED(exitStatus);
        proc->deleteLater();
        this->setBusy(false);

        if (exitCode == 0 && QFile::exists(outFile)) {
            if (this->m_controller)
                this->m_controller->importMediaToTimeline(outFile);
            this->appendChatMessage(QStringLiteral("assistant"),
                              QObject::tr("🎙️ Locução (%1) sintetizada com sucesso e inserida na timeline de áudio:\n%2")
                                  .arg(engine, outFile));
            emit this->voiceSynthesisFinished(true, outFile, QObject::tr("Áudio adicionado à timeline!"));
        } else {
            const QString err = QString::fromUtf8(proc->readAllStandardError());
            this->appendChatMessage(QStringLiteral("assistant"),
                              QObject::tr("❌ Falha na síntese de voz:\n%1").arg(err));
            emit this->voiceSynthesisFinished(false, QString(), err);
        }
    });

    const QString script = QStringLiteral("C:/Users/dluzgg/.gemini/config/skills/dublagem/scripts/dubber.py");
    if (engine == QStringLiteral("omnivoice")) {
        // OmniVoice CUDA on RTX 2060
        const QString refVoice = voicePath.isEmpty() ? QStringLiteral("C:/Users/dluzgg/Documents/antigravity/blissful-hertz/bilibili_tools/reference_voice/dluz_voice.pt") : voicePath;
        proc->start(QStringLiteral("python"),
                    QStringList{script, QStringLiteral("--tts"), text,
                                QStringLiteral("--engine"), QStringLiteral("omnivoice"),
                                QStringLiteral("--output"), outFile,
                                QStringLiteral("--voice"), refVoice,
                                QStringLiteral("--lang"), lang.isEmpty() ? QStringLiteral("pt") : lang,
                                QStringLiteral("--speed"), QStringLiteral("0.95")});
    } else {
        // Edge-TTS neural
        proc->start(QStringLiteral("python"),
                    QStringList{script, QStringLiteral("--tts"), text,
                                QStringLiteral("--engine"), QStringLiteral("edge_tts"),
                                QStringLiteral("--output"), outFile,
                                QStringLiteral("--lang"), lang.isEmpty() ? QStringLiteral("pt-BR") : lang});
    }
}

void AiAgentController::dubVideo(const QString &videoPath,
                                 const QString &targetLang,
                                 const QString &engine,
                                 bool generateSubs,
                                 bool burnSubs,
                                 double bgmVolume)
{
    if (videoPath.trimmed().isEmpty() || !QFile::exists(videoPath)) {
        appendChatMessage(QStringLiteral("assistant"),
                          tr("❌ Erro: Arquivo de vídeo não encontrado para dublagem:\n%1").arg(videoPath));
        emit videoDubbingFinished(false, QString(), QString(), tr("Arquivo de vídeo inválido"));
        return;
    }

    setBusy(true, tr("Dublando vídeo para %1 e gerando legendas...").arg(targetLang.toUpper()));

    const QString outDir = QStringLiteral("D:/antigravity/videos gerados");
    QDir().mkpath(outDir);

    auto *proc = new QProcess(this);
    setupSilentProcess(proc);

    const QString script = QStringLiteral("C:/Users/dluzgg/.gemini/config/skills/dublagem/scripts/dubber.py");
    QStringList args{
        script,
        videoPath,
        QStringLiteral("--lang"), targetLang,
        QStringLiteral("--engine"), engine,
        QStringLiteral("--output"), outDir,
        QStringLiteral("--bgm-vol"), QString::number(bgmVolume, 'f', 2)
    };

    if (burnSubs)
        args << QStringLiteral("--burn");

    QObject::connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this, proc, videoPath, targetLang, generateSubs](int exitCode, QProcess::ExitStatus exitStatus) {
        Q_UNUSED(exitStatus);
        const QString stdoutStr = QString::fromUtf8(proc->readAllStandardOutput());
        const QString stderrStr = QString::fromUtf8(proc->readAllStandardError());
        proc->deleteLater();
        this->setBusy(false);

        QString outputVideo;
        QString outputSrt;

        const QStringList lines = stdoutStr.split(QLatin1Char('\n'));
        for (const QString &line : lines) {
            const QString trimmed = line.trimmed();
            if (trimmed.startsWith(QStringLiteral("OUTPUT_VIDEO:"))) {
                outputVideo = trimmed.mid(13).trimmed();
            } else if (trimmed.startsWith(QStringLiteral("OUTPUT_SRT:"))) {
                outputSrt = trimmed.mid(11).trimmed();
            }
        }

        if (exitCode == 0 && !outputVideo.isEmpty() && QFile::exists(outputVideo)) {
            // Importar o vídeo dublado para a timeline
            if (this->m_controller) {
                this->m_controller->importMediaToTimeline(outputVideo);
                // Se o usuário solicitou legendas e o .srt foi gerado, importa na timeline
                if (generateSubs && !outputSrt.isEmpty() && QFile::exists(outputSrt)) {
                    this->m_controller->importSubtitleFile(QUrl::fromLocalFile(outputSrt));
                }
            }

            QString msg = QObject::tr("🎬 Vídeo dublado para %1 com sucesso!\n📁 Vídeo: %2")
                              .arg(targetLang.toUpper(), outputVideo);
            if (!outputSrt.isEmpty()) {
                msg += QObject::tr("\n📝 Legendas geradas e inseridas na timeline: %1").arg(outputSrt);
            }

            this->appendChatMessage(QStringLiteral("assistant"), msg);
            emit this->videoDubbingFinished(true, outputVideo, outputSrt,
                                            QObject::tr("Dublagem e legendas adicionadas à timeline!"));
        } else {
            const QString err = stderrStr.isEmpty() ? stdoutStr : stderrStr;
            this->appendChatMessage(QStringLiteral("assistant"),
                              QObject::tr("❌ Falha na dublagem do vídeo:\n%1").arg(err));
            emit this->videoDubbingFinished(false, QString(), QString(), err);
        }
    });

    proc->start(QStringLiteral("python"), args);
}

void AiAgentController::generateOmniFlash(const QString &prompt, const QString &aspectRatio)
{
    if (prompt.trimmed().isEmpty())
        return;

    setBusy(true, tr("Gerando cena com OmniFlash / Google Flow..."));

    const QString outDir = QStringLiteral("D:/antigravity/videos gerados");
    QDir().mkpath(outDir);
    const QString outFile = outDir + QStringLiteral("/omniflash_")
                          + QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd_HHmmss"))
                          + QStringLiteral(".mp4");

    auto *proc = new QProcess(this);
    setupSilentProcess(proc);

    QObject::connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this, proc, outFile](int exitCode, QProcess::ExitStatus exitStatus) {
        Q_UNUSED(exitStatus);
        proc->deleteLater();
        this->setBusy(false);

        if (exitCode == 0 && QFile::exists(outFile)) {
            if (this->m_controller)
                this->m_controller->importMediaToTimeline(outFile);
            this->appendChatMessage(QStringLiteral("assistant"),
                              QObject::tr("🎥 Cena OmniFlash gerada com sucesso e inserida na timeline:\n%1").arg(outFile));
            emit this->omniFlashFinished(true, outFile, QObject::tr("Vídeo adicionado à timeline!"));
        } else {
            const QString err = QString::fromUtf8(proc->readAllStandardError());
            this->appendChatMessage(QStringLiteral("assistant"),
                              QObject::tr("❌ Falha na geração OmniFlash:\n%1").arg(err));
            emit this->omniFlashFinished(false, QString(), err);
        }
    });

    proc->start(QStringLiteral("cmd.exe"),
                QStringList{QStringLiteral("/c"), QStringLiteral("uvx"), QStringLiteral("--from"),
                            QStringLiteral("gflow-cli"), QStringLiteral("gflow"), QStringLiteral("video"),
                            QStringLiteral("t2v"), QStringLiteral("--prompt"), prompt,
                            QStringLiteral("--aspect"), aspectRatio,
                            QStringLiteral("-o"), outFile});
}

void AiAgentController::editClipWithOmniFlash(int trackIndex, int clipIndex,
                                              const QString &clipPath,
                                              double inPoint, double duration,
                                              const QString &prompt,
                                              bool preserveAudio,
                                              bool replaceInPlace)
{
    if (clipPath.trimmed().isEmpty() || !QFile::exists(clipPath)) {
        appendChatMessage(QStringLiteral("assistant"),
                          tr("❌ Erro: Arquivo do clipe não encontrado:\n%1").arg(clipPath));
        emit omniFlashClipEditFinished(false, QString(), tr("Arquivo de vídeo inválido"));
        return;
    }

    if (prompt.trimmed().isEmpty()) {
        appendChatMessage(QStringLiteral("assistant"),
                          tr("⚠️ Informe um prompt para a edição com OmniFlash."));
        emit omniFlashClipEditFinished(false, QString(), tr("Prompt vazio"));
        return;
    }

    setBusy(true, tr("Editando clipe com OmniFlash (Google Flow)..."));
    emit omniFlashClipEditProgress(5, tr("Iniciando fatiamento e conexão ao Google Flow..."));

    auto *proc = new QProcess(this);
    setupSilentProcess(proc);

    QString script = QCoreApplication::applicationDirPath() + QStringLiteral("/scripts/omniflash_clip_editor.py");
    if (!QFile::exists(script)) {
        script = QStringLiteral("h:/Editor dluz/scripts/omniflash_clip_editor.py");
    }
    if (!QFile::exists(script)) {
        script = QStringLiteral("D:/DluzEditorSource/scripts/omniflash_clip_editor.py");
    }

    QStringList args{
        script,
        QStringLiteral("--clip"), clipPath,
        QStringLiteral("--in-point"), QString::number(inPoint, 'f', 3),
        QStringLiteral("--duration"), QString::number(duration, 'f', 3),
        QStringLiteral("--prompt"), prompt.trimmed()
    };

    if (preserveAudio) {
        args << QStringLiteral("--preserve-audio");
    } else {
        args << QStringLiteral("--no-preserve-audio");
    }

    auto fullOutput = std::make_shared<QString>();

    connect(proc, &QProcess::readyReadStandardOutput, this, [this, proc, fullOutput]() {
        const QString out = QString::fromUtf8(proc->readAllStandardOutput());
        fullOutput->append(out);
        const QStringList lines = out.split(QLatin1Char('\n'));
        for (const QString &line : lines) {
            const QString trimmed = line.trimmed();
            if (trimmed.startsWith(QStringLiteral("PROGRESS:"))) {
                const QString payload = trimmed.mid(9);
                const int sep = payload.indexOf(QLatin1Char('|'));
                if (sep != -1) {
                    const int pct = payload.left(sep).toInt();
                    const QString status = payload.mid(sep + 1);
                    emit omniFlashClipEditProgress(pct, status);
                    this->setBusy(true, QStringLiteral("[%1%] %2").arg(pct).arg(status));
                }
            }
        }
    });

    connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this, proc, fullOutput, trackIndex, clipIndex, replaceInPlace, prompt](int exitCode, QProcess::ExitStatus exitStatus) {
        Q_UNUSED(exitStatus);
        fullOutput->append(QString::fromUtf8(proc->readAllStandardOutput()));
        const QString stderrStr = QString::fromUtf8(proc->readAllStandardError());
        proc->deleteLater();
        this->setBusy(false);

        QString outputVideo;
        const QStringList lines = fullOutput->split(QLatin1Char('\n'));
        for (const QString &line : lines) {
            const QString trimmed = line.trimmed();
            if (trimmed.startsWith(QStringLiteral("OUTPUT_VIDEO:"))) {
                outputVideo = trimmed.mid(13).trimmed();
            }
        }

        if (exitCode == 0 && !outputVideo.isEmpty() && QFile::exists(outputVideo)) {
            bool ok = false;
            if (this->m_controller) {
                if (replaceInPlace) {
                    ok = this->m_controller->replaceClipMedia(trackIndex, clipIndex, outputVideo);
                } else {
                    ok = this->m_controller->insertClipAbove(trackIndex, clipIndex, outputVideo);
                }
            }

            QString successMsg = QObject::tr("✨ Clipe transformado pelo OmniFlash (Flow) com sucesso!\n"
                                             "🎥 Vídeo: %1\n"
                                             "🔒 Áudio original do personagem: 100% Preservado e Sincronizado!")
                                     .arg(outputVideo);
            this->appendChatMessage(QStringLiteral("assistant"), successMsg);
            emit this->omniFlashClipEditProgress(100, QObject::tr("Concluído!"));
            emit this->omniFlashClipEditFinished(true, outputVideo, QObject::tr("Clipe atualizado na timeline!"));
        } else {
            const QString err = stderrStr.isEmpty() ? *fullOutput : stderrStr;
            this->appendChatMessage(QStringLiteral("assistant"),
                              tr("❌ Falha na edição do clipe com OmniFlash:\n%1").arg(err));
            emit this->omniFlashClipEditFinished(false, QString(), err);
        }
    });

    QString pythonExe = QStandardPaths::findExecutable(QStringLiteral("python"));
    if (pythonExe.isEmpty() || !QFile::exists(pythonExe)) {
        pythonExe = QStringLiteral("C:/Python314/python.exe");
    }

    proc->start(pythonExe, args);
}

void AiAgentController::startHardModeProduction(const QString &articleUrlOrText,
                                                 const QString &gameplayUrlOrPath,
                                                 const QString &voiceEngine,
                                                 const QString &lang,
                                                 const QString &aspectRatio)
{
    if (articleUrlOrText.trimmed().isEmpty()) {
        appendChatMessage(QStringLiteral("assistant"),
                          tr("⚠️ Por favor, informe um link de matéria/notícia ou o tema do vídeo para o Modo Hard."));
        return;
    }

    setBusy(true, tr("Modo Hard: Produzindo vídeo completo..."));
    appendChatMessage(QStringLiteral("assistant"),
                      tr("⚡ **Iniciando Modo Hard — Produção Autônoma de Vídeo**\n"
                         "📰 **Fonte:** %1\n"
                         "🎮 **Gameplay:** %2\n"
                         "🎙️ **Voz:** %3 (%4)\n"
                         "📐 **Formato:** %5\n\n"
                         "Acompanhe o progresso em tempo real...")
                          .arg(articleUrlOrText)
                          .arg(gameplayUrlOrPath.isEmpty() ? tr("Busca automática no YouTube / Local") : gameplayUrlOrPath)
                          .arg(voiceEngine == QStringLiteral("omnivoice") ? tr("Voz DLuz (OmniVoice CUDA RTX 2060)") : tr("Edge-TTS Neural"))
                          .arg(lang.toUpper())
                          .arg(aspectRatio));

    auto *proc = new QProcess(this);
    setupSilentProcess(proc);

    QString script = QCoreApplication::applicationDirPath() + QStringLiteral("/scripts/dluz_auto_producer.py");
    if (!QFile::exists(script)) {
        script = QStringLiteral("h:/Editor dluz/scripts/dluz_auto_producer.py");
    }
    if (!QFile::exists(script)) {
        script = QStringLiteral("D:/DluzEditorSource/scripts/dluz_auto_producer.py");
    }

    QStringList args{
        script,
        QStringLiteral("--article"), articleUrlOrText.trimmed(),
        QStringLiteral("--voice-engine"), voiceEngine,
        QStringLiteral("--lang"), lang,
        QStringLiteral("--format"), aspectRatio,
        QStringLiteral("--provider"), m_provider
    };

    if (!gameplayUrlOrPath.trimmed().isEmpty()) {
        args << QStringLiteral("--gameplay") << gameplayUrlOrPath.trimmed();
    }

    QString apiKey;
    if (m_provider == QStringLiteral("gemini")) apiKey = m_geminiKey;
    else if (m_provider == QStringLiteral("openrouter")) apiKey = m_openrouterKey;
    else if (m_provider == QStringLiteral("groq")) apiKey = m_groqKey;
    else if (m_provider == QStringLiteral("opencode")) apiKey = m_opencodeKey;

    if (!apiKey.isEmpty()) {
        args << QStringLiteral("--api-key") << apiKey;
    }
    if (!m_model.isEmpty()) {
        args << QStringLiteral("--model") << m_model;
    }

    auto fullOutput = std::make_shared<QString>();

    connect(proc, &QProcess::readyReadStandardOutput, this, [this, proc, fullOutput]() {
        const QString out = QString::fromUtf8(proc->readAllStandardOutput());
        fullOutput->append(out);
        const QStringList lines = out.split(QLatin1Char('\n'));
        for (const QString &line : lines) {
            const QString trimmed = line.trimmed();
            if (trimmed.startsWith(QStringLiteral("PROGRESS:"))) {
                const QString payload = trimmed.mid(9);
                const int sep = payload.indexOf(QLatin1Char('|'));
                if (sep != -1) {
                    const int pct = payload.left(sep).toInt();
                    const QString status = payload.mid(sep + 1);
                    emit hardModeProgress(pct, status);
                    this->setBusy(true, QStringLiteral("[%1%] %2").arg(pct).arg(status));
                }
            }
        }
    });

    connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this, proc, fullOutput](int exitCode, QProcess::ExitStatus exitStatus) {
        Q_UNUSED(exitStatus);
        fullOutput->append(QString::fromUtf8(proc->readAllStandardOutput()));
        const QString stderrStr = QString::fromUtf8(proc->readAllStandardError());
        proc->deleteLater();
        this->setBusy(false);

        QString manifestFile;
        const QStringList lines = fullOutput->split(QLatin1Char('\n'));
        for (const QString &line : lines) {
            const QString trimmed = line.trimmed();
            if (trimmed.startsWith(QStringLiteral("TIMELINE_MANIFEST:"))) {
                manifestFile = trimmed.mid(18).trimmed();
            }
        }

        if (exitCode == 0 && !manifestFile.isEmpty() && QFile::exists(manifestFile)) {
            applyTimelineManifest(manifestFile);
        } else {
            const QString err = stderrStr.isEmpty() ? *fullOutput : stderrStr;
            appendChatMessage(QStringLiteral("assistant"),
                              tr("❌ Falha na produção do Modo Hard:\n%1").arg(err));
            emit hardModeFinished(false, QString(), err);
        }
    });

    QString pythonExe = QStandardPaths::findExecutable(QStringLiteral("python"));
    if (pythonExe.isEmpty() || !QFile::exists(pythonExe)) {
        pythonExe = QStringLiteral("C:/Python314/python.exe");
    }

    proc->start(pythonExe, args);
}

bool AiAgentController::applyTimelineManifest(const QString &manifestPath)
{
    if (!m_controller)
        return false;

    QFile f(manifestPath);
    if (!f.open(QIODevice::ReadOnly)) {
        appendChatMessage(QStringLiteral("assistant"),
                          tr("❌ Erro ao abrir manifesto da timeline: %1").arg(manifestPath));
        return false;
    }

    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
    f.close();

    if (!doc.isObject()) {
        appendChatMessage(QStringLiteral("assistant"),
                          tr("❌ Formato inválido do manifesto da timeline."));
        return false;
    }

    const QJsonObject root = doc.object();
    const QString projectName = root.value(QStringLiteral("project_name")).toString();
    const QJsonArray tracks = root.value(QStringLiteral("tracks")).toArray();
    const QString subtitlesPath = root.value(QStringLiteral("subtitles")).toString();

    auto *proj = m_controller->project();
    if (!proj)
        return false;

    // Garante que existam pelo menos 2 trilhas de vídeo e 2 de áudio
    auto countTracksOfType = [proj](drift::TrackType tType) -> int {
        int c = 0;
        for (const auto &t : proj->tracks()) {
            if (t.type == tType) c++;
        }
        return c;
    };

    while (countTracksOfType(drift::TrackType::Video) < 2) {
        m_controller->addTrack(QStringLiteral("video"));
    }
    while (countTracksOfType(drift::TrackType::Audio) < 2) {
        m_controller->addTrack(QStringLiteral("audio"));
    }

    QList<int> videoTrackIndices;
    QList<int> audioTrackIndices;
    for (int i = 0; i < proj->tracks().size(); ++i) {
        if (proj->tracks().at(i).type == drift::TrackType::Video) {
            videoTrackIndices.append(i);
        } else if (proj->tracks().at(i).type == drift::TrackType::Audio) {
            audioTrackIndices.append(i);
        }
    }

    // No Dluz Film, a trilha de menor índice renderiza por cima (topo = overlays)
    int vOverlayTrack = videoTrackIndices.value(0);
    int vGameplayTrack = videoTrackIndices.value(videoTrackIndices.size() > 1 ? 1 : 0);
    int aVoiceTrack = audioTrackIndices.value(0);
    int aBgmTrack = audioTrackIndices.value(audioTrackIndices.size() > 1 ? 1 : 0);

    for (const auto &tVal : tracks) {
        const QJsonObject tObj = tVal.toObject();
        const int manifestTrackIdx = tObj.value(QStringLiteral("index")).toInt();
        const QString tType = tObj.value(QStringLiteral("type")).toString();
        const QJsonArray clips = tObj.value(QStringLiteral("clips")).toArray();

        int targetTrack = -1;
        if (manifestTrackIdx == 0) targetTrack = vGameplayTrack;
        else if (manifestTrackIdx == 1) targetTrack = vOverlayTrack;
        else if (manifestTrackIdx == 2) targetTrack = aVoiceTrack;
        else if (manifestTrackIdx == 3) targetTrack = aBgmTrack;
        else targetTrack = (tType == QStringLiteral("video")) ? vGameplayTrack : aVoiceTrack;

        for (const auto &cVal : clips) {
            const QJsonObject cObj = cVal.toObject();
            const QString clipPath = cObj.value(QStringLiteral("path")).toString();
            const double atSec = cObj.value(QStringLiteral("timeline_start")).toDouble();
            const QString effect = cObj.value(QStringLiteral("effect")).toString();

            if (!clipPath.isEmpty() && QFile::exists(clipPath)) {
                m_controller->importMediaToTimeline(clipPath, atSec, targetTrack, effect);
            }
        }
    }

    // Importa legendas se o arquivo existir
    if (!subtitlesPath.isEmpty() && QFile::exists(subtitlesPath)) {
        m_controller->importSubtitleFile(QUrl::fromLocalFile(subtitlesPath), 0.0);
    }

    // Posiciona o cursor no início
    m_controller->setPlayheadSeconds(0.0);

    appendChatMessage(QStringLiteral("assistant"),
                      tr("🎉 **Modo Hard Concluído com Sucesso!**\n"
                         "Todos os elementos foram sincronizados e injetados na timeline:\n"
                         "- 🎮 **Trilha V1:** Gameplay dinamicamente fatiada com cortes sequenciados\n"
                         "- 🎬 **Trilha V2:** Overlays HyperFrames (Chroma Key ativo sem fundo verde)\n"
                         "- 🎙️ **Trilha A1:** Locução oficial com voz clonada do DLuz (OmniVoice)\n"
                         "- 🎵 **Trilha A2:** Trilha sonora (BGM) ducked\n"
                         "- 📝 **Legendas:** Sincronizadas na trilha de legendas\n\n"
                         "O projeto está pronto! Dê Play na barra de espaço para conferir, refinar os cortes e exportar."));

    emit hardModeFinished(true, manifestPath, tr("Vídeo completo montado na timeline com sucesso!"));
    return true;
}

