import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Drift
import ".."

ThemedDialog {
    id: root

    title: qsTr("✨ Gerar Legendas Dinâmicas — Estilo MrBeast")
    preferredWidth: 640
    showAccept: false
    rejectText: isRunning ? qsTr("Fechar janela") : qsTr("Cancelar")

    property int targetTrackIndex: -1
    property int targetClipIndex: -1
    property var clipData: ({})
    property string clipPath: ""
    property double clipDuration: 0.0
    property double clipInPoint: 0.0
    property double clipStart: 0.0
    property string clipName: ""
    property string clipThumb: ""

    // Preset selecionado (padrão: MrBeast / Karaoke Pop)
    property string selectedPresetId: "karaoke-pop"
    // Ritmo de exibição: 1 = palavra por palavra (MrBeast), 2 = 2-3 palavras, 0 = frases completas
    property int selectedWordsPerCue: 1
    // Idioma do áudio
    property string selectedLang: "pt"
    // Converter para MAIÚSCULAS
    property bool uppercaseEnabled: true

    property bool isRunning: false
    property int progressPercent: 0
    property string progressStatus: ""

    // Lista de presets nativos em destaque com descrições amigáveis
    readonly property var popularPresets: [
        {
            id: "karaoke-pop",
            name: qsTr("MrBeast (Karaoke Pop)"),
            desc: qsTr("League Spartan 900 • Amarelo ouro #ffd400 com zoom e contorno"),
            badge: qsTr("Padrão MrBeast")
        },
        {
            id: "hormozi",
            name: qsTr("Hormozi Punch"),
            desc: qsTr("Anton 96 • Primeira palavra em vermelho vivo #ff2d2d"),
            badge: qsTr("Alta Retenção")
        },
        {
            id: "karaoke-highlight",
            name: qsTr("Karaoke Highlight"),
            desc: qsTr("Inter 800 • Destaque dinâmico em caixa verde neon #22c55e"),
            badge: ""
        },
        {
            id: "pop",
            name: qsTr("Impact Pop"),
            desc: qsTr("Fredoka 600 • Pop in/out amarelo vibrante e contorno"),
            badge: ""
        },
        {
            id: "neon",
            name: qsTr("Neon Glow"),
            desc: qsTr("Bebas Neue • Brilho e sombra ciano neon de alto impacto"),
            badge: ""
        },
        {
            id: "word-background",
            name: qsTr("Word Background"),
            desc: qsTr("Inter 800 • Caixa sólida em destaque nas palavras"),
            badge: ""
        },
        {
            id: "sentence-background",
            name: qsTr("Sentence Box"),
            desc: qsTr("Montserrat 800 • Tarja amarela sólida de alto contraste"),
            badge: ""
        }
    ]

    function openForClip(trackIndex, clipIndex, clip) {
        root.targetTrackIndex = trackIndex
        root.targetClipIndex = clipIndex
        root.clipData = clip || {}
        root.clipPath = clip ? (clip.path || "") : ""
        root.clipDuration = clip ? (clip.duration || 0.0) : 0.0
        root.clipInPoint = clip ? (clip.inPoint || 0.0) : 0.0
        root.clipStart = clip ? (clip.start || 0.0) : 0.0
        root.clipName = clip ? (clip.name || qsTr("Clipe selecionado")) : qsTr("Clipe selecionado")
        root.clipThumb = clip ? (clip.thumbnailPath || "") : ""

        // Configurações padrão MrBeast
        root.selectedPresetId = "karaoke-pop"
        root.selectedWordsPerCue = 1
        root.selectedLang = "pt"
        root.uppercaseEnabled = true

        root.progressPercent = 0
        root.progressStatus = ""
        root.isRunning = false
        open()
    }

    Connections {
        target: AiAgent

        function onDynamicSubtitlesProgress(percent, statusText) {
            root.progressPercent = percent
            root.progressStatus = statusText
            root.isRunning = true
        }

        function onDynamicSubtitlesFinished(success, srtPath, message) {
            root.isRunning = false
            if (success) {
                root.progressPercent = 100
                root.close()
                Toasts.success(qsTr("Legendas dinâmicas MrBeast geradas e adicionadas à timeline!"))
            } else {
                Toasts.error(qsTr("Falha ao gerar legendas: %1").arg(message))
            }
        }
    }

    contentItem: Column {
        id: body
        width: parent ? parent.width : 640
        spacing: Theme.spacingMd

        // =================================================================
        // CARD 1: Informações do Clipe
        // =================================================================
        Rectangle {
            width: parent.width
            height: clipInfoRow.implicitHeight + Theme.spacingSm * 2
            radius: Theme.radiusSm
            color: Theme.panelBackground
            border.width: Theme.borderWidth
            border.color: Theme.panelBorder

            RowLayout {
                id: clipInfoRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Theme.spacingSm
                spacing: Theme.spacingSm

                Rectangle {
                    width: 44
                    height: 44
                    radius: Theme.radiusSm
                    color: Theme.panelAccent
                    border.width: Theme.borderWidth
                    border.color: Theme.panelBorder
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: root.clipThumb.length > 0 ? ("image://preview/" + root.clipThumb) : ""
                        fillMode: Image.PreserveAspectCrop
                        visible: root.clipThumb.length > 0
                    }

                    IconGlyph {
                        anchors.centerIn: parent
                        visible: root.clipThumb.length === 0
                        glyph: Theme.icons.captions
                        iconSize: 22
                        iconColor: Theme.primary
                    }
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 2

                    ThemedLabel {
                        text: root.clipName
                        size: "sm"
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        width: parent.width
                    }

                    Row {
                        spacing: Theme.spacingSm

                        ThemedLabel {
                            text: qsTr("Duração: %1s").arg(root.clipDuration.toFixed(1))
                            size: "xs"
                            color: Theme.mutedForeground
                        }

                        ThemedLabel {
                            text: "•"
                            size: "xs"
                            color: Theme.mutedForeground
                        }

                        ThemedLabel {
                            text: qsTr("Posição Timeline: %1s").arg(root.clipStart.toFixed(1))
                            size: "xs"
                            color: Theme.mutedForeground
                        }

                        ThemedLabel {
                            text: "•"
                            size: "xs"
                            color: Theme.mutedForeground
                        }

                        ThemedLabel {
                            text: qsTr("Whisper IA Neural")
                            size: "xs"
                            color: Theme.primary
                            font.weight: Font.Medium
                        }
                    }
                }
            }
        }

        // =================================================================
        // CARD 2: Seleção do Estilo Visual (Presets Nativos)
        // =================================================================
        Column {
            width: parent.width
            spacing: Theme.spacingXs

            RowLayout {
                width: parent.width

                ThemedLabel {
                    text: qsTr("🎨 Estilo Visual das Legendas (Predefinições Nativas):")
                    size: "sm"
                    font.weight: Font.Medium
                    Layout.fillWidth: true
                }

                ThemedLabel {
                    text: qsTr("Predefinições prontas do programa")
                    size: "xs"
                    color: Theme.mutedForeground
                }
            }

            // Scroll com cards dos presets
            Flickable {
                width: parent.width
                height: 148
                contentWidth: presetGridRow.width
                contentHeight: 148
                clip: true
                ScrollBar.horizontal: AppScrollBar { orientation: Qt.Horizontal }

                Row {
                    id: presetGridRow
                    spacing: Theme.spacingSm
                    padding: 2

                    Repeater {
                        model: root.popularPresets

                        delegate: Rectangle {
                            id: presetCard
                            required property var modelData
                            required property int index

                            readonly property bool isSelected: root.selectedPresetId === modelData.id
                            width: 170
                            height: 140
                            radius: Theme.radiusSm
                            color: isSelected ? Theme.panelAccent : Theme.panelBackground
                            border.width: isSelected ? 2 : 1
                            border.color: isSelected ? Theme.primary : (cardHover.hovered ? Theme.panelMuted : Theme.panelBorder)

                            Behavior on border.color {
                                ColorAnimation { duration: Theme.durationFast }
                            }
                            Behavior on scale {
                                NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
                            }

                            HoverHandler {
                                id: cardHover
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectedPresetId = presetCard.modelData.id
                            }

                            Column {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 6

                                // Miniatura do texto gerada pelo motor nativo
                                TextStylePackThumb {
                                    width: parent.width
                                    height: 58
                                    presetId: presetCard.modelData.id
                                    selected: presetCard.isSelected
                                }

                                // Título do preset
                                RowLayout {
                                    width: parent.width
                                    spacing: 4

                                    ThemedLabel {
                                        text: presetCard.modelData.name
                                        size: "xs"
                                        font.weight: Font.DemiBold
                                        color: presetCard.isSelected ? Theme.primary : Theme.panelForeground
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Rectangle {
                                        visible: presetCard.modelData.badge.length > 0
                                        color: Theme.primary
                                        radius: 3
                                        height: 14
                                        width: badgeText.implicitWidth + 6

                                        Text {
                                            id: badgeText
                                            anchors.centerIn: parent
                                            text: presetCard.modelData.badge
                                            color: "#FFFFFF"
                                            font.pixelSize: 8
                                            font.bold: true
                                        }
                                    }
                                }

                                // Descrição curta
                                Text {
                                    text: presetCard.modelData.desc
                                    width: parent.width
                                    elide: Text.ElideRight
                                    color: Theme.mutedForeground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                }
                            }
                        }
                    }
                }
            }
        }

        // =================================================================
        // CARD 3: Ritmo de Exibição na Tela (Agrupamento)
        // =================================================================
        Column {
            width: parent.width
            spacing: Theme.spacingXs

            ThemedLabel {
                text: qsTr("⏱️ Ritmo de Exibição na Tela:")
                size: "sm"
                font.weight: Font.Medium
            }

            RowLayout {
                width: parent.width
                spacing: Theme.spacingSm

                ThemedButton {
                    text: "🔤 " + qsTr("Palavra por Palavra (MrBeast)")
                    variant: root.selectedWordsPerCue === 1 ? "primary" : "secondary"
                    tooltip: qsTr("Exatamente 1 palavra por vez na tela com zoom e impacto instantâneo")
                    Layout.fillWidth: true
                    onClicked: root.selectedWordsPerCue = 1
                }

                ThemedButton {
                    text: "⚡ " + qsTr("2 a 3 Palavras")
                    variant: root.selectedWordsPerCue === 2 ? "primary" : "secondary"
                    tooltip: qsTr("Blocos curtos de 2 a 3 palavras para leitura rápida")
                    Layout.fillWidth: true
                    onClicked: root.selectedWordsPerCue = 2
                }

                ThemedButton {
                    text: "📄 " + qsTr("Frases Completas")
                    variant: root.selectedWordsPerCue === 0 ? "primary" : "secondary"
                    tooltip: qsTr("Frases inteiras com destaque karaoke progressivo na palavra ativa")
                    Layout.fillWidth: true
                    onClicked: root.selectedWordsPerCue = 0
                }
            }
        }

        // =================================================================
        // CARD 4: Idioma & Opções Adicionais
        // =================================================================
        RowLayout {
            width: parent.width
            spacing: Theme.spacingMd

            // Coluna de Idioma
            Column {
                Layout.fillWidth: true
                spacing: Theme.spacingXs

                ThemedLabel {
                    text: qsTr("🌐 Idioma do Áudio:")
                    size: "sm"
                    font.weight: Font.Medium
                }

                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingXs

                    ThemedButton {
                        text: "🇧🇷 PT"
                        variant: root.selectedLang === "pt" ? "primary" : "secondary"
                        Layout.fillWidth: true
                        onClicked: root.selectedLang = "pt"
                    }
                    ThemedButton {
                        text: "🇺🇸 EN"
                        variant: root.selectedLang === "en" ? "primary" : "secondary"
                        Layout.fillWidth: true
                        onClicked: root.selectedLang = "en"
                    }
                    ThemedButton {
                        text: "🇪🇸 ES"
                        variant: root.selectedLang === "es" ? "primary" : "secondary"
                        Layout.fillWidth: true
                        onClicked: root.selectedLang = "es"
                    }
                    ThemedButton {
                        text: "Auto"
                        variant: root.selectedLang === "auto" ? "primary" : "secondary"
                        Layout.fillWidth: true
                        onClicked: root.selectedLang = "auto"
                    }
                }
            }

            // Coluna de Opção Maiúsculas
            Column {
                Layout.preferredWidth: 240
                spacing: Theme.spacingXs

                ThemedLabel {
                    text: qsTr("Formatação:")
                    size: "sm"
                    font.weight: Font.Medium
                }

                ThemedCheckBox {
                    text: qsTr("Letras MAIÚSCULAS (MrBeast)")
                    checked: root.uppercaseEnabled
                    onToggled: root.uppercaseEnabled = checked
                }
            }
        }

        // =================================================================
        // BARRA DE PROGRESSO (QUANDO EM EXECUÇÃO)
        // =================================================================
        Column {
            width: parent.width
            spacing: Theme.spacingXs
            visible: root.isRunning

            ThemedProgressBar {
                width: parent.width
                value: root.progressPercent / 100.0
            }

            RowLayout {
                width: parent.width

                ThemedLabel {
                    text: root.progressStatus.length > 0 ? root.progressStatus : qsTr("Transcrevendo falas com Whisper IA...")
                    size: "xs"
                    color: Theme.mutedForeground
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                ThemedLabel {
                    text: root.progressPercent + "%"
                    size: "xs"
                    color: Theme.primary
                    font.weight: Font.Bold
                }
            }
        }

        // =================================================================
        // BOTÕES DE AÇÃO
        // =================================================================
        RowLayout {
            width: parent.width
            spacing: Theme.spacingSm

            Item {
                Layout.fillWidth: true
            }

            ThemedButton {
                text: qsTr("Cancelar")
                variant: "ghost"
                enabled: !root.isRunning
                onClicked: root.close()
            }

            ThemedButton {
                text: root.isRunning ? qsTr("Gerando Legendas...") : qsTr("✨ Gerar Legendas Dinâmicas")
                variant: "primary"
                icon.name: Theme.icons.sparkles
                enabled: !root.isRunning && root.clipPath.length > 0
                onClicked: {
                    root.isRunning = true
                    root.progressPercent = 5
                    root.progressStatus = qsTr("Iniciando transcrição neural...")
                    AiAgent.generateDynamicSubtitles(
                        root.targetTrackIndex,
                        root.targetClipIndex,
                        root.clipPath,
                        root.clipInPoint,
                        root.clipDuration,
                        root.clipStart,
                        root.selectedLang,
                        root.selectedWordsPerCue,
                        root.uppercaseEnabled,
                        root.selectedPresetId
                    )
                }
            }
        }
    }
}
