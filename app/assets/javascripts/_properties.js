/* _properties.js */

$(document).ready(function() {

  // Show the "Apply" button when a switch is clicked
  $(".switch.property").change(function() {
    $(".properties .apply-btn").show()
  })

  // Set the changed properties when the button is clicked
  $(".properties .apply-btn").click(function() {
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

    // FIXME: better error handling
    $.ajax({
      type: "PUT",
      url: window.location.href,
      data: data
    })
      .done(function(html) {
        $("#main").html(html)
      })
  })

})