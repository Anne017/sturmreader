var pageNumber = 1;
var page_is_rendering = false;
var pageNumIsPending = null;
var page_width = window.innerWidth;
var book_aspect_ratio = 1;
var first_render = true;
var mc = undefined;
var doc = undefined;
var outline = undefined;
var number_of_pages = 0;

// BOOK PAGE API

function statusUpdate() {
	// for the chapter, scroll throught the chapters to find the right one if any
	let chap = -1;
	for(let i=0; i<outline.length; i++) {
		if(outline[i].src <= pageNumber)
			chap = outline[i].src;
		else
			break;
	}
	console.log("chapter " + JSON.stringify(chap));
	console.log("pageNumber " + pageNumber);
	console.log("UpdatePage");
}
function moveToPageRelative (num) {
	let target = pageNumber + Number(num);
	if(target < 1)
		target = 1;
	else if(target > number_of_pages)
		target = number_of_pages;
	
	// Don't trigger turning if it's the same page
	if(target != pageNumber) {
		if(Math.abs(target - pageNumber) > 1)
			console.log("Jumping " + JSON.stringify({pageNumber: pageNumber}) + " " + JSON.stringify({pageNumber: target}))
	
		queueRenderPage(target);
	}
}
function moveToLocus(locus) {
	queueRenderPage(locus.pageNumber);
}
function moveToChapter(chap) {
	console.log("Jumping " + JSON.stringify({pageNumber: pageNumber}) + " " + JSON.stringify({pageNumber: Number(chap)}));
	queueRenderPage(Number(chap));
}
var styleManager = {

	updateStyles: function(style){
		if(style.background)
			document.body.style.background = style.background;
		console.log("ok");
	}
}
// END BOOK PAGE CALLS

function slowForeground(){
	document.getElementById("slow-canvas").style.visibility = "visible";
	document.getElementById("fast-canvas").style.visibility = "hidden";
}

function fastForeground(){
	document.getElementById("slow-canvas").style.visibility = "hidden";
	document.getElementById("fast-canvas").style.visibility = "visible";
}

function centerCanvas(){
	var slow_canvas = document.getElementById("slow-canvas");
	var fast_canvas = document.getElementById("fast-canvas");
	if(window.innerWidth / window.innerHeight < book_aspect_ratio) {
		slow_canvas.style.top = "50%";
		slow_canvas.style.transform = "translateY(-50%)";
		fast_canvas.style.top = "50%";
		fast_canvas.style.transform = "translateY(-50%)";
	} else {
		slow_canvas.style.top = "0px";
		slow_canvas.style.transform = "translateY(-0px)";
		fast_canvas.style.top = "0px";
		fast_canvas.style.transform = "translateY(-0px)";
	}
}

function renderPage (num, fast) {
    doc.getPage(num).then(
		function(page) {
		
			var target_width = page_width;
			var original_viewport = page.getViewport({ scale: 1 });
			var scale = target_width / original_viewport.width;
			
			if(fast)
				scale = Math.max(2, scale * 0.3);
			else
				// 5 is quite a lot anyway
				scale = Math.min(5, scale);
			
			var viewport = page.getViewport({ scale: scale });

			var canvas = document.getElementById(fast ? 'fast-canvas' : 'slow-canvas');
			var context = canvas.getContext('2d');
			canvas.height = viewport.height;
			canvas.width = viewport.width;
			
			book_aspect_ratio = viewport.width / viewport.height;

			var renderContext = {
				canvasContext: context,
				viewport: viewport,
				enableWebGL: true
			}
			pageNumber = num;

			page.render(renderContext).promise.then(
				function(){
					// set up canvases
					if(fast) fastForeground()
					else slowForeground()
					centerCanvas();
					
					if(first_render) {
						console.log("Ready")
						first_render = false;
					}
					
					// avoid double status updates, since each page is rendered twice
					if(fast)
						console.log("status_requested");
					
					// if there is another page to render, render it
					if (pageNumIsPending !== null) {
						var temp_next_page = pageNumIsPending
						pageNumIsPending = null;
						renderPage(temp_next_page, true);
					}
					// or if this was the fast render, render it better
					else if(fast)
						renderPage(num, false);
				},
				(reason) => console.log("# page rendering failed " + reason)
			)
		},
		(reason) => console.log("# page loading failed " + reason)
	)
}

function queueRenderPage (num) {
    if (page_is_rendering) {
        pageNumIsPending = num;
    } else {
		page_is_rendering = true;
        renderPage(num, true);
		page_is_rendering = false;
    }
};

function tapPageTurn(ev) {

	// do not move if zoomed
	if(window.visualViewport.scale > 1.001)
		return;
	
	if(ev.center.x > window.innerWidth * 0.4) {
		moveToPageRelative(1);
		
		var fast_canvas = document.getElementById('fast-canvas');
		var slow_canvas = document.getElementById('slow-canvas');
		fast_canvas.classList.add("transitionPageOut");
		slow_canvas.classList.add("transitionPageOut");
		fast_canvas.style.left = "-100%";
		slow_canvas.style.left = "-100%";
	} else {
		moveToPageRelative(-1);
		var fast_canvas = document.getElementById('fast-canvas');
		var slow_canvas = document.getElementById('slow-canvas');
		fast_canvas.style.left = "-100%";
		slow_canvas.style.left = "-100%";
		setTimeout( () => {
			fast_canvas.classList.add("transitionPageOut");
			slow_canvas.classList.add("transitionPageOut");
			fast_canvas.style.left = "0px";
			slow_canvas.style.left = "0px";
		}, 50);
	}
}

async function parseOutlineNode(ol, depth) {
	const dest = ol.dest;
	let o_title = ol.title;
	let o_pageNumber = 1;
		
	var ref = dest[0];
		
	if(typeof(dest) === "string") {
		try {
			var destination = await doc.getDestination(dest);
			ref = destination[0];
		} catch(err) {
			console.log("# getDestination error: " + err);
		}
	}
	
	try {
		o_pageNumber = 1 + await doc.getPageIndex(ref);
	} catch(err) {
		console.log("# getPageIndex error: " + err);
	}
	
	outline.push({title: o_title, src: o_pageNumber, level: depth});
	
	// analize child
	await parseOutlineNodeArray(ol.items, depth+1);
}

async function parseOutlineNodeArray(ol, depth) {
	for (let i=0; i < ol.length; i++) {
		await parseOutlineNode(ol[i], depth);
	}
}

function transitionPageTurned() {
	document.getElementById("slow-canvas").classList.remove("transitionPageOut");
	document.getElementById("fast-canvas").classList.remove("transitionPageOut");
	document.getElementById("slow-canvas").style.left = "0px";
	document.getElementById("fast-canvas").style.left = "0px";
}

window.onload = function() {
	
	// set the background
	document.getElementById("next-canvas").style.zIndex = -1;
	
	outline = [];
	
	mc = new Hammer.Manager(document.getElementById("container"));
	
	// initialize gestures
	var Tap = new Hammer.Tap();
	var Press = new Hammer.Press();
	
	// Add the recognizer to the manager
	mc.add(Press);
	mc.add(Tap);
	mc.on("tap press", (ev) => tapPageTurn(ev) );
	
	// initialize event listeners
	document.getElementById("slow-canvas").addEventListener("transitionend", transitionPageTurned)
	
	// load saved page or open from the beginning
	if(SAVED_PLACE && SAVED_PLACE.pageNumber)
		pageNumber = SAVED_PLACE.pageNumber;
	
	// load file and render first page
	pdfjsLib.GlobalWorkerOptions.workerSrc = '.pdfjs/build/pdf.worker.js';
	pdfjsLib.getDocument("book.pdf").promise.then(
		function(pdf_obj) {
			// init stuff
			doc = pdf_obj;
			first_render = true;
			number_of_pages = doc.numPages;
			console.log("numberOfPages " + number_of_pages);
			
			// populate content
			doc.getOutline().then( function(ol) {
				if(!ol) return;
				
				parseOutlineNodeArray(ol, 0).then( () => console.log("setContent " + JSON.stringify(outline)), ()=> console.log("# Error 414234") );
				
			}, (reason) => console.log("# cannot fetch outline") );
			
			// render
			queueRenderPage(pageNumber);
		},
		function(reason){
			console.log("# file loading failed " + reason)
		}
	);
}
window.onresize = function() {
	if(!doc) return;

	var past_width = page_width
	page_width = window.innerWidth
	
	centerCanvas();
	
	// trigger a background rendering if resolution increase
	if(window.innerWidth > past_width)
		queueRenderPage(pageNumber);
}
