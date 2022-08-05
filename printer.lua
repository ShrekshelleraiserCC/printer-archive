local config = {
  supplyName="", -- name of the chest with dye in it
  outputName="", -- name of the chest to output printed pages to
  belowName="", -- name of the chest (on the network) of the chest above the turtle
  paperName="", -- name of the hopper for paper
  paperOutName="", -- name of the paper output hopper
  speakerName="", -- name of speaker to play sound effects on (optional)
  hostname="printer", -- hostname of the printer on rednet
}

local printerPer
local supplyPer
local outputPer
local belowPer
local paperOutPer
local speakerPer

--- takes an inventory peripehral, and item name, returns slot in chest or false
local function findItem(per, name, fuzzy)
  local items = per.list()
  fuzzy = fuzzy or false
  for slot, item in pairs(items) do
    if item and (item.name == name) and not fuzzy then
      return slot
    elseif item and string.match(item.name, name) then
      return slot -- fuzzy
    end
  end
  return false
end

local function countItem(per, name)
  local count = 0
  local items = per.list()
  for slot, item in pairs(items) do
    if item and (item.name == name) then
      count = count + item.count
    end
  end
  return count
end

-- move turtle's contents into chest
local function emptyTurtle()
  for i = 1, 16 do
    turtle.select(i)
    turtle.dropDown()
  end
end

-- Just list the contents of the turtle's inventory
local function listTurtleInv()
  local retVal = {}
  for slot = 1, 16 do
    -- 13 slots in a printer
    retVal[slot] = turtle.getItemDetail(slot)
  end
  return retVal
end

-- move the inventory contents of all hoppers, chests, printer, and the turtle into the resource chest
local function clearJam()
  while turtle.suck() do end -- empty the printer
  emptyTurtle() -- move turtles inventory into chest below
  for s, item in pairs(belowPer.list()) do
    belowPer.pushItems(config.supplyName, s) -- move the contents of the below chest to the supply chest
  end
  for s, item in pairs(paperOutPer.list()) do
    paperOutPer.pushItems(config.outputName, s) -- move the contents of the output hopper to the output chest
  end
end

local supplyNameLookup = {
  [0] = "minecraft:white_dye",
  "minecraft:orange_dye",
  "minecraft:magenta_dye",
  "minecraft:light_blue_dye",
  "minecraft:yellow_dye",
  "minecraft:lime_dye",
  "minecraft:pink_dye",
  "minecraft:gray_dye",
  "minecraft:light_gray_dye",
  "minecraft:cyan_dye",
  "minecraft:purple_dye",
  "minecraft:blue_dye",
  "minecraft:brown_dye",
  "minecraft:green_dye",
  "minecraft:red_dye",
  "minecraft:black_dye",
}
-- returns boolean of success
local function addDye(n)
  local dyeCol = tonumber(n,16)
  assert(dyeCol, "Invalid dye character")
  assert(dyeCol >= 0 and dyeCol <= 15, "Invalid dye color")
  local inv = listTurtleInv()
  local slot = findItem(supplyPer, supplyNameLookup[dyeCol])
  if slot then
    supplyPer.pushItems(config.belowName,slot,1)
    turtle.select(1)
    turtle.suckDown()
    turtle.drop() -- move dye into printer
    return true
  end
  return false
end

-- returns a boolean of success
local function addPage()
  local slot = findItem(supplyPer, "minecraft:paper")
  if slot then
    supplyPer.pushItems(config.paperName, slot, 1)
    return true
  end
  return false
end

-- returns a boolean of success
local function cyclePage()
  return (paperOutPer.pushItems(config.paperName, 1, 1) > 0)
end

-- c is a color character
-- p is a page
-- page should already be in printer, and will be ejected afterwards
-- returns boolean success
local function printColor(c, p, title)
  if not addDye(c) then error("Out of dye "..c) end
  if not printerPer.newPage() then error("Printer is jammed") end
  printerPer.setPageTitle(title)
  for y, line in pairs(p) do
    for x, column in pairs(line) do
      if column[2] == c then
        -- this is a color we're printing!
        -- this is where fun sound effects will go.
        -- if speakerPer then
        --   speakerPer.playSound("minecraft:block.anvil.hit")
        --   sleep()
        -- end
        printerPer.setCursorPos(x,y)
        printerPer.write(column[1]) -- write the character
      end
    end
  end
  if speakerPer then
    speakerPer.playSound("minecraft:block.anvil.hit",0.5)
  end
  printerPer.endPage()
  return true
end

-- p should be a 3D blit table with character/FG, indexed [Y][X]
-- {
--   {{"H","a"},{"i","b"}}
-- }
-- returns boolean success
local function printPage(p, title)
  local usedColors = {}
  local colorCount = 0
  for y, row in pairs(p) do
    for x, column in pairs(row) do
      if not usedColors[column[2]] then
        colorCount = colorCount + 1
      end
      usedColors[column[2]] = true
    end
  end
  -- now we know which colors this print needs
  if colorCount < 1 then
    -- this page is blank, add a color just to satisfy CC's requirement for dye
    usedColors["f"] = true
    colorCount = 1
  end
  local currentColor = 1
  if not addPage() then
    error("Out of paper")
  end
  for c, _ in pairs(usedColors) do
    if not printColor(c, p, title) then
      error("Printer is in an invalid state") -- this should be impossible
    end
    -- attempt to recycle page
    if currentColor ~= colorCount then
      if not cyclePage() then error("Printer is jammed") end
    end
    currentColor = currentColor + 1
  end
  paperOutPer.pushItems(config.outputName, 1)
  return true
end

-- d should be a 4D blit table with character/FG, indexed [page][Y][X]
local function printDocument(d, title)
  local documentLen = #d
  for pageN, page in pairs(d) do
    if not printPage(page, string.format("%s [Page %u / %u]",title,pageN,documentLen)) then
      return false -- this should be impossible to reach
    end
    if speakerPer then
      speakerPer.playSound("minecraft:block.stone_button.click_on",0.5)
      sleep()
    end
  end
  return true
end

-- convert from bimg, blit, and strings to the 4D blit table format used internally
local function processInput(i, color)
  local pageWidth, pageHeight = 25, 21 -- hardcoding this
  local output = {}
  if type(i) == "string" then
    local tmp = {} -- split the string up into page width regions
    for x = 1, i:len(), pageWidth do
      tmp[#tmp+1] = i:sub(x, x+pageWidth-1)
    end
    color = color or "f"
    assert(tonumber(color, 16), "Invalid color character")
    for page = 1, math.ceil(#tmp / pageHeight) do
      output[page] = {}
      for line = 1, pageHeight do
        output[page][line] = {}
        for char = 1, pageWidth do
          local ch = tmp[(page-1)*pageHeight + line]
          if ch then
            output[page][line][char] = {ch:sub(char,char),color}
          end
        end
      end
    end
    return output
  elseif type(i) == "table" then
    local tmp = {{}} -- split the bimg/blit table up into page divided secitions
    local currentPageNo = 1
    local function incPage()
      currentPageNo = currentPageNo + 1
      tmp[currentPageNo] = {}
    end

    local function processFrame(frame)
      for charN = 1, frame[1][1]:len(), pageWidth do
        local offset = 0
        for lineN, line in ipairs(frame) do
          -- this will maybe split the image to fit on multiple pages horizontally and vertically ???
          tmp[currentPageNo][lineN-offset] = {line[1]:sub(charN, charN+pageWidth), line[2]:sub(charN, charN+pageWidth)}
          if (lineN / pageHeight) >= 1 and (lineN % pageHeight == 0) then
            incPage()
            offset = offset + pageHeight
          end
        end
        incPage()
      end
    end

    if type(i[1][1]) == "string" then
      -- this is a 2D blit table
      processFrame(i)
    elseif type(i[1][1]) == "table" then
      -- this is a bimg compatible blit table
      for frameN, frame in ipairs(i) do
        processFrame(frame)
      end
    else
      -- this is an unknown format
      error("Unsupported input")
    end
    tmp[currentPageNo] = nil -- remove the last empty page

    for pageN, page in pairs(tmp) do
      output[pageN] = {}
      for lineN, line in pairs(page) do
        output[pageN][lineN] = {}
        for charN = 1, line[1]:len() do
          output[pageN][lineN][charN] = {line[1]:sub(charN, charN),line[2]:sub(charN, charN)}
          if output[pageN][lineN][charN][2] == " " then
            -- filter out space FG
            output[pageN][lineN][charN] = nil
          end
        end
      end
    end
    return output
  end
  error("Unsupported input")
end

local function getDyeCount()
  local dyeCount = {}
  for k,v in pairs(supplyNameLookup) do
    dyeCount[k] = countItem(supplyPer, v)
  end
  return dyeCount
end

local function getPaperCount()
  return countItem(supplyPer, "minecraft:paper")
end

local printQueue = {}

local function addToQueue(d)
  printQueue[#printQueue+1] = d
end

local function popFromQueue()
  local d = printQueue[1]
  table.remove(printQueue, 1)
  return d
end

local function handleMessages()
  rednet.open("right")
  rednet.host("printer",config.hostname)
  while true do
    -- do main rednet event loop
    local id, m = rednet.receive("printer")
    print("message recieved")
    if type(m) == "table" and type(m.job) == "table" then
      addToQueue({id, m}) -- queue will have an id to send a message to about the printjob, and the actual requested document
      print("Added document to queue")
    elseif m == "getDyeCount" then
      rednet.send(id, getDyeCount())
    elseif m == "getPaperCount" then
      rednet.send(id, getPaperCount())
    end
    -- a document should be a table {title="whatever you want your title to be", job="your requested print",color="0" (a hex char, for mono text documents)}
  end
end

local function doPrinting()
  while true do
    if #printQueue > 0 then
      clearJam() -- ensure there is nothing in the printer
      -- something to do
      print("Attempting print")
      local doc = popFromQueue()
      local stat, info = pcall(processInput, doc[2].job, doc[2].color)
      if stat then
        ---@diagnostic disable-next-line: cast-local-type
        stat, info = pcall(printDocument, info, doc[2].title or "Untitled")
        rednet.send(doc[1], {stat, info})
        if not stat then
          print("Print failed",info)
        else
          print("Print succeeded")
        end
      else
        -- errored at this stage
        rednet.send(doc[1], {stat, info})
        print("Print failed", info)
      end
    end
    sleep()
  end
end

local function main()
  print("started")
  clearJam()
  parallel.waitForAll(handleMessages, doPrinting)
end



local function loadConfig()
  local f = fs.open("printer.conf", "r")
  if f then
    -- config file exists
    config = assert(textutils.unserialize(f.readAll()), "printer.conf is invalid")
    printerPer = assert(peripheral.wrap("front"), "there should be a printer in front of the turtle")
    supplyPer = assert(peripheral.wrap(config.supplyName), "supplyName is not a peripheral")
    outputPer = assert(peripheral.wrap(config.outputName), "outputName is not a peripheral")
    belowPer = assert(peripheral.wrap(config.belowName), "belowName is not a peripheral")
    paperOutPer = assert(peripheral.wrap(config.paperOutName), "paperOutName is not a peripheral")
    speakerPer = peripheral.wrap(config.speakerName)
    f.close()
    main()
  else
    f = fs.open("printer.conf", "w")
    f.write(textutils.serialize(config))
    f.close()
    print("printer.conf created, please set your settings.")
  end
end

loadConfig()