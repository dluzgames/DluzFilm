import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Drift
import ".."

ThemedDialog {
    id: root

    title: qsTr("Agente IA Dluz Film")
    preferredWidth: 640
    showAccept: false
    rejectText: qsTr("Fechar")

    property int activeTab: 0

    function openDialog() {
        open()
    }

    contentItem: Column {
        id: body
        width: parent ? parent.width : 640
        spacing: Theme.spacingMd

        // Barra de Abas (Chat vs Configurações de Chaves)
        RowLayout {
            width: parent.width
            spacing: Theme.spacingSm

            ThemedButton {
                text: qsTr("💬 Chat com Agente IA")
                variant: root.activeTab === 0 ? "primary" : "secondary"
                Layout.fillWidth: true
                onClicked: root.activeTab = 0
            }

            ThemedButton {
                text: qsTr("⚙️ Chaves de API & Provedores")
                variant: root.activeTab === 1 ? "primary" : "secondary"
                Layout.fillWidth: true
                onClicked: root.activeTab = 1
            }
        }

        // --- ABA 0: CHAT INTERATIVO ---
        Column {
            width: parent.width
            spacing: Theme.spacingMd
            visible: root.activeTab === 0

            // Seletor rápido de provedor
            RowLayout {
                width: parent.width

                ThemedLabel {
                    text: qsTr("Provedor:")
                    size: "xs"
                    color: Theme.mutedForeground
                }

                ThemedLabel {
                    text: {
                        if (AiAgent.provider === "antigravity") return "ANTIGRAVITY CLI (LOCAL)"
                        if (AiAgent.provider === "codex") return "CODEX CLI (LOCAL)"
                        if (AiAgent.provider === "opencode" && AiAgent.opencodeCliAvailable) return "OPENCODE CLI (LOCAL)"
                        return AiAgent.provider.toUpperCase()
                    }
                    size: "xs"
                    color: (AiAgent.provider === "antigravity" || AiAgent.provider === "codex" || (AiAgent.provider === "opencode" && AiAgent.opencodeCliAvailable)) ? Theme.constructive : Theme.primary
                    font.weight: Font.Bold
                }

                Item { Layout.fillWidth: true }

                ThemedButton {
                    text: qsTr("Limpar conversa")
                    variant: "ghost"
                    onClicked: AiAgent.clearChat()
                }
            }

            // Lista de Mensagens
            Rectangle {
                width: parent.width
                height: 280
                radius: Theme.radiusSm
                color: Theme.panelBackground
                border.width: Theme.borderWidth
                border.color: Theme.panelBorder

                ListView {
                    id: chatListView
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMd
                    model: AiAgent.chatHistory
                    clip: true
                    spacing: Theme.spacingMd
                    ScrollBar.vertical: AppScrollBar {}

                    onCountChanged: {
                        Qt.callLater(function() {
                            chatListView.positionViewAtEnd()
                        })
                    }

                    delegate: Column {
                        required property var modelData
                        width: chatListView.width - Theme.spacingMd

                        Row {
                            spacing: Theme.spacingSm
                            anchors.right: modelData.role === "user" ? parent.right : undefined
                            anchors.left: modelData.role !== "user" ? parent.left : undefined

                            IconGlyph {
                                glyph: modelData.role === "user" ? Theme.icons.mousePointer : Theme.icons.bot
                                iconSize: Theme.iconSizeSm
                                iconColor: modelData.role === "user" ? Theme.primary : Theme.constructive
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: modelData.role === "user" ? qsTr("Você") : qsTr("Agente Dluz")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeXs
                                font.weight: Font.Bold
                                color: modelData.role === "user" ? Theme.primary : Theme.constructive
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: modelData.time || ""
                                font.family: Theme.monoFontFamily
                                font.pixelSize: Theme.fontSizeTiny
                                color: Theme.mutedForeground
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Rectangle {
                            anchors.right: modelData.role === "user" ? parent.right : undefined
                            anchors.left: modelData.role !== "user" ? parent.left : undefined
                            width: Math.min(implicitWidth + Theme.spacingLg * 2, parent.width * 0.85)
                            height: msgText.implicitHeight + Theme.spacingMd * 2
                            radius: Theme.radiusSm
                            color: modelData.role === "user" ? Theme.primary : Theme.inputBackground
                            border.width: Theme.borderWidth
                            border.color: Theme.panelBorder

                            Text {
                                id: msgText
                                anchors.centerIn: parent
                                width: parent.width - Theme.spacingLg * 2
                                text: modelData.text || ""
                                color: modelData.role === "user" ? Theme.onMedia : Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }

            // Chips de Ação Rápida
            Flow {
                width: parent.width
                spacing: Theme.spacingXs

                ThemedButton {
                    text: qsTr("🚀 Antigravity CLI")
                    variant: AiAgent.provider === "antigravity" ? "primary" : "secondary"
                    onClicked: {
                        AiAgent.provider = "antigravity"
                        promptInput.text = "Crie uma vinheta animada com o nome Dluz Games"
                    }
                }

                ThemedButton {
                    text: qsTr("💻 Codex CLI")
                    variant: AiAgent.provider === "codex" ? "primary" : "secondary"
                    onClicked: {
                        AiAgent.provider = "codex"
                        promptInput.text = "Crie uma vinheta animada com meu canal Dluz Games"
                    }
                }

                ThemedButton {
                    text: qsTr("⚡ OpenCode")
                    variant: AiAgent.provider === "opencode" ? "primary" : "secondary"
                    onClicked: {
                        AiAgent.provider = "opencode"
                        promptInput.text = "Remova todos os silêncios e pausas da gravação na timeline"
                    }
                }

                ThemedButton {
                    text: qsTr("🎬 Lower Third")
                    variant: "secondary"
                    onClicked: promptInput.text = "Crie uma vinheta lower third estilizada com meu nome DLuz Games"
                }

                ThemedButton {
                    text: qsTr("🎙️ Voz DLuz")
                    variant: "secondary"
                    onClicked: promptInput.text = "Gere uma locução de abertura usando o bordão oficial da DLuz Games"
                }
            }

            // Campo de Entrada do Chat
            RowLayout {
                width: parent.width
                spacing: Theme.spacingSm

                ThemedTextField {
                    id: promptInput
                    Layout.fillWidth: true
                    placeholderText: qsTr("Peça algo ao Agente IA...")
                    onAccepted: sendBtn.clicked()
                }

                ThemedButton {
                    id: sendBtn
                    text: qsTr("Enviar")
                    variant: "primary"
                    enabled: !AiAgent.isBusy && promptInput.text.trim().length > 0
                    onClicked: {
                        AiAgent.sendMessage(promptInput.text.trim())
                        promptInput.text = ""
                    }
                }
            }
        }

        // --- ABA 1: CONFIGURAÇÃO DE CHAVES DE API ---
        Column {
            width: parent.width
            spacing: Theme.spacingMd
            visible: root.activeTab === 1

            ThemedLabel {
                width: parent.width
                size: "sm"
                wrapMode: Text.WordWrap
                text: qsTr("Configure suas chaves de API para desbloquear o Agente IA nativo. As chaves são salvas de forma segura no seu computador.")
            }

            // Provedor ativo
            Column {
                width: parent.width
                spacing: Theme.spacingXs

                ThemedLabel {
                    text: qsTr("Provedor de IA Padrão:")
                    size: "sm"
                    font.weight: Font.Medium
                }

                Flow {
                    width: parent.width
                    spacing: Theme.spacingSm

                    ThemedButton {
                        text: "Antigravity CLI" + (AiAgent.antigravityAvailable ? " ✨" : "")
                        variant: AiAgent.provider === "antigravity" ? "primary" : "secondary"
                        onClicked: AiAgent.provider = "antigravity"
                    }

                    ThemedButton {
                        text: "OpenAI Codex CLI" + (AiAgent.codexAvailable ? " ✨" : "")
                        variant: AiAgent.provider === "codex" ? "primary" : "secondary"
                        onClicked: AiAgent.provider = "codex"
                    }

                    ThemedButton {
                        text: "OpenCode" + (AiAgent.opencodeCliAvailable ? " ✨" : "")
                        variant: AiAgent.provider === "opencode" ? "primary" : "secondary"
                        onClicked: AiAgent.provider = "opencode"
                    }

                    ThemedButton {
                        text: "Google Gemini"
                        variant: AiAgent.provider === "gemini" ? "primary" : "secondary"
                        onClicked: AiAgent.provider = "gemini"
                    }

                    ThemedButton {
                        text: "Groq"
                        variant: AiAgent.provider === "groq" ? "primary" : "secondary"
                        onClicked: AiAgent.provider = "groq"
                    }

                    ThemedButton {
                        text: "OpenRouter"
                        variant: AiAgent.provider === "openrouter" ? "primary" : "secondary"
                        onClicked: AiAgent.provider = "openrouter"
                    }
                }
            }

            // Antigravity CLI Card
            Column {
                width: parent.width
                spacing: Theme.spacingSm
                visible: AiAgent.provider === "antigravity"

                Rectangle {
                    width: parent.width
                    height: agyCardCol.implicitHeight + Theme.spacingMd * 2
                    radius: Theme.radiusSm
                    color: AiAgent.antigravityAvailable ? Qt.rgba(0.08, 0.64, 0.29, 0.12) : Qt.rgba(0.8, 0.2, 0.2, 0.12)
                    border.width: Theme.borderWidth
                    border.color: AiAgent.antigravityAvailable ? Theme.constructive : Theme.destructive

                    Column {
                        id: agyCardCol
                        anchors.fill: parent
                        anchors.margins: Theme.spacingMd
                        spacing: Theme.spacingXs

                        RowLayout {
                            width: parent.width
                            spacing: Theme.spacingSm

                            IconGlyph {
                                glyph: AiAgent.antigravityAvailable ? Theme.icons.check : Theme.icons.alertTriangle
                                iconSize: Theme.iconSizeMd
                                iconColor: AiAgent.antigravityAvailable ? Theme.constructive : Theme.destructive
                            }

                            ThemedLabel {
                                text: AiAgent.antigravityAvailable ? qsTr("Antigravity CLI (agy) Conectado") : qsTr("Antigravity CLI Não Localizado")
                                size: "sm"
                                font.weight: Font.Bold
                                color: AiAgent.antigravityAvailable ? Theme.constructive : Theme.destructive
                            }

                            Item { Layout.fillWidth: true }

                            ThemedLabel {
                                text: qsTr("Ambiente Antigravity Ativo")
                                size: "xs"
                                color: Theme.mutedForeground
                            }
                        }

                        ThemedLabel {
                            width: parent.width
                            text: AiAgent.antigravityAvailable
                                  ? qsTr("Executável: ") + AiAgent.antigravityExecutablePath()
                                  : qsTr("Instale ou adicione o Antigravity CLI (agy) ao PATH do Windows.")
                            size: "xs"
                            color: Theme.mutedForeground
                            wrapMode: Text.WrapAnywhere
                        }

                        ThemedLabel {
                            width: parent.width
                            text: qsTr("O Antigravity CLI executa nativamente com acesso a skills, automações e ecossistema oficial da Google DeepMind no seu DluzPC.")
                            size: "xs"
                            color: Theme.foreground
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            // Codex CLI Card
            Column {
                width: parent.width
                spacing: Theme.spacingSm
                visible: AiAgent.provider === "codex"

                Rectangle {
                    width: parent.width
                    height: codexCardCol.implicitHeight + Theme.spacingMd * 2
                    radius: Theme.radiusSm
                    color: AiAgent.codexAvailable ? Qt.rgba(0.08, 0.64, 0.29, 0.12) : Qt.rgba(0.8, 0.2, 0.2, 0.12)
                    border.width: Theme.borderWidth
                    border.color: AiAgent.codexAvailable ? Theme.constructive : Theme.destructive

                    Column {
                        id: codexCardCol
                        anchors.fill: parent
                        anchors.margins: Theme.spacingMd
                        spacing: Theme.spacingXs

                        RowLayout {
                            width: parent.width
                            spacing: Theme.spacingSm

                            IconGlyph {
                                glyph: AiAgent.codexAvailable ? Theme.icons.check : Theme.icons.alertTriangle
                                iconSize: Theme.iconSizeMd
                                iconColor: AiAgent.codexAvailable ? Theme.constructive : Theme.destructive
                            }

                            ThemedLabel {
                                text: AiAgent.codexAvailable ? qsTr("OpenAI Codex CLI Conectado") : qsTr("Codex CLI Não Localizado")
                                size: "sm"
                                font.weight: Font.Bold
                                color: AiAgent.codexAvailable ? Theme.constructive : Theme.destructive
                            }

                            Item { Layout.fillWidth: true }

                            ThemedLabel {
                                text: qsTr("Autenticação Local Ativa")
                                size: "xs"
                                color: Theme.mutedForeground
                            }
                        }

                        ThemedLabel {
                            width: parent.width
                            text: AiAgent.codexAvailable
                                  ? qsTr("Executável: ") + AiAgent.codexExecutablePath()
                                  : qsTr("Instale o OpenAI Codex ou verifique se está no PATH do Windows.")
                            size: "xs"
                            color: Theme.mutedForeground
                            wrapMode: Text.WrapAnywhere
                        }

                        ThemedLabel {
                            width: parent.width
                            text: qsTr("O Codex CLI executa localmente no seu PC através da CLI oficial da OpenAI, sem necessidade de inserir chaves API manuais.")
                            size: "xs"
                            color: Theme.foreground
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            // Gemini Key
            Column {
                width: parent.width
                spacing: Theme.spacingXs
                visible: AiAgent.provider === "gemini"

                ThemedLabel {
                    text: qsTr("Google Gemini API Key:")
                    size: "xs"
                    font.weight: Font.Medium
                }
                ThemedTextField {
                    width: parent.width
                    echoMode: TextInput.PasswordEchoOnEdit
                    text: AiAgent.geminiKey
                    placeholderText: "AIzaSy..."
                    onTextChanged: AiAgent.geminiKey = text.trim()
                }
            }

            // OpenRouter Key
            Column {
                width: parent.width
                spacing: Theme.spacingXs
                visible: AiAgent.provider === "openrouter"

                ThemedLabel {
                    text: qsTr("OpenRouter API Key:")
                    size: "xs"
                    font.weight: Font.Medium
                }
                ThemedTextField {
                    width: parent.width
                    echoMode: TextInput.PasswordEchoOnEdit
                    text: AiAgent.openrouterKey
                    placeholderText: "sk-or-v1-..."
                    onTextChanged: AiAgent.openrouterKey = text.trim()
                }
            }

            // Groq Key
            Column {
                width: parent.width
                spacing: Theme.spacingXs
                visible: AiAgent.provider === "groq"

                ThemedLabel {
                    text: qsTr("Groq API Key:")
                    size: "xs"
                    font.weight: Font.Medium
                }
                ThemedTextField {
                    width: parent.width
                    echoMode: TextInput.PasswordEchoOnEdit
                    text: AiAgent.groqKey
                    placeholderText: "gsk_..."
                    onTextChanged: AiAgent.groqKey = text.trim()
                }
            }

            // OpenCode CLI / Custom URL + Key
            Column {
                width: parent.width
                spacing: Theme.spacingSm
                visible: AiAgent.provider === "opencode"

                Rectangle {
                    width: parent.width
                    height: opencodeCardCol.implicitHeight + Theme.spacingMd * 2
                    radius: Theme.radiusSm
                    color: AiAgent.opencodeCliAvailable ? Qt.rgba(0.08, 0.64, 0.29, 0.12) : Qt.rgba(0.2, 0.4, 0.8, 0.12)
                    border.width: Theme.borderWidth
                    border.color: AiAgent.opencodeCliAvailable ? Theme.constructive : Theme.panelBorder

                    Column {
                        id: opencodeCardCol
                        anchors.fill: parent
                        anchors.margins: Theme.spacingMd
                        spacing: Theme.spacingXs

                        RowLayout {
                            width: parent.width
                            spacing: Theme.spacingSm

                            IconGlyph {
                                glyph: AiAgent.opencodeCliAvailable ? Theme.icons.check : Theme.icons.globe
                                iconSize: Theme.iconSizeMd
                                iconColor: AiAgent.opencodeCliAvailable ? Theme.constructive : Theme.primary
                            }

                            ThemedLabel {
                                text: AiAgent.opencodeCliAvailable ? qsTr("OpenCode CLI Detectado") : qsTr("OpenCode Endpoint REST")
                                size: "sm"
                                font.weight: Font.Bold
                                color: AiAgent.opencodeCliAvailable ? Theme.constructive : Theme.foreground
                            }

                            Item { Layout.fillWidth: true }

                            ThemedLabel {
                                text: AiAgent.opencodeCliAvailable ? qsTr("Modo CLI Nativo") : qsTr("Modo Servidor / Ollama")
                                size: "xs"
                                color: Theme.mutedForeground
                            }
                        }

                        ThemedLabel {
                            width: parent.width
                            text: AiAgent.opencodeCliAvailable
                                  ? qsTr("Executável CLI: ") + AiAgent.opencodeExecutablePath()
                                  : qsTr("Configure a URL do servidor OpenCode ou Ollama abaixo.")
                            size: "xs"
                            color: Theme.mutedForeground
                            wrapMode: Text.WrapAnywhere
                        }

                        ThemedLabel {
                            width: parent.width
                            text: qsTr("Quando a chave API estiver vazia e o CLI estiver instalado, o Dluz Film usa o OpenCode CLI diretamente.")
                            size: "xs"
                            color: Theme.foreground
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                ThemedLabel {
                    text: qsTr("OpenCode / Endpoint Base URL (opcional se usando CLI):")
                    size: "xs"
                    font.weight: Font.Medium
                }
                ThemedTextField {
                    width: parent.width
                    text: AiAgent.opencodeUrl
                    placeholderText: "http://localhost:11434/v1"
                    onTextChanged: AiAgent.opencodeUrl = text.trim()
                }

                ThemedLabel {
                    text: qsTr("OpenCode / OpenAI API Key (deixe vazio para usar CLI local):")
                    size: "xs"
                    font.weight: Font.Medium
                }
                ThemedTextField {
                    width: parent.width
                    echoMode: TextInput.PasswordEchoOnEdit
                    text: AiAgent.opencodeKey
                    placeholderText: "sk-... (opcional)"
                    onTextChanged: AiAgent.opencodeKey = text.trim()
                }
            }

            // Modelo personalizado
            Column {
                width: parent.width
                spacing: Theme.spacingXs

                ThemedLabel {
                    text: qsTr("Modelo (deixe em branco para o padrão ideal):")
                    size: "xs"
                    color: Theme.mutedForeground
                }
                ThemedTextField {
                    width: parent.width
                    text: AiAgent.model
                    placeholderText: qsTr("Ex: gemini-2.5-flash, claude-3.5-sonnet, llama-3.3-70b...")
                    onTextChanged: AiAgent.model = text.trim()
                }
            }
        }
    }
}
