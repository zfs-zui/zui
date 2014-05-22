$("#create-snap").click(function() {
  $button = $(this)
  $button.prop("disabled", true)
  $button.text("Creating...")

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
    .done(function(html) {
      $("#main").html(html)
    })
})