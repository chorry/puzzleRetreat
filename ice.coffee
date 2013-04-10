#TODO: undo state
#Description:
#i - ice block
#0 - hole
#1-6 - block containers
#S - stopper container
#s - stopper block
#F - fire container
#f - fireblock

#u,d,l,r - block changes direction

levels = [
  #test level
  [
    "12ooooooo",
    "12ioioooo",
    "12ooFirdo",
    "ooio6ouoo",
    "oo1iooooo",
    "1oo11uolo",
  ],
  #test level
  [
    "xx1xx",
    "x1oox",
    "x1oxx"
  ],
  #Morning: level 1
  [
   "x112x",
   "2ooox",
   "xooo1",
   "1ooo1"
  ],
  #Morning #2
  [
    "xxS1x",
    "xdoo2",
    "xooox",
    "2ooux",
    "xx1xx",
  ]
]

undoStates = []

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

`function clone(obj) {
    // Handle the 3 simple types, and null or undefined
    if (null == obj || "object" != typeof obj) return obj;

    // Handle Date
    if (obj instanceof Date) {
        var copy = new Date();
        copy.setTime(obj.getTime());
        return copy;
    }

    // Handle Array
    if (obj instanceof Array) {
        var copy = [];
        for (var i = 0, len = obj.length; i < len; i++) {
            copy[i] = clone(obj[i]);
        }
        return copy;
    }

    // Handle Object
    if (obj instanceof Object) {
        var copy = {};
        for (var attr in obj) {
            if (obj.hasOwnProperty(attr)) copy[attr] = clone(obj[attr]);
        }
        return copy;
    }

    throw new Error("Unable to copy obj! Its type isn't supported.");
}`


hashCode = (string) ->
  hash = 0
  if (string.length == 0)
    return hash
  for i in [0...string.length]
    char = string.charCodeAt(i)
    hash = ((hash<<5)-hash)+char
    hash = hash & hash
  return hash


BLOCK_SIZE=64
BLOCK_SPEED = 16
TICK_SPEED = 100
OBJECT_TTL = 3000
currentLevel = {}

BLOCK_TYPE_BORDER = 'x'
BLOCK_TYPE_HOLE = 'o'
BLOCK_TYPE_ICE  = 'i'
BLOCK_TYPE_STOPPER = 's'
BLOCK_TYPE_FIRE = 'f'
BLOCK_TYPE_CONTAINER = 'c'
BLOCK_TYPE_CONTAINER_ICE  = 'I' #not used as descriptor on map
BLOCK_TYPE_CONTAINER_FIRE = 'F' #not used as descriptor on map
BLOCK_TYPE_CONTAINER_STOP = 'S' #not used as descriptor on map
BLOCK_TYPE_ICE_CLASSNAME = 'IceBlock'
BLOCK_TYPE_STOPPER_CLASSNAME = 'StopperBlock'
BLOCK_TYPE_FIRE_CLASSNAME = 'FireBlock'
BLOCK_TYPE_DIRECTION_UP = 'u'
BLOCK_TYPE_DIRECTION_LEFT = 'l'
BLOCK_TYPE_DIRECTION_DOWN = 'd'
BLOCK_TYPE_DIRECTION_RIGHT = 'r'

canvasElements = {} #keeps all existant elements on canvas

canvas = document.getElementById('canvas')
canvas.valid = false
ctx    = canvas.getContext('2d')
activeElement = false

canvasDown = (e) ->
  x = e.pageX - canvas.offsetLeft
  y = e.pageY - canvas.offsetTop
  canvas.dragX = x
  canvas.dragY = y

  for id, element of canvasElements
    if (typeof element is 'object')
      if (
        y > element.canvasY && y < element.canvasY + element.height &&
        x > element.canvasX && x < element.canvasX + element.width
        )
        activeElement = element

#LOL
uniqueObjectId = 0
getUniqId = ->
  uniqueObjectId += 1

canvasUp = (e) ->
  if (activeElement.blockCount == 0 &&
  activeElement.blockType == BLOCK_TYPE_CONTAINER &&
  undoStates.length > 0
  )
    lastTime = undoStates.pop()
    map.loadMap(lastTime)
    canvas.valid = false


  x = e.pageX - canvas.offsetLeft
  y = e.pageY - canvas.offsetTop
  if dragGetDirection(canvas.dragX, canvas.dragY, x, y) != false
    neighbCellCoords =  Helper.getNeighborCellByDirection(dragGetDirection(canvas.dragX, canvas.dragY, x, y) , ~~(@dragX/BLOCK_SIZE), ~~(@dragY/BLOCK_SIZE))

    if map.isCellAvailableForMoveOver(neighbCellCoords[1],neighbCellCoords[0]) &&
    activeElement.blockCount > 0
      undoStates.push( dumpMapState() )
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
    for id, element of canvasElements
      if (typeof element is 'object')
        ctx.globalAlpha = 1
        if element.transparency > 0
          ctx.globalAlpha = 1 #element.transparency

        ctx.fillStyle = element.blockColor
        if (typeof element  == 'object')
          element.drawOnCtx(ctx, element.canvasX, element.canvasY, element.width, element.height)

    canvas.valid = true

class Map
  constructor: (levelMap) ->
    #@blocks = []
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
    if @checkIfMapIsComplete()
      console.log('Congratulations!')
    setTimeout @tick, TICK_SPEED

  loadMap: (levelMap) ->
    #reset level
    canvasElements = {}
    currentLevel = {}

    @cells = for y in [0...levelMap.length]
      row = levelMap[y].split(/(?:)/)

      for x in [0...row.length]
        blockCount = -1

        switch row[x]
          when BLOCK_TYPE_ICE
            item = new IceBlock(blockCount, BLOCK_TYPE_ICE)
          when BLOCK_TYPE_HOLE
            item = new BlockHole()
          when BLOCK_TYPE_FIRE
            item = new FireBlock(blockCount, BLOCK_TYPE_FIRE)
          when BLOCK_TYPE_STOPPER
            item = new StopperBlock(blockCount, BLOCK_TYPE_STOPPER)
          when '0'
            item = new BlockContainer(0, BLOCK_TYPE_CONTAINER_ICE, BLOCK_TYPE_ICE)
          when '1'
            item = new BlockContainer(1, BLOCK_TYPE_CONTAINER_ICE, BLOCK_TYPE_ICE)
          when '2'
            item = new BlockContainer(2, BLOCK_TYPE_CONTAINER_ICE, BLOCK_TYPE_ICE)
          when '3'
            item = new BlockContainer(3, BLOCK_TYPE_CONTAINER_ICE, BLOCK_TYPE_ICE)
          when '4'
            item = new BlockContainer(4, BLOCK_TYPE_CONTAINER_ICE, BLOCK_TYPE_ICE)
          when '5'
            item = new BlockContainer(5, BLOCK_TYPE_CONTAINER_ICE, BLOCK_TYPE_ICE)
          when '6'
            item = new BlockContainer(6, BLOCK_TYPE_CONTAINER_ICE, BLOCK_TYPE_ICE)
          when BLOCK_TYPE_CONTAINER_STOP
            item = new BlockContainer(1, BLOCK_TYPE_CONTAINER_STOP, BLOCK_TYPE_STOPPER)
          when BLOCK_TYPE_CONTAINER_FIRE
            item = new BlockContainer(1, BLOCK_TYPE_CONTAINER_FIRE, BLOCK_TYPE_FIRE)
          when BLOCK_TYPE_DIRECTION_UP
            item = new DirectionBlock(BLOCK_TYPE_DIRECTION_UP)
          when BLOCK_TYPE_DIRECTION_DOWN
            item = new DirectionBlock(BLOCK_TYPE_DIRECTION_DOWN)
          when BLOCK_TYPE_DIRECTION_LEFT
            item = new DirectionBlock(BLOCK_TYPE_DIRECTION_LEFT)
          when BLOCK_TYPE_DIRECTION_RIGHT
            item = new DirectionBlock(BLOCK_TYPE_DIRECTION_RIGHT)
          else
            item = new Border(blockCount, BLOCK_TYPE_BORDER)

        currentLevel[x]    ?= {}
        item.setXY(x,y)
        currentLevel[x][y]      = item
        canvasElements[item.id] = item
    canvas.valid = false

  checkIfMapIsComplete: ->
    for k1,v1 of currentLevel
      for k2,v2 of v1
        if (v2.blockType == BLOCK_TYPE_HOLE)
          return false
    return true

  isCellAvailableForMoveOver: (y, x)->
    if (typeof currentLevel[x] == 'object')
      if currentLevel[x][y].blockType in [BLOCK_TYPE_HOLE, BLOCK_TYPE_ICE, BLOCK_TYPE_DIRECTION_DOWN, BLOCK_TYPE_DIRECTION_LEFT, BLOCK_TYPE_DIRECTION_RIGHT, BLOCK_TYPE_DIRECTION_UP ]
        return true
    return false

  updateBlockPositionOnMap: (blockObj) ->
    if blockObj.canvasX/BLOCK_SIZE > blockObj.x || (blockObj.canvasX/BLOCK_SIZE) == (blockObj.x - 1)
      blockObj.x = ~~(blockObj.canvasX/BLOCK_SIZE)


    if (blockObj.canvasY/BLOCK_SIZE) > blockObj.y || (blockObj.canvasY/BLOCK_SIZE) == (blockObj.y - 1)
      blockObj.y = ~~(blockObj.canvasY/BLOCK_SIZE)


    if blockObj.x*BLOCK_SIZE == blockObj.canvasX &&
    blockObj.y*BLOCK_SIZE == blockObj.canvasY
      switch currentLevel[blockObj.x][blockObj.y].blockType
        when BLOCK_TYPE_HOLE
          blockObj.movable = false
          currentLevel[blockObj.x][blockObj.y] = blockObj
        when BLOCK_TYPE_DIRECTION_UP
          blockObj.setDirection('up')
        when BLOCK_TYPE_DIRECTION_DOWN
          blockObj.setDirection('down')
        when BLOCK_TYPE_DIRECTION_LEFT
          blockObj.setDirection('left')
        when BLOCK_TYPE_DIRECTION_RIGHT
          blockObj.setDirection('right')
        when BLOCK_TYPE_ICE
          if blockObj.blockType is BLOCK_TYPE_FIRE
            hole = new BlockHole(BLOCK_TYPE_HOLE)
            hole.setXY(
                        canvasElements[currentLevel[blockObj.x][blockObj.y].id].x,
                        canvasElements[currentLevel[blockObj.x][blockObj.y].id].y
                      )
            canvasElements[currentLevel[blockObj.x][blockObj.y].id] = hole
    return true


class DrawableBlock
  drawOnCtx: (ctx,x,y,w,h) ->
    ctx.beginPath()
    ctx.rect(x,y,w,h)
    ctx.closePath()
    ctx.fill()

    #todo: add nice gradient
    gradient = ctx.createLinearGradient(x,y,w+x,y+h)
    gradient.addColorStop(0, ctx.fillStyle)
    gradient.addColorStop(1, ctx.fillStyle)
    ctx.shadowBlur = 1
    ctx.shadowColor = "black"
    ctx.fillStyle = gradient
    ctx.fill()

    @drawSymbol(ctx,x,y,w,h)

  drawSymbol: (ctx,x,y,w,h) ->
    switch @blockType
      when BLOCK_TYPE_ICE
        @drawIceSymbol(ctx,x,y,w,h)
      when BLOCK_TYPE_FIRE
        @drawFireSymbol(ctx,x,y,w,h)
      when BLOCK_TYPE_DIRECTION_DOWN
        @drawDownSymbol(ctx,x,y,w,h)
      when BLOCK_TYPE_DIRECTION_LEFT
        @drawLeftSymbol(ctx,x,y,w,h)
      when BLOCK_TYPE_DIRECTION_RIGHT
        @drawRightSymbol(ctx,x,y,w,h)
      when BLOCK_TYPE_DIRECTION_UP
        @drawUpSymbol(ctx,x,y,w,h)
      when BLOCK_TYPE_CONTAINER
        @drawContainerSymbol(ctx,x,y,w,h)

  drawContainerSymbol: (ctx,x,y,w,h) ->
    if (@blockCount > 0)
      ctx.fillStyle = "black"
      ctx.font = "bold 16px Arial"
      ctx.fillText(@blockCount + ":" + @blockChildType, x+w/10, y+h/2)
    else
      @drawUndoSymbol(ctx,x,y,w,h)

  drawUndoSymbol: (ctx,x,y,w,h) ->
    ctx.fillStyle = "black"
    ctx.font = "bold 16px Arial"
    ctx.fillText("UNDO",x+w/10, y+h/2)
    return

  drawIceSymbol: (ctx,x,y,w,h) ->
    offset = ~~(w/10)
    ctx.beginPath()
    ctx.moveTo(x+w/2,y+offset) #top
    ctx.lineTo(x+w-offset*2,y+h/2) #right
    ctx.lineTo(x+w/2,y+h-offset) #bottom
    ctx.lineTo(x+offset*2,y+h/2) #left
    ctx.closePath()
    ctx.shadowBlur = 0
    gradient = ctx.createLinearGradient(x,y,w+x,y+h)
    gradient.addColorStop(0, "#FFFFFF")
    gradient.addColorStop(1, "#9fbae0")
    ctx.fillStyle = gradient
    ctx.fill()

  drawFireSymbol: (ctx,x,y,w,h) ->
    offset = ~~(w/10)
    ctx.beginPath()
    ctx.moveTo(x+w/2,y+offset) #top
    ctx.lineTo(x+w-offset*2,y+h/2) #right
    ctx.lineTo(x+w/2,y+h-offset) #bottom
    ctx.lineTo(x+offset*2,y+h/2) #left
    ctx.closePath()
    gradient = ctx.createLinearGradient(x,y,w+x,y+h)
    gradient.addColorStop(0, "#FF3333")
    gradient.addColorStop(1, "#9f3333")
    ctx.fillStyle = gradient
    ctx.fill()
  drawUpSymbol: (ctx,x,y,w,h) ->
    offset = ~~(w/10)
    ctx.beginPath()
    ctx.moveTo(x+w/2,y+offset)
    ctx.lineTo(x+w-offset,y+h-offset)
    ctx.lineTo(x+offset,y+h-offset)
    ctx.closePath()
    gradient = ctx.createLinearGradient(x,y,w+x,y+h)
    gradient.addColorStop(0, "#fff")
    gradient.addColorStop(1, "#ccc")
    ctx.fillStyle = gradient
    ctx.fill()
  drawDownSymbol: (ctx,x,y,w,h) ->
    offset = ~~(w/10)
    ctx.beginPath()
    ctx.moveTo(x+offset,y+offset)
    ctx.lineTo(x+w-offset,y+offset)
    ctx.lineTo(x+w/2,y+h-offset) #bottom
    ctx.closePath()
    gradient = ctx.createLinearGradient(x,y,w+x,y+h)
    gradient.addColorStop(0, "#FF3333")
    gradient.addColorStop(1, "#9f3333")
    ctx.fillStyle = gradient
    ctx.fill()
  drawLeftSymbol: (ctx,x,y,w,h) ->
    offset = ~~(w/10)
    ctx.beginPath()
    ctx.moveTo(x+offset,y+h/2)
    ctx.lineTo(x+w-offset,y+offset)
    ctx.lineTo(x+w-offset,y+h-offset)
    ctx.closePath()
    gradient = ctx.createLinearGradient(x,y,w+x,y+h)
    gradient.addColorStop(0, "#FF3333")
    gradient.addColorStop(1, "#9f3333")
    ctx.fillStyle = gradient
    ctx.fill()
  drawRightSymbol: (ctx,x,y,w,h) ->
    offset = ~~(w/10)
    ctx.beginPath()
    ctx.moveTo(x+offset,y+offset)
    ctx.lineTo(x+w-offset,y+h/2)
    ctx.lineTo(x+offset,y+h-offset)
    ctx.closePath()
    gradient = ctx.createLinearGradient(x,y,w+x,y+h)
    gradient.addColorStop(0, "#FF3333")
    gradient.addColorStop(1, "#9f3333")
    ctx.fillStyle = gradient
    ctx.fill()

#MIXIN CLASS
class MovableBlock
  enableBlock: () ->
    @state = 'active'
    @doEvent = 'moveBlock'
    map.addListener(this)

  setDirection: (@direction) ->
    @direction = direction
    if @state != 'active'
      @enableBlock()

  getDirection: ->
    @direction

  updateBlockPosition: ->
    return

  moveBlock: ->
    a = @canvasX+@canvasY
    switch @direction
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
      else
        throw {message:'no direction were set'}

    #TODO: check outbounds
    if (@canvasX+@canvasY != a)
      canvas.valid = false
    return false

  checkBlockStatus: () ->
    if @direction is false
      @state = false
      map.deleteListener(this)


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

    #get direction, L or R
    moveDirection = if modifier < 0 then -1 else 1

    if (@nextDirectionModifier != '' )
      if @direction == @direction_old && currentLevel[@x+moveDirection][@y].blockType == BLOCK_TYPE_HOLE
        modifier = @nextDirectionModifier
        @nextDirectionModifier = ''
      else
        @nextDirectionModifier = ''

    @canvasX += modifier

    boundLeft  = @width*(  ~~(@canvasX/@width) )
    boundRight = @width*(  ~~(@canvasX/@width) + 1)

    if (@canvasX + modifier) < boundLeft && currentLevel[@x+moveDirection][@y].blockType == BLOCK_TYPE_HOLE
      @nextDirectionModifier = boundLeft - @canvasX

    if (@canvasX + modifier) >= boundRight && currentLevel[@x+moveDirection][@y].blockType == BLOCK_TYPE_HOLE
      @nextDirectionModifier = boundRight - @canvasX
      
    @direction_old = @direction

    map.updateBlockPositionOnMap(this)

  modifyCanvasY: (modifier) ->
    moveDirection = if modifier < 0 then -1 else 1
    if (@nextDirectionModifier != '' )
      if @direction == @direction_old
        modifier = @nextDirectionModifier
        @nextDirectionModifier = ''
      else
        @nextDirectionModifier = ''
        
    @canvasY += modifier

    boundTop    = @height*(  ~~(@canvasY/@height) )
    boundBottom = @height*(  ~~(@canvasY/@height) + 1)

    if (@canvasY + modifier) < boundTop && currentLevel[@x][@y+moveDirection] in [BLOCK_TYPE_HOLE, BLOCK_TYPE_DIRECTION_UP, BLOCK_TYPE_DIRECTION_DOWN, BLOCK_TYPE_DIRECTION_LEFT, BLOCK_TYPE_DIRECTION_RIGHT]
      @nextDirectionModifier = boundTop - @canvasY

    if (@canvasY + modifier) > boundBottom && currentLevel[@x][@y+moveDirection] in [BLOCK_TYPE_HOLE, BLOCK_TYPE_DIRECTION_UP, BLOCK_TYPE_DIRECTION_DOWN, BLOCK_TYPE_DIRECTION_LEFT, BLOCK_TYPE_DIRECTION_RIGHT]
      @nextDirectionModifier = boundBottom - @canvasY

    @direction_old = @direction
    
    map.updateBlockPositionOnMap(this)

  setCanvasXY: (@canvasX,@canvasY) ->

  setXY: (@x,@y) ->
    @canvasX = BLOCK_SIZE*@x
    @canvasY = BLOCK_SIZE*@y

class DirectionBlock extends GenericBlock
  constructor: (type) ->
    super (type)
    @blockColor = '#335577'
    @transparency = 0.3

class IceBlock extends GenericBlock
  constructor: () ->
    super (BLOCK_TYPE_ICE)
    @blockColor = '#000077'
    @transparency = 0.3

class FireBlock extends GenericBlock
  constructor: () ->
    super (BLOCK_TYPE_FIRE)
    @blockColor = '#FF1111'
    @transparency = 0.3

class StopperBlock extends GenericBlock
  constructor: () ->
    super (BLOCK_TYPE_STOPPER)
    @blockColor = '#115090'

class AbstractBlockContainer extends DrawableBlock
  blockType = ''
  blockCount = 0
  constructor: ->
    #@blockCount = 0
    #@blockType = ''
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
  constructor:(blockCount, @blockContainerType, @blockChildType) ->
    super
    @blockCount = blockCount
    @blockType = BLOCK_TYPE_CONTAINER #blockType
    @blockChildTypeClass = Helper.getBlockClassName(blockChildType)
    @blockList = []
    @blockColor = "#FFF"

  spawnBlocks: ->
    for i in [0...@blockCount]
      block = eval("new #{@blockChildTypeClass}()")
      block.setXY(@x, @y)
      canvasElements[block.id] = block
      @blockList.push(block)
    @blockCount = 0

    canvas.valid = false

class BlockHole extends AbstractBlockContainer
  constructor: () ->
    super
    @blockType = BLOCK_TYPE_HOLE
    @blockColor = "#eeeeee"

class Border extends AbstractBlockContainer
  constructor: () ->
    @className  = 'border'
    super
    @blockType = BLOCK_TYPE_BORDER
    @blockColor = "#000000"



class Helper
  constructor: ->

  @getNeighborCellByDirection: (direction, x, y)->
    switch direction
      when 'left'
        return [x-1,y]
      when 'right'
        return [x+1,y]
      when 'up'
        return [x,y-1]
      when 'down'
        return [x,y+1]
      else
        throw {message:'lolwut?'}

  @getBlockClassName: (className) ->
    switch className
      when BLOCK_TYPE_FIRE
        return BLOCK_TYPE_FIRE_CLASSNAME
      when BLOCK_TYPE_STOPPER
        return BLOCK_TYPE_STOPPER_CLASSNAME
      when BLOCK_TYPE_ICE
        return BLOCK_TYPE_ICE_CLASSNAME


level = parseInt(location.search.substr(1), 10) or 1
map = new Map(levels[level-1])

levelPicker = document.getElementById('level')
for i in [1..levels.length]
  option = document.createElement('option')
  option.value = i
  option.appendChild(document.createTextNode("Level #{i}"))
  levelPicker.appendChild(option)

levelPicker.value = level

levelPicker.addEventListener 'change', () ->
  location.search = '?' + levelPicker.value

mapState = []
document.getElementById('reset').addEventListener 'click', () ->
  mapState = dumpMapState()

document.getElementById('debug').addEventListener 'click', () ->
  map.loadMap( mapState )




dumpMapState = () ->
  mapState = []
  for k,v1 of currentLevel
    if typeof v1 == 'object'
      tmp = ''
      for j,v2 of v1
        if typeof v2 == 'object'
          mapState[j] ?= ''
          switch v2.blockType
            when BLOCK_TYPE_CONTAINER
              if v2.blockContainerType == BLOCK_TYPE_CONTAINER_ICE
                mapState[j] += v2.blockCount
              else if v2.blockCount > 0 && v2.blockChildType
                mapState[j] += v2.blockContainerType
              else
                mapState[j] += v2.blockContainerType
            else
              mapState[j] += v2.blockType
  return mapState