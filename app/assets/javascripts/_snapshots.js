$("#create-snap").click(function() {
  $button = $(this)
  $button.text("Creating...").prop("disabled", true)

  // Get the snapshot name
  var data = {
    name: $("#new-snap-form input[name='name']").val()
  }

  // FIXME: better error handling
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
  $("#btn-delete").prop("disabled", (nbrChecked == 0))

  /*
   * If the current checkbox was unchecked,
   * ensure the 'master' checkbox is also unchecked.
   */
  if (!this.checked) {
    $("#check-all").prop("checked", false)
  }
})

// Delete a snapshot
$(".delete-snapshot").click(function(e) {
  //Pace.restart()
  e.preventDefault()
  var url = encodeURI($(this).attr("href"))

  // FIXME: better error handling
  $.ajax({
    type: "DELETE",
    url: url
  })
  .fail(function(xhr) {
    $("#flash").displayErrorMsg(xhr.responseText)
  })
  .done(function(html) {
    $("#main").load(window.location.href)
  })
})