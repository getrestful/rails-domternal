# frozen_string_literal: true

require "test_helper"

class PlainTextTest < ActiveSupport::TestCase
  def plain(html)
    Domternal::RichText.new(body: html).to_plain_text
  end

  def test_blank_body
    assert_equal "", plain(nil)
    assert_equal "", plain("")
  end

  def test_paragraphs_are_separated_by_newlines
    assert_equal "One\n\nTwo", plain("<p>One</p><p>Two</p>")
  end

  def test_line_oriented_content_keeps_one_item_per_line
    html = "<p>[x] Correct answer</p><p>[-] Wrong answer</p>"
    assert_equal ["[x] Correct answer", "[-] Wrong answer"], plain(html).lines.map(&:strip).reject(&:empty?)
  end

  def test_br_becomes_a_newline
    assert_equal "One\nTwo", plain("<p>One<br>Two</p>")
  end

  def test_list_items_are_separate_lines
    assert_equal "First\nSecond", plain("<ul><li>First</li><li>Second</li></ul>")
  end

  def test_inline_markup_does_not_introduce_breaks
    assert_equal "Hello World!", plain("<p>Hello <strong>World</strong>!</p>")
  end

  def test_headings_separate_from_body_text
    assert_equal "Title\n\nBody", plain("<h2>Title</h2><p>Body</p>")
  end

  def test_table_cells_are_space_separated_and_rows_newline_separated
    html = "<table><tbody><tr><td>A</td><td>B</td></tr><tr><td>C</td><td>D</td></tr></tbody></table>"
    assert_equal "A B\nC D", plain(html)
  end

  def test_entities_are_decoded
    assert_equal "a & b", plain("<p>a &amp; b</p>")
  end

  def test_horizontal_whitespace_is_collapsed
    assert_equal "a b", plain("<p>a    b</p>")
  end

  # ActionText keeps text-node newlines, and content authored as plain lines (one quiz answer
  # or list entry per line, no markup) relies on them.
  def test_newlines_in_tagless_content_are_preserved
    assert_equal "[x] Correct\n[-] Wrong", plain("[x] Correct\n[-] Wrong")
  end

  def test_newlines_inside_a_block_are_preserved
    assert_equal "a\nb", plain("<p>a    \n   b</p>")
  end

  def test_blank_predicate_uses_plain_text
    assert Domternal::RichText.new(body: "<p></p>").blank?
    refute Domternal::RichText.new(body: "<p>x</p>").blank?
  end
end
