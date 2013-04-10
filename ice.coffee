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
BLOCK_TYPE_CONTAINER_ICE  = 'I'
BLOCK_TYPE_CONTAINER_FIRE = 'F'
BLOCK_TYPE_CONTAINER_STOP = 'S' #not used as descriptor on map
BLOCK_TYPE_CONTAINER_FIRE_EMPTY = 'Ꝼ' #not used as descriptor on map
BLOCK_TYPE_CONTAINER_STOP_EMPTY = 'Ś' #not used as descriptor on map
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
    console.debug("Restoring ", lastTime)
    map.loadMap(lastTime)
    canvas.valid = false


  x = e.pageX - canvas.offsetLeft
  y = e.pageY - canvas.offsetTop
  if dragGetDirection(canvas.dragX, canvas.dragY, x, y) != false
    neighbCellCoords =  Helper.getNeighborCellByDirection(dragGetDirection(canvas.dragX, canvas.dragY, x, y) , ~~(@dragX/BLOCK_SIZE), ~~(@dragY/BLOCK_SIZE))

    if map.isCellAvailableForMoveOver(neighbCellCoords[1],neighbCellCoords[0]) &&
    activeElement.blockCount > 0
      a = dumpMapState()
      undoStates.push( a )
      console.debug("Memorized:", a)
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
    console.debug("Loading: ", levelMap)
    console.debug("Cur/Canv: " , currentLevel, canvasElements)

    @cells = for y in [0...levelMap.length]
      row = levelMap[y].split(/(?:)/)

      for x in [0...row.length]
        blockCount = -1

        switch row[x]
          when BLOCK_TYPE_ICE
            console.log(BLOCK_TYPE_ICE + " for #{x+1}:#{y+1} ")
            item = new IceBlock(blockCount, BLOCK_TYPE_ICE)
          when BLOCK_TYPE_HOLE
            item = new BlockHole()
          when BLOCK_TYPE_FIRE
            item = new FireBlock(blockCount, BLOCK_TYPE_FIRE)
          when BLOCK_TYPE_STOPPER
            item = new StopperBlock(blockCount, BLOCK_TYPE_STOPPER)
          when '0'
            console.log(BLOCK_TYPE_CONTAINER_ICE + " 0 for #{x+1}:#{y+1} ")
            item = new BlockContainer(0, BLOCK_TYPE_CONTAINER_ICE, BLOCK_TYPE_ICE)
          when '1'
            console.log(BLOCK_TYPE_CONTAINER_ICE + " 1 for #{x+1}:#{y+1} ")
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
          when BLOCK_TYPE_CONTAINER_STOP_EMPTY
            item = new BlockContainer(0, BLOCK_TYPE_CONTAINER_STOP, BLOCK_TYPE_STOPPER)
          when BLOCK_TYPE_CONTAINER_FIRE
            item = new BlockContainer(1, BLOCK_TYPE_CONTAINER_FIRE, BLOCK_TYPE_FIRE)
          when BLOCK_TYPE_CONTAINER_FIRE_EMPTY
            item = new BlockContainer(0, BLOCK_TYPE_CONTAINER_FIRE, BLOCK_TYPE_FIRE)
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
    if currentLevel[2][1].blockType == BLOCK_TYPE_ICE
      console.log('ICE!')
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
    ctx.save()
    ctx.fillStyle = "#ff0000"
    ctx.beginPath()
    ctx.moveTo(292.0733337402344,172)
    ctx.lineTo(312.53582763671875,204.35079956054688)
    ctx.bezierCurveTo(351.8642578125,267.0616455078125,363.6740417480469,313.51263427734375,363.04449462890625,402.94232177734375)
    ctx.bezierCurveTo(362.5291748046875,476.1221008300781,359.14666748046875,494.9073181152344,335.0704345703125,560.2098083496094)
    ctx.bezierCurveTo(310.66961669921875,626.3924865722656,308.1097717285156,641.0450134277344,311.4997253417969,696.2249450683594)
    ctx.lineTo(315.1260070800781,758.0929260253906)
    ctx.lineTo(298.5487976074219,724.0892028808594)
    ctx.bezierCurveTo(279.62249755859375,685.7153625488281,277.7745056152344,644.1753234863281,288.7060852050781,499.52252197265625)
    ctx.lineTo(295.6995849609375,407.19281005859375)
    ctx.lineTo(270.0567321777344,359.7292175292969)
    ctx.bezierCurveTo(243.81228637695312,311.1573181152344,177.926025390625,242.8827667236328,188.72482299804688,275.4281311035156)
    ctx.bezierCurveTo(196.4998779296875,298.8606262207031,174.48806762695312,350.89849853515625,121.63897705078125,434.3486022949219)
    ctx.bezierCurveTo(55.970603942871094,538.0405578613281,42,578.5638732910156,46.52350997924805,648.5252380371094)
    ctx.bezierCurveTo(51.99464797973633,733.1406555175781,98.66461944580078,810.2752990722656,179.91819763183594,868.8414001464844)
    ctx.bezierCurveTo(206.4759521484375,887.9836730957031,228.52279663085938,897.8863830566406,245.19091796875,897.8862609863281)
    ctx.lineTo(270.31573486328125,897.8862609863281)
    ctx.lineTo(235.3482208251953,863.1741027832031)
    ctx.bezierCurveTo(187.00404357910156,815.3599548339844,159.10643005371094,756.3572692871094,154.01629638671875,691.5022888183594)
    ctx.bezierCurveTo(150.990478515625,652.9480285644531,152.53106689453125,640.1369323730469,159.45570373535156,644.0386047363281)
    ctx.bezierCurveTo(164.6754608154297,646.9795837402344,168.7804718017578,655.5267639160156,168.7803955078125,662.9295349121094)
    ctx.bezierCurveTo(168.7803955078125,684.3775939941406,215.21884155273438,763.1204528808594,249.07620239257812,799.1808776855469)
    ctx.bezierCurveTo(266.14434814453125,817.3595886230469,302.24139404296875,847.0287780761719,329.1130065917969,865.0632019042969)
    ctx.bezierCurveTo(375.73443603515625,896.3520202636719,380.41607666015625,897.8863830566406,435.5697326660156,897.8862609863281)
    ctx.bezierCurveTo(467.3592834472656,897.8862609863281,491.9608154296875,895.3360900878906,490.22271728515625,892.2190246582031)
    ctx.bezierCurveTo(440.53924560546875,803.1229553222656,438.1243591308594,795.8184509277344,438.4189758300781,735.4237976074219)
    ctx.bezierCurveTo(438.69122314453125,679.5966491699219,441.8666687011719,669.1926574707031,477.5307922363281,599.4085998535156)
    ctx.bezierCurveTo(521.8492431640625,512.6906433105469,532.9354858398438,474.21533203125,533.2197875976562,409.7903137207031)
    ctx.bezierCurveTo(533.6323852539062,316.3744812011719,484.8915710449219,246.14523315429688,391.0185241699219,204.8230743408203)
    ctx.bezierCurveTo(362.2380676269531,192.1541748046875,328.20648193359375,179.4442596435547,315.385009765625,176.72274780273438)
    ctx.lineTo(292.0733337402344,172)
    ctx.closePath()
    ctx.moveTo(637.8634643554688,418.0551452636719)
    ctx.lineTo(631.387939453125,452.05889892578125)
    ctx.bezierCurveTo(622.22705078125,500.43487548828125,610.8256225585938,523.4263610839844,562.7479858398438,591.8522644042969)
    ctx.bezierCurveTo(539.3870849609375,625.1003112792969,515.4966430664062,663.4790954589844,509.3901062011719,677.0978698730469)
    ctx.bezierCurveTo(492.10345458984375,715.6507873535156,501.7059020996094,794.4850158691406,530.111572265625,846.8805847167969)
    ctx.lineTo(553.6823120117188,890.5660095214844)
    ctx.lineTo(564.0430297851562,857.9790954589844)
    ctx.bezierCurveTo(572.0131225585938,833.0603332519531,589.8157958984375,811.9314880371094,640.194580078125,768.2468566894531)
    ctx.bezierCurveTo(713.2570190429688,704.8929138183594,724.0380859375,684.1929016113281,724.11669921875,606.2565612792969)
    ctx.bezierCurveTo(724.17431640625,549.0911560058594,707.4849243164062,504.5606689453125,668.1686401367188,455.83709716796875)
    ctx.lineTo(637.8634643554688,418.0551452636719)
    ctx.closePath()
    ctx.fill()
    ctx.stroke()
    ctx.restore()

  drawFireSymbol2: (ctx,x,y,w,h) ->
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

  @getEmptyBlockDesc: (className) ->
    if className == BLOCK_TYPE_CONTAINER_FIRE
      return BLOCK_TYPE_CONTAINER_FIRE_EMPTY
    if className == BLOCK_TYPE_CONTAINER_STOP
      return BLOCK_TYPE_CONTAINER_STOP_EMPTY

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
  console.debug ( dumpMapState() )
  console.debug(currentLevel)

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
              else if v2.blockChildType
                if v2.blockCount > 0
                  mapState[j] += v2.blockContainerType
                else
                  mapState[j] += Helper.getEmptyBlockDesc(v2.blockContainerType)
              else
                mapState[j] += v2.blockContainerType
            else
              mapState[j] += v2.blockType
  return mapState