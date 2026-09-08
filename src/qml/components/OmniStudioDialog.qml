import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Drift
import ".."

ThemedDialog {
    id: root

    title: qsTr("OmniStudio — Clonagem de Voz & Vídeos OmniFlash")
    preferredWidth: Theme.dialogWidthMd
    showAccept: false
    rejectText: qsTr("Fechar")

    property int activeTab: 0

    function openDialog() {
        open()
    }

    contentItem: Column {
        id: body
        width: parent ? parent.width : Theme.dialogWidthMd
        spacing: Theme.spacingLg

        // Abas do Studio
        RowLayout {
            width: parent.width
            spacing: Theme.spacingSm

            ThemedButton {
                text: qsTr("🎙️ Clonagem de Voz (OmniVoice)")
                variant: root.activeTab === 0 ? "primary" : "secondary"
                Layout.fillWidth: true
                onClicked: root.activeTab = 0
            }

            ThemedButton {
                text: qsTr("🎥 Vídeo IA (OmniFlash)")
                variant: root.activeTab === 1 ? "primary" : "secondary"
                Layout.fillWidth: true
                onClicked: root.activeTab = 1
            }
        }

        // --- Aba 0: Voz ---
        Column {
            width: parent.width
            spacing: Theme.spacingMd
            visible: root.activeTab === 0

            RowLayout {
                width: parent.width
                ThemedLabel {
                    text: qsTr("Motor de Síntese:")
                    size: "sm"
                    font.weight: Font.Medium
                }
                ThemedButton {
                    text: qsTr("OmniVoice (CUDA RTX 2060)")
                    variant: voiceEngineGroup.checkedEngine === "omnivoice" ? "primary" : "secondary"
                    onClicked: voiceEngineGroup.checkedEngine = "omnivoice"
                }
                ThemedButton {
                    text: qsTr("Edge-TTS (Neural)")
                    variant: voiceEngineGroup.checkedEngine === "edge_tts" ? "primary" : "secondary"
                    onClicked: voiceEngineGroup.checkedEngine = "edge_tts"
                }
                Item { id: voiceEngineGroup; property string checkedEngine: "omnivoice" }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingXs

                ThemedLabel {
                    text: qsTr("Perfil de Voz Clonada:")
                    size: "xs"
                    color: Theme.mutedForeground
                }
                ThemedLabel {
                    text: qsTr("dluz_voice.pt (Voz Oficial DLuz - RTX 2060 Acelerada)")
                    size: "sm"
                    color: Theme.foreground
                    font.weight: Font.Medium
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingXs

                RowLayout {
                    width: parent.width
                    ThemedLabel {
                        text: qsTr("Texto da Narração:")
                        size: "sm"
                        font.weight: Font.Medium
                        Layout.fillWidth: true
                    }
                    ThemedButton {
                        text: qsTr("Bordão Oficial")
                        variant: "ghost"
                        onClicked: voiceTextArea.text = "Fala melhores, beleza? Hoje eu vou mostrar uma novidade incrível para vocês..."
                    }
                }

                ScrollView {
                    width: parent.width
                    height: 100

                    TextArea {
                        id: voiceTextArea
                        placeholderText: qsTr("Digite ou cole o roteiro da locução...")
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

            ThemedButton {
                width: parent.width
                text: qsTr("🎙️ Sintetizar Voz & Inserir na Timeline")
                variant: "primary"
                enabled: !AiAgent.isBusy && voiceTextArea.text.trim().length > 0
                onClicked: {
                    AiAgent.synthesizeVoice(voiceTextArea.text.trim(), voiceEngineGroup.checkedEngine)
                    Toasts.info(qsTr("Sintetizando locução em segundo plano..."))
                    root.close()
                }
            }
        }

        // --- Aba 1: OmniFlash ---
        Column {
            width: parent.width
            spacing: Theme.spacingMd
            visible: root.activeTab === 1

            ThemedLabel {
                width: parent.width
                size: "sm"
                wrapMode: Text.WordWrap
                text: qsTr("Gere vídeos em alta definição com o OmniFlash / Google Flow direto no seu projeto da DLuz Games.")
            }

            Column {
                width: parent.width
                spacing: Theme.spacingXs

                ThemedLabel {
                    text: qsTr("Proporção do Vídeo:")
                    size: "sm"
                    font.weight: Font.Medium
                }

                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingSm

                    ThemedButton {
                        text: qsTr("16:9 (Horizontal / YouTube)")
                        variant: flashAspectGroup.aspect === "16:9" ? "primary" : "secondary"
                        Layout.fillWidth: true
                        onClicked: flashAspectGroup.aspect = "16:9"
                    }

                    ThemedButton {
                        text: qsTr("9:16 (Vertical / TikTok / Shorts)")
                        variant: flashAspectGroup.aspect === "9:16" ? "primary" : "secondary"
                        Layout.fillWidth: true
                        onClicked: flashAspectGroup.aspect = "9:16"
                    }
                    Item { id: flashAspectGroup; property string aspect: "16:9" }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingXs

                ThemedLabel {
                    text: qsTr("Prompt da Cena:")
                    size: "sm"
                    font.weight: Font.Medium
                }

                ScrollView {
                    width: parent.width
                    height: 90

                    TextArea {
                        id: omniPromptArea
                        placeholderText: qsTr("Descreva a cena desejada (em inglês ou português)...")
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

            ThemedButton {
                width: parent.width
                text: qsTr("🎥 Gerar Cena OmniFlash & Inserir na Timeline")
                variant: "primary"
                enabled: !AiAgent.isBusy && omniPromptArea.text.trim().length > 0
                onClicked: {
                    AiAgent.generateOmniFlash(omniPromptArea.text.trim(), flashAspectGroup.aspect)
                    Toasts.info(qsTr("Iniciando geração de vídeo com OmniFlash..."))
                    root.close()
                }
            }
        }
    }
}
