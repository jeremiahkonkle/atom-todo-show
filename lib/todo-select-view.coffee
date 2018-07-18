fs = require 'fs-plus'
path = require 'path'
SelectListView = require 'atom-select-list'

module.exports =
class TodoSelectView
  constructor: (collection) ->
    @collection = collection

    @selectListView = new SelectListView({
      emptyMessage: 'No todos found.',
      items: [],
      filterKeyForItem: (todo) -> todo.type + ' ' + todo.text,
      elementForItem: (todo) ->
        element = document.createElement 'li'
        element.className = 'two-lines'
        element.innerHTML = "
          <div class='primary-line'>#{todo.type} #{todo.text}</div>
          <div class='secondary-line path'>#{todo.path} (#{todo.line})</div>
        "
        element
      didChangeSelection: (todo) =>
        console.log('didChangeSelection')
        @open(todo, {activate: false})
      didConfirmSelection: (todo) =>
        console.log('didConfirmSelection')
        @cancel()
        @open(todo, {activate: true})
      didCancelSelection: () =>
        console.log('didCancelSelection')
        @cancel()
    })

    @selectListView.element.classList.add('todo-select')
    
    @collection.onDidFinishSearch =>
      @collection.sortTodos()
      @selectListView.update({
        items: @collection.getFilteredTodos(),
        loadingMessage: undefined
      })

  dispose: ->
    throw 'foo'
    @cancel()
    @selectListView.destroy()

  cancel: ->
    if (@initialState)
      @deserializeEditorState(@initialState)
      @initialState = null
    if @panel?
      @panel.destroy()
      @panel = null
    if @previouslyFocusedElement
      @previouslyFocusedElement.focus()
      @previouslyFocusedElement = null
      

  attach: ->
    @previouslyFocusedElement = document.activeElement
    @initialState = @serializeEditorState()
    if not @panel?
      @panel = atom.workspace.addModalPanel({item: @selectListView})
    @selectListView.focus()
    @selectListView.reset()

  toggle: ->
    if @panel?
      @cancel()
    else
      @selectListView.update({loadingMessage: 'Updating...'})
      @collection.search(true)
      @attach()

  open: (todo, {activate=false}) ->
    return unless todo and todo.loc
    
    position = [todo.position[0][0], todo.position[0][1]]
    console.log('opening', todo.loc)
    atom.workspace.open(todo.loc, {activatePane: activate})
      .then ->
        console.log('opened', position)
        if textEditor = atom.workspace.getActiveTextEditor()
          textEditor.setCursorBufferPosition(position, autoscroll: false)
          textEditor.scrollToCursorPosition(center: true)
  
  serializeEditorState: () ->
    editor = atom.workspace.getActiveTextEditor()
    editorElement = atom.views.getView(editor)
    scrollTop = editorElement.getScrollTop()
    activePath = editor?.buffer.file?.path
    if activePath
      [projectPath, activePath] = atom.project.relativizePath(activePath)
    console.log('serializeEditorState', activePath, editor.getSelectedBufferRanges(), scrollTop)
    {
      path: activePath,
      bufferRanges: editor.getSelectedBufferRanges(),
      scrollTop,
    }

  deserializeEditorState: ({path, bufferRanges, scrollTop}) ->
    console.log('deserializeEditorState', path, bufferRanges, scrollTop)
    atom.workspace.open(path)
      .then ->
        if editor = atom.workspace.getActiveTextEditor()
          editorElement = atom.views.getView(editor)
          editor.setSelectedBufferRanges(bufferRanges)
          editorElement.setScrollTop(scrollTop)
