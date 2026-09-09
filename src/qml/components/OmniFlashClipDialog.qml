import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Drift
import ".."

ThemedDialog {
    id: root

    title: qsTr("Editar com OmniFlash (Google Flow)")
    preferredWidth: 620
    showAccept: false
    rejectText: isRunning ? qsTr("Fechar janela") : qsTr("Cancelar")

    property int targetTrackIndex: -1
    property int targetClipIndex: -1
    property var clipData: ({})
    property string clipPath: ""
    property double clipDuration: 0.0
    property double clipInPoint: 0.0
    property string clipName: ""
    property string clipThumb: ""

    property bool preserveAudio: true
    property bool replaceInPlace: true
    property bool isRunning: false
    property int progressPercent: 0
    property string progressStatus: ""

    function openForClip(trackIndex, clipIndex, clip) {
        root.targetTrackIndex = trackIndex
        root.targetClipIndex = clipIndex
        root.clipData = clip || {}
        root.clipPath = clip ? (clip.path || "") : ""
        root.clipDuration = clip ? (clip.duration || 0.0) : 0.0
        root.clipInPoint = clip ? (clip.inPoint || 0.0) : 0.0
        root.clipName = clip ? (clip.name || qsTr("Clipe selecionado")) : qsTr("Clipe selecionado")
        root.clipThumb = clip ? (clip.thumbnailPath || "") : ""

        root.progressPercent = 0
        root.progressStatus = ""
        root.isRunning = false
        promptField.text = ""
        open()
        promptField.forceActiveFocus()
    }

    Connections {
        target: AiAgent

        function onOmniFlashClipEditProgress(percent, statusText) {
            root.progressPercent = percent
            root.progressStatus = statusText
            root.isRunning = true
        }

        function onOmniFlashClipEditFinished(success, outputPath, message) {
            root.isRunning = false
            if (success) {
                root.progressPercent = 100
                root.progressStatus = qsTr("Clipe atualizado com sucesso na timeline!")
            } else {
                root.progressStatus = qsTr("Erro: ") + message
            }
        }
    }

    contentItem: Column {
        id: body
        width: parent ? parent.width : 620
        spacing: Theme.spacingMd

        // 1. Card do Clipe Selecionado & Status de Duração Flow (Padrão Google Stitch)
        Rectangle {
            width: parent.width
            height: clipCardRow.implicitHeight + Theme.spacingMd * 2
            radius: Theme.radiusMd
            color: Theme.panelBackground
            border.width: Theme.borderWidth
            border.color: Theme.panelBorder

            RowLayout {
                id: clipCardRow
                anchors.fill: parent
                anchors.margins: Theme.spacingMd
                spacing: Theme.spacingMd

                // Thumbnail ou placeholder
                Rectangle {
                    Layout.preferredWidth: 84
                    Layout.preferredHeight: 56
                    radius: Theme.radiusSm
                    color: Theme.surface
                    border.width: 1
                    border.color: Theme.panelBorder
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: root.clipThumb.length > 0 ? (root.clipThumb.indexOf("://") !== -1 ? root.clipThumb : "file:///" + root.clipThumb) : ""
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready
                    }

                    ThemedLabel {
                        anchors.centerIn: parent
                        text: "🎬"
                        font.pixelSize: 24
                        visible: root.clipThumb.length === 0
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        spacing: Theme.spacingSm
                        ThemedLabel {
                            text: root.clipName
                            font.weight: Font.DemiBold
                            size: "md"
                            color: Theme.foreground
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        // Badge de duração
                        Rectangle {
                            height: 22
                            radius: 11
                            color: root.clipDuration <= 8.5 ? Qt.rgba(0.08, 0.65, 0.4, 0.2) : Qt.rgba(0.9, 0.55, 0.1, 0.2)
                            border.width: 1
                            border.color: root.clipDuration <= 8.5 ? Qt.rgba(0.08, 0.75, 0.45, 0.5) : Qt.rgba(0.95, 0.65, 0.15, 0.5)
                            Layout.preferredWidth: durLabel.implicitWidth + 14

                            ThemedLabel {
                                id: durLabel
                                anchors.centerIn: parent
                                text: root.clipDuration.toFixed(1) + "s"
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: root.clipDuration <= 8.5 ? "#26e690" : "#ffb84d"
                            }
                        }
                    }

                    ThemedLabel {
                        text: qsTr("Faixa %1 • Início: %2s • InPoint: %3s")
                              .arg(root.targetTrackIndex + 1)
                              .arg(root.clipData.start ? root.clipData.start.toFixed(1) : "0.0")
                              .arg(root.clipInPoint.toFixed(1))
                        size: "xs"
                        color: Theme.mutedForeground
                    }

                    // Aviso explicativo de duração do Google Flow
                    ThemedLabel {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        size: "xs"
                        color: root.clipDuration <= 8.5 ? Theme.mutedForeground : "#ffb84d"
                        text: root.clipDuration <= 8.5
                              ? qsTr("⚡ Duração ideal para o Google Flow Veo (4s a 8s recomendados).")
                              : qsTr("ℹ️ Clipe longo (>8s): Será fatiado nos primeiros 8 a 10s (tamanho máximo recomendado pelo Google Flow).")
                    }
                }
            }
        }

        // 2. Campo de Prompt de Transformação Visual
        Column {
            width: parent.width
            spacing: Theme.spacingXs

            RowLayout {
                width: parent.width
                ThemedLabel {
                    text: qsTr("Prompt de Edição Visual:")
                    font.weight: Font.Medium
                    size: "sm"
                    color: Theme.foreground
                }
                Item { Layout.fillWidth: true }
                ThemedLabel {
                    text: qsTr("O Flow alterará somente os elementos visuais da cena")
                    font.pixelSize: 11
                    color: Theme.mutedForeground
                }
            }

            Rectangle {
                width: parent.width
                height: 86
                radius: Theme.radiusSm
                color: Theme.inputBackground
                border.width: promptField.activeFocus ? 2 : Theme.borderWidth
                border.color: promptField.activeFocus ? Theme.primary : Theme.panelBorder

                Flickable {
                    id: flickablePrompt
                    anchors.fill: parent
                    anchors.margins: Theme.spacingSm
                    contentWidth: width
                    contentHeight: promptField.implicitHeight
                    clip: true

                    TextArea {
                        id: promptField
                        width: parent.width
                        wrapMode: Text.WordWrap
                        color: Theme.foreground
                        font.pixelSize: 13
                        font.family: Theme.fontFamily
                        placeholderText: qsTr("Ex: adicione um dia chuvoso com poças d'água refletindo a luz, troque a roupa do personagem por jaqueta de couro...")
                        placeholderTextColor: Theme.mutedForeground
                        background: null
                        selectByMouse: true
                    }
                }
            }
        }

        // 3. Chips de Presets Rápidos de Prompt
        Column {
            width: parent.width
            spacing: 6

            ThemedLabel {
                text: qsTr("Sugestões Rápidas:")
                size: "xs"
                color: Theme.mutedForeground
            }

            Flow {
                width: parent.width
                spacing: Theme.spacingXs

                Repeater {
                    model: [
                        { label: qsTr("🌧️ Dia Chuvoso"), text: "adicione chuva intensa, asfalto molhado com poças d'água e reflexos realistas" },
                        { label: qsTr("👕 Trocar Roupas"), text: "troque a roupa do personagem por jaqueta futurista de alta costura" },
                        { label: qsTr("🌅 Pôr do Sol"), text: "iluminação mágica de pôr do sol, golden hour com tons dourados e quentes" },
                        { label: qsTr("⚡ Neon Cyberpunk"), text: "estilo cyberpunk, iluminação neon azul e magenta, atmosfera futurista" },
                        { label: qsTr("❄️ Neve & Inverno"), text: "cenário coberto de neve caindo suavemente, clima gelado e atmosfera invernal" },
                        { label: qsTr("🎨 Anime 3D"), text: "render cinematográfico estilizado estilo anime 3D Makoto Shinkai" }
                    ]

                    Rectangle {
                        height: 26
                        radius: 13
                        color: presetMouse.containsMouse ? Theme.surfaceHover : Theme.surface
                        border.width: 1
                        border.color: Theme.panelBorder
                        width: presetRow.implicitWidth + 16

                        RowLayout {
                            id: presetRow
                            anchors.centerIn: parent
                            spacing: 4
                            ThemedLabel {
                                text: modelData.label
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: Theme.foreground
                            }
                        }

                        MouseArea {
                            id: presetMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (promptField.text.trim().length > 0) {
                                    promptField.text = promptField.text.trim() + ", " + modelData.text
                                } else {
                                    promptField.text = modelData.text
                                }
                            }
                        }
                    }
                }
            }
        }

        // 4. Trava de Segurança: Preservação de Áudio / Voz (Regra Crítica Solicitada)
        Rectangle {
            width: parent.width
            height: audioLockRow.implicitHeight + Theme.spacingMd * 2
            radius: Theme.radiusMd
            color: root.preserveAudio ? Qt.rgba(0.08, 0.45, 0.3, 0.15) : Theme.panelBackground
            border.width: 1
            border.color: root.preserveAudio ? Qt.rgba(0.1, 0.7, 0.4, 0.4) : Theme.panelBorder

            RowLayout {
                id: audioLockRow
                anchors.fill: parent
                anchors.margins: Theme.spacingMd
                spacing: Theme.spacingMd

                ThemedLabel {
                    text: "🔒"
                    font.pixelSize: 22
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    ThemedLabel {
                        text: qsTr("Preservar 100% da voz e áudio original do personagem")
                        font.weight: Font.DemiBold
                        size: "sm"
                        color: root.preserveAudio ? "#26e690" : Theme.foreground
                    }

                    ThemedLabel {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        size: "xs"
                        color: Theme.mutedForeground
                        text: qsTr("O Google Flow processa apenas a camada visual. A voz e trilha sonora originais são extraídas e remuxadas pelo FFmpeg sem qualquer distorção.")
                    }
                }

                ThemedSwitch {
                    checked: root.preserveAudio
                    onToggled: root.preserveAudio = checked
                }
            }
        }

        // 5. Destino na Timeline (Substituir ou Nova Trilha)
        RowLayout {
            width: parent.width
            spacing: Theme.spacingMd

            ThemedLabel {
                text: qsTr("Destino na Timeline:")
                size: "xs"
                font.weight: Font.Medium
                color: Theme.mutedForeground
            }

            Rectangle {
                height: 28
                radius: 14
                color: root.replaceInPlace ? Theme.primarySurface : Theme.surface
                border.width: 1
                border.color: root.replaceInPlace ? Theme.primary : Theme.panelBorder
                Layout.preferredWidth: repLabel.implicitWidth + 18

                ThemedLabel {
                    id: repLabel
                    anchors.centerIn: parent
                    text: qsTr("🔄 Substituir no mesmo local")
                    font.pixelSize: 11
                    font.weight: root.replaceInPlace ? Font.DemiBold : Font.Normal
                    color: root.replaceInPlace ? Theme.primary : Theme.foreground
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.replaceInPlace = true
                }
            }

            Rectangle {
                height: 28
                radius: 14
                color: !root.replaceInPlace ? Theme.primarySurface : Theme.surface
                border.width: 1
                border.color: !root.replaceInPlace ? Theme.primary : Theme.panelBorder
                Layout.preferredWidth: addLabel.implicitWidth + 18

                ThemedLabel {
                    id: addLabel
                    anchors.centerIn: parent
                    text: qsTr("➕ Adicionar em nova trilha acima")
                    font.pixelSize: 11
                    font.weight: !root.replaceInPlace ? Font.DemiBold : Font.Normal
                    color: !root.replaceInPlace ? Theme.primary : Theme.foreground
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.replaceInPlace = false
                }
            }

            Item { Layout.fillWidth: true }
        }

        // 6. Barra de Progresso (quando em execução)
        Column {
            width: parent.width
            spacing: 4
            visible: root.isRunning || root.progressPercent > 0

            RowLayout {
                width: parent.width
                ThemedLabel {
                    text: root.progressStatus.length > 0 ? root.progressStatus : qsTr("Processando com Google Flow...")
                    size: "xs"
                    color: Theme.foreground
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                ThemedLabel {
                    text: root.progressPercent + "%"
                    size: "xs"
                    font.weight: Font.DemiBold
                    color: Theme.primary
                }
            }

            ThemedProgressBar {
                width: parent.width
                value: root.progressPercent / 100.0
            }
        }

        // 7. Ações do Rodapé
        RowLayout {
            width: parent.width
            spacing: Theme.spacingSm

            Item { Layout.fillWidth: true }

            ThemedButton {
                text: isRunning ? qsTr("Fechar Janela") : qsTr("Cancelar")
                variant: "secondary"
                onClicked: root.reject()
            }

            ThemedButton {
                text: isRunning ? qsTr("Transformando...") : qsTr("✨ Transformar com OmniFlash")
                variant: "primary"
                enabled: promptField.text.trim().length > 0 && !root.isRunning
                icon.name: Theme.icons.sparkles

                onClicked: {
                    root.isRunning = true
                    root.progressPercent = 5
                    root.progressStatus = qsTr("Conectando ao Google Flow...")
                    AiAgent.editClipWithOmniFlash(
                        root.targetTrackIndex,
                        root.targetClipIndex,
                        root.clipPath,
                        root.clipInPoint,
                        root.clipDuration,
                        promptField.text.trim(),
                        root.preserveAudio,
                        root.replaceInPlace
                    )
                }
            }
        }
    }
}
