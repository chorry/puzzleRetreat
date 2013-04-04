#TODO: undo state. better opacity
#Description:
#i - ice block
#f - fire block
#0 - hole
#1-6 - block containers
#u,d,l,r - block changes direction

levels = [
  #test level
  [
    "120000000"
    "12i0i0000"
    "1200fird0"
    "00i060u00",
    "001i00000",
    "10011u0l0",
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
   "2000x",
   "x0001",
   "10001"
  ],
  #Morning #2
  [
    "xxs1x",
    "xd002",
    "x000x",
    "200ux",
    "xx1xx",
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
OBJECT_TTL = 3000
currentLevel = {}

BLOCK_TYPE_HOLE = '0'
BLOCK_TYPE_ICE  = 'i'
BLOCK_TYPE_STOPPER = 's'
BLOCK_TYPE_FIRE = 'f'
BLOCK_TYPE_CONTAINER = 'c' #not used as descriptor on map
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


moveObject = () ->


canvasUp = (e) ->
  x = e.pageX - canvas.offsetLeft
  y = e.pageY - canvas.offsetTop
  if dragGetDirection(canvas.dragX, canvas.dragY, x, y) != false
    neighbCellCoords =  Helper.getNeighborCellByDirection(dragGetDirection(canvas.dragX, canvas.dragY, x, y) , ~~(@dragX/BLOCK_SIZE), ~~(@dragY/BLOCK_SIZE))

    if map.isCellAvailableForMoveOver(neighbCellCoords[1],neighbCellCoords[0]) &&
    activeElement.blockCount > 0
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
        element.drawOnCtx(ctx, element.canvasX, element.canvasY, element.width, element.height)
        ctx.strokeStyle = "red";
        ctx.strokeRect(element.canvasX, element.canvasY, element.width, element.height);
        #debug - draw block ids
        if element.blockType in [ BLOCK_TYPE_ICE, BLOCK_TYPE_CONTAINER]
          ctx.fillStyle = "black"
          ctx.font = "bold 16px Arial";
          ctx.fillText(element.x + ":" + element.y, element.canvasX + 20, element.canvasY + 30);
          ctx.fillText(element.id+":"+element.blockType, element.canvasX + 5, element.canvasY + 50);
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
    if @checkIfMapIsComplete()
      alert('Congratulations!')
    redrawCanvas()
    setTimeout @tick, TICK_SPEED

  loadMap: (levelMap) ->
    @cells = for y in [0...levelMap.length]
      row = levelMap[y].split(/(?:)/)

      for x in [0...row.length]
        blockCount = -1

        switch row[x]
          when 'i'
            item = new IceBlock(blockCount, BLOCK_TYPE_ICE)
          when BLOCK_TYPE_HOLE
            item = new BlockHole()
          when '1'
            item = new BlockContainer(1, BLOCK_TYPE_ICE)
          when '2'
            item = new BlockContainer(2, BLOCK_TYPE_ICE)
          when '3'
            item = new BlockContainer(3, BLOCK_TYPE_ICE)
          when '4'
            item = new BlockContainer(4, BLOCK_TYPE_ICE)
          when '5'
            item = new BlockContainer(5, BLOCK_TYPE_ICE)
          when '6'
            item = new BlockContainer(6, BLOCK_TYPE_ICE)
          when 's'
            item = new BlockContainer(1, BLOCK_TYPE_STOPPER)
          when 'f'
            item = new BlockContainer(1, BLOCK_TYPE_FIRE)
          when 'u'
            item = new DirectionBlock(BLOCK_TYPE_DIRECTION_UP)
          when 'd'
            item = new DirectionBlock(BLOCK_TYPE_DIRECTION_DOWN)
          when 'l'
            item = new DirectionBlock(BLOCK_TYPE_DIRECTION_LEFT)
          when 'r'
            item = new DirectionBlock(BLOCK_TYPE_DIRECTION_RIGHT)
          else
            blockType='border'
            item = new Border(blockCount, blockType)

        currentLevel[x]    ?= {}
        item.setXY(x,y)
        currentLevel[x][y]      = item
        canvasElements[item.id] = item

  checkIfMapIsComplete: ->
    return false
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
            console.log('FIRE OVER ICE')
            console.debug("1" , currentLevel[blockObj.x][blockObj.y].id)
            #currentLevel[blockObj.x][blockObj.y] = "0"
            hole = new BlockHole(BLOCK_TYPE_HOLE)
            hole.setXY(
                        canvasElements[currentLevel[blockObj.x][blockObj.y].id].x,
                        canvasElements[currentLevel[blockObj.x][blockObj.y].id].y
                      )
            canvasElements[currentLevel[blockObj.x][blockObj.y].id] = hole
            #console.debug("2", canvasElements[currentLevel[blockObj.x][blockObj.y].id] )
            #canvasElements[blockObj.x][blockObj.y] = new BlockHole(BLOCK_TYPE_HOLE)
    return true


class DrawableBlock
  drawOnCtx: (ctx,x,y,w,h) ->
    ctx.beginPath()
    ctx.rect(x,y,w,h)
    ctx.closePath()
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

#class for handling resourse stuff (gfx/snd?)
class Resource
  resFile = 'icons_2727347B.jpg'
  resData = ''

  constructor: (ctx) ->
    @ctx = ctx
    resData = new Image()
    resData.src = resFile

  drawResource: (resourceId, ctx) ->
    sourceX = sourceY = 0
    tileWidth = tileHeight = 64
    console.debug()
    ctx.drawImage(
                   resData,
                   sourceX+tileWidth*resourceId, sourceY,
                   tileWidth, tileHeight,
                   canvasElements[resourceId].canvasX, canvasElements[resourceId].canvasY,
                   tileWidth, tileHeight
                 )



class BlockContainer extends AbstractBlockContainer
  constructor:(blockCount, blockChildType) ->
    super
    @blockCount = blockCount
    @blockType = BLOCK_TYPE_CONTAINER #blockType
    @blockChildType = Helper.getBlockClassName(blockChildType)
    @blockList = []
    @blockColor = "#FFF"

  spawnBlocks: ->
    for i in [0...@blockCount]
      block = eval("new #{@blockChildType}()")
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

Resource = new Resource(ctx)

levelPicker = document.getElementById('level')
for i in [1..levels.length]
  option = document.createElement('option')
  option.value = i
  option.appendChild(document.createTextNode("Level #{i}"));
  levelPicker.appendChild(option)

levelPicker.value = level

levelPicker.addEventListener 'change', () ->
  location.search = '?' + levelPicker.value

document.getElementById('debug').addEventListener 'click', () ->
  Resource.drawResource(4, ctx)
  #canvas.valid = false