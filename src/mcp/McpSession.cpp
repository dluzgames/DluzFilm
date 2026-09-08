#include "mcp/McpSession.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>

namespace drift::mcp {
namespace {

QString defaultSessionDir()
{
    QString base = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation);
    if (base.isEmpty())
        base = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
    return QDir(base).filePath(QStringLiteral("dluzfilm"));
}

} // namespace

QString sessionFilePath()
{
    const QString override = qEnvironmentVariable("DLUZFILM_MCP_SESSION_PATH");
    if (!override.isEmpty())
        return override;
    const QString driftOverride = qEnvironmentVariable("DRIFT_MCP_SESSION_PATH");
    if (!driftOverride.isEmpty())
        return driftOverride;

    return QDir(defaultSessionDir()).filePath(QStringLiteral("mcp-session.json"));
}

bool writeSessionFile(quint16 port, const QString &token)
{
    const QString path = sessionFilePath();
    const QString dir = QFileInfo(path).absolutePath();
    if (!QDir().mkpath(dir))
        return false;

    const QJsonObject body{
        {QStringLiteral("port"), static_cast<int>(port)},
        {QStringLiteral("url"), QStringLiteral("http://127.0.0.1:%1/mcp").arg(port)},
        {QStringLiteral("token"), token},
        {QStringLiteral("pid"), QCoreApplication::applicationPid()},
    };

    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return false;
    file.write(QJsonDocument(body).toJson(QJsonDocument::Compact));
    file.write("\n");
    file.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner);

    // Also mirror to legacy drift path for backward compatibility with older tools
    QString base = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation);
    if (base.isEmpty())
        base = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
    const QString legacyPath = QDir(base).filePath(QStringLiteral("drift/mcp-session.json"));
    if (legacyPath != path) {
        QDir().mkpath(QFileInfo(legacyPath).absolutePath());
        QFile legacyFile(legacyPath);
        if (legacyFile.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            legacyFile.write(QJsonDocument(body).toJson(QJsonDocument::Compact));
            legacyFile.write("\n");
            legacyFile.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner);
        }
    }

    return true;
}

void removeSessionFile()
{
    QFile::remove(sessionFilePath());
    QString base = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation);
    if (base.isEmpty())
        base = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
    QFile::remove(QDir(base).filePath(QStringLiteral("drift/mcp-session.json")));
}

bool readSessionFile(quint16 *port, QString *token, QString *error)
{
    QString path = sessionFilePath();
    if (!QFile::exists(path)) {
        QString base = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation);
        if (base.isEmpty())
            base = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
        const QString legacy = QDir(base).filePath(QStringLiteral("drift/mcp-session.json"));
        if (QFile::exists(legacy))
            path = legacy;
    }
    QFile file(path);
    if (!file.exists()) {
        if (error) {
            *error = QStringLiteral(
                "Dluz Film MCP is off. Open Dluz Film and enable Agent access in Settings.");
        }
        return false;
    }
    if (!file.open(QIODevice::ReadOnly)) {
        if (error)
            *error = QStringLiteral("Could not read the Dluz Film MCP session file.");
        return false;
    }
    const auto doc = QJsonDocument::fromJson(file.readAll());
    if (!doc.isObject()) {
        if (error)
            *error = QStringLiteral("Dluz Film MCP session file is invalid.");
        return false;
    }
    const QJsonObject o = doc.object();
    const int p = o.value(QStringLiteral("port")).toInt();
    const QString t = o.value(QStringLiteral("token")).toString();
    if (p <= 0 || p > 65535 || t.isEmpty()) {
        if (error)
            *error = QStringLiteral("Dluz Film MCP session file is incomplete.");
        return false;
    }
    if (port)
        *port = static_cast<quint16>(p);
    if (token)
        *token = t;
    return true;
}

} // namespace drift::mcp
