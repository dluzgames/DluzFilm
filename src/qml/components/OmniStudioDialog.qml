import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Drift
import ".."

ThemedDialog {
    id: root

    title: qsTr("Dublagem & Voz IA — OmniVoice & Whisper")
    preferredWidth: Theme.dialogWidthMd + 40
    showAccept: false
    rejectText: qsTr("Fechar")

    property int activeTab: 0

    function openDialog() {
        // Se houver clipe de vídeo selecionado na timeline, auto-preenche o campo
        const selected = AiAgent.selectedVideoClipPath()
        if (selected && selected.length > 0) {
            videoPathField.text = selected
        }
        open()
    }

    contentItem: Column {
        id: body
        width: parent ? parent.width : Theme.dialogWidthMd + 40
        spacing: Theme.spacingMd

        // Barra de Abas do Studio estilo Google Stitch
        RowLayout {
            width: parent.width
            spacing: Theme.spacingSm

            ThemedButton {
                text: qsTr("🎬 Dublar Vídeo & Legendas (IA)")
                variant: root.activeTab === 0 ? "primary" : "secondary"
                Layout.fillWidth: true
                onClicked: root.activeTab = 0
            }

            ThemedButton {
                text: qsTr("🎙️ Clonagem de Voz (Locução)")
                variant: root.activeTab === 1 ? "primary" : "secondary"
                Layout.fillWidth: true
                onClicked: root.activeTab = 1
            }
        }

        // =================================================================
        // ABA 0: DUBLAR VÍDEO & GERAR LEGENDAS
        // =================================================================
        Column {
            width: parent.width
            spacing: Theme.spacingMd
            visible: root.activeTab === 0

            // Header explicativo
            Rectangle {
                width: parent.width
                height: dubHeaderCol.implicitHeight + Theme.spacingSm * 2
                radius: Theme.radiusSm
                color: Theme.panelBackground
                border.width: Theme.borderWidth
                border.color: Theme.panelBorder

                Column {
                    id: dubHeaderCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingSm
                    spacing: 2

                    ThemedLabel {
                        text: qsTr("Transcreva, traduza e duble qualquer vídeo automaticamente com sincronia labial e legendas.")
                        size: "xs"
                        color: Theme.mutedForeground
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }
                }
            }

            // Card 1: Seleção do Vídeo
            Column {
                width: parent.width
                spacing: Theme.spacingXs

                ThemedLabel {
                    text: qsTr("Vídeo a ser Dublado:")
                    size: "sm"
                    font.weight: Font.Medium
                }

                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingSm

                    TextField {
                        id: videoPathField
                        Layout.fillWidth: true
                        placeholderText: qsTr("Caminho do arquivo de vídeo (.mp4, .mov, .mkv)...")
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                        background: Rectangle {
                            color: Theme.inputBackground
                            radius: Theme.radiusSm
                            border.width: Theme.borderWidth
                            border.color: Theme.panelBorder
                        }
                    }

                    ThemedButton {
                        text: qsTr("Usar da Timeline")
                        variant: "ghost"
                        tooltip: qsTr("Preencher com o clipe de vídeo atualmente selecionado na timeline")
                        onClicked: {
                            const selected = AiAgent.selectedVideoClipPath()
                            if (selected && selected.length > 0) {
                                videoPathField.text = selected
                            } else {
                                Toasts.info(qsTr("Nenhum clipe de vídeo selecionado na timeline."))
                            }
                        }
                    }

                    ThemedButton {
                        text: qsTr("Procurar...")
                        variant: "secondary"
                        onClicked: {
                            const url = FileDialogs.openFile(
                                qsTr("Selecionar Vídeo para Dublagem"),
                                [qsTr("Arquivos de Vídeo (*.mp4 *.mov *.mkv *.avi *.webm)"), qsTr("Todos os arquivos (*)")])
                            if (url && url.toString() !== "") {
                                let localPath = url.toLocalFile ? url.toLocalFile() : url.toString()
                                if (localPath.indexOf("file:///") === 0) localPath = localPath.substring(8)
                                else if (localPath.indexOf("file://") === 0) localPath = localPath.substring(7)
                                videoPathField.text = localPath
                            }
                        }
                    }
                }
            }

            // Card 2: Idioma de Destino (Outras Línguas)
            Column {
                width: parent.width
                spacing: Theme.spacingXs

                ThemedLabel {
                    text: qsTr("Idioma de Destino (Dublar para):")
                    size: "sm"
                    font.weight: Font.Medium
                }

                GridLayout {
                    width: parent.width
                    columns: 4
                    rowSpacing: Theme.spacingXs
                    columnSpacing: Theme.spacingXs

                    ThemedButton {
                        text: "🇺🇸 " + qsTr("Inglês")
                        variant: dubLangGroup.targetLang === "en" ? "primary" : "secondary"
                        Layout.fillWidth: true
                        onClicked: dubLangGroup.targetLang = "en"
                    }
                    ThemedButton {
                        text: "🇪🇸 " + qsTr("Espanhol")
                        variant: dubLangGroup.targetLang === "es" ? "primary" : "secondary"
                        Layout.fillWidth: true
                        onClicked: dubLangGroup.targetLang = "es"
                    }
                    ThemedButton {
                        text: "🇨🇳 " + qsTr("Chinês")
                        variant: dubLangGroup.targetLang === "zh" ? "primary" : "secondary"
                        Layout.fillWidth: true
                        onClicked: dubLangGroup.targetLang = "zh"
                    }
                    ThemedButton {
                        text: "🇧🇷 " + qsTr("Português")
                        variant: dubLangGroup.targetLang === "pt-BR" ? "primary" : "secondary"
                        Layout.fillWidth: true
                        onClicked: dubLangGroup.targetLang = "pt-BR"
                    }
                    ThemedButton {
                        text: "🇫🇷 " + qsTr("Francês")
                        variant: dubLangGroup.targetLang === "fr" ? "primary" : "secondary"
                        Layout.fillWidth: true
                        onClicked: dubLangGroup.targetLang = "fr"
                    }
                    ThemedButton {
                        text: "🇩🇪 " + qsTr("Alemão")
                        variant: dubLangGroup.targetLang === "de" ? "primary" : "secondary"
                        Layout.fillWidth: true
                        onClicked: dubLangGroup.targetLang = "de"
                    }
                    ThemedButton {
                        text: "🇯🇵 " + qsTr("Japonês")
                        variant: dubLangGroup.targetLang === "ja" ? "primary" : "secondary"
                        Layout.fillWidth: true
                        onClicked: dubLangGroup.targetLang = "ja"
                    }
                    ThemedButton {
                        text: "🇮🇹 " + qsTr("Italiano")
                        variant: dubLangGroup.targetLang === "it" ? "primary" : "secondary"
                        Layout.fillWidth: true
                        onClicked: dubLangGroup.targetLang = "it"
                    }
                }
                Item { id: dubLangGroup; property string targetLang: "en" }
            }

            // Card 3: Motor de Dublagem
            Column {
                width: parent.width
                spacing: Theme.spacingXs

                ThemedLabel {
                    text: qsTr("Motor de Voz da Dublagem:")
                    size: "sm"
                    font.weight: Font.Medium
                }

                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingSm

                    ThemedButton {
                        text: qsTr("🤖 OmniVoice (Voz do DLuz - CUDA RTX 2060)")
                        variant: dubEngineGroup.engine === "omnivoice" ? "primary" : "secondary"
                        Layout.fillWidth: true
                        onClicked: dubEngineGroup.engine = "omnivoice"
                    }

                    ThemedButton {
                        text: qsTr("🗣️ Edge-TTS (Vozes Neurais)")
                        variant: dubEngineGroup.engine === "edge_tts" ? "primary" : "secondary"
                        Layout.fillWidth: true
                        onClicked: dubEngineGroup.engine = "edge_tts"
                    }
                    Item { id: dubEngineGroup; property string engine: "omnivoice" }
                }
            }

            // Card 4: Opções de Legenda e Ducking
            Column {
                width: parent.width
                spacing: Theme.spacingXs

                ThemedLabel {
                    text: qsTr("Opções de Entrega:")
                    size: "sm"
                    font.weight: Font.Medium
                }

                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingMd

                    CheckBox {
                        id: autoSubsCheck
                        text: qsTr("Gerar Legendas (.srt) e Inserir na Timeline")
                        checked: true
                    }

                    CheckBox {
                        id: hardsubCheck
                        text: qsTr("Gravar Legenda no Vídeo (Hardsub)")
                        checked: false
                    }
                }

                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingSm

                    ThemedLabel {
                        text: qsTr("Volume do Áudio Original de Fundo:")
                        size: "xs"
                        color: Theme.mutedForeground
                    }

                    ThemedButton {
                        text: qsTr("Mudo (0%)")
                        variant: bgmGroup.vol === 0.0 ? "primary" : "secondary"
                        onClicked: bgmGroup.vol = 0.0
                    }
                    ThemedButton {
                        text: qsTr("Sutil (15%)")
                        variant: bgmGroup.vol === 0.15 ? "primary" : "secondary"
                        onClicked: bgmGroup.vol = 0.15
                    }
                    ThemedButton {
                        text: qsTr("Presente (30%)")
                        variant: bgmGroup.vol === 0.30 ? "primary" : "secondary"
                        onClicked: bgmGroup.vol = 0.30
                    }
                    Item { id: bgmGroup; property real vol: 0.15 }
                }
            }

            // Botão CTA Dublar
            ThemedButton {
                width: parent.width
                height: 44
                text: AiAgent.isBusy ? qsTr("⏳ Dublando Vídeo em Segundo Plano...") : qsTr("🚀 Dublar Vídeo, Gerar Legendas & Inserir na Timeline")
                variant: "primary"
                enabled: !AiAgent.isBusy && videoPathField.text.trim().length > 0
                onClicked: {
                    AiAgent.dubVideo(
                        videoPathField.text.trim(),
                        dubLangGroup.targetLang,
                        dubEngineGroup.engine,
                        autoSubsCheck.checked,
                        hardsubCheck.checked,
                        bgmGroup.vol
                    )
                    Toasts.info(qsTr("Iniciando processo de dublagem e legendagem por IA..."))
                    root.close()
                }
            }
        }

        // =================================================================
        // ABA 1: CLONAGEM DE VOZ (LOCUÇÃO DE TEXTO)
        // =================================================================
        Column {
            width: parent.width
            spacing: Theme.spacingMd
            visible: root.activeTab === 1

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

            // Idioma da Voz
            Column {
                width: parent.width
                spacing: Theme.spacingXs

                ThemedLabel {
                    text: qsTr("Idioma da Narração:")
                    size: "sm"
                    font.weight: Font.Medium
                }

                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingSm

                    ThemedButton {
                        text: "🇧🇷 Português"
                        variant: voiceLangGroup.lang === "pt" ? "primary" : "secondary"
                        Layout.fillWidth: true
                        onClicked: voiceLangGroup.lang = "pt"
                    }
                    ThemedButton {
                        text: "🇺🇸 Inglês"
                        variant: voiceLangGroup.lang === "en" ? "primary" : "secondary"
                        Layout.fillWidth: true
                        onClicked: voiceLangGroup.lang = "en"
                    }
                    ThemedButton {
                        text: "🇪🇸 Espanhol"
                        variant: voiceLangGroup.lang === "es" ? "primary" : "secondary"
                        Layout.fillWidth: true
                        onClicked: voiceLangGroup.lang = "es"
                    }
                    ThemedButton {
                        text: "🇨🇳 Chinês"
                        variant: voiceLangGroup.lang === "zh" ? "primary" : "secondary"
                        Layout.fillWidth: true
                        onClicked: voiceLangGroup.lang = "zh"
                    }
                    Item { id: voiceLangGroup; property string lang: "pt" }
                }
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
                        onClicked: voiceTextArea.text = "Fala melhores, beleza? Sejam muito bem-vindos ao canal DLuz Games! Hoje vou mostrar uma novidade incrível para vocês..."
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
                height: 44
                text: qsTr("🎙️ Sintetizar Voz & Inserir na Timeline")
                variant: "primary"
                enabled: !AiAgent.isBusy && voiceTextArea.text.trim().length > 0
                onClicked: {
                    AiAgent.synthesizeVoice(voiceTextArea.text.trim(), voiceEngineGroup.checkedEngine, voiceLangGroup.lang)
                    Toasts.info(qsTr("Sintetizando locução em segundo plano..."))
                    root.close()
                }
            }
        }
    }
}
