/*
 * _pools.js
 */

// Enable the destroy button only when the pool's name matches
$(document).on("keyup", "#destroy-modal #pool-name", function() {
    var value = $(this).val()
    var expected = $(this).attr("data-pool-name")
    
    if (value == expected) {
      $("#destroy").prop("disabled", false)
    } else {
      $("#destroy").prop("disabled", true)
    }
})

// Called when the destroy modal is closed
$(document).on("hidden.bs.modal", "#destroy-modal", function(e) {
  // Convert the jQuery element to a JS object to use the reset function
  $(this).find("#destroy-form")[0].reset()
  // Disable destroy button
  $("#destroy").prop("disabled", true)
})
