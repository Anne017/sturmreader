/* Copyright 2013-2015 Robert Schroll
 *
 * This file is part of Beru and is distributed under the terms of
 * the GPL. See the file COPYING for full details.
 */

import QtQuick 2.4
import QtQuick.LocalStorage 2.0
import QtQuick.Window 2.0
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3
import U1db 1.0 as U1db
import File 1.0

import "components"


MainView {
    // objectName for functional testing purposes (autopilot-qt5)
    objectName: "mainView"
    id: mainView
    
    applicationName: "sturmreader.plus.emanuelesorce"
    
    /* 
     This property enables the application to change orientation 
     when the device is rotated. The default is false.
    */
    automaticOrientation: true
    
    width: units.gu(200)
    height: units.gu(200)

    FileSystem {
        id: filesystem
    }

    PageStack {
        id: pageStack
        Component.onCompleted: push(localBooks)
        onCurrentPageChanged: currentPage.forceActiveFocus()


        LocalBooks {
            id: localBooks
            visible: false
        }

        BookSources {
            id: bookSources
            visible: false
        }

        BookPage {
            id: bookPage
            visible: false
        }
    }

    Component {
        id: errorOpen
        Dialog {
            id: errorOpenDialog
            title: i18n.tr("Error Opening File")
            text: server.reader.error
            StyledButton {
                text: i18n.tr("OK")
                onClicked: PopupUtils.close(errorOpenDialog)
            }
        }
    }

    Server {
        id: server
    }

    Importer {
        id: importer
    }

    function loadFile(filename) {
        if (server.reader.load(filename)) {
            while (pageStack.currentPage != localBooks)
                pageStack.pop()

            pageStack.push(bookPage, {url: "http://127.0.0.1:" + server.port})
            window.title = server.reader.title()
            localBooks.updateRead(filename)
            return true
        }
        PopupUtils.open(errorOpen)
        return false
    }

    function openSettingsDatabase() {
        return LocalStorage.openDatabaseSync("BeruSettings", "1", "Global settings for Beru", 10000)
    }

    function getSetting(key) {
        var db = openSettingsDatabase()
        var retval = null
        db.readTransaction(function (tx) {
            var res = tx.executeSql("SELECT value FROM Settings WHERE key=?", [key])
            if (res.rows.length > 0)
                retval = res.rows.item(0).value
        })
        return retval
    }

    function setSetting(key, value) {
        var db = openSettingsDatabase()
        db.transaction(function (tx) {
            tx.executeSql("INSERT OR REPLACE INTO Settings(key, value) VALUES(?, ?)", [key, value])
        })
    }

    function sizeChanged() {
        setSetting("winsize", JSON.stringify([width, height]))
    }

    U1db.Database {
        id: bookSettingsDatabase
        path: "BeruBookSettings.db"
    }

    function getBookSetting(key) {
        if (server.reader.hash() == "")
            return undefined

        var settings = bookSettingsDatabase.getDoc(server.reader.hash())
        if (settings == undefined)
            return undefined
        return settings[key]
    }

    function setBookSetting(key, value) {
        if (server.reader.hash() == "")
            return false

        if (databaseTimer.hash != null &&
                (databaseTimer.hash != server.reader.hash() || databaseTimer.key != key))
            databaseTimer.triggered()

        databaseTimer.stop()
        databaseTimer.hash = server.reader.hash()
        databaseTimer.key = key
        databaseTimer.value = value
        databaseTimer.start()

        return true
    }

    Timer {
        id: databaseTimer
        interval: 1000
        repeat: false
        running: false
        triggeredOnStart: false
        property var hash: null
        property var key
        property var value
        onTriggered: {
            if (hash == null)
                return

            var settings = bookSettingsDatabase.getDoc(hash)
            if (settings == undefined)
                settings = {}
            settings[key] = value
            bookSettingsDatabase.putDoc(settings, hash)
            hash = null
        }
    }

    Arguments {
        id: args

        Argument {
            name: "appargs"
            required: true
            valueNames: ["APP_ARGS"]
        }
    }

    Component.onCompleted: {
        var db = openSettingsDatabase()
        db.transaction(function (tx) {
            tx.executeSql("CREATE TABLE IF NOT EXISTS Settings(key TEXT UNIQUE, value TEXT)")
        })

        var filePath = filesystem.canonicalFilePath(args.values.appargs)
        if (filePath !== "") {
            if (loadFile(filePath))
                localBooks.addFile(filePath)
        }

        onWidthChanged.connect(sizeChanged)
        onHeightChanged.connect(sizeChanged)
        var size = JSON.parse(getSetting("winsize"))
        if (size != null) {
            width = size[0]
            height = size[1]
        }

        localBooks.onMainCompleted()
    }
}
