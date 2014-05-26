/*
 * _snapshots.js
 */

// Create a snapshot
$("#create-snap").click(function() {
  $button = $(this)
  $button.text("Creating...").prop("disabled", true)

  // Get the snapshot name
  var data = {
    name: $("#new-snap-form input[name='name']").val()
  }

  $.ajax({
    type: "POST",
    url: $("#new-snap-form").attr("action"),
    data: data
  })
  .fail(function(xhr) {
    $("#flash").displayErrorMsg(xhr.responseText)
    // Re-enable create button
    $button.text("Create").prop("disabled", false)
  })
  .done(function(html, status, xhr) {
    $("#main").load(window.location.href)
  })
})

/*
 * Check/uncheck all checkboxes when clicking
 * the 'master' checkbox.
 */
$("#check-all").change(function() {
  var $table= $("#snapshots-table")
  $('td input:checkbox', $table).prop("checked", this.checked)
})

$("#snapshots-table input:checkbox").change(function() {
  var nbrChecked = $("#snapshots-table tbody").find('input[type="checkbox"]:checked').length

  // Enable the delete button only if at least one checkbox is checked
  $("#btn-bulk-delete").prop("disabled", (nbrChecked == 0))

  /*
   * If the current checkbox was unchecked,
   * ensure the 'master' checkbox is also unchecked.
   */
  if (!this.checked) {
    $("#check-all").prop("checked", false)
  }
})


// Rename the clicked snapshot
$(".rename-snapshot").click(function(e) {
  e.preventDefault()

  var $nameRow = $(this).closest("tr").find("td.name")
  var $label = $nameRow.find("label")
  var $input = $nameRow.find(".edit")

  $label.hide()
  $input.val($label.text())
  $input.show().focus()
})

// Handle keys when renaming snapshot
$("td.name :text").keyup(function(e) {
  var $input = $(this)

  // Enter key
  if (e.which == 13) {
    var snapshot = $input.closest("tr").attr("data-path")
    var oldName = $input.prev("label").text()
    var newName = $input.val()

    // Abort if the name hasn't changed
    if (oldName == newName) {
      $(this).blur()
      return
    }

    // Rename snapshot
    $.ajax({
      type: "PUT",
      url: encodeURI("/snapshot/" + snapshot),
      data: { newname: newName }
    })
    .fail(function(xhr) {
      $("#flash").displayErrorMsg(xhr.responseText)
      $(this).blur()
    })
    .done(function(html, status, xhr) {
      $("#main").load(window.location.href)
    })
  }

  // Esc key
  if (e.keyCode == 27) {
    // Cancel
    $(this).blur()
  }
})

// Called when the the 'edit' field for renaming snapshots 
// loses its focus.
$("td.name :text").on("blur", function() {
  $(this).hide()
  $(this).prev("label").show()
})

// Rollback the clicked snapshot
$(".rollback-snapshot").click(function(e) {
  e.preventDefault()

  var snapshot = $(this).closest("tr").attr("data-path")
  var url = encodeURI("/snapshot/"+snapshot+"/rollback")

  $.ajax({
    type: "POST",
    url: url
  })
  .fail(function(xhr) {
    $("#flash").displayErrorMsg(xhr.responseText)
  })
  .done(function(html) {
    $("#flash").displaySuccessMsg("Snapshot '" + snapshot + "' has beed rolled back successfully!")
  })
})

// Clone modal opened
$('#clone-modal').on('show.bs.modal', function(e) {
  var $clickedTarget = $(e.relatedTarget)
  var snapshot = $clickedTarget.closest("tr").attr("data-path")

  // Set modal title to the current snapshot
  $("#clone-modal .modal-title").text("Clone '" + snapshot + "'")
  // Store the snapshot uid in the hidden input,
  // so we can retrieve it when sending the form.
  $("#clone-modal input[type='hidden']").val(snapshot)

  // Clear any previous error
  $("#clone-modal .error").html("")
})

// Clone a snapshot
$("#clone").click(function(e) {
  e.preventDefault()

  var snapshot = $("#clone-modal input[type='hidden']").val()
  var url = encodeURI("/snapshot/"+snapshot+"/clone")
  var data = {
    name: $("#clone-modal input[name='name']").val(),
    location: $("#clone-modal select[name='location']").val()
  }

  $.ajax({
    type: "POST",
    url: url,
    data: data
  })
  .fail(function(xhr) {
    $("#clone-modal .error").displayErrorMsg(xhr.responseText)
  })
  .done(function(html) {
    $('#clone-modal').modal('hide')
    // Reload the whole page to refresh the sidebar
    location.reload()
  })
})

// Delete the specified snapshots
//  snaps: Array of snapshots identifiers
var deleteSnapshots = function(snaps) {
  $.ajax({
    type: "DELETE",
    url: '/snapshot',
    data: {
      'snapshots[]': snaps
    }
  })
  .fail(function(xhr) {
    $("#flash").displayErrorMsg(xhr.responseText)
  })
  .done(function(html) {
    $("#main").load(window.location.href)
  })
}

// Delete a single snapshot
$(".delete-snapshot").click(function(e) {
  e.preventDefault()

  var snapshot = $(this).closest("tr").attr("data-path")
  deleteSnapshots([snapshot])
})

// Bulk delete selected snapshots
$("#btn-bulk-delete").click(function() {
  var checkedSnapshots = []

  $("#snapshots-table tbody").find('input[type="checkbox"]:checked').each(function() {
    var snapshot = $(this).closest("tr").attr("data-path")
    checkedSnapshots.push(snapshot)
  })

  deleteSnapshots(checkedSnapshots)
})
