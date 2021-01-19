/* Copyright 2013-2015 Robert Schroll
 * Copyright 2020 Emanuele Sorce - emanuele.sorce@hotmail.com
 *
 * This file is part of Beru and is distributed under the terms of
 * the GPL. See the file COPYING for full details.
 * 
 * This file is part of Sturm Reader and is distributed under the terms of
 * the GPL. See the file COPYING for full details.
 */

import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import QtWebEngine 1.10

import "historystack.js" as History

import Metrics 1.0

Page {
	id: bookPage
    
	property alias url: bookWebView.url
	property var currentChapter: null
	property var history: new History.History(updateNavButtons)
	property bool navjump: false
	property bool canBack: false
	property bool canForward: false
	property bool isBookReady: false
	property bool doPageChangeAsSoonAsReady: false
    
	property string book_componentId;
	property real book_percent;
	
	// picture (i.e. pdf) has limited options
	property bool pictureBook: false;
	
	property int pdf_pageNumber: 0;
	property int pdf_numberOfPages: 0;
    
    signal contentOpened()

	function openContent() {
		content.open();
		contentOpened();
	}
    function closeContent() {
        content.close();
    }
	function closeControls() {
		controls.close();
	}
	function openControls() {
		controls.open();
	}
	function turnControlsOn() {
		controls.interactive = true;
	}
	function turnControlsOff() {
		controls.interactive = false;
	}
    
	ListModel {
		id: pagesTumblerModel
	}
    
	Dialog {
		id: content
		width: Math.min(parent.width, scaling.dp(750))
		height: Math.max(parent.height * 0.75, Math.min(parent.height, scaling.dp(500)))
		y: (parent.height - height) * 0.5
		x: (parent.width - width) * 0.5
		dim: true
		
		property alias pdf_newPage: pageSlider.value
		
		header: Column {
			width: parent.width
			ToolBar {
				width: parent.width
				RowLayout {
					anchors.fill: parent
					Label {
						text: gettext.tr("Contents")
						font.pixelSize: scaling.dp(27)
						elide: Label.ElideRight
						horizontalAlignment: Qt.AlignHCenter
						verticalAlignment: Qt.AlignVCenter
						Layout.fillWidth: true
					}
				}
			}
			TabBar {
				id: sorttabs
				width: parent.width
				TabButton {
					text: gettext.tr("Outline")
					onClicked: {
						pagesLoader.visible = false;
						outlineLoader.visible = true;
						content.standardButtons = Dialog.Cancel;
					}
				}
				TabButton {
					text: gettext.tr("Pages")
					visible: pictureBook && !appsettings.legacypdf
					onClicked: {
						outlineLoader.visible = false;
						pagesLoader.visible = true;
						content.standardButtons = Dialog.Cancel | Dialog.Ok;
					}
				}
			}
		}
		
		standardButtons: Dialog.Cancel
		
		Item {
			id: outlineLoader
			
			anchors.fill: parent
			
			ListView {
				id: contentsListView
				anchors.fill: parent
				visible: contentsListModel.count > 0

				model: contentsListModel
				delegate: ItemDelegate {
					width: parent.width
					highlighted: bookPage.currentChapter == model.src
					text: (new Array(model.level + 1)).join("    ") +
							model.title.replace(/(\n| )+/g, " ").replace(/^%PAGE%/, gettext.tr("Page"))
					onClicked: {
						bookLoadingStart();
						bookWebView.runJavaScript('moveToChapter("' + model.src + '")');
						closeContent();
					}
				}

				Connections {
					target: bookPage
					onContentOpened: {
						for (var i=0; i<contentsListModel.count; i++) {
							if (contentsListModel.get(i).src == bookPage.currentChapter) {
								contentsListView.positionViewAtIndex(i, ListView.Center);
								break;
							}
						}
					}
				}
				ScrollBar.vertical: ScrollBar {}
			}
			Label {
				anchors.centerIn: parent
				visible: contentsListModel.count == 0
				text: gettext.tr("No outline available")
			}
		}
		
		Item {
			id: pagesLoader
			anchors.fill: parent
			visible: false
			
			property alias slider: pageSlider
			
			Column {
				width: parent.width
				anchors.leftMargin: scaling.dp(10)
				anchors.rightMargin: scaling.dp(10)
				
				spacing: scaling.dp(15)
				
				onVisibleChanged: {
					pagesLoader.slider.value = pdf_pageNumber;
				}
				
				Label {
					width: parent.width
					horizontalAlignment: Text.AlignHCenter
					text: gettext.tr("Page") + " " + pagesLoader.slider.value + "/" + (pdf_numberOfPages)
					font.pointSize: 19
				}
				RowLayout {
					width: parent.width
					Button {
						Layout.alignment: Qt.AlignLeft
						text: "-"
						font.pointSize: 19
						onClicked: pagesTumbler.currentIndex -= 1
					}
					Tumbler {
						Layout.alignment: Qt.AlignHCenter
						id: pagesTumbler
						rotation: -90
						wrap: false
						model: pagesTumblerModel
						delegate: Label {
							text: model.num
							rotation: 90
							font.weight: (model.num == pagesTumbler.currentIndex+1) ? Font.Bold : Font.Normal
							font.pointSize: (model.num == pagesTumbler.currentIndex+1) ? 18 : 16
							width: scaling.dp(60)
							height: scaling.dp(60)
							horizontalAlignment: Text.AlignHCenter
							verticalAlignment: Text.AlignVCenter
						}
						onCurrentIndexChanged: {
							if (pagesLoader.slider.value != currentIndex+1)
								pagesLoader.slider.value = currentIndex+1;
						}
					}
					Button {
						Layout.alignment: Qt.AlignRight
						text: "+"
						font.pointSize: 19
						onClicked: pagesTumbler.currentIndex += 1
					}
				}
			}
			RowLayout {
				id: sliderRow
				width: parent.width
				anchors.bottom: parent.bottom
				Slider {
					id: pageSlider
					Layout.fillWidth: true
					from: 1
					to: pdf_numberOfPages
					stepSize: 1
					value: pdf_pageNumber
					onValueChanged: {
						if (pagesTumbler.currentIndex != value-1)
							pagesTumbler.currentIndex = value-1;
					}
					snapMode: Slider.SnapAlways
				}
				Label {
					width: scaling.dp(50)
					text: Math.floor(100 * pageSlider.value / pdf_numberOfPages) + "%"
				}
			}
		}
		
		onAccepted: {
			var locus = {pageNumber: pdf_newPage}
			bookWebView.runJavaScript("moveToLocus(" + JSON.stringify(locus) + ")");
		}
	}

	Drawer {
		id: controls
		width: parent.width
		height: controlRect.height
		edge: Qt.BottomEdge
		modal: false
		
		// is turned on by turnControlsOn()
		interactive: false
		
		Rectangle {
			
			id: controlRect
			
			antialiasing: false
			color: colors.background
			
			anchors.left: parent.left
			anchors.right: parent.right
			anchors.top: parent.top
			height: childrenRect.height
			width: parent.width
			
			// relaxed layout uses more space, nicer on wider screens
			// there is one button more on the right, so we check there
			property bool relaxed_layout: width * 0.5 >= jump_button.width + content_button.width + settings_button.width
			
			// reduce button size when even not relaxed layout not enought
			// 7 is the number of buttons
			// Not 100% accurate alghorithm, but this convers just edge cases (very small phone display)
			property int max_button_size: width / 7 - scaling.dp(1)
			
			FloatingButton {
				id: home_button
				anchors.left: parent.left
				max_size: controlRect.max_button_size
				buttons: [
					Action {
						iconName: "go-home"
						onTriggered: {
							// turn stuff off and exit
							closeContent()
							closeControls()
							turnControlsOff()
							pageStack.pop()
							mainView.title = mainView.defaultTitle
						}
					}
				]
			}
			FloatingButton {
				id: history_button
				anchors.right: jump_button.left
				max_size: controlRect.max_button_size
				buttons: [
					Action {
						iconName: "undo"
						enabled: canBack
						onTriggered: {
							var locus = history.goBackward()
							if (locus !== null) {
								navjump = true;
								bookLoadingStart()
								bookWebView.runJavaScript("moveToLocus(" + locus + ")");
							}
						}
					},
					Action {
						iconName: "redo"
						enabled: canForward
						onTriggered: {
							var locus = history.goForward()
							if (locus !== null) {
								navjump = true;
								bookLoadingStart()
								bookWebView.runJavaScript("moveToLocus(" + locus + ")");
							}
						}
					}
				]
			}
			FloatingButton {
				id: jump_button
				anchors.right: content_button.left
				anchors.rightMargin: controlRect.relaxed_layout ? parent.width * 0.5 - content_button.width - settings_button.width - width : 0
				max_size: controlRect.max_button_size
				
				buttons: [
					Action {
						iconName: "go-previous"
						onTriggered: {
							bookLoadingStart()
							bookWebView.runJavaScript("moveToPageRelative(-10)");
						}
					},
					Action {
						iconName: "go-next"
						onTriggered: {
							bookLoadingStart()
							bookWebView.runJavaScript("moveToPageRelative(10)");
						}
					}
				]
			}
			FloatingButton {
				id: content_button
				anchors.right: settings_button.left
				max_size: controlRect.max_button_size
				buttons: [
					Action {
						iconName: "book"
						onTriggered: {
							openContent()
							closeControls()
						}
					}
				]
			}
			FloatingButton {
				id: settings_button
				anchors.right: parent.right
				max_size: controlRect.max_button_size
				buttons: [
					Action {
						iconName: "settings"
						onTriggered: {
							stylesDialog.open()
							closeControls()
						}
					}
				]
			}
        }
	}

    onVisibleChanged: {
		if(visible)
			bookStyles.loadForBook();
    }

    BusyIndicator {
        id: loadingIndicator
        width: scaling.dp(50)
        height: scaling.dp(50)
        anchors.centerIn: parent
        opacity: 1
        running: opacity != 0
    }
    
    function bookLoadingStart(){
		bookWebView.opacity = 0;
		loadingIndicator.opacity = 1;
	}
	function bookLoadingCompleted(){
		bookWebView.opacity = 1;
		loadingIndicator.opacity = 0;
	}
    
	WebEngineView {
		id: bookWebView
		anchors.fill: parent
		opacity: 0
		
		settings.showScrollBars: false
		
		onJavaScriptConsoleMessage: function(level, message, linen, sourceID) {
			console.log("Book: " + message + " | level: " + level + " | line: " + linen + " | source: " + sourceID);
		
			var msg = message.split(" ");
			
			if(msg[0] == "Jumping") {
				bookPage.onJumping([msg[1], msg[2]]);
			} else if(msg[0] == "UpdatePage") {
				if(!isBookReady) {
					doPageChangeAsSoonAsReady = true;
				} else {
					bookLoadingCompleted();
					bookPage.updateSavedPage();
				}
			} else if(msg[0] == "startLoading") {
				bookLoadingStart();
			} else if(msg[0] == "Ready") {
				isBookReady = true;
				if(doPageChangeAsSoonAsReady) {
					bookPage.updateSavedPage();
					doPageChangeAsSoonAsReady = false;
				}
				bookLoadingCompleted();
				openControls();
			} else if(msg[0] == "setContent") {
				contentsListModel.clear();
				if(msg.length > 2)
					for(var i=2; i<msg.length; i++) msg[1] += " " + msg[i];
				var con = JSON.parse(msg[1]);
				for(var i=0; i<con.length; i++) contentsListModel.append(con[i]);
			} else if(msg[0] == "status_requested") {
				bookWebView.runJavaScript("statusUpdate()");
			} else if(msg[0] == "chapter") {
				if(msg.length > 2)
					for(var i=2; i<msg.length; i++) msg[1] += " " + msg[i];
				currentChapter = JSON.parse(msg[1]);
			} else if(msg[0] == "percent") {
				book_percent = Number(msg[1]);
			} else if(msg[0] == "componentId") {
				book_componentId = msg[1];
			} else if(msg[0] == "pageNumber") {
				pdf_pageNumber = Number(msg[1]);
			} else if(msg[0] == "numberOfPages") {
				pdf_numberOfPages = Number(msg[1]);
				pagesTumblerModel.clear();
				for (var i = 1; i <= pdf_numberOfPages; i += 1)
					pagesTumblerModel.append({"num": (i)});
			} else if(msg[0] == "ok") {
				bookLoadingCompleted();
			} else if(msg[0] == "monocle:notfound") {
				// This is caused by some bug - we prevent the app from freeze in loading at least
				bookLoadingCompleted()
			} else if(msg[0] == "monocle:link:external") {
				var comp_id = msg[1].split("127.0.0.1:" + server.port + "/")[1];
				runJavaScript("moveToChapter('" + comp_id + "')");
			} else if(msg[0] == "pictureBook") {
				pictureBook = true;
			// debug messages
			} else if(msg[0] == "#") {}
			// not handled messages
			else console.log("ignored");
		}
		
		onActiveFocusChanged: {
			if(activeFocus)
				closeControls()
		}
		
		Keys.onPressed: {
			if (event.key == Qt.Key_Right || event.key == Qt.Key_Down || event.key == Qt.Key_Space
					|| event.key == Qt.Key_Period) {
				bookLoadingStart();
				bookWebView.runJavaScript("moveToPageRelative(1)");
				event.accepted = true;
			} else if (event.key == Qt.Key_Left || event.key == Qt.Key_Up
					|| event.key == Qt.Key_Backspace || event.key == Qt.Key_Comma) {
				bookLoadingStart();
				bookWebView.runJavaScript("moveToPageRelative(-1)");
				event.accepted = true;
			}
		}
	}
	
	Metrics {
		id: pageMetric
	}

    ListModel {
        id: contentsListModel
    }

    Item {
        id: bookStyles
        property bool loading: false
        property bool atdefault: false

        property string textColor
        property string fontFamily
        property real lineHeight
        property real fontScale
        property string background
        property real margin
        property real marginv
        property real bumper

        property var defaults: ({
            textColor: "#222",
            fontFamily: "Default",
            lineHeight: 1,
            fontScale: 1,
            background: "url(.background_paper@30.png)",
            margin: 0,
            marginv: 0
        })

        //onTextColorChanged: update()  // This is always updated with background
        onFontFamilyChanged: update()
        onLineHeightChanged: update()
        onFontScaleChanged: update()
        onBackgroundChanged: update()
        onMarginChanged: update()

        function load(styles) {
            loading = true
            textColor = styles.textColor || defaults.textColor
            fontFamily = styles.fontFamily || defaults.fontFamily
            lineHeight = styles.lineHeight || defaults.lineHeight
            fontScale = styles.fontScale || defaults.fontScale
            background = styles.background || defaults.background
            margin = styles.margin || (pictureBook ? 0 : defaults.margin)
            marginv = styles.marginv || (pictureBook ? 0 : defaults.marginv)
            bumper = pictureBook ? 0 : 1
            loading = false
        }

        function loadForBook() {
            var saved = getBookSetting("styles") || {}
            load(saved)
        }

        function asObject() {
            return {
                textColor: textColor,
                fontFamily: fontFamily,
                lineHeight: lineHeight,
                fontScale: fontScale,
                background: background,
                margin: margin,
                marginv: marginv,
                bumper: bumper
            }
        }

        function update() {
            if (loading)
                return
			
			// book is not loaded
			if(bookWebView.url == "")
				return
			
			bookLoadingStart()
			
            // this one below should be improved
			bookWebView.runJavaScript("if(styleManager) styleManager.updateStyles(" + JSON.stringify(asObject()) + ");");
			setBookSetting("styles", asObject());
			atdefault = (JSON.stringify(asObject()) == JSON.stringify(defaults));
        }

        function resetToDefaults() {
            load({})
            update()
        }

        function saveAsDefault() {
            setSetting("defaultBookStyle", JSON.stringify(asObject()))
            defaults = asObject()
            atdefault = true
        }

        Component.onCompleted: {
            var targetwidth = 60
            var widthgu = width/scaling.dp(8)
            if (widthgu > targetwidth)
                // Set the margins to give us the target width, but no more than 30%.
                defaults.margin = Math.round(Math.min(50 * (1 - targetwidth/widthgu), 30))

            var saveddefault = getSetting("defaultBookStyle")
            var savedvals = {}
            if (saveddefault != null)
                savedvals = JSON.parse(saveddefault)
            for (var prop in savedvals)
                if (prop in defaults)
                    defaults[prop] = savedvals[prop]

            if (savedvals.marginv == undefined && widthgu > targetwidth)
                // Set the vertical margins to be the same as the horizontal, but no more than 5%.
                defaults.marginv = Math.min(defaults.margin, 5)
        }
    }

    function getBookStyles() {
        return bookStyles.asObject()
    }
    
    FontLoader {
        source: Qt.resolvedUrl("../html/fonts/Bitstream Charter.ttf")
    }

    FontLoader {
        source: Qt.resolvedUrl("../html/fonts/URW Bookman L.ttf")
    }

    FontLoader {
        source: Qt.resolvedUrl("../html/fonts/URW Gothic L.ttf")
    }

    QtObject {
        id: fontLister

        property var fontList: ["Default", "Bitstream Charter", "Ubuntu", "URW Bookman L", "URW Gothic L"]

        Component.onCompleted: {
            var familyList = qtfontlist.families()
			
            var possibleFamilies = [["Droid Serif", "Nimbus Roman No9 L", "FreeSerif"],
                                   ["Droid Sans", "Nimbus Sans L", "FreeSans"]]
            for (var j=0; j<possibleFamilies.length; j++) {
                for (var i=0; i<possibleFamilies[j].length; i++) {
                    if (familyList.indexOf(possibleFamilies[j][i]) >= 0) {
                        fontList.splice(2, 0, possibleFamilies[j][i])
						break
                    }
                }
            }
        }
    }

    Dialog {
		id: stylesDialog
		property real labelwidth: width * 0.3
		visible: false
		
		x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
		width: Math.min(parent.width, Math.max(parent.width * 0.5, scaling.dp(450)))
		height: Math.min(parent.height*0.9, stylesFlickable.contentHeight + stylesToolbar.height + scaling.dp(50))
		
		modal: true
		
		header: ToolBar {
			id: stylesToolbar
			width: parent.width
			RowLayout {
				anchors.fill: parent
				Label {
					text: gettext.tr("Book Settings")
					font.pixelSize: scaling.dp(27)
					elide: Label.ElideRight
					horizontalAlignment: Qt.AlignHCenter
					verticalAlignment: Qt.AlignVCenter
					Layout.fillWidth: true
				}
				
				BusyIndicator {
					width: height
					height: scaling.dp(25)
					Layout.rightMargin: scaling.dp(0)
					opacity: loadingIndicator.opacity
					running: opacity != 0
				}
			}
		}
		
		Flickable {
			id: stylesFlickable
			
			clip: true
			boundsBehavior: Flickable.OvershootBounds
			
			anchors.top: parent.top
			anchors.bottom: parent.bottom
			width: parent.width
			contentWidth: parent.width
			contentHeight: settingsColumn.height
			
			ScrollBar.vertical: ScrollBar { }
			
			Column {
				id: settingsColumn
				width: parent.width
				anchors.centerIn: parent.center
				
				spacing: scaling.dp(20)
				
				Row {
					anchors.horizontalCenter: parent.horizontalCenter
					width: parent.width * 0.9
					
					Label {
						/*/ Prefer string of < 16 characters /*/
						text: gettext.tr("Color scheme")
						verticalAlignment: Text.AlignVCenter
						wrapMode: Text.Wrap
						width: stylesDialog.labelwidth
						height: fontSelector.height
					}
					
					ComboBox {
						id: colorSelector
						displayText: styleModel.get(currentIndex).stext
						width: parent.width - stylesDialog.labelwidth
						model: ListModel {
							id: styleModel
							ListElement {
								stext: "Black on White"
								back: "white"
								fore: "black"
								comboboxback: "white"
								comboboxfore: "black"
							}
							ListElement {
								stext: "Dark on Texture"
								back: "url(.background_paper@30.png)"
								fore: "#222"
								comboboxback: "#dddddd"
								comboboxfore: "#222222"
							}
							ListElement {
								stext: "Light on Texture"
								back: "url(.background_paper_invert@30.png)"
								fore: "#999"
								comboboxback: "#222222"
								comboboxfore: "#dddddd"
							}
							ListElement {
								stext: "White on Black"
								back: "black"
								fore: "white"
								comboboxback: "black"
								comboboxfore: "white"
							}
						}
						onCurrentIndexChanged: {
							bookStyles.textColor = styleModel.get(currentIndex).fore
							bookStyles.background = styleModel.get(currentIndex).back
						}
						delegate: ItemDelegate {
							highlighted: colorSelector.highlightedIndex === index
							width: parent.width
							contentItem: Label {
								text: stext
								color: comboboxfore
							}
							background: Rectangle {
								color: comboboxback
							}
						}
					}
				}
				
				Row {
					anchors.horizontalCenter: parent.horizontalCenter
					width: parent.width * 0.9
					visible: !pictureBook
					
					Label {
						/*/ Prefer string of < 16 characters /*/
						text: gettext.tr("Font")
						verticalAlignment: Text.AlignVCenter
						wrapMode: Text.Wrap
						width: stylesDialog.labelwidth
						height: fontSelector.height
					}
					
					ComboBox {
						id: fontSelector
						onCurrentIndexChanged: bookStyles.fontFamily = model[currentIndex]
						displayText: (model[currentIndex] == "Default") ? gettext.tr("Default Font") : model[currentIndex]
						width: parent.width - stylesDialog.labelwidth
						
						model: fontLister.fontList
						
						delegate: ItemDelegate {
							highlighted: fontSelector.highlightedIndex === index
							width: parent.width
							contentItem: Label {
								verticalAlignment: Text.AlignVCenter
								text: (modelData == "Default") ? gettext.tr("Default Font") : modelData
								font.family: modelData
							}
						}
					}
				}

				Row {
					anchors.horizontalCenter: parent.horizontalCenter
					width: parent.width * 0.9
					visible: !pictureBook
					Label {
						/*/ Prefer string of < 16 characters /*/
						text: gettext.tr("Font Scaling")
						verticalAlignment: Text.AlignVCenter
						wrapMode: Text.Wrap
						width: stylesDialog.labelwidth
						height: fontScaleSlider.height
					}

					Slider {
						id: fontScaleSlider
						width: parent.width - stylesDialog.labelwidth
						from: 0.5
						to: 4
						stepSize: 0.25
						snapMode: Slider.SnapAlways
						onMoved: bookStyles.fontScale = value
					}
				}

				Row {
					anchors.horizontalCenter: parent.horizontalCenter
					width: parent.width * 0.9
					visible: !pictureBook
					Label {
						/*/ Prefer string of < 16 characters /*/
						text: gettext.tr("Line Height")
						verticalAlignment: Text.AlignVCenter
						wrapMode: Text.Wrap
						width: stylesDialog.labelwidth
						height: lineHeightSlider.height
					}

					Slider {
						id: lineHeightSlider
						width: parent.width - stylesDialog.labelwidth
						from: 0.8
						to: 2
						stepSize: 0.2
						snapMode: Slider.SnapAlways
						onMoved: bookStyles.lineHeight = value
					}
				}

				Row {
					anchors.horizontalCenter: parent.horizontalCenter
					width: parent.width * 0.9
					visible: !pictureBook
					Label {
						/*/ Prefer string of < 16 characters /*/
						text: gettext.tr("Margins")
						verticalAlignment: Text.AlignVCenter
						wrapMode: Text.Wrap
						width: stylesDialog.labelwidth
						height: marginSlider.height
					}

					Slider {
						id: marginSlider
						width: parent.width - stylesDialog.labelwidth
						from: 0
						to: 24
						stepSize: 2
						snapMode: Slider.SnapAlways
						function formatValue(v) { return Math.round(v) + "%" }
						onValueChanged: bookStyles.margin = value
					}
				}

				Button {
					anchors.horizontalCenter: parent.horizontalCenter
					width: parent.width * 0.8
					/*/ Prefer < 16 characters /*/
					text: gettext.tr("Make Default")
					enabled: !bookStyles.atdefault
					onClicked: bookStyles.saveAsDefault()
				}
				Button {
					anchors.horizontalCenter: parent.horizontalCenter
					width: parent.width * 0.8
					/*/ Prefer < 16 characters /*/
					text: gettext.tr("Load Defaults")
					enabled: !bookStyles.atdefault
					onClicked: bookStyles.resetToDefaults()
				}
				
				Button {
					anchors.horizontalCenter: parent.horizontalCenter
					width: parent.width * 0.8
					text: gettext.tr("Close")
					highlighted: true
					onClicked: stylesDialog.close()
				}
			}
		}
		
		onOpened: {
			if (bookStyles.loading == false)
				setValues()
		}
			
		function setValues() {
			for (var i=0; i<styleModel.count; i++) {
				if (styleModel.get(i).fore == bookStyles.textColor) {
					colorSelector.currentIndex = i
					break
				}
			}
			fontSelector.currentIndex = fontSelector.model.indexOf(bookStyles.fontFamily)
			fontScaleSlider.value = bookStyles.fontScale
			lineHeightSlider.value = bookStyles.lineHeight
			marginSlider.value = bookStyles.margin
		}
		/* function onLoadingChanged() {
			if (bookStyles.loading == false)
				setValues()
		}
		Component.onCompleted: {
			setValues()
			bookStyles.onLoadingChanged.connect(onLoadingChanged)
		}
		Component.onDestruction: {
			bookStyles.onLoadingChanged.disconnect(onLoadingChanged)
		}*/
    }

    function updateNavButtons(back, forward) {
        canBack = back
        canForward = forward
    }

    function parseContents(contents, level) {
        if (level === undefined) {
            level = 0
            contentsListModel.clear()
        }
        for (var i in contents) {
            var chp = contents[i]
            chp.level = level
            contentsListModel.append(chp)
            if (chp.children !== undefined)
                parseContents(chp.children, level + 1)
        }
    }

    function onJumping(locuses) {
        if (navjump)
            navjump = false
        else
            history.add(locuses[0], locuses[1])
    }

	function updateSavedPage() {
		setBookSetting("locus", {
			// monocle
			componentId: book_componentId,
			percent: Number(book_percent),
			// pdfjs
			pageNumber: pdf_pageNumber
		})
		pageMetric.turnPage()
	}

	Component.onCompleted: {
		server.reader.contentsReady.connect(parseContents)
	}
}
