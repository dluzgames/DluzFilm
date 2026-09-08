import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Drift
import ".."

ThemedDialog {
    id: root

    title: qsTr("HyperFrames Studio — Motion Graphics & Vinhetas")
    preferredWidth: Theme.dialogWidthMd
    showAccept: false
    rejectText: qsTr("Fechar")

    property string selectedTemplate: "lower_third"

    function openDialog() {
        open()
    }

    contentItem: Column {
        id: body
        width: parent ? parent.width : Theme.dialogWidthMd
        spacing: Theme.spacingLg

        ThemedLabel {
            width: parent.width
            size: "sm"
            wrapMode: Text.WordWrap
            text: qsTr("Crie lower-thirds, vinhetas, cards de redes sociais e animações gráficas profissionais com HyperFrames renderizados com Chroma Key (fundo verde removido automaticamente) direto para a sua timeline.")
        }

        RowLayout {
            width: parent.width
            spacing: Theme.spacingXs

            Rectangle {
                width: 8
                height: 8
                radius: 4
                color: "#22c55e"
            }

            ThemedLabel {
                text: qsTr("Chroma Key Automático Ativado (elimina tela branca / verde)")
                size: "xs"
                color: "#22c55e"
                font.weight: Font.DemiBold
            }
        }

        // Seletor de Modelo
        Column {
            width: parent.width
            spacing: Theme.spacingXs

            ThemedLabel {
                text: qsTr("Modelo de Animação")
                size: "sm"
                font.weight: Font.Medium
            }

            RowLayout {
                width: parent.width
                spacing: Theme.spacingSm

                ThemedButton {
                    text: qsTr("Lower Third")
                    variant: root.selectedTemplate === "lower_third" ? "primary" : "secondary"
                    Layout.fillWidth: true
                    onClicked: root.selectedTemplate = "lower_third"
                }

                ThemedButton {
                    text: qsTr("Título Kinetic")
                    variant: root.selectedTemplate === "title_card" ? "primary" : "secondary"
                    Layout.fillWidth: true
                    onClicked: root.selectedTemplate = "title_card"
                }

                ThemedButton {
                    text: qsTr("Card Social")
                    variant: root.selectedTemplate === "social_card" ? "primary" : "secondary"
                    Layout.fillWidth: true
                    onClicked: root.selectedTemplate = "social_card"
                }
            }
        }

        // Título
        Column {
            width: parent.width
            spacing: Theme.spacingXs

            ThemedLabel {
                text: qsTr("Título Principal")
                size: "sm"
                font.weight: Font.Medium
            }

            ThemedTextField {
                id: titleField
                width: parent.width
                text: "DLuz Games"
                placeholderText: qsTr("Ex: Seu Nome, Título do Vídeo, etc.")
            }
        }

        // Subtítulo
        Column {
            width: parent.width
            spacing: Theme.spacingXs

            ThemedLabel {
                text: qsTr("Subtítulo / Handle")
                size: "sm"
                font.weight: Font.Medium
            }

            ThemedTextField {
                id: subtitleField
                width: parent.width
                text: "@dluzgames"
                placeholderText: qsTr("Ex: @instagram, Edição Profissional, etc.")
            }
        }

        // Status de Renderização
        RowLayout {
            width: parent.width
            visible: AiAgent.isBusy
            spacing: Theme.spacingMd

            IconGlyph {
                glyph: Theme.icons.spinner
                spinning: true
                iconSize: Theme.iconSizeMd
                iconColor: Theme.primary
            }

            ThemedLabel {
                text: AiAgent.statusMessage
                size: "sm"
                color: Theme.primary
                font.weight: Font.Medium
                Layout.fillWidth: true
            }
        }

        ThemedButton {
            width: parent.width
            text: qsTr("🎬 Renderizar & Inserir na Timeline")
            variant: "primary"
            enabled: !AiAgent.isBusy
            onClicked: {
                AiAgent.createHyperframes(titleField.text.trim(), subtitleField.text.trim(), root.selectedTemplate)
                Toasts.info(qsTr("Iniciando renderização HyperFrames em segundo plano..."))
                root.close()
            }
        }
    }
}
