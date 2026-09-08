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
                    text: AiAgent.provider.toUpperCase()
                    size: "xs"
                    color: Theme.primary
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
            RowLayout {
                width: parent.width
                spacing: Theme.spacingXs

                ThemedButton {
                    text: qsTr("🎬 Criar Lower Third")
                    variant: "secondary"
                    onClicked: promptInput.text = "Crie uma vinheta lower third estilizada com meu nome DLuz Games"
                }

                ThemedButton {
                    text: qsTr("✂️ Remover Silêncios")
                    variant: "secondary"
                    onClicked: promptInput.text = "Remova todos os silêncios e pausas da gravação na timeline"
                }

                ThemedButton {
                    text: qsTr("🎙️ Voz Clonada DLuz")
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

                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingSm

                    ThemedButton {
                        text: "Google Gemini"
                        variant: AiAgent.provider === "gemini" ? "primary" : "secondary"
                        Layout.fillWidth: true
                        onClicked: AiAgent.provider = "gemini"
                    }

                    ThemedButton {
                        text: "OpenRouter"
                        variant: AiAgent.provider === "openrouter" ? "primary" : "secondary"
                        Layout.fillWidth: true
                        onClicked: AiAgent.provider = "openrouter"
                    }

                    ThemedButton {
                        text: "Groq"
                        variant: AiAgent.provider === "groq" ? "primary" : "secondary"
                        Layout.fillWidth: true
                        onClicked: AiAgent.provider = "groq"
                    }

                    ThemedButton {
                        text: "OpenCode"
                        variant: AiAgent.provider === "opencode" ? "primary" : "secondary"
                        Layout.fillWidth: true
                        onClicked: AiAgent.provider = "opencode"
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

            // OpenCode / Custom URL + Key
            Column {
                width: parent.width
                spacing: Theme.spacingXs
                visible: AiAgent.provider === "opencode"

                ThemedLabel {
                    text: qsTr("OpenCode / Endpoint Base URL:")
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
                    text: qsTr("OpenCode / OpenAI API Key (opcional se local):")
                    size: "xs"
                    font.weight: Font.Medium
                }
                ThemedTextField {
                    width: parent.width
                    echoMode: TextInput.PasswordEchoOnEdit
                    text: AiAgent.opencodeKey
                    placeholderText: "sk-..."
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
