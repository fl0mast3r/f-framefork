local process = require("@lune/process")
local fs = require("@lune/fs")

local DEVIDER = "-------- :: Generated stuff below :: -----------------"

local outputPath: string = process.args[1] or "Types"

local function convertArguments(arguments: string): (string)
    local newLine = ""

    for argumentName, argumentType in arguments:gmatch("([^,:)%s]+)%s*:?%s*([^,]*)") do
        if argumentType == "" then
            argumentType = "any"
        end

        if argumentName == "..." then
            newLine ..= "..."..argumentType..", "

            continue
        end

        newLine ..= argumentName..": "..argumentType..", "
    end

    return "("..newLine:sub(1, newLine:len()-2)..")"
end

local function parseFileFields(content: string, type: "Service"|"Controller")
    local result = ""
    local fields = content:match("local%s*%w+"..type.."%s*=%s*{\r\n(.*)\n}")

    if not fields then
        return
    end

    for fieldName, fieldType in fields:gmatch("%s+(%u%w*)%s*=%s*[^:]*::%s*([^\r\n]*)") do
        if not fieldType then
            continue
        end

        result ..= "\t"..fieldName..": "..fieldType..(if fieldType:sub(fieldType:len(), fieldType:len()) == "," then "" else ",").."\n"
    end

    if result == "" then
        return
    end

    return result
end

local function parseDirectory(filesType: "Controller" | "Service", path: string)
    local result: string = ""

    for _, fileName: string in next, fs.readDir(path) do
        if not fileName:find(filesType) then
            continue
        end

        local content: string = fs.readFile(path.."/"..fileName)
        local fileNameWOluau = fileName:split(".luau")[1]

        result ..= `export type {fileNameWOluau} = {"{"}\n`
        local fieldsParse = parseFileFields(content, filesType)
        result ..= if fieldsParse then fieldsParse.."\n" else ""
        
        for method, generic, arguments, colon, returnTypes in content:gmatch(`function%s+%w+%.(%w+)(<?[^>]?>?)(%b())%s*(:?)%s*(%(?[^\n]*%)?)`) do
            if colon == "" then
                returnTypes = "()"
            end

            arguments = arguments:gsub("self:%s*[^,)]*", "self: "..fileNameWOluau)
            arguments = arguments:sub(2, arguments:len()-1)

            result ..= `\t{method}: {generic}{convertArguments(arguments)} -> {returnTypes}`
            if result:sub(result:len(), result:len()) == "\r" then
                result = result:sub(1, result:len()-1)..",\n"
            else
                result = result..",\n"
            end
        end

        result ..= "}\n\n"
    end

    return result
end

local function mergeWithWrittenCode(path: string, generatedContent: string)
    if not fs.isFile(path) then
        fs.writeFile(path, "")
    end

    local code = ""

    local codeBefore = fs.readFile(path):match(`(.-){DEVIDER}`)
    if codeBefore then
        code ..= codeBefore .. "" .. DEVIDER .. "\n\n"
    else
        code ..= "\n\n".. DEVIDER .. "\n\n"
    end

    return code..generatedContent.."return {}"
end

fs.writeFile(outputPath .. "/Services.luau", mergeWithWrittenCode(outputPath .. "/Services.luau", parseDirectory("Service", "src/server/Services")))
fs.writeFile(outputPath .. "/Controllers.luau", mergeWithWrittenCode(outputPath .. "/Controllers.luau", parseDirectory("Controller", "src/shared/Controllers")))