import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Drift
import ".."

ThemedDialog {
    id: root

    title: qsTr("OmniFlash — Gerador de Vídeos IA (Google Flow)")
    preferredWidth: Theme.dialogWidthMd
    showAccept: false
    rejectText: qsTr("Fechar")

    property string selectedAspect: "16:9"

    function openDialog() {
        open()
    }

    contentItem: Column {
        id: body
        width: parent ? parent.width : Theme.dialogWidthMd
        spacing: Theme.spacingMd

        // Header Card estilo Google Stitch
        Rectangle {
            width: parent.width
            height: headerCol.implicitHeight + Theme.spacingMd * 2
            radius: Theme.radiusMd
            color: Theme.panelBackground
            border.width: Theme.borderWidth
            border.color: Theme.panelBorder

            Column {
                id: headerCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spacingMd
                spacing: Theme.spacingXs

                RowLayout {
                    spacing: Theme.spacingSm
                    ThemedLabel {
                        text: "🎥"
                        font.pixelSize: 20
                    }
                    ThemedLabel {
                        text: qsTr("Geração Cinematográfica com Veo & Google Flow")
                        font.weight: Font.DemiBold
                        size: "md"
                        color: Theme.foreground
                    }
                }

                ThemedLabel {
                    width: parent.width
                    size: "xs"
                    color: Theme.mutedForeground
                    wrapMode: Text.WordWrap
                    text: qsTr("Crie cenas completas por inteligência artificial em alta definição. O vídeo renderizado é salvo automaticamente em D:\\antigravity\\videos gerados e importado na sua timeline.")
                }
            }
        }

        // Seletor de Aspect Ratio com cards visuais
        Column {
            width: parent.width
            spacing: Theme.spacingXs

            ThemedLabel {
                text: qsTr("Proporção e Formato:")
                size: "sm"
                font.weight: Font.Medium
            }

            RowLayout {
                width: parent.width
                spacing: Theme.spacingSm

                // Card 16:9
                Rectangle {
                    Layout.fillWidth: true
                    height: 52
                    radius: Theme.radiusSm
                    color: root.selectedAspect === "16:9" ? Theme.primarySurface : Theme.inputBackground
                    border.width: root.selectedAspect === "16:9" ? 2 : 1
                    border.color: root.selectedAspect === "16:9" ? Theme.primary : Theme.panelBorder

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectedAspect = "16:9"
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: Theme.spacingSm
                        ThemedLabel {
                            text: "🖥️"
                            font.pixelSize: 18
                        }
                        Column {
                            spacing: 1
                            ThemedLabel {
                                text: qsTr("16:9 Horizontal")
                                font.weight: root.selectedAspect === "16:9" ? Font.DemiBold : Font.Normal
                                size: "sm"
                                color: root.selectedAspect === "16:9" ? Theme.primary : Theme.foreground
                            }
                            ThemedLabel {
                                text: qsTr("YouTube & Telas Grandes")
                                size: "xs"
                                color: Theme.mutedForeground
                            }
                        }
                    }
                }

                // Card 9:16
                Rectangle {
                    Layout.fillWidth: true
                    height: 52
                    radius: Theme.radiusSm
                    color: root.selectedAspect === "9:16" ? Theme.primarySurface : Theme.inputBackground
                    border.width: root.selectedAspect === "9:16" ? 2 : 1
                    border.color: root.selectedAspect === "9:16" ? Theme.primary : Theme.panelBorder

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectedAspect = "9:16"
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: Theme.spacingSm
                        ThemedLabel {
                            text: "📱"
                            font.pixelSize: 18
                        }
                        Column {
                            spacing: 1
                            ThemedLabel {
                                text: qsTr("9:16 Vertical")
                                font.weight: root.selectedAspect === "9:16" ? Font.DemiBold : Font.Normal
                                size: "sm"
                                color: root.selectedAspect === "9:16" ? Theme.primary : Theme.foreground
                            }
                            ThemedLabel {
                                text: qsTr("TikTok, Shorts & Reels")
                                size: "xs"
                                color: Theme.mutedForeground
                            }
                        }
                    }
                }
            }
        }

        // Sugestões Rápidas de Prompt
        Column {
            width: parent.width
            spacing: Theme.spacingXs

            RowLayout {
                width: parent.width
                ThemedLabel {
                    text: qsTr("Prompt da Cena:")
                    size: "sm"
                    font.weight: Font.Medium
                    Layout.fillWidth: true
                }

                ThemedLabel {
                    text: qsTr("Sugestões:")
                    size: "xs"
                    color: Theme.mutedForeground
                }

                ThemedButton {
                    text: qsTr("Cyberpunk Neon")
                    variant: "ghost"
                    onClicked: promptArea.text = "Cinematic slow motion drone shot of a futuristic cyberpunk gamer city with neon lights and holographic displays, 4k ultra realistic"
                }

                ThemedButton {
                    text: qsTr("Mascote Chibi")
                    variant: "ghost"
                    onClicked: promptArea.text = "Cute 2.5D chibi mascot with golden headphones and red hoodie dancing happily on an editing desk, ray tracing, studio lighting"
                }
            }

            ScrollView {
                width: parent.width
                height: 100

                TextArea {
                    id: promptArea
                    placeholderText: qsTr("Descreva a cena desejada em detalhes (ex: Cinematic drone shot of a neon gaming setup, 4k...)...")
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                    wrapMode: TextEdit.Wrap
                    background: Rectangle {
                        color: Theme.inputBackground
                        radius: Theme.radiusSm
                        border.width: Theme.borderWidth
                        border.color: Theme.panelBorder
                    }
                }
            }
        }

        // Botão de Ação CTA
        ThemedButton {
            width: parent.width
            height: 44
            text: AiAgent.isBusy ? qsTr("⏳ Gerando Vídeo com OmniFlash...") : qsTr("🎥 Gerar Vídeo OmniFlash & Inserir na Timeline")
            variant: "primary"
            enabled: !AiAgent.isBusy && promptArea.text.trim().length > 0
            onClicked: {
                AiAgent.generateOmniFlash(promptArea.text.trim(), root.selectedAspect)
                Toasts.info(qsTr("Iniciando renderização de vídeo OmniFlash em segundo plano..."))
                root.close()
            }
        }
    }
}
