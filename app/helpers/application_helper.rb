module ApplicationHelper
  def markdown_to_html(text)
    return "" if text.blank?
    Kramdown::Document.new(text, input: "GFM").to_html.html_safe
  end
end
