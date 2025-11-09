local Converter = {}

local suffixes = {'','K','M','B','T','Qa','Qu','s','S','O','N','d','U','D','td','qdD','QnD','sxD','SpD','OcD','NvD','Vgn','UVg','DVg','TVg','qtV','QnV','SeV','SPG','OVG','NVG','TGN','UTG','DTG','tsTG','qtTG','QnTG','ssTG','SpTG','OcTG','NoAG','UnAG','DuAG','TeAG','QdAG','QnAG','SxAG','SpAG','OcAG','NvAG','CT'}

function Converter:SuffixNumber(number)
	local number = tonumber(number)
	for i = 1, #suffixes do
		if number < 10^(i * 3) then
			return math.floor(number/((10^((i - 1)*3))/100))/(100)..suffixes[i]
		end
	end
end

function Converter:Comma(Number)
	local left, num, right = string.match(Number,'^([^%d]*%d)(%d*)(.-)$')
	return left .. (num:reverse():gsub('(%d%d%d)','%1,'):reverse())..right
end

function Converter:Convert(Number)
	if Number < 1000000 then
		return self:Comma(Number)
	end
	
	return self:SuffixNumber(Number)
end

function Converter:ConvertOrderedDataToNumber(orderedData)
	return math.floor(orderedData ~= 0 and (1.0000001 ^ orderedData) or 0)
end

function Converter:ConvertNumberToOrderedData(number)
	return number ~= 0 and math.floor(math.log(number) / math.log(1.0000001)) or 0
end

return Converter