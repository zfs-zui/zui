/* application.js
 *
 *= require jquery
 */

// Sidebar search
$(document).ready(function() {
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
})

// Sidebar selection handling
$(document).on("click", ".sidebar .list .item", function() {
	var $item = $(this)

	// Select the item only if it wasn't already selected
	if (!$item.hasClass("active")) {
		// Deselect all selected items
		$(".sidebar .list .item.active").removeClass("active")
		// And select the clicked one
		$item.addClass("active")
	}
	
	return false
})