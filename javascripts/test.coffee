@Elems =
  tidy: (text) ->
    elems = $('span').filter ->
      $(this).text().toLowerCase() == text.toLowerCase()
    elems.each -> $(this).replaceWith($(this).html())

@Word =
  forget: (text) ->
    $.get "/forget/#{text}", (data) -> eval(data)

TranslateForm =
  init: (form_id) ->
    $(form_id).submit ->
      valuesToSubmit = $(this).serialize()
      url = $(this).attr('action')
      $.post url, valuesToSubmit, (data) ->
        eval(data)
      false


@WordsApp =
  highlightWords: (type) ->
    $.get "/words/#{type}", (data) ->
      words = JSON.parse(data)
      $("body").highlight(words, className: type, wordsOnly: true) 

  bindMenus: ->
    $.contextMenu
      selector: '.known, .translated'
      items:
        "forget":
          name: "Forget"
          icon: "delete"
      callback: (key, options) ->
        return if not key == 'forget'
        text = options.$trigger.text()
        Elems.tidy(text)
        Word.forget(text)

  initialize: ->
    WordsApp.highlightWords('known')
    WordsApp.highlightWords('unknown')
    WordsApp.bindMenus()
    TranslateForm.init '#translate_form'

$ -> WordsApp.initialize()

