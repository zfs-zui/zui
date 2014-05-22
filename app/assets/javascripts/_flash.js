/* _flash.js */

/*
 * jQuery function
 * Display an error message.
 */
$.fn.displayErrorMsg = function(text) {
  var html = '<div class="bs-callout bs-callout-danger">'
  html += '<h4>An error occured</h4>'
  html += '<p>' + text +'</p></div>'
  
  this.html(html)
}

/*
 * jQuery function
 * Display a success message.
 */
$.fn.displaySuccessMsg = function(text) {
  var html = '<div class="bs-callout bs-callout-success">'
  html += '<h4>Success!</h4>'
  html += '<p>' + text +'</p></div>'
  
  this.html(html)
}
