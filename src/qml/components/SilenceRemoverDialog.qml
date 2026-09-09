import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Drift
import ".."

ThemedDialog {
    id: root

    title: qsTr("Removedor de Silêncios (Auto Jump Cut)")
    preferredWidth: Theme.dialogWidthMd
    showAccept: false
    rejectText: qsTr("Fechar")

    property double thresholdDb: -30.0
    property double minDurationSec: 0.3
    property double paddingSec: 0.08
    property int detectedCount: -1
    property double detectedTime: 0.0
    property bool analyzing: false

    function openDialog() {
        detectedCount = -1
        detectedTime = 0.0
        open()
    }

    function openForClip(trackIndex, clipIndex) {
        if (trackIndex >= 0 && clipIndex >= 0) {
            EditorState.selectClip(trackIndex, clipIndex)
        }
        openDialog()
    }

    contentItem: Column {
        id: body
        width: parent ? parent.width : Theme.dialogWidthMd
        spacing: Theme.spacingLg

        ThemedLabel {
            width: parent.width
            size: "sm"
            wrapMode: Text.WordWrap
            text: qsTr("Detecta pausas e momentos de silêncio na gravação e remove-os automaticamente em lote, aplicando ripple cut para manter o vídeo dinâmico e sem lacunas.")
        }

        // Limiar de Volume (Sensibilidade dB)
        Column {
            width: parent.width
            spacing: Theme.spacingXs

            RowLayout {
                width: parent.width
                ThemedLabel {
                    text: qsTr("Sensibilidade do Silêncio (Limiar)")
                    size: "sm"
                    font.weight: Font.Medium
                    Layout.fillWidth: true
                }
                ThemedLabel {
                    text: Math.round(thresholdSlider.value) + " dB"
                    size: "sm"
                    color: Theme.primary
                    font.weight: Font.Bold
                }
            }

            Slider {
                id: thresholdSlider
                width: parent.width
                from: -50.0
                to: -15.0
                value: -30.0
                stepSize: 1.0
                onValueChanged: root.thresholdDb = value
            }

            ThemedLabel {
                text: qsTr("Áudios abaixo deste volume serão considerados silêncio (padrão: -30 dB).")
                size: "xs"
                color: Theme.mutedForeground
            }
        }

        // Duração Mínima do Silêncio
        Column {
            width: parent.width
            spacing: Theme.spacingXs

            RowLayout {
                width: parent.width
                ThemedLabel {
                    text: qsTr("Duração Mínima de Pausa")
                    size: "sm"
                    font.weight: Font.Medium
                    Layout.fillWidth: true
                }
                ThemedLabel {
                    text: minDurationSlider.value.toFixed(2) + " s"
                    size: "sm"
                    color: Theme.primary
                    font.weight: Font.Bold
                }
            }

            Slider {
                id: minDurationSlider
                width: parent.width
                from: 0.1
                to: 1.5
                value: 0.3
                stepSize: 0.05
                onValueChanged: root.minDurationSec = value
            }

            ThemedLabel {
                text: qsTr("Pausas mais curtas que este valor serão mantidas (padrão: 0.30s).")
                size: "xs"
                color: Theme.mutedForeground
            }
        }

        // Margem de Segurança (Padding)
        Column {
            width: parent.width
            spacing: Theme.spacingXs

            RowLayout {
                width: parent.width
                ThemedLabel {
                    text: qsTr("Margem de Segurança (Padding)")
                    size: "sm"
                    font.weight: Font.Medium
                    Layout.fillWidth: true
                }
                ThemedLabel {
                    text: (paddingSlider.value * 1000).toFixed(0) + " ms"
                    size: "sm"
                    color: Theme.primary
                    font.weight: Font.Bold
                }
            }

            Slider {
                id: paddingSlider
                width: parent.width
                from: 0.02
                to: 0.25
                value: 0.08
                stepSize: 0.01
                onValueChanged: root.paddingSec = value
            }

            ThemedLabel {
                text: qsTr("Preserva o início e o fim da fala para evitar cortes secos em consoantes (padrão: 80 ms).")
                size: "xs"
                color: Theme.mutedForeground
            }
        }

        // Área de Análise / Feedback
        Rectangle {
            width: parent.width
            height: root.detectedCount >= 0 ? 50 : 0
            visible: root.detectedCount >= 0
            radius: Theme.radiusSm
            color: Theme.panelBackground
            border.width: Theme.borderWidth
            border.color: Theme.constructive

            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingMd

                IconGlyph {
                    glyph: Theme.icons.check
                    iconColor: Theme.constructive
                    iconSize: Theme.iconSizeMd
                }

                ThemedLabel {
                    text: qsTr("Encontrados %1 silêncios (~%2s eliminados)").arg(root.detectedCount).arg(root.detectedTime.toFixed(1))
                    color: Theme.foreground
                    font.weight: Font.Medium
                    Layout.fillWidth: true
                }
            }
        }

        RowLayout {
            width: parent.width
            spacing: Theme.spacingMd

            ThemedButton {
                text: qsTr("Analisar")
                variant: "secondary"
                Layout.fillWidth: true
                onClicked: {
                    var res = EditorState.detectSilence(EditorState.selectedTrackIndex,
                                                        EditorState.selectedClipIndex,
                                                        root.thresholdDb,
                                                        root.minDurationSec,
                                                        root.paddingSec)
                    root.detectedCount = res.n !== undefined ? res.n : 0
                    var ranges = res.ranges || []
                    var total = 0.0
                    for (var i = 0; i < ranges.length; ++i) {
                        total += (ranges[i].end - ranges[i].start)
                    }
                    root.detectedTime = total
                }
            }

            ThemedButton {
                text: qsTr("✂️ Cortar e Juntar")
                variant: "primary"
                Layout.fillWidth: true
                onClicked: {
                    var res = EditorState.removeSilence(EditorState.selectedTrackIndex,
                                                        EditorState.selectedClipIndex,
                                                        root.thresholdDb,
                                                        root.minDurationSec,
                                                        root.paddingSec)
                    var count = res.n !== undefined ? res.n : 0
                    Toasts.success(qsTr("Silêncios removidos: %1 cortes aplicados.").arg(count))
                    root.close()
                }
            }
        }
    }
}
