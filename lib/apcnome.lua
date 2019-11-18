-- [[--

-- cheapskate lib for getting midi grid devices to behave like monome grid devices
--   --]]
-- local apcnome ={}
--two things are run before returning, 'setup_connect_handling' and 'update_devices'
--setup_connect_handling copies over 'og' midi add and remove callbacks, and gives its own add and remove handlers, which means the call backs for 
--add and remove handlers:
--update devices:
--find_midi_devices: iterates through 'midi.devices' to see if the name matches, then returns id, this system manages its own ids, which is why you have to initialize it and why
--first, you connect to it, 'apcnome.connect', which returns a apcnome object and does 'set_midi_handler'
--
-----------------------------
--loading up config file here
-----------------------------
local config = include('cheapskate/lib/apcmini_config')
local gridnotes = config.grid
local brightness_handler = config.brightness_handler
local device_name = config.device_name
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



--here, using the grid from the config file, we generate the table to help us go the other way around
--so, if you press a midi note and you wanna know what it is, this will have an index with our coordinates
local note2coords={}

for i,v in ipairs(gridnotes) do
  for j,k in ipairs(v) do
    note2coords[k]={j,i}
  end
end

apcnome.ledbuf={}

apcnome.rows = #gridnotes[1]
apcnome.cols = #gridnotes

function apcnome.handle_key_midi(event)
  --block cc messages, so they can be mapped
  if(event[1]==0x90 or event[1]==0x80) then
    local note = event[2]
    local coords = note2coords[note]
    local x, y
    if coords then
      x, y = coords[1],coords[2]
      local s = event[1] ==0x90 and 1 or 0
      if apcnome.key ~= nil then
        apcnome.key(x, y, s)
      end
    else
      print("missing coords!")
    end
  end
end


function apcnome:led(x, y, z)
  if self.device then
    chan = 1
    --flag reversed here because thats actually what it is in lua table!!!, see above. this is clearer either way I think
    note = ((x<9 and x>0) and (y<9 and y>0)) and gridnotes[y][x] or null
    vel = brightness_handler(z)
    if note then
      table.insert(self.ledbuf,0x90)
      table.insert(self.ledbuf,note)
      table.insert(self.ledbuf,vel)
    else
      --debugger, probably want to comment this out if you are being messyy
      print("no note found! coordinates....  x:"..x.."  y:"..y.."  z:"..z)
    end
  end
end


--sending our buff
function apcnome:refresh()
  if self.device then
    -- self:send(self.ledbuf)
    midi.devices[apcnome.midi_id]:send(self.ledbuf)
    self.ledbuf={}
  end
end

function apcnome:all(vel)
  if self.device then
    self.ledbuf={}
    for x=1, #gridnotes do
      for y=1, #gridnotes[x] do
        chan = 1
        note = gridnotes[x][y]
        vel = brightness_handler(vel)
        table.insert(self.ledbuf,0x90)
        table.insert(self.ledbuf,note)
        table.insert(self.ledbuf,vel)
      end
      -- it is unclear to me sometimes if a call to all in a regular grid requires a subsequent refresh, have this here in case
      -- self:refresh()
    end
  end
end

-- setting up connection and connection callbacks before returning
apcnome.setup_connect_handling()
apcnome.update_devices()

return apcnome
