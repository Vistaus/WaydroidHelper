import QtQuick 2.7
import Ubuntu.Components 1.3
import QtQuick.Layouts 1.3
import Qt.labs.settings 1.0
import io.thp.pyotherside 1.4
import Ubuntu.Components.Popups 1.3

Page {
    id: installerPage
    header: PageHeader {
        id: header
        title: i18n.tr("Install Waydroid")
        opacity: 1
        trailingActionBar {
            actions: [
                Action {
                    iconName: "google-plus-symbolic"
                    text: i18n.tr("GAPPS")
                    onTriggered: PopupUtils.open(gapps)
                }
            ]
        }
    }

    property var gAPPS: false
    property bool completed: false
    property bool running: false

    property string state: "initial"
    property var states: new Map([
        [ "initial", i18n.tr("By pressing 'start' the installation will, well... start. The installer will let you know what it is doing at the moment. Be patient! The installation may take a while. Do not close the app during the installation! I reccomend to disable screen suspension in the settings to keep the screen always on without touching it.") ],
        [ "starting", i18n.tr("Installation starting") ],
        [ "remount.rw", i18n.tr("Remounting filesystem as read-write") ],
        [ "remount.ro", i18n.tr("Remounting filesystem as read-only") ],
        [ "apt.install", i18n.tr("Installing Waydroid package") ],
        [ "dl.init.gapps", i18n.tr("Preparing to download system image (with GAPPS)") ],
        [ "dl.init.vanilla", i18n.tr("Preparing to download system image") ],
        [ "dl.gapps", i18n.tr("Downloading system image (with GAPPS)") ],
        [ "dl.vanilla", i18n.tr("Downloading system image") ],
        [ "dl.vendor", i18n.tr("Downloading vendor image") ],
        [ "validate.system", i18n.tr("Validating system image") ],
        [ "validate.vendor", i18n.tr("Validating vendor image") ],
        [ "extract.system", i18n.tr("Extracting system image") ],
        [ "extract.vendor", i18n.tr("Extracting vendor image") ],
        [ "complete", i18n.tr("Installation complete!") ],
    ])

    function startInstallation(password) {
        installerPage.running = true;
        python.call('installer.install', [ password, gAPPS ]);
    }

    function showPasswordPrompt() {
        if (root.inputMethodHints === null) {
            startInstallation('');
            return;
        }

        PopupUtils.open(passwordPrompt);
    }

    Connections {
        target: python

        onState: { // (string id, bool hasProgress)
            if (!installerPage.states.has(id)) {
                console.log('unknown state', id);
                return;
            }

            if (id === installerPage.state && hasProgress === !progress.indeterminate) {
                return;
            }

            progress.indeterminate = !hasProgress;
            installerPage.state = id;

            if (id === "complete") {
                installerPage.completed = true;
                installerPage.running = false;
            }
        }

        onDownloadProgress: { // (real current, real target, real speed, string unit)
            progress.maximumValue = target
            progress.value = current;
            unit = unit === 'kbps' ? 'KB/s' : 'MB/s';
            if (speed > 1000 && unit === 'KB/s') {
                speed = speed / 1000;
                unit = 'MB/s'
            }

            progressText.text = `${current.toFixed(2)} MB/${target.toFixed(2)} MB (${speed.toFixed(2)} ${unit})`;
        }
    }

    ColumnLayout {
        anchors {
            horizontalCenter: parent.horizontalCenter
            verticalCenter: parent.verticalCenter
        }
        spacing: units.gu(2)

        Component.onCompleted: PopupUtils.open(dialogInstall)

        Label {
            id: content
            text: installerPage.states.get(installerPage.state)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: installerPage.width / 1.5
        }

        ProgressBar {
            id: progress
            visible: running
            indeterminate: true
            value: 0
            Layout.alignment: Qt.AlignHCenter
        }

        Label {
            id: progressText
            visible: running
            opacity: progress.indeterminate ? 0 : 1
            Layout.alignment: Qt.AlignHCenter
        }

        Button {
            id: startButton
            visible: !running
            color: theme.palette.normal.positive
            text: installerPage.completed ? i18n.tr("Ok") : i18n.tr("Start")
            Layout.alignment: Qt.AlignHCenter

            onClicked: {
                if (!installerPage.completed) {
                    showPasswordPrompt();
                    return;
                }

                pageStack.pop();
            }
        }
    }

    Component {
        id: dialogInstall

        Dialog {
            id: dialogueInstall
            title: "Disclaimer!"

            Label {
                text: i18n.tr("You are about to use an experimental Waydroid installer! <br> Supported devices:") + i18n.tr("<br>Fairephone 3/3+<br>OnePlus 5/5T<br>Pixel/Pixel XL<br>Pixel 2 XL<br>Pixel 3a<br>Poco F1<br>Redmi Note 7/7 Pro/9 Pro/9 Pro Max<br>Samsung Galaxy S10<br>SHIFT6mq<br>Vollaphone (X)<br>") + i18n.tr("Other devices using Halium 9 or above may or may not work as well! <br> There is absolutely no warranty for this to work! Do not use this installer if you dont want to risk to brick your device permenantly (,which is highly unlikely though)!")
                wrapMode: Text.Wrap
            }

            Button {
                text: i18n.tr ("I understand the risk")
                color: theme.palette.normal.negative
                onClicked: PopupUtils.close(dialogueInstall)
            }

            Button {
                text: i18n.tr("Cancel")
                onClicked: {
                    PopupUtils.close(dialogueInstall);
                    pageStack.pop();
                }
            }
        }
    }

    Component {
        id: passwordPrompt

        PasswordPrompt {
            id: passPrompt

            onPassword: {
                startInstallation(password);
            }
        }
    }

    Component {
        id: gapps

        Dialog {
            id: gappsPrompt
            title: "Google Apps"

            Label {
                text: i18n.tr("You can install a special version of Waydroid that comes with google apps. (I personally do not recommend this as it will result in worse privacy.)")
                wrapMode: Text.Wrap
            }

            Button {
                text: i18n.tr("Enable GAPPS")
                color: theme.palette.normal.focus
                onClicked: {
                    gAPPS = true;
                    PopupUtils.close(gappsPrompt);
                }
            }

            Button {
                text: i18n.tr("Cancel")
                onClicked: {
                    PopupUtils.close(gappsPrompt);
                }
            }
        }
    }

    Python {
        id: python

        signal state(string id, bool hasProgress)
        signal downloadProgress(real current, real target, real speed, string unit)

        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl('../src/'));

            importNames('installer', ['installer'], () => {});

            python.setHandler('state', state);
            python.setHandler('downloadProgress', downloadProgress);
        }

        onError: {
            console.log('python error:', traceback);
        }
    }
}
