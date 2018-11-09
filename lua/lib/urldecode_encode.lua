function encodeURI(str)
		if (str) then
			str = string.gsub (str, "\n", "\r\n")
			str = string.gsub (str, "([^%w ])",
				function (c) return string.format ("%%%02X", string.byte(c)) end)
			str = string.gsub (str, " ", "+")
	   end
	   return str
	end

	function decodeURI(s)
		if(s) then
			s = string.gsub(s, '%%(%x%x)',
				function (hex) return string.char(tonumber(hex,16)) end )
		end
		return s
	end