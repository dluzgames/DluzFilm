import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Drift
import ".."

ThemedDialog {
    id: root

    title: qsTr("Agente IA Dluz Film")
    preferredWidth: 860
    showAccept: false
    rejectText: qsTr("Fechar")

    property int activeTab: 0

    function openDialog() {
        open()
    }

    contentItem: Column {
        id: body
        width: parent ? parent.width : 860
        spacing: Theme.spacingLg

        // --- BARRA SUPERIOR DE NAVEGAÇÃO (GOOGLE STITCH SEGMENTED CONTROL) ---
        Rectangle {
            width: parent.width
            height: 40
            radius: Theme.radiusSm
            color: Theme.appBackground
            border.width: Theme.borderWidth
            border.color: Theme.panelBorder

            RowLayout {
                anchors.fill: parent
                anchors.margins: 3
                spacing: 4

                // Aba 0: Chat
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.radiusSm - 1
                    color: root.activeTab === 0 ? Theme.panelAccent : "transparent"
                    border.width: root.activeTab === 0 ? Theme.borderWidth : 0
                    border.color: root.activeTab === 0 ? Theme.panelBorder : "transparent"

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.spacingSm

                        IconGlyph {
                            glyph: Theme.icons.bot
                            iconSize: Theme.iconSizeBase
                            iconColor: root.activeTab === 0 ? Theme.primary : Theme.mutedForeground
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: qsTr("Chat & Assistente IA")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            font.weight: root.activeTab === 0 ? Font.DemiBold : Font.Normal
                            color: root.activeTab === 0 ? Theme.panelForeground : Theme.mutedForeground
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activeTab = 0
                    }
                }

                // Aba 1: ⚡ Modo Hard (Produção por Link)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.radiusSm - 1
                    color: root.activeTab === 1 ? Theme.panelAccent : "transparent"
                    border.width: root.activeTab === 1 ? Theme.borderWidth : 0
                    border.color: root.activeTab === 1 ? "#f59e0b" : "transparent"

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.spacingSm

                        Text {
                            text: "⚡"
                            font.pixelSize: 14
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: qsTr("Modo Hard (Por Link)")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            font.weight: root.activeTab === 1 ? Font.DemiBold : Font.Normal
                            color: root.activeTab === 1 ? "#f59e0b" : Theme.mutedForeground
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activeTab = 1
                    }
                }

                // Aba 2: Provedores e Modelos
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.radiusSm - 1
                    color: root.activeTab === 2 ? Theme.panelAccent : "transparent"
                    border.width: root.activeTab === 2 ? Theme.borderWidth : 0
                    border.color: root.activeTab === 2 ? Theme.panelBorder : "transparent"

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.spacingSm

                        IconGlyph {
                            glyph: Theme.icons.settings
                            iconSize: Theme.iconSizeBase
                            iconColor: root.activeTab === 2 ? Theme.primary : Theme.mutedForeground
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: qsTr("Modelos & Provedores")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            font.weight: root.activeTab === 2 ? Font.DemiBold : Font.Normal
                            color: root.activeTab === 2 ? Theme.panelForeground : Theme.mutedForeground
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activeTab = 2
                    }
                }
            }
        }

        // ====================================================================
        // ABA 0: CHAT & ASSISTENTE INTELIGENTE
        // ====================================================================
        Column {
            width: parent.width
            spacing: Theme.spacingMd
            visible: root.activeTab === 0

            // Sub-Barra de Status do Motor & Ações Rápidas
            RowLayout {
                width: parent.width
                spacing: Theme.spacingMd

                // Badge do Motor Ativo
                Rectangle {
                    height: 28
                    implicitWidth: engineRow.implicitWidth + Theme.spacingLg * 2
                    radius: 14
                    color: Theme.panelAccent
                    border.width: Theme.borderWidth
                    border.color: Theme.panelBorder

                    Row {
                        id: engineRow
                        anchors.centerIn: parent
                        spacing: Theme.spacingSm

                        // Ponto luminoso de status
                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: {
                                if (AiAgent.provider === "antigravity") return AiAgent.antigravityAvailable ? Theme.constructive : Theme.destructive
                                if (AiAgent.provider === "codex") return AiAgent.codexAvailable ? Theme.constructive : Theme.destructive
                                if (AiAgent.provider === "opencode") return AiAgent.opencodeCliAvailable ? Theme.constructive : Theme.warning
                                if (AiAgent.provider === "gemini") return AiAgent.geminiKey.length > 0 ? Theme.constructive : Theme.warning
                                if (AiAgent.provider === "groq") return AiAgent.groqKey.length > 0 ? Theme.constructive : Theme.warning
                                if (AiAgent.provider === "openrouter") return AiAgent.openrouterKey.length > 0 ? Theme.constructive : Theme.warning
                                return Theme.constructive
                            }
                        }

                        Text {
                            text: {
                                if (AiAgent.provider === "antigravity") return qsTr("Antigravity CLI (Local)")
                                if (AiAgent.provider === "codex") return qsTr("Codex CLI (Local)")
                                if (AiAgent.provider === "opencode") return AiAgent.opencodeCliAvailable ? qsTr("OpenCode CLI (Local)") : qsTr("OpenCode (Server)")
                                if (AiAgent.provider === "gemini") return qsTr("Google Gemini (API)")
                                if (AiAgent.provider === "groq") return qsTr("Groq LPU (API)")
                                if (AiAgent.provider === "openrouter") return qsTr("OpenRouter (API)")
                                return AiAgent.provider.toUpperCase()
                            }
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Font.DemiBold
                            color: Theme.foreground
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        IconGlyph {
                            glyph: Theme.icons.settings
                            iconSize: Theme.iconSizeSm
                            iconColor: Theme.mutedForeground
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activeTab = 1
                    }
                }

                // Indicador de "Processando"
                Row {
                    spacing: Theme.spacingXs
                    visible: AiAgent.isBusy
                    anchors.verticalCenter: parent.verticalCenter

                    IconGlyph {
                        glyph: Theme.icons.spinner
                        iconSize: Theme.iconSizeSm
                        iconColor: Theme.primary
                        spinning: true
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: qsTr("Processando com IA...")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Item { Layout.fillWidth: true }

                ThemedButton {
                    text: qsTr("Limpar Chat")
                    glyph: Theme.icons.trash
                    variant: "ghost"
                    tooltip: qsTr("Limpar histórico da conversa")
                    onClicked: AiAgent.clearChat()
                }
            }

            // CONTAINER DA LISTA DE MENSAGENS
            Rectangle {
                id: chatContainer
                width: parent.width
                height: Math.min(420, Math.max(280, root.availableContentHeight - 220))
                radius: Theme.radiusSm
                color: Theme.appBackground
                border.width: Theme.borderWidth
                border.color: Theme.panelBorder
                clip: true

                // --- EMPTY STATE (QUANDO NÃO HÁ MENSAGENS) ---
                Item {
                    id: emptyStateArea
                    anchors.fill: parent
                    visible: AiAgent.chatHistory.length === 0

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 64
                        spacing: Theme.spacingLg

                        // Ícone Central
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 52
                            height: 52
                            radius: 26
                            color: Qt.rgba(0.9, 0.05, 0.1, 0.15)
                            border.width: Theme.borderWidth
                            border.color: Qt.rgba(0.9, 0.05, 0.1, 0.35)

                            IconGlyph {
                                anchors.centerIn: parent
                                glyph: Theme.icons.wand
                                iconSize: 24
                                iconColor: Theme.primary
                            }
                        }

                        // Título & Descrição
                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            spacing: Theme.spacingXs

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: qsTr("Como posso acelerar sua edição hoje?")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeBase
                                font.weight: Font.Bold
                                color: Theme.panelForeground
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: Math.min(parent.width, 560)
                                horizontalAlignment: Text.AlignHCenter
                                text: qsTr("Automatize cortes, crie vinhetas profissionais com HyperFrames, remova silêncios da timeline ou acione o Antigravity, Codex e OpenCode.")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                color: Theme.mutedForeground
                                wrapMode: Text.WordWrap
                            }
                        }

                        // Card Destaque Modo Hard (Full Width)
                        Rectangle {
                            width: 696
                            height: 56
                            anchors.horizontalCenter: parent.horizontalCenter
                            radius: Theme.radiusSm
                            color: hardModeBannerMouse.containsMouse ? Qt.rgba(0.96, 0.62, 0.07, 0.15) : Qt.rgba(0.96, 0.62, 0.07, 0.08)
                            border.width: 1.5
                            border.color: hardModeBannerMouse.containsMouse ? "#f59e0b" : Qt.rgba(0.96, 0.62, 0.07, 0.4)

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingMd
                                spacing: Theme.spacingMd

                                Text {
                                    text: "⚡"
                                    font.pixelSize: 22
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Column {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 2
                                    Text {
                                        text: qsTr("Modo Hard: Produzir Vídeo Completo por Link")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSm
                                        font.weight: Font.Bold
                                        color: "#f59e0b"
                                    }
                                    Text {
                                        text: qsTr("Scraping da notícia + Roteiro IA + Gameplay 1080p60 + OmniVoice CUDA + Overlays + Legendas na timeline")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeTiny
                                        color: Theme.mutedForeground
                                        elide: Text.ElideRight
                                    }
                                }

                                Rectangle {
                                    width: 80
                                    height: 28
                                    radius: 14
                                    color: "#f59e0b"
                                    Layout.alignment: Qt.AlignVCenter

                                    Text {
                                        anchors.centerIn: parent
                                        text: qsTr("Abrir ➔")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeTiny
                                        font.weight: Font.Bold
                                        color: "#121216"
                                    }
                                }
                            }

                            MouseArea {
                                id: hardModeBannerMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activeTab = 1
                            }
                        }

                        // Grid 2x2 de Prompts Rápidos
                        Grid {
                            anchors.horizontalCenter: parent.horizontalCenter
                            columns: 2
                            spacing: Theme.spacingMd

                            // Prompt 1: Lower Third
                            Rectangle {
                                width: 340
                                height: 50
                                radius: Theme.radiusSm
                                color: promptMouse1.containsMouse ? Theme.panelAccent : Theme.panelBackground
                                border.width: Theme.borderWidth
                                border.color: promptMouse1.containsMouse ? Theme.primary : Theme.panelBorder

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingMd
                                    spacing: Theme.spacingSm

                                    Text {
                                        text: "🎬"
                                        font.pixelSize: 18
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2
                                        Text {
                                            text: qsTr("Criar Lower Third HyperFrames")
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeXs
                                            font.weight: Font.DemiBold
                                            color: Theme.foreground
                                        }
                                        Text {
                                            text: qsTr("Vinheta animada com Chroma Key automático")
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeTiny
                                            color: Theme.mutedForeground
                                        }
                                    }
                                }
                                MouseArea {
                                    id: promptMouse1
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        promptInput.text = "Crie uma vinheta lower third estilizada com o nome DLuz Games"
                                        promptInput.forceActiveFocus()
                                    }
                                }
                            }

                            // Prompt 2: Remover Silêncios
                            Rectangle {
                                width: 340
                                height: 50
                                radius: Theme.radiusSm
                                color: promptMouse2.containsMouse ? Theme.panelAccent : Theme.panelBackground
                                border.width: Theme.borderWidth
                                border.color: promptMouse2.containsMouse ? Theme.primary : Theme.panelBorder

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingMd
                                    spacing: Theme.spacingSm

                                    Text {
                                        text: "✂️"
                                        font.pixelSize: 18
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2
                                        Text {
                                            text: qsTr("Remover Silêncios da Gravação")
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeXs
                                            font.weight: Font.DemiBold
                                            color: Theme.foreground
                                        }
                                        Text {
                                            text: qsTr("Corta pausas e respirações na timeline")
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeTiny
                                            color: Theme.mutedForeground
                                        }
                                    }
                                }
                                MouseArea {
                                    id: promptMouse2
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        promptInput.text = "Remova todos os silêncios e pausas da gravação na timeline"
                                        promptInput.forceActiveFocus()
                                    }
                                }
                            }

                            // Prompt 3: Locução DLuz
                            Rectangle {
                                width: 340
                                height: 50
                                radius: Theme.radiusSm
                                color: promptMouse3.containsMouse ? Theme.panelAccent : Theme.panelBackground
                                border.width: Theme.borderWidth
                                border.color: promptMouse3.containsMouse ? Theme.primary : Theme.panelBorder

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingMd
                                    spacing: Theme.spacingSm

                                    Text {
                                        text: "🎙️"
                                        font.pixelSize: 18
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2
                                        Text {
                                            text: qsTr("Locução Oficial com Voz DLuz")
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeXs
                                            font.weight: Font.DemiBold
                                            color: Theme.foreground
                                        }
                                        Text {
                                            text: qsTr("Sintetize voz clonada no OmniVoice (CUDA)")
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeTiny
                                            color: Theme.mutedForeground
                                        }
                                    }
                                }
                                MouseArea {
                                    id: promptMouse3
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        promptInput.text = "Gere uma locução de abertura usando a voz clonada do DLuz"
                                        promptInput.forceActiveFocus()
                                    }
                                }
                            }

                            // Prompt 4: Antigravity CLI
                            Rectangle {
                                width: 340
                                height: 50
                                radius: Theme.radiusSm
                                color: promptMouse4.containsMouse ? Theme.panelAccent : Theme.panelBackground
                                border.width: Theme.borderWidth
                                border.color: promptMouse4.containsMouse ? Theme.primary : Theme.panelBorder

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingMd
                                    spacing: Theme.spacingSm

                                    Text {
                                        text: "🚀"
                                        font.pixelSize: 18
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2
                                        Text {
                                            text: qsTr("Automação Antigravity DeepMind")
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeXs
                                            font.weight: Font.DemiBold
                                            color: Theme.foreground
                                        }
                                        Text {
                                            text: qsTr("Acessa habilidades avançadas no PC")
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeTiny
                                            color: Theme.mutedForeground
                                        }
                                    }
                                }
                                MouseArea {
                                    id: promptMouse4
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        AiAgent.provider = "antigravity"
                                        promptInput.text = "Crie uma vinheta com texto kinetic animado para o canal"
                                        promptInput.forceActiveFocus()
                                    }
                                }
                            }
                        }
                    }
                }

                // --- LISTA DE MENSAGENS COM HISTÓRICO ---
                ListView {
                    id: chatListView
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMd
                    model: AiAgent.chatHistory
                    clip: true
                    spacing: Theme.spacingLg
                    ScrollBar.vertical: AppScrollBar {}

                    onCountChanged: {
                        Qt.callLater(function() {
                            chatListView.positionViewAtEnd()
                        })
                    }

                    delegate: Item {
                        id: messageDelegate
                        required property var modelData
                        width: chatListView.width - Theme.spacingMd
                        implicitHeight: isUserMsg ? userBubbleCol.implicitHeight : botBubbleRow.implicitHeight

                        readonly property bool isUserMsg: modelData.role === "user"

                        // ==========================================
                        // MENSAGEM DO USUÁRIO (ALINHADA À DIREITA)
                        // ==========================================
                        Column {
                            id: userBubbleCol
                            visible: isUserMsg
                            anchors.right: parent.right
                            width: Math.min(Math.max(userTextItem.implicitWidth + 32, userHeaderRow.implicitWidth + 32), parent.width * 0.78)
                            spacing: 4

                            // Cabeçalho Usuário
                            Row {
                                id: userHeaderRow
                                anchors.right: parent.right
                                spacing: Theme.spacingXs

                                Text {
                                    text: modelData.time || ""
                                    font.family: Theme.monoFontFamily
                                    font.pixelSize: Theme.fontSizeTiny
                                    color: Theme.mutedForeground
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: qsTr("Você")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: Font.Bold
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            // Balão Usuário (Vermelho DLuz)
                            Rectangle {
                                width: parent.width
                                height: userTextItem.implicitHeight + Theme.spacingMd * 2 + 6
                                radius: 12
                                color: Theme.primary

                                Text {
                                    id: userTextItem
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingMd + 2
                                    anchors.leftMargin: Theme.spacingLg
                                    anchors.rightMargin: Theme.spacingLg
                                    text: modelData.text || ""
                                    color: Theme.primaryForeground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSm
                                    wrapMode: Text.Wrap
                                    textFormat: Text.PlainText
                                }
                            }
                        }

                        // ==========================================
                        // MENSAGEM DO BOT (ALINHADA À ESQUERDA)
                        // ==========================================
                        Row {
                            id: botBubbleRow
                            visible: !isUserMsg
                            anchors.left: parent.left
                            width: parent.width
                            spacing: Theme.spacingSm

                            // Avatar do Agente
                            Rectangle {
                                width: 32
                                height: 32
                                radius: 16
                                color: Theme.panelAccent
                                border.width: Theme.borderWidth
                                border.color: Theme.panelBorder
                                anchors.top: parent.top
                                anchors.topMargin: 2

                                IconGlyph {
                                    anchors.centerIn: parent
                                    glyph: Theme.icons.bot
                                    iconSize: Theme.iconSizeBase
                                    iconColor: Theme.constructive
                                }
                            }

                            // Coluna do Balão + Metadados
                            Column {
                                width: Math.min(Math.max(botTextItem.implicitWidth + 32, botHeaderRow.implicitWidth + 48), messageDelegate.width - 44)
                                spacing: 4

                                // Cabeçalho do Agente (Nome, Horário e Botão Copiar)
                                RowLayout {
                                    id: botHeaderRow
                                    width: parent.width
                                    spacing: Theme.spacingXs

                                    Text {
                                        text: qsTr("Agente Dluz")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Font.Bold
                                        color: Theme.constructive
                                    }

                                    Text {
                                        text: modelData.time || ""
                                        font.family: Theme.monoFontFamily
                                        font.pixelSize: Theme.fontSizeTiny
                                        color: Theme.mutedForeground
                                    }

                                    Item { Layout.fillWidth: true }

                                    // Botão de Copiar Resposta
                                    Rectangle {
                                        width: 20
                                        height: 20
                                        radius: 4
                                        color: copyMouse.containsMouse ? Theme.panelAccent : "transparent"

                                        IconGlyph {
                                            anchors.centerIn: parent
                                            glyph: Theme.icons.copy
                                            iconSize: 12
                                            iconColor: copyMouse.containsMouse ? Theme.foreground : Theme.mutedForeground
                                        }

                                        MouseArea {
                                            id: copyMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                AiAgent.copyToClipboard(modelData.text || "")
                                                Toasts.success(qsTr("Resposta copiada para a área de transferência"))
                                            }
                                        }
                                    }
                                }

                                // Card do Balão do Agente
                                Rectangle {
                                    width: parent.width
                                    height: botTextItem.implicitHeight + Theme.spacingLg * 2
                                    radius: 12
                                    color: Theme.panelAccent
                                    border.width: Theme.borderWidth
                                    border.color: Theme.panelBorder

                                    Text {
                                        id: botTextItem
                                        anchors.fill: parent
                                        anchors.margins: Theme.spacingLg
                                        text: modelData.text || ""
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSm
                                        wrapMode: Text.Wrap
                                        textFormat: Text.PlainText
                                        lineHeight: 1.25
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // BARRA DE CHIPS DE AÇÕES RÁPIDAS
            Flow {
                width: parent.width
                spacing: Theme.spacingXs

                ThemedChip {
                    text: "🚀 Antigravity CLI"
                    selected: AiAgent.provider === "antigravity"
                    variant: "primary"
                    onClicked: {
                        AiAgent.provider = "antigravity"
                        promptInput.text = "Crie uma vinheta com texto kinetic animado para o canal"
                        promptInput.forceActiveFocus()
                    }
                }

                ThemedChip {
                    text: "💻 Codex CLI"
                    selected: AiAgent.provider === "codex"
                    variant: "primary"
                    onClicked: {
                        AiAgent.provider = "codex"
                        promptInput.text = "Crie uma vinheta animada estilizada com o nome Dluz Games"
                        promptInput.forceActiveFocus()
                    }
                }

                ThemedChip {
                    text: "⚡ OpenCode"
                    selected: AiAgent.provider === "opencode"
                    variant: "primary"
                    onClicked: {
                        AiAgent.provider = "opencode"
                        promptInput.text = "Remova todos os silêncios e pausas da gravação na timeline"
                        promptInput.forceActiveFocus()
                    }
                }

                ThemedChip {
                    text: "🎬 Lower Third"
                    variant: "outline"
                    onClicked: {
                        promptInput.text = "Crie uma vinheta lower-third animada com o nome DLuz Games"
                        promptInput.forceActiveFocus()
                    }
                }

                ThemedChip {
                    text: "🎙️ Voz DLuz"
                    variant: "outline"
                    onClicked: {
                        promptInput.text = "Gere uma locução de abertura usando a voz oficial da DLuz Games"
                        promptInput.forceActiveFocus()
                    }
                }

                ThemedChip {
                    text: "✂️ Cortar Silêncios"
                    variant: "outline"
                    onClicked: {
                        promptInput.text = "Remova todos os silêncios e pausas da timeline"
                        promptInput.forceActiveFocus()
                    }
                }
            }

            // CÁPSULA MODERNA DE ENTRADA DO CHAT (GOOGLE STITCH STYLE)
            Rectangle {
                id: inputCard
                width: parent.width
                height: 72
                radius: 12
                color: Theme.panelAccent
                border.width: promptInput.activeFocus ? Theme.borderWidthFocus : Theme.borderWidth
                border.color: promptInput.activeFocus ? Theme.primary : Theme.panelBorder

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingSm
                    spacing: 4

                    ThemedTextArea {
                        id: promptInput
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        placeholderText: qsTr("Peça algo ao Agente IA... (Enter envia, Shift+Enter quebra linha)")
                        background: null

                        Keys.onReturnPressed: function(event) {
                            if (event.modifiers & Qt.ShiftModifier) {
                                event.accepted = false
                            } else {
                                event.accepted = true
                                if (sendBtn.enabled) {
                                    sendBtn.clicked()
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingSm

                        // Indicador discreto de atalho
                        Text {
                            text: qsTr("Shift+Enter para pular linha")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeTiny
                            color: Theme.mutedForeground
                        }

                        Item { Layout.fillWidth: true }

                        ThemedButton {
                            id: sendBtn
                            text: qsTr("Enviar")
                            glyph: Theme.icons.chevronsRight
                            variant: "primary"
                            enabled: !AiAgent.isBusy && promptInput.text.trim().length > 0
                            onClicked: {
                                const textToSend = promptInput.text.trim()
                                if (textToSend.length > 0) {
                                    AiAgent.sendMessage(textToSend)
                                    promptInput.text = ""
                                }
                            }
                        }
                    }
                }
            }
        }

        // ====================================================================
        // ABA 1: ⚡ MODO HARD — PRODUÇÃO TOTAL DE VÍDEO POR LINK
        // ====================================================================
        Column {
            id: hardModeTab
            width: parent.width
            spacing: Theme.spacingMd
            visible: root.activeTab === 1

            property string selectedVoice: "omnivoice"
            property string selectedFormat: "16:9"
            property int livePercent: 0
            property string liveStatus: ""

            Connections {
                target: AiAgent
                function onHardModeProgress(percent, statusText) {
                    hardModeTab.livePercent = percent
                    hardModeTab.liveStatus = statusText
                }
                function onHardModeFinished(success, manifestPath, message) {
                    if (success) {
                        hardModeTab.livePercent = 100
                        hardModeTab.liveStatus = qsTr("Vídeo montado na timeline com sucesso!")
                    }
                }
            }

            // Banner Hero Google Stitch
            Rectangle {
                width: parent.width
                height: 64
                radius: Theme.radiusMd
                color: Qt.rgba(0.96, 0.62, 0.07, 0.1)
                border.width: 1.5
                border.color: Qt.rgba(0.96, 0.62, 0.07, 0.35)

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMd
                    spacing: Theme.spacingMd

                    Rectangle {
                        width: 40
                        height: 40
                        radius: 20
                        color: "#f59e0b"
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            anchors.centerIn: parent
                            text: "⚡"
                            font.pixelSize: 20
                        }
                    }

                    Column {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        Text {
                            text: qsTr("Modo Hard: Produção Autônoma de Vídeo por Link")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            font.weight: Font.Bold
                            color: "#f59e0b"
                        }

                        Text {
                            text: qsTr("Gera roteiro com 'Fala melhores, beleza?', gameplay 1080p60, voz OmniVoice CUDA (RTX 2060), overlays HyperFrames e legendas sincronizadas.")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeTiny
                            color: Theme.mutedForeground
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            // Card Principal do Formulário
            Rectangle {
                width: parent.width
                implicitHeight: formLayout.implicitHeight + Theme.spacingLg * 2
                radius: Theme.radiusMd
                color: Theme.panelBackground
                border.width: Theme.borderWidth
                border.color: Theme.panelBorder

                ColumnLayout {
                    id: formLayout
                    anchors.fill: parent
                    anchors.margins: Theme.spacingLg
                    spacing: Theme.spacingMd

                    // Campo 1: Link da Matéria ou Notícia
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: qsTr("📰 Link da Matéria / Artigo ou Tema do Vídeo *")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Font.DemiBold
                            color: Theme.foreground
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 38
                            radius: Theme.radiusSm
                            color: Theme.appBackground
                            border.width: Theme.borderWidth
                            border.color: articleField.activeFocus ? "#f59e0b" : Theme.panelBorder

                            TextInput {
                                id: articleField
                                anchors.fill: parent
                                anchors.margins: 9
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                color: Theme.foreground
                                clip: true
                                selectByMouse: true

                                Text {
                                    anchors.fill: parent
                                    visible: !articleField.text && !articleField.activeFocus
                                    text: qsTr("Cole a URL da matéria (ex: https://dluzgames.com.br/...) ou texto da notícia")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSm
                                    color: Theme.mutedForeground
                                }
                            }
                        }
                    }

                    // Campo 2: Link da Gameplay
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: qsTr("🎮 Link da Gameplay no YouTube (ou arquivo local)")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Font.DemiBold
                            color: Theme.foreground
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 38
                            radius: Theme.radiusSm
                            color: Theme.appBackground
                            border.width: Theme.borderWidth
                            border.color: gameplayField.activeFocus ? "#f59e0b" : Theme.panelBorder

                            TextInput {
                                id: gameplayField
                                anchors.fill: parent
                                anchors.margins: 9
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                color: Theme.foreground
                                clip: true
                                selectByMouse: true

                                Text {
                                    anchors.fill: parent
                                    visible: !gameplayField.text && !gameplayField.activeFocus
                                    text: qsTr("URL do YouTube (ex: https://youtube.com/watch?v=...) ou deixe em branco para busca automática")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSm
                                    color: Theme.mutedForeground
                                }
                            }
                        }
                    }

                    // Seletores lado a lado
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingMd

                        // Seletor de Voz
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: qsTr("🎙️ Motor de Voz")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeXs
                                font.weight: Font.DemiBold
                                color: Theme.foreground
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacingSm

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 34
                                    radius: Theme.radiusSm
                                    color: hardModeTab.selectedVoice === "omnivoice" ? Theme.panelAccent : Theme.appBackground
                                    border.width: hardModeTab.selectedVoice === "omnivoice" ? 1.5 : 1
                                    border.color: hardModeTab.selectedVoice === "omnivoice" ? "#f59e0b" : Theme.panelBorder

                                    Text {
                                        anchors.centerIn: parent
                                        text: qsTr("🎙️ Voz DLuz (OmniVoice CUDA)")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeTiny
                                        font.weight: hardModeTab.selectedVoice === "omnivoice" ? Font.DemiBold : Font.Normal
                                        color: hardModeTab.selectedVoice === "omnivoice" ? "#f59e0b" : Theme.mutedForeground
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: hardModeTab.selectedVoice = "omnivoice"
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 34
                                    radius: Theme.radiusSm
                                    color: hardModeTab.selectedVoice === "edge_tts" ? Theme.panelAccent : Theme.appBackground
                                    border.width: hardModeTab.selectedVoice === "edge_tts" ? 1.5 : 1
                                    border.color: hardModeTab.selectedVoice === "edge_tts" ? "#f59e0b" : Theme.panelBorder

                                    Text {
                                        anchors.centerIn: parent
                                        text: qsTr("⚡ Edge-TTS Neural")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeTiny
                                        font.weight: hardModeTab.selectedVoice === "edge_tts" ? Font.DemiBold : Font.Normal
                                        color: hardModeTab.selectedVoice === "edge_tts" ? "#f59e0b" : Theme.mutedForeground
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: hardModeTab.selectedVoice = "edge_tts"
                                    }
                                }
                            }
                        }

                        // Seletor de Formato
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: qsTr("📐 Formato do Vídeo")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeXs
                                font.weight: Font.DemiBold
                                color: Theme.foreground
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacingSm

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 34
                                    radius: Theme.radiusSm
                                    color: hardModeTab.selectedFormat === "16:9" ? Theme.panelAccent : Theme.appBackground
                                    border.width: hardModeTab.selectedFormat === "16:9" ? 1.5 : 1
                                    border.color: hardModeTab.selectedFormat === "16:9" ? Theme.primary : Theme.panelBorder

                                    Text {
                                        anchors.centerIn: parent
                                        text: qsTr("📺 16:9 (YouTube)")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeTiny
                                        font.weight: hardModeTab.selectedFormat === "16:9" ? Font.DemiBold : Font.Normal
                                        color: hardModeTab.selectedFormat === "16:9" ? Theme.primary : Theme.mutedForeground
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: hardModeTab.selectedFormat = "16:9"
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 34
                                    radius: Theme.radiusSm
                                    color: hardModeTab.selectedFormat === "9:16" ? Theme.panelAccent : Theme.appBackground
                                    border.width: hardModeTab.selectedFormat === "9:16" ? 1.5 : 1
                                    border.color: hardModeTab.selectedFormat === "9:16" ? Theme.primary : Theme.panelBorder

                                    Text {
                                        anchors.centerIn: parent
                                        text: qsTr("📱 9:16 (TikTok/Shorts)")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeTiny
                                        font.weight: hardModeTab.selectedFormat === "9:16" ? Font.DemiBold : Font.Normal
                                        color: hardModeTab.selectedFormat === "9:16" ? Theme.primary : Theme.mutedForeground
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: hardModeTab.selectedFormat = "9:16"
                                    }
                                }
                            }
                        }
                    }

                    // Botão de Disparo Principal
                    Rectangle {
                        Layout.fillWidth: true
                        height: 44
                        radius: Theme.radiusSm
                        color: {
                            if (AiAgent.isBusy || !articleField.text.trim()) return Theme.panelAccent
                            return launchMouse.containsMouse ? "#d97706" : "#f59e0b"
                        }
                        border.width: 1
                        border.color: Qt.darker(color, 1.2)

                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.spacingSm

                            Text {
                                text: AiAgent.isBusy ? "⏳" : "🚀"
                                font.pixelSize: 16
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: AiAgent.isBusy ? qsTr("Produzindo Vídeo... Aguarde...") : qsTr("Iniciar Produção Autônoma & Injetar na Timeline")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: Font.Bold
                                color: (AiAgent.isBusy || !articleField.text.trim()) ? Theme.mutedForeground : "#121216"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: launchMouse
                            anchors.fill: parent
                            enabled: !AiAgent.isBusy && articleField.text.trim().length > 0
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            hoverEnabled: true
                            onClicked: {
                                AiAgent.startHardModeProduction(
                                    articleField.text.trim(),
                                    gameplayField.text.trim(),
                                    hardModeTab.selectedVoice,
                                    "pt",
                                    hardModeTab.selectedFormat
                                )
                            }
                        }
                    }
                }
            }

            // Card de Progresso em Tempo Real
            Rectangle {
                width: parent.width
                height: 72
                radius: Theme.radiusMd
                color: Theme.panelAccent
                border.width: Theme.borderWidth
                border.color: Theme.panelBorder
                visible: AiAgent.isBusy || hardModeTab.livePercent > 0

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMd
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: qsTr("Status da Produção:")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Font.DemiBold
                            color: Theme.foreground
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: hardModeTab.livePercent + "%"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Font.Bold
                            color: "#f59e0b"
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 6
                        radius: 3
                        color: Theme.appBackground

                        Rectangle {
                            height: parent.height
                            width: parent.width * (Math.min(100, Math.max(0, hardModeTab.livePercent)) / 100.0)
                            radius: 3
                            color: "#f59e0b"
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: hardModeTab.liveStatus.length > 0 ? hardModeTab.liveStatus : AiAgent.statusMessage
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeTiny
                        color: Theme.mutedForeground
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // ====================================================================
        // ABA 2: MODELOS & PROVEDORES DE IA
        // ====================================================================
        Column {
            width: parent.width
            spacing: Theme.spacingLg
            visible: root.activeTab === 2

            ThemedLabel {
                width: parent.width
                size: "sm"
                wrapMode: Text.WordWrap
                color: Theme.mutedForeground
                text: qsTr("Selecione o motor de Inteligência Artificial para o seu Dluz Film. Provedores locais com CLI executam sem necessidade de chaves de API.")
            }

            // GRID DE CARDS DOS PROVEDORES (3 COLUNAS)
            Grid {
                width: parent.width
                columns: 3
                spacing: Theme.spacingMd

                // 1. Antigravity CLI (DeepMind)
                Rectangle {
                    width: (parent.width - Theme.spacingMd * 2) / 3
                    height: 94
                    radius: Theme.radiusSm
                    color: AiAgent.provider === "antigravity" ? Qt.rgba(0.9, 0.05, 0.1, 0.12) : Theme.panelAccent
                    border.width: AiAgent.provider === "antigravity" ? 2 : 1
                    border.color: AiAgent.provider === "antigravity" ? Theme.primary : Theme.panelBorder

                    Column {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingMd
                        spacing: 4

                        RowLayout {
                            width: parent.width
                            spacing: Theme.spacingXs

                            Text { text: "🚀"; font.pixelSize: 16 }
                            Text {
                                text: "Antigravity CLI"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: Font.Bold
                                color: Theme.foreground
                            }
                            Item { Layout.fillWidth: true }
                            // Badge de Status
                            Rectangle {
                                height: 18
                                width: agyBadgeText.implicitWidth + 10
                                radius: 9
                                color: AiAgent.antigravityAvailable ? Qt.rgba(0.1, 0.8, 0.3, 0.2) : Qt.rgba(0.8, 0.1, 0.1, 0.2)
                                Text {
                                    id: agyBadgeText
                                    anchors.centerIn: parent
                                    text: AiAgent.antigravityAvailable ? qsTr("Local ✨") : qsTr("Ausente")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeTiny
                                    font.weight: Font.Bold
                                    color: AiAgent.antigravityAvailable ? Theme.constructive : Theme.destructive
                                }
                            }
                        }

                        Text {
                            width: parent.width
                            text: qsTr("Google DeepMind oficial. Conexão direta no seu PC.")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeTiny
                            color: Theme.mutedForeground
                            wrapMode: Text.WordWrap
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AiAgent.provider = "antigravity"
                    }
                }

                // 2. OpenAI Codex CLI
                Rectangle {
                    width: (parent.width - Theme.spacingMd * 2) / 3
                    height: 94
                    radius: Theme.radiusSm
                    color: AiAgent.provider === "codex" ? Qt.rgba(0.9, 0.05, 0.1, 0.12) : Theme.panelAccent
                    border.width: AiAgent.provider === "codex" ? 2 : 1
                    border.color: AiAgent.provider === "codex" ? Theme.primary : Theme.panelBorder

                    Column {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingMd
                        spacing: 4

                        RowLayout {
                            width: parent.width
                            spacing: Theme.spacingXs

                            Text { text: "💻"; font.pixelSize: 16 }
                            Text {
                                text: "Codex CLI"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: Font.Bold
                                color: Theme.foreground
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                height: 18
                                width: codexBadgeText.implicitWidth + 10
                                radius: 9
                                color: AiAgent.codexAvailable ? Qt.rgba(0.1, 0.8, 0.3, 0.2) : Qt.rgba(0.8, 0.1, 0.1, 0.2)
                                Text {
                                    id: codexBadgeText
                                    anchors.centerIn: parent
                                    text: AiAgent.codexAvailable ? qsTr("Local ✨") : qsTr("Ausente")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeTiny
                                    font.weight: Font.Bold
                                    color: AiAgent.codexAvailable ? Theme.constructive : Theme.destructive
                                }
                            }
                        }

                        Text {
                            width: parent.width
                            text: qsTr("OpenAI Codex oficial via terminal local.")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeTiny
                            color: Theme.mutedForeground
                            wrapMode: Text.WordWrap
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AiAgent.provider = "codex"
                    }
                }

                // 3. OpenCode CLI
                Rectangle {
                    width: (parent.width - Theme.spacingMd * 2) / 3
                    height: 94
                    radius: Theme.radiusSm
                    color: AiAgent.provider === "opencode" ? Qt.rgba(0.9, 0.05, 0.1, 0.12) : Theme.panelAccent
                    border.width: AiAgent.provider === "opencode" ? 2 : 1
                    border.color: AiAgent.provider === "opencode" ? Theme.primary : Theme.panelBorder

                    Column {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingMd
                        spacing: 4

                        RowLayout {
                            width: parent.width
                            spacing: Theme.spacingXs

                            Text { text: "⚡"; font.pixelSize: 16 }
                            Text {
                                text: "OpenCode"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: Font.Bold
                                color: Theme.foreground
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                height: 18
                                width: opencodeBadgeText.implicitWidth + 10
                                radius: 9
                                color: AiAgent.opencodeCliAvailable ? Qt.rgba(0.1, 0.8, 0.3, 0.2) : Qt.rgba(0.9, 0.6, 0.1, 0.2)
                                Text {
                                    id: opencodeBadgeText
                                    anchors.centerIn: parent
                                    text: AiAgent.opencodeCliAvailable ? qsTr("Local ✨") : qsTr("Servidor")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeTiny
                                    font.weight: Font.Bold
                                    color: AiAgent.opencodeCliAvailable ? Theme.constructive : Theme.warning
                                }
                            }
                        }

                        Text {
                            width: parent.width
                            text: qsTr("OpenCode CLI nativo ou servidor Ollama/REST.")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeTiny
                            color: Theme.mutedForeground
                            wrapMode: Text.WordWrap
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AiAgent.provider = "opencode"
                    }
                }

                // 4. Google Gemini
                Rectangle {
                    width: (parent.width - Theme.spacingMd * 2) / 3
                    height: 94
                    radius: Theme.radiusSm
                    color: AiAgent.provider === "gemini" ? Qt.rgba(0.9, 0.05, 0.1, 0.12) : Theme.panelAccent
                    border.width: AiAgent.provider === "gemini" ? 2 : 1
                    border.color: AiAgent.provider === "gemini" ? Theme.primary : Theme.panelBorder

                    Column {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingMd
                        spacing: 4

                        RowLayout {
                            width: parent.width
                            spacing: Theme.spacingXs

                            Text { text: "✨"; font.pixelSize: 16 }
                            Text {
                                text: "Google Gemini"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: Font.Bold
                                color: Theme.foreground
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                height: 18
                                width: geminiBadgeText.implicitWidth + 10
                                radius: 9
                                color: AiAgent.geminiKey.length > 0 ? Qt.rgba(0.1, 0.8, 0.3, 0.2) : Qt.rgba(0.9, 0.6, 0.1, 0.2)
                                Text {
                                    id: geminiBadgeText
                                    anchors.centerIn: parent
                                    text: AiAgent.geminiKey.length > 0 ? qsTr("Ativo") : qsTr("Sem chave")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeTiny
                                    font.weight: Font.Bold
                                    color: AiAgent.geminiKey.length > 0 ? Theme.constructive : Theme.warning
                                }
                            }
                        }

                        Text {
                            width: parent.width
                            text: qsTr("Gemini 2.5 Flash e Pro direto via API do Google.")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeTiny
                            color: Theme.mutedForeground
                            wrapMode: Text.WordWrap
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AiAgent.provider = "gemini"
                    }
                }

                // 5. Groq LPU
                Rectangle {
                    width: (parent.width - Theme.spacingMd * 2) / 3
                    height: 94
                    radius: Theme.radiusSm
                    color: AiAgent.provider === "groq" ? Qt.rgba(0.9, 0.05, 0.1, 0.12) : Theme.panelAccent
                    border.width: AiAgent.provider === "groq" ? 2 : 1
                    border.color: AiAgent.provider === "groq" ? Theme.primary : Theme.panelBorder

                    Column {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingMd
                        spacing: 4

                        RowLayout {
                            width: parent.width
                            spacing: Theme.spacingXs

                            Text { text: "⚡"; font.pixelSize: 16 }
                            Text {
                                text: "Groq LPU"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: Font.Bold
                                color: Theme.foreground
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                height: 18
                                width: groqBadgeText.implicitWidth + 10
                                radius: 9
                                color: AiAgent.groqKey.length > 0 ? Qt.rgba(0.1, 0.8, 0.3, 0.2) : Qt.rgba(0.9, 0.6, 0.1, 0.2)
                                Text {
                                    id: groqBadgeText
                                    anchors.centerIn: parent
                                    text: AiAgent.groqKey.length > 0 ? qsTr("Ativo") : qsTr("Sem chave")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeTiny
                                    font.weight: Font.Bold
                                    color: AiAgent.groqKey.length > 0 ? Theme.constructive : Theme.warning
                                }
                            }
                        }

                        Text {
                            width: parent.width
                            text: qsTr("Velocidade extrema de inferência com Llama 3.3.")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeTiny
                            color: Theme.mutedForeground
                            wrapMode: Text.WordWrap
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AiAgent.provider = "groq"
                    }
                }

                // 6. OpenRouter
                Rectangle {
                    width: (parent.width - Theme.spacingMd * 2) / 3
                    height: 94
                    radius: Theme.radiusSm
                    color: AiAgent.provider === "openrouter" ? Qt.rgba(0.9, 0.05, 0.1, 0.12) : Theme.panelAccent
                    border.width: AiAgent.provider === "openrouter" ? 2 : 1
                    border.color: AiAgent.provider === "openrouter" ? Theme.primary : Theme.panelBorder

                    Column {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingMd
                        spacing: 4

                        RowLayout {
                            width: parent.width
                            spacing: Theme.spacingXs

                            Text { text: "🌐"; font.pixelSize: 16 }
                            Text {
                                text: "OpenRouter"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: Font.Bold
                                color: Theme.foreground
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                height: 18
                                width: routerBadgeText.implicitWidth + 10
                                radius: 9
                                color: AiAgent.openrouterKey.length > 0 ? Qt.rgba(0.1, 0.8, 0.3, 0.2) : Qt.rgba(0.9, 0.6, 0.1, 0.2)
                                Text {
                                    id: routerBadgeText
                                    anchors.centerIn: parent
                                    text: AiAgent.openrouterKey.length > 0 ? qsTr("Ativo") : qsTr("Sem chave")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeTiny
                                    font.weight: Font.Bold
                                    color: AiAgent.openrouterKey.length > 0 ? Theme.constructive : Theme.warning
                                }
                            }
                        }

                        Text {
                            width: parent.width
                            text: qsTr("Acesso unificado a Claude, GPT-4o, DeepSeek.")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeTiny
                            color: Theme.mutedForeground
                            wrapMode: Text.WordWrap
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AiAgent.provider = "openrouter"
                    }
                }
            }

            // PAINEL DE DETALHES E CONFIGURAÇÃO DO MOTOR SELECIONADO
            Rectangle {
                width: parent.width
                implicitHeight: configCol.implicitHeight + Theme.spacingLg * 2
                radius: Theme.radiusSm
                color: Theme.panelAccent
                border.width: Theme.borderWidth
                border.color: Theme.panelBorder

                Column {
                    id: configCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingLg
                    spacing: Theme.spacingMd

                    // 1. Caso Antigravity
                    Column {
                        width: parent.width
                        spacing: Theme.spacingSm
                        visible: AiAgent.provider === "antigravity"

                        RowLayout {
                            width: parent.width
                            spacing: Theme.spacingSm

                            IconGlyph {
                                glyph: AiAgent.antigravityAvailable ? Theme.icons.check : Theme.icons.warning
                                iconSize: Theme.iconSizeMd
                                iconColor: AiAgent.antigravityAvailable ? Theme.constructive : Theme.destructive
                            }
                            Text {
                                text: AiAgent.antigravityAvailable ? qsTr("Antigravity CLI Conectado & Operacional") : qsTr("Antigravity CLI não encontrado no PATH")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: Font.Bold
                                color: AiAgent.antigravityAvailable ? Theme.constructive : Theme.destructive
                            }
                        }

                        Text {
                            width: parent.width
                            text: AiAgent.antigravityAvailable
                                  ? qsTr("Executável detectado: ") + AiAgent.antigravityExecutablePath()
                                  : qsTr("Certifique-se de que o executável 'agy' está no PATH do sistema.")
                            font.family: Theme.monoFontFamily
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.mutedForeground
                            wrapMode: Text.WrapAnywhere
                        }

                        Text {
                            width: parent.width
                            text: qsTr("O Antigravity CLI executa localmente com aceleração no DluzPC, garantindo respostas em 1 segundo e integração nativa com todas as ferramentas de vídeo.")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.foreground
                            wrapMode: Text.WordWrap
                        }
                    }

                    // 2. Caso Codex
                    Column {
                        width: parent.width
                        spacing: Theme.spacingSm
                        visible: AiAgent.provider === "codex"

                        RowLayout {
                            width: parent.width
                            spacing: Theme.spacingSm

                            IconGlyph {
                                glyph: AiAgent.codexAvailable ? Theme.icons.check : Theme.icons.warning
                                iconSize: Theme.iconSizeMd
                                iconColor: AiAgent.codexAvailable ? Theme.constructive : Theme.destructive
                            }
                            Text {
                                text: AiAgent.codexAvailable ? qsTr("OpenAI Codex CLI Conectado & Operacional") : qsTr("Codex CLI não encontrado no PATH")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: Font.Bold
                                color: AiAgent.codexAvailable ? Theme.constructive : Theme.destructive
                            }
                        }

                        Text {
                            width: parent.width
                            text: AiAgent.codexAvailable
                                  ? qsTr("Executável detectado: ") + AiAgent.codexExecutablePath()
                                  : qsTr("Certifique-se de que o executável 'codex' está instalado e configurado no PATH.")
                            font.family: Theme.monoFontFamily
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.mutedForeground
                            wrapMode: Text.WrapAnywhere
                        }

                        Text {
                            width: parent.width
                            text: qsTr("O Codex CLI roda diretamente pelo terminal autenticado da OpenAI no seu computador, dispensando a necessidade de chaves de API manuais.")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.foreground
                            wrapMode: Text.WordWrap
                        }
                    }

                    // 3. Caso OpenCode
                    Column {
                        width: parent.width
                        spacing: Theme.spacingSm
                        visible: AiAgent.provider === "opencode"

                        RowLayout {
                            width: parent.width
                            spacing: Theme.spacingSm

                            IconGlyph {
                                glyph: AiAgent.opencodeCliAvailable ? Theme.icons.check : Theme.icons.settings
                                iconSize: Theme.iconSizeMd
                                iconColor: AiAgent.opencodeCliAvailable ? Theme.constructive : Theme.primary
                            }
                            Text {
                                text: AiAgent.opencodeCliAvailable ? qsTr("OpenCode CLI Detectado (Modo Local)") : qsTr("Modo Servidor OpenCode / Ollama")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: Font.Bold
                                color: AiAgent.opencodeCliAvailable ? Theme.constructive : Theme.foreground
                            }
                        }

                        ThemedLabel {
                            text: qsTr("URL do Servidor / Endpoint (opcional no modo CLI):")
                            size: "xs"
                        }
                        ThemedTextField {
                            width: parent.width
                            text: AiAgent.opencodeUrl
                            placeholderText: "http://localhost:11434/v1"
                            onTextChanged: AiAgent.opencodeUrl = text.trim()
                        }

                        ThemedLabel {
                            text: qsTr("API Key (opcional, deixe vazio para usar o CLI local):")
                            size: "xs"
                        }
                        ThemedTextField {
                            width: parent.width
                            echoMode: TextInput.PasswordEchoOnEdit
                            text: AiAgent.opencodeKey
                            placeholderText: "sk-... (opcional)"
                            onTextChanged: AiAgent.opencodeKey = text.trim()
                        }
                    }

                    // 4. Caso Gemini
                    Column {
                        width: parent.width
                        spacing: Theme.spacingSm
                        visible: AiAgent.provider === "gemini"

                        ThemedLabel {
                            text: qsTr("Chave de API do Google Gemini:")
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

                    // 5. Caso Groq
                    Column {
                        width: parent.width
                        spacing: Theme.spacingSm
                        visible: AiAgent.provider === "groq"

                        ThemedLabel {
                            text: qsTr("Chave de API do Groq:")
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

                    // 6. Caso OpenRouter
                    Column {
                        width: parent.width
                        spacing: Theme.spacingSm
                        visible: AiAgent.provider === "openrouter"

                        ThemedLabel {
                            text: qsTr("Chave de API do OpenRouter:")
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

                    // Campo comum de Modelo Personalizado
                    Column {
                        width: parent.width
                        spacing: Theme.spacingXs

                        ThemedLabel {
                            text: qsTr("Nome do Modelo (opcional, deixe vazio para o padrão otimizado):")
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
    }
}
