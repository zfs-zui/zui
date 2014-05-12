/* application.js
 *
 *= require jquery
 *= require pace
 *= require bootstrap/transition
 *= require bootstrap/dropdown
 *= require bootstrap/modal
 */

/*
 * jQuery function
 * Check if the specified element is visible
 * in the window's viewport.
 */
$.fn.onScreen = function() {
    var win = $(window);
    var viewport = {
        top : win.scrollTop(),
        left : win.scrollLeft()
    };

    viewport.right = viewport.left + win.width();
    viewport.bottom = viewport.top + win.height();
 
    var bounds = this.offset();
    bounds.right = bounds.left + this.outerWidth();
    bounds.bottom = bounds.top + this.outerHeight();
 
    return (!(viewport.right < bounds.left || 
    	viewport.left > bounds.right || 
    	viewport.bottom < bounds.top || 
    	viewport.top > bounds.bottom));
};

$(document).ready(function() {
	// Scroll to the active sidebar item
	var $selectedItem = $(".sidebar .item.active")
	if ($selectedItem.length && !$selectedItem.onScreen()) {
		$(".sidebar .list").animate({ 
			scrollTop: $selectedItem.position().top 
		}, 1000) // 1s duration
	}

	// Sidebar search
	$('#search').keyup(function() {
	   var search = $(this).val()

		$('.sidebar .list > .item').each(function() {
			var $item = $(this)
			var text = $item.text().toLowerCase()

			// Search only folders, not pools
			if ($item.hasClass("filesystem")) {
				(text.indexOf(search) != -1) ? $item.show() : $item.hide()
			}
		})
	})

}) /* end document ready */

// Sidebar selection handling
$(document).on("click", ".sidebar .list .item", function() {
	var $item = $(this)
	var url = $item.attr("href")

	// Select the item only if it wasn't already selected
	if (!$item.hasClass("active")) {
		// Deselect all selected items
		$(".sidebar .list .item.active").removeClass("active")
		// And select the clicked one
		$item.addClass("active")

		// Update the browser url
		history.replaceState(null, '', url)

		// Load target url via ajax
		$("#main").load(url, function(response, status, xhr) {
			if (status == "error") {
				var msg = "An unknown error occured."
				$("#main").html("<h2 class='error'>" + msg + "</h2>")
			}
		})
	}
	
	return false
})