#Description:
#i - ice block
#f - fire block
#0 - hole
#1-6 - block containers

levels = [
  #test level
  [
    "01i00"
    "01110"
    "01010",
    "01110",
    "000x0",
  ],
  #test level
  [
    "xx1xx",
    "x100x",
    "x10xx"
  ],
  #Morning: level 1
  [
   "x112x",
   "2000 ",
   "x000s",
   "10001"
  ]
]

###
  Coffeescript mixins/multiple inheritance @https://gist.github.com/brandonedmark/2170758
###
Object.prototype.mixin = (Klass) ->
  # assign class properties
  for key, value of Klass
    @[key] = value

  # assign instance properties
  for key, value of Klass.prototype
    @::[key] = value
  @

class ObjectHash
  getObjectHash: () ->
    try
      hashCode(Object.toJSON(this))
    catch e
      hashCode(JSON.stringify(this))




###
  Helpers stuff
###

hashCode = (string) ->
  hash = 0;
  if (string.length == 0)
    return hash
  for i in [0...string.length]
    char = string.charCodeAt(i);
    hash = ((hash<<5)-hash)+char;
    hash = hash & hash
  return hash


BLOCK_SIZE=64
BLOCK_SPEED = 16
TICK_SPEED = 100
OBJECT_TTL = 18
currentLevel = {}

canvasElements = [] #keeps all existant elements on canvas

canvas = document.getElementById('canvas')
canvas.valid = false
ctx    = canvas.getContext('2d')
activeElement = false

canvasDown = (e) ->
  x = e.pageX - canvas.offsetLeft
  y = e.pageY - canvas.offsetTop
  canvas.dragX = x
  canvas.dragY = y

  for element in canvasElements
    if (
      y > element.canvasY && y < element.canvasY + element.height &&
      x > element.canvasX && x < element.canvasX + element.width
      )
      activeElement = element

#LOL
uniqueObjectId = 0
getUniqId = ->
  uniqueObjectId += 1


moveObject = () ->


canvasUp = (e) ->
  x = e.pageX - canvas.offsetLeft
  y = e.pageY - canvas.offsetTop
  if dragGetDirection(canvas.dragX, canvas.dragY, x, y) != false

    if activeElement.blockCount > 0
      activeElement.spawnBlocks()
      for blockElem in activeElement.blockList
        blockElem.setDirection( dragGetDirection(canvas.dragX, canvas.dragY, x, y) )

dragGetDirection = (xf,yf,xt,yt) ->
  if xf == xt && yf == yt
    return false
  if xf > xt
    return 'left'
  if xf + BLOCK_SIZE < xt
    return 'right'
  if yf  < yt
    return 'down'
  if yf + BLOCK_SIZE > yt
    return 'up'

canvas.onmousedown = canvasDown
canvas.onmouseup = canvasUp

redrawCanvas = ->
  if !canvas.valid
    for element in canvasElements
      ctx.globalAlpha = 1
      if element.transparency > 0
        ctx.globalAlpha = element.transparency

      ctx.fillStyle = element.blockColor
      element.drawOnCtx(ctx, element.canvasX, element.canvasY, element.width, element.height)
      ctx.strokeStyle = "red";
      ctx.strokeRect(element.canvasX, element.canvasY, element.width, element.height);
    canvas.valid = true

class Map
  constructor: (levelMap) ->
    @blocks = []
    @listeners = {}
    @loadMap(levelMap)
    @tick()

  addListener: (obj) ->
    obj.ttl = OBJECT_TTL
    @listeners[obj.id] = obj

  removeListener: (obj) ->
    delete @listeners[obj.id]

  updateListeners: () ->
    for listenerId, listener of @listeners
      if listener.state == 'active'
        if listener.movable == false || listener.ttl < 0
          @removeListener(listener)
        else
          listener[listener['doEvent']]()
          listener.ttl -= 1
        #listener.state = false

  tick: =>
    @updateListeners()
    redrawCanvas()
    setTimeout @tick, TICK_SPEED

  loadMap: (levelMap) ->
    @cells = for y in [0...levelMap.length]
      row = levelMap[y].split(/(?:)/)

      for x in [0...row.length]
        blockCount = -1

        switch row[x]
          when 'x'
            blockType='border'
            item = new Border(blockCount, blockType)
          when 'i'
            blockType = 'ice'
            item = new IceBlock(blockCount, blockType)
          when '0'
            blockType = 'empty'
            item = new BlockHole(blockCount, blockType)
          when '1'
            blockType = 'one'
            blockCount = 1
            item = new BlockContainer(blockCount, blockType)
          when '2'
            blockType = 'two'
            blockCount = 2
            item = new BlockContainer(blockCount, blockType)
          when 's'
            blockType = 'stopper'
            item = new BlockContainer(blockCount, blockType)

        currentLevel[x]    ?= {}
        currentLevel[x][y] = row[x]
        item.setXY(x,y)

        canvasElements.push(item)


  isCellAvailableForMoveOver: (y, x)->
    if (typeof currentLevel[x] == 'object')
      if currentLevel[x][y] in ['0','i']
        return true
    return false

  updateBlockPositionOnMap: (blockObj) ->

#    console.debug('curValue ['+blockObj.x+'/'+blockObj.canvasX/BLOCK_SIZE+':'+blockObj.y+'/'+blockObj.canvasY/BLOCK_SIZE+']= ' + currentLevel[blockObj.x][blockObj.y])

    if blockObj.canvasX/BLOCK_SIZE > blockObj.x || (blockObj.canvasX/BLOCK_SIZE) <= (blockObj.x - 1)
      console.log('MATCH:' + blockObj.x + "= " + ~~(blockObj.canvasX/BLOCK_SIZE))
      blockObj.x = ~~(blockObj.canvasX/BLOCK_SIZE)


    console.log('X:' +  (blockObj.canvasX/BLOCK_SIZE) + ":" + blockObj.x)
    console.log('Y:' +  (blockObj.canvasY/BLOCK_SIZE) + ":" + blockObj.y)

    if ~~(blockObj.canvasY/BLOCK_SIZE) != blockObj.y && ~~(blockObj.canvasY/BLOCK_SIZE) > blockObj.y || ~~(blockObj.canvasY/BLOCK_SIZE) < (blockObj.y-1)
      blockObj.y = ~~(blockObj.canvasY/BLOCK_SIZE)
      console.log('MATCH Y')

    if currentLevel[blockObj.x][blockObj.y] == '0'
      console.log('stop move for ' + blockObj.id)
      blockObj.movable = false
      currentLevel[blockObj.x][blockObj.y] = '1'
      return true


class DrawableBlock
  drawOnCtx: (ctx,x,y,w,h) ->
    ctx.beginPath()
    ctx.rect(x,y,w,h)
    ctx.closePath()
    ctx.fill()

#MIXIN CLASS
class MovableBlock
  moveBlockToDirection: (direction = @direction) ->
    log = document.getElementById('log').innerText || document.getElementById('log').textContent
    document.getElementById('log').innerHTML = log + '<br>' + 'Move [' + direction + ']'
    a = @canvasX+@canvasY
    switch direction
      when 'left'
        if map.isCellAvailableForMoveOver(@y, @x-1)
          @modifyCanvasX(-BLOCK_SPEED)
      when 'right'
        if map.isCellAvailableForMoveOver(@y, @x+1)
          @modifyCanvasX(BLOCK_SPEED)
      when 'up'
        if map.isCellAvailableForMoveOver(@y-1, @x)
          @modifyCanvasY(-BLOCK_SPEED)
      when 'down'
        if map.isCellAvailableForMoveOver(@y+1, @x)
          @modifyCanvasY(BLOCK_SPEED)

    #TODO: check outbounds
    if (@canvasX+@canvasY != a)
      canvas.valid = false

    return false

  checkBlockStatus: () ->
    if @direction == false
      @state = false
      map.deleteListener(this)

  setDirection: (direction) ->
    if @direction == false && direction != false
      @direction = direction
      @state = 'active'
      @doEvent = 'moveBlockToDirection'
      map.addListener(this)

  setMoveTo: (@moveToX,@moveToY) ->
  @

class GenericBlock extends DrawableBlock
  @mixin ObjectHash
  @mixin MovableBlock

  constructor: (blockType) ->
    @id  = getUniqId()
    @blockType = blockType
    @x = 0
    @y = 0
    @canvasX = 0
    @canvasY = 0
    @movable = true
    @direction = false
    @width = BLOCK_SIZE
    @height = BLOCK_SIZE

  modifyCanvasX: (modifier) ->
    if (@nextDirectionModifier != '' )
      console.log("nextDir is #{@nextDirectionModifier}")
      if @direction == @direction_old
        modifier = @nextDirectionModifier
      else
        @nextDirectionModifier = ''

    console.log("using mod #{modifier}")
    @canvasX += modifier

    boundLeft  = @width*(  ~~(@canvasX/@width) )
    boundRight = @width*(  ~~(@canvasX/@width) + 1)

    if (@canvasX + modifier) < boundLeft
      console.log('left bound')
      @nextDirectionModifier = boundLeft - @canvasX

    if (@canvasX + modifier) > boundRight
      console.log('right bound')
      @nextDirectionModifier = boundRight - @canvasX
      
    @direction_old = @direction

    map.updateBlockPositionOnMap(this)

  modifyCanvasY: (modifier) ->

    if (@nextDirectionModifier != '' )
      console.log("nextDir is #{@nextDirectionModifier}")
      if @direction == @direction_old
        modifier = @nextDirectionModifier
      else
        @nextDirectionModifier = ''
        
    console.log("using mod #{modifier}")
    @canvasY += modifier

    boundTop  = @height*(  ~~(@canvasY/@height) )
    boundBottom = @height*(  ~~(@canvasY/@height) + 1)

    if (@canvasY + modifier) < boundTop
      console.log('top bound')
      @nextDirectionModifier = boundTop - @canvasY

    if (@canvasY + modifier) > boundBottom
      console.log('bottom bound')
      @nextDirectionModifier = boundBottom - @canvasY

    @direction_old = @direction
    
    map.updateBlockPositionOnMap(this)

  setCanvasXY: (@canvasX,@canvasY) ->

  setXY: (@x,@y) ->
    @canvasX = BLOCK_SIZE*@x
    @canvasY = BLOCK_SIZE*@y

  getBlockType: ->
    switch @blockType
      when 'green'
        return 'g'
      when 'ice'
        return 'i'
      when 'stopper'
        return 's'
      when 'border'
        return 'x'
      when 'empty'
        return '0'

class IceBlock extends GenericBlock
  constructor: () ->
    super ('ice')
    @blockColor = '#000077'
    @transparency = 0.3

class GrassBlock extends GenericBlock
  constructor: () ->
    super ('grass')
    @blockColor = '#007700'

class AbstractBlockContainer extends DrawableBlock
  constructor: ->
    @blockCount = 0
    @blockType = ''
    @x = 0
    @y = 0
    @id  = getUniqId()
    @width = BLOCK_SIZE
    @height = BLOCK_SIZE

  setCanvasXY: (@canvasX,@canvasY) ->

  setXY: (@x,@y) ->
    @canvasX = BLOCK_SIZE * @x
    @canvasY = BLOCK_SIZE * @y



class BlockContainer extends AbstractBlockContainer
  constructor:(blockCount, blockType) ->
    super
    @blockCount = blockCount
    @blockType = blockType
    @className = 'blockContainer'
    @blockList = []
    @blockColor = "#a2e2a2"

  spawnBlocks: ->
    for i in [0...@blockCount]
      console.debug(@blockType)
      block = new IceBlock()
      block.setXY(@x, @y)
      canvasElements.push(block)
      @blockList.push(block)
    @blockCount = 0

    canvas.valid = false

class BlockHole extends AbstractBlockContainer
  constructor: ->
    @className = 'blockHole'
    super
    @blockColor = "#eeeeee"

class Border extends AbstractBlockContainer
  constructor: () ->
    @className  = 'border'
    super
    @blockColor = "#000000"


level = parseInt(location.search.substr(1), 10) or 1
map = new Map(levels[level-1])

levelPicker = document.getElementById('level')
for i in [1..levels.length]
  option = document.createElement('option')
  option.value = i
  option.appendChild(document.createTextNode("Level #{i}"));
  levelPicker.appendChild(option)

levelPicker.value = level

levelPicker.addEventListener 'change', () ->
  location.search = '?' + levelPicker.value