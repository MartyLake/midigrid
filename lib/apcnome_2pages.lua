-- [[--
--  cheapskate library for apc, 2 pages
--  contains within itself a full 128 grid table, that can be viewed and played with by changing the two buttons at the bottom of the apc
-- --]]

--start on "page" 1
local apcpage=1

--make the grid buf
local gridbuf={}
for i=1,16 do
  gridbuf[i]={}
  for j=1,8 do
    gridbuf[i][j]=0
  end
end

-----------------------------
--loading up config file here
-----------------------------
local config = include('cheapskate/lib/apcmini_config')
local gridnotes = config.grid
local brightness_handler = config.brightness_handler
local device_name = config.device_name
--set your left right page numbers here...
-- local leftpage = config.auxrow[3]
local leftpage = config.leftpage_button
local rightpage = config.rightpage_button
-- local rightpage = config.auxrow[4]
-----------------------------
--adding midi device call backs
--------------------------------
local apcnome= {
  midi_id = nil
}

local og_dev_add, og_dev_remove

function apcnome.find_midi_device_id()
    local found_id = nil
    for i, dev in pairs(midi.devices) do
        local name = string.lower(dev.name)
        if apcnome.name_matches(name) then
            found_id = dev.id
        end
    end
    return found_id
end

function apcnome.connect(dummy_id)
    apcnome.set_midi_handler()
    midi.devices[apcnome.midi_id]:send({144,leftpage,1})
    midi.devices[apcnome.midi_id]:send({144,rightpage,0})
    return apcnome
end

-- function apcnome.set_key_handler(key_handler)
--     apcnome.set_midi_handler()
--     apcnome.key = key_handler
-- end

function apcnome.setup_connect_handling()
    og_dev_add = midi.add
    og_dev_remove = midi.remove

    midi.add = apcnome.handle_dev_add
    midi.remove = apcnome.handle_dev_remove
end

function apcnome.name_matches(name)
    return (name == device_name)
end

function apcnome.handle_dev_add(id, name, dev)
    og_dev_add(id, name, dev)

    apcnome.update_devices()

    if (apcnome.name_matches(name)) and (id ~= apcnome.midi_id) then
        apcnome.midi_id = id
        apcnome.device = dev
        apcnome.set_midi_handler()
    end
end

function apcnome.handle_dev_remove(id)
    og_dev_remove(id)
    apcnome.update_devices()
end

--this already expects it to have Midi_id
function apcnome.set_midi_handler()
    if apcnome.midi_id == nil then
        return
    end

    if midi.devices[apcnome.midi_id] ~= nil then
        midi.devices[apcnome.midi_id].event = apcnome.handle_key_midi
        --need this for checking .device
        apcnome.device=midi.devices[apcnome.midi_id]
    else
        apcnome.midi_id = nil
    end
end

function apcnome.cleanup()
  apcnome.key = nil
end

function apcnome.update_devices()
  midi.update_devices()

  local new_id = apcnome.find_midi_device_id()

  -- Only set id/handler when helpful
  if (apcnome.midi_id ~= new_id) and (new_id ~= nil) then
    apcnome.midi_id = new_id
    return apcnome.set_midi_handler()
  end

  return (apcnome.midi_id ~= nil)
end





--getting the two pages set up
apcnotecoords1={}
apcnotecoords2={}
for i,v in ipairs(gridnotes) do
  for j,k in ipairs(v) do
    apcnotecoords1[k]={j,i}
  end
end

for i,v in ipairs(gridnotes) do
  for j,k in ipairs(v) do
    apcnotecoords2[k]={j+8,i}
  end
end
apcnotecoords = {apcnotecoords1,apcnotecoords2}


apcnome.ledbuf={}

apcnome.rows = #gridnotes[1]
apcnome.cols = #gridnotes


function apcnome:led(x, y, z) 
  gridbuf[x][y]=z
  --if we aint on the right page dont bother
  if x>8 and apcpage==1 then
    return
  end
  if x<8 and apcpage==2 then
    return
  end

  if self.device then
    chan = 1

    if apcpage==1 then
      note = gridnotes[y][x] 
    elseif apcpage==2 then
      note = gridnotes[y][x-8]
    end

    vel = brightness_handler(z)
    if note then
      table.insert(self.ledbuf,0x90)
      table.insert(self.ledbuf,note)
      table.insert(self.ledbuf,vel)
    else
      --debugger
      print("no note found! coordinates....  x:"..x.."  y:"..y.."  z:"..z)
    end
  end
end

-- sure there is more elegant way!
function apcnome.changepage(page)
  -- apcnome:all(0)
  if page==1 then
    for i=1,8 do
      for j=1,8 do
        -- print(gridbuf[i][j])
        apcnome:led(i,j,gridbuf[i][j])
      end
    end
  elseif page==2 then
    for i=9,16 do
      for j=1,8 do
        -- print(gridbuf[i][j])
        apcnome:led(i,j,gridbuf[i][j])
      end
    end
  end
  apcnome:refresh()
end

function apcnome.handle_key_midi(data)
  note = data[2]
  --first, intercept page selectors
  if note==leftpage or note==rightpage then
    if note==leftpage and data[1]==0x90 and apcpage ~= 1 then
      apcpage=1
      -- midi.devices[apcnome.midi_id]:send({type="note_on",ch=1,note=rightpage,vel=0})
      midi.devices[apcnome.midi_id]:send({144,rightpage,0})
      midi.devices[apcnome.midi_id]:send({144,leftpage,1})
      -- midi.devices[apcnome.midi_id]:send({type="note_on",ch=1,note=leftpage,vel=1})
      apcnome.changepage(apcpage)
    elseif note==rightpage and data[1]==0x90 and apcpage ~= 2  then
      apcpage=2
      -- midi.devices[apcnome.midi_id]:send({type="note_on",ch=1,note=leftpage,vel=0})
      -- midi.devices[apcnome.midi_id]:send({type="note_on",ch=1,note=rightpage,vel=1})
      midi.devices[apcnome.midi_id]:send({144,rightpage,1})
      midi.devices[apcnome.midi_id]:send({144,leftpage,0})
      apcnome.changepage(apcpage)
    end
  elseif note > -1 and note < 64 then
    local coords = apcnotecoords[apcpage][note]
    local x, y
    if coords then
      x, y = coords[1],coords[2] 
      local s = data[1] ==0x90 and 1 or 0
      apcnome.key(x,y,s)
    else
      local coords = apcnotecoords[apcpage][note]
      local x, y
      print("missing coords!",x,y,s)
    end
  else
    print("unmapped key")
  end
end

function apcnome:refresh() 
  if self.device then
    -- self:send(self.ledbuf)
    midi.devices[apcnome.midi_id]:send(self.ledbuf)
    self.ledbuf={}
  end
end

function apcnome:all(vel)
  vel = brightness_handler(vel)
  if self.device then
    self.ledbuf={}
    for x=1, 16 do
      for y=1, 8 do
        local data
        gridbuf[x][y]=vel
        chan = 1
        if (apcpage==1 and x<9) then
          note = gridnotes[y][x] 
          table.insert(self.ledbuf,0x90)
          table.insert(self.ledbuf,note)
          table.insert(self.ledbuf,vel)
        elseif (apcpage==2 and x>8) then
          note = gridnotes[y][x-8]
          table.insert(self.ledbuf,0x90)
          table.insert(self.ledbuf,note)
          table.insert(self.ledbuf,vel)
        end
      end
      -- if this is needed
      -- self:refresh()
    end
  end
end
--init on page 1
apcnome.setup_connect_handling()
apcnome.update_devices()


return apcnome
