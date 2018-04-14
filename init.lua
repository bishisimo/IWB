 local function split(str, reps)
    local resultStrList = {}
    string.gsub(
        str,
        "[^" .. reps .. "]+",
        function(w)
            table.insert(resultStrList, w)
        end
    )
    return resultStrList
end
print(node.bootreason())
for fileName in pairs(file.list()) do
    local list = split(fileName, ".")
    if list[2] == "lua" then
        node.compile(fileName)
        file.remove(fileName)
    end
end
collectgarbage()
dofile('main.lc')