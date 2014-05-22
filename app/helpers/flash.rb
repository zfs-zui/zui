module Flash
  module Helpers

    def render_flash()
      if flash[:error]
        error_message(flash[:error])
      elsif flash[:ok]
        success_message(flash[:ok])
      else
        ""
      end
    end

    def error_message(err)
      html = ""
      html << '<div class="bs-callout bs-callout-danger">'
      html << '<h4>An error occured</h4>'
      html << "<p>#{err}</p>"
      html << '</div>'
      return html
    end

    def success_message(text)
      html = ""
      html << '<div class="bs-callout bs-callout-success">'
      html << '<h4>Success!</h4>'
      html << "<p>#{text}</p>"
      html << '</div>'
      return html
    end

  end
end