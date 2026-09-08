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

AiAgentController::AiAgentController(AppController *controller, QObject *parent)
    : QObject(parent)
    , m_controller(controller)
{
    loadSettings();

    // Default welcome message
    appendChatMessage(QStringLiteral("assistant"),
                      tr("Olá! Sou o seu Agente IA interno do Dluz Film. Posso ajudar você a criar vinhetas e lower-thirds animados com HyperFrames, remover silêncios automaticamente, clonar voz com OmniVoice e gerar cenas com OmniFlash. Como posso ajudar agora?"));
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
    m_provider = s.value(QStringLiteral("ai/provider"), QStringLiteral("gemini")).toString();
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
                                  "- Gerar vídeo OmniFlash: [ACTION:OMNIFLASH|16:9|prompt da cena em inglês]\n");

    return info;
}

void AiAgentController::sendMessage(const QString &prompt)
{
    if (prompt.trimmed().isEmpty() || m_isBusy)
        return;

    appendChatMessage(QStringLiteral("user"), prompt.trimmed());
    setBusy(true, tr("Consultando IA (%1)...").arg(m_provider));

    const QString sysPrompt = buildSystemPrompt();

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

    appendChatMessage(QStringLiteral("assistant"), replyText);
    executeActionFromResponse(replyText);
}

void AiAgentController::executeActionFromResponse(const QString &response)
{
    // Check for [ACTION:HYPERFRAMES|template|title|subtitle]
    static const QRegularExpression hfRegex(QStringLiteral(R"(\[ACTION:HYPERFRAMES\|([^|]+)\|([^|]+)\|([^\]]+)\])"));
    const auto hfMatch = hfRegex.match(response);
    if (hfMatch.hasMatch()) {
        const QString tmpl = hfMatch.captured(1).trimmed();
        const QString title = hfMatch.captured(2).trimmed();
        const QString subtitle = hfMatch.captured(3).trimmed();
        createHyperframes(title, subtitle, tmpl);
        return;
    }

    // Check for [ACTION:REMOVE_SILENCE|threshold|min_duration|padding]
    static const QRegularExpression silRegex(QStringLiteral(R"(\[ACTION:REMOVE_SILENCE\|([^|]+)\|([^|]+)\|([^\]]+)\])"));
    const auto silMatch = silRegex.match(response);
    if (silMatch.hasMatch()) {
        const double th = silMatch.captured(1).toDouble();
        const double md = silMatch.captured(2).toDouble();
        const double pad = silMatch.captured(3).toDouble();
        runSilenceRemoval(th > 0 ? -th : th, md, pad);
        return;
    }

    // Check for [ACTION:CLONE_VOICE|engine|text]
    static const QRegularExpression voiceRegex(QStringLiteral(R"(\[ACTION:CLONE_VOICE\|([^|]+)\|([^\]]+)\])"));
    const auto voiceMatch = voiceRegex.match(response);
    if (voiceMatch.hasMatch()) {
        const QString eng = voiceMatch.captured(1).trimmed();
        const QString text = voiceMatch.captured(2).trimmed();
        synthesizeVoice(text, eng);
        return;
    }

    // Check for [ACTION:OMNIFLASH|aspect|prompt]
    static const QRegularExpression omniRegex(QStringLiteral(R"(\[ACTION:OMNIFLASH\|([^|]+)\|([^\]]+)\])"));
    const auto omniMatch = omniRegex.match(response);
    if (omniMatch.hasMatch()) {
        const QString aspect = omniMatch.captured(1).trimmed();
        const QString pr = omniMatch.captured(2).trimmed();
        generateOmniFlash(pr, aspect);
        return;
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

    // Prepare temp directory
    const QString tempDir = QStandardPaths::writableLocation(QStandardPaths::TempLocation)
                          + QStringLiteral("/dluzfilm_hf_") + QUuid::createUuid().toString(QUuid::WithoutBraces);
    QDir().mkpath(tempDir);

    QString html;
    if (!customHtml.isEmpty()) {
        html = customHtml;
    } else if (templateType == QStringLiteral("title_card")) {
        html = QString::fromUtf8(R"HTML(<!DOCTYPE html>
<html>
<head><meta charset="utf-8">
<style>
  body { margin:0; padding:0; background:transparent; overflow:hidden; width:1920px; height:1080px; display:flex; justify-content:center; align-items:center; font-family:'Segoe UI',system-ui,sans-serif; }
  .box { text-align:center; opacity:0; transform:scale(0.9); }
  .title { font-size:76px; font-weight:900; color:#ffffff; text-transform:uppercase; letter-spacing:4px; text-shadow:0 8px 30px rgba(0,0,0,0.9); }
  .subtitle { font-size:30px; font-weight:600; color:#16a34a; margin-top:16px; letter-spacing:3px; }
</style>
<script src="https://cdnjs.cloudflare.com/ajax/libs/gsap/3.12.5/gsap.min.js"></script>
</head>
<body data-duration="4">
  <div class="box" id="box">
    <div class="title">%1</div>
    <div class="subtitle">%2</div>
  </div>
  <script>
    const tl = gsap.timeline();
    tl.to("#box", { opacity:1, scale:1, duration:0.8, ease:"back.out(1.7)" })
      .to("#box", { opacity:0, scale:1.05, duration:0.6, ease:"power2.in" }, 3.4);
  </script>
</body>
</html>)HTML").arg(title, subtitle);
    } else if (templateType == QStringLiteral("social_card")) {
        html = QString::fromUtf8(R"HTML(<!DOCTYPE html>
<html>
<head><meta charset="utf-8">
<style>
  body { margin:0; padding:0; background:transparent; overflow:hidden; width:1920px; height:1080px; font-family:'Segoe UI',system-ui,sans-serif; }
  .card { position:absolute; bottom:100px; right:100px; background:rgba(20,20,20,0.9); border:2px solid #16a34a; border-radius:20px; padding:18px 32px; display:flex; align-items:center; box-shadow:0 10px 40px rgba(0,0,0,0.8); opacity:0; transform:translateY(40px); }
  .avatar { width:56px; height:56px; border-radius:50%; background:#16a34a; display:flex; justify-content:center; align-items:center; font-size:28px; font-weight:bold; color:white; margin-right:18px; }
  .name { font-size:26px; font-weight:800; color:white; }
  .handle { font-size:18px; color:#22c55e; font-weight:600; margin-top:2px; }
</style>
<script src="https://cdnjs.cloudflare.com/ajax/libs/gsap/3.12.5/gsap.min.js"></script>
</head>
<body data-duration="4">
  <div class="card" id="card">
    <div class="avatar">▶</div>
    <div>
      <div class="name">%1</div>
      <div class="handle">%2</div>
    </div>
  </div>
  <script>
    const tl = gsap.timeline();
    tl.to("#card", { opacity:1, y:0, duration:0.7, ease:"elastic.out(1, 0.75)" })
      .to("#card", { opacity:0, y:30, duration:0.5, ease:"power2.in" }, 3.5);
  </script>
</body>
</html>)HTML").arg(title, subtitle);
    } else { // default: lower_third
        html = QString::fromUtf8(R"HTML(<!DOCTYPE html>
<html>
<head><meta charset="utf-8">
<style>
  body { margin:0; padding:0; background:transparent; overflow:hidden; width:1920px; height:1080px; font-family:'Segoe UI',system-ui,sans-serif; }
  .wrapper { position:absolute; bottom:120px; left:100px; display:flex; align-items:center; }
  .accent-bar { width:8px; height:72px; background:linear-gradient(to bottom, #16a34a, #22c55e); border-radius:4px; transform:scaleY(0); }
  .content { margin-left:20px; opacity:0; transform:translateX(-30px); }
  .title { font-size:38px; font-weight:800; color:#ffffff; text-shadow:0 4px 12px rgba(0,0,0,0.8); }
  .subtitle { font-size:22px; font-weight:500; color:#22c55e; margin-top:4px; letter-spacing:1px; text-shadow:0 2px 8px rgba(0,0,0,0.8); }
</style>
<script src="https://cdnjs.cloudflare.com/ajax/libs/gsap/3.12.5/gsap.min.js"></script>
</head>
<body data-duration="4">
  <div class="wrapper">
    <div class="accent-bar" id="bar"></div>
    <div class="content" id="content">
      <div class="title">%1</div>
      <div class="subtitle">%2</div>
    </div>
  </div>
  <script>
    const tl = gsap.timeline();
    tl.to("#bar", { scaleY:1, duration:0.5, ease:"power3.out" })
      .to("#content", { opacity:1, x:0, duration:0.6, ease:"power3.out" }, "-=0.3")
      .to(["#content", "#bar"], { opacity:0, x:-20, duration:0.5, ease:"power3.in" }, 3.5);
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
    QObject::connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this, proc, outFile, tempDir](int exitCode, QProcess::ExitStatus exitStatus) {
        Q_UNUSED(exitStatus);
        proc->deleteLater();
        this->setBusy(false);

        if (exitCode == 0 && QFile::exists(outFile)) {
            if (this->m_controller)
                this->m_controller->importMediaToTimeline(outFile);
            this->appendChatMessage(QStringLiteral("assistant"),
                              QObject::tr("🎬 HyperFrames renderizado com sucesso e inserido na timeline:\n%1").arg(outFile));
            emit this->hyperframesFinished(true, outFile, QObject::tr("Renderizado e adicionado à timeline!"));
        } else {
            const QString err = QString::fromUtf8(proc->readAllStandardError());
            this->appendChatMessage(QStringLiteral("assistant"),
                              QObject::tr("❌ Falha na renderização do HyperFrames:\n%1").arg(err));
            emit this->hyperframesFinished(false, QString(), err);
        }
        QDir(tempDir).removeRecursively();
    });

    proc->start(QStringLiteral("cmd.exe"),
                QStringList{QStringLiteral("/c"), QStringLiteral("npx"), QStringLiteral("hyperframes"),
                            QStringLiteral("render"), tempDir, QStringLiteral("-o"), outFile});
}

void AiAgentController::synthesizeVoice(const QString &text, const QString &engine, const QString &voicePath)
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

    if (engine == QStringLiteral("omnivoice")) {
        // OmniVoice CUDA on RTX 2060
        const QString refVoice = voicePath.isEmpty() ? QStringLiteral("D:/rosto dluz/dluz_voice.pt") : voicePath;
        const QString script = QStringLiteral("C:/Users/dluzgg/.gemini/config/skills/dublagem/scripts/dubber.py");

        proc->start(QStringLiteral("python"),
                    QStringList{script, QStringLiteral("--tts"), text,
                                QStringLiteral("--output"), outFile,
                                QStringLiteral("--voice"), refVoice,
                                QStringLiteral("--lang"), QStringLiteral("pt"),
                                QStringLiteral("--speed"), QStringLiteral("0.95")});
    } else {
        // Edge-TTS default
        proc->start(QStringLiteral("cmd.exe"),
                    QStringList{QStringLiteral("/c"), QStringLiteral("edge-tts"),
                                QStringLiteral("--voice"), QStringLiteral("pt-BR-AntonioNeural"),
                                QStringLiteral("--text"), text,
                                QStringLiteral("--write-media"), outFile});
    }
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
