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

  var snapshot = $(this).attr("data-path")
  deleteSnapshots([snapshot])
})

// Bulk delete selected snapshots
$("#btn-bulk-delete").click(function() {
  var checkedSnapshots = []

  $("#snapshots-table tbody").find('input[type="checkbox"]:checked').each(function() {
    checkedSnapshots.push($(this).val())
  })

  deleteSnapshots(checkedSnapshots)
})
