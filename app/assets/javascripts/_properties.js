/* _properties.js */

// Show the "Apply" button when a switch is clicked
$(document).on("change", ".switch.property", function() {
  $(".properties .apply-btn").show()
})

// Apply the changed properties
$(document).on("click", ".properties .apply-btn", function() {
  var $button = $(this)
  $button.prop('disabled', true)
  $button.text("Applying...")

  // Available properties
  var properties = [
    "compression", 
    "deduplication", 
    "readonly"
  ]

  // Get the changed properties
  var data = {}
  $.each(properties, function(index, value) {
    $switch = $("input[name='"+ value +"']")
    if ($switch.prop("checked") !=  $switch[0].hasAttribute("data-checked")) {
      data[value] = ($switch.prop("checked") ? 1 : 0)
    }
  })

  // FIXME: handle errors
  $.ajax({
    type: "PUT",
    url: window.location.href,
    data: data
  }).done(function(html) {
    $("#main").html(html)
  })
})
