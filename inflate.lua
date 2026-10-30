-- raw DEFLATE (RFC 1951) decompressor + base64, for embedding compressed
-- hub sources. Luau-safe: uses bit32 when present, else native bitwise ops.
local b32 = rawget(_G, "bit32")
local band, bor, shl, shr
if b32 then
    band, bor, shl, shr = b32.band, b32.bor, b32.lshift, b32.rshift
else
    band = function(a, b) return a & b end
    bor  = function(a, b) return a | b end
    shl  = function(a, n) return a << n end
    shr  = function(a, n) return a >> n end
end

local LEN_BASE  = {3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258}
local LEN_EXTRA = {0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0}
local DIST_BASE = {1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577}
local DIST_EXTRA= {0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13}
local CL_ORDER  = {16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15}

local B64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_LOOKUP = {}
for i = 1, 64 do
    B64_LOOKUP[string.sub(B64_CHARS, i, i)] = i - 1
end

local function base64decode(s)
    local parts = {}
    local i, n = 1, #s
    while i <= n do
        local c1 = B64_LOOKUP[string.sub(s, i, i)] or 0
        local c2 = B64_LOOKUP[string.sub(s, i + 1, i + 1)] or 0
        local ch3 = string.sub(s, i + 2, i + 2)
        local ch4 = string.sub(s, i + 3, i + 3)
        local c3 = (ch3 ~= "" and ch3 ~= "=") and B64_LOOKUP[ch3] or nil
        local c4 = (ch4 ~= "" and ch4 ~= "=") and B64_LOOKUP[ch4] or nil

        parts[#parts + 1] = string.char(band(bor(shl(c1, 2), shr(c2, 4)), 255))
        if c3 then
            parts[#parts + 1] = string.char(band(bor(shl(band(c2, 15), 4), shr(c3, 2)), 255))
            if c4 then
                parts[#parts + 1] = string.char(band(bor(shl(band(c3, 3), 6), c4), 255))
            end
        end
        i = i + 4
    end
    return table.concat(parts)
end

local function inflate(src)
    local pos, bitbuf, bitcnt = 1, 0, 0

    local function bits(n)
        while bitcnt < n do
            local byte = string.byte(src, pos)
            if not byte then error("inflate: truncated stream") end
            bitbuf = bor(bitbuf, shl(byte, bitcnt))
            pos = pos + 1
            bitcnt = bitcnt + 8
        end
        local value = band(bitbuf, shl(1, n) - 1)
        bitbuf = shr(bitbuf, n)
        bitcnt = bitcnt - n
        return value
    end

    local function build(lengths, n)
        local count = {}
        for i = 1, 16 do count[i] = 0 end
        for i = 1, n do
            local l = lengths[i]
            if l and l > 0 then count[l] = count[l] + 1 end
        end
        local offs = { 0 }
        for l = 1, 15 do offs[l + 1] = offs[l] + count[l] end
        local symbol = {}
        for i = 1, n do
            local l = lengths[i]
            if l and l > 0 then
                symbol[offs[l] + 1] = i - 1
                offs[l] = offs[l] + 1
            end
        end
        return { count = count, symbol = symbol }
    end

    local function decode(h)
        local code, first, index = 0, 0, 0
        for len = 1, 15 do
            code = bor(code, bits(1))
            local c = h.count[len]
            if code - c < first then
                return h.symbol[index + (code - first) + 1]
            end
            index = index + c
            first = shl(first + c, 1)
            code = shl(code, 1)
        end
        error("inflate: bad huffman code")
    end

    local out, recent, recentLen = {}, {}, 0

    local function push(chunk)
        if chunk == "" then return end
        out[#out + 1] = chunk
        recent[#recent + 1] = chunk
        recentLen = recentLen + #chunk
        if recentLen > 131072 then
            local joined = table.concat(recent)
            joined = string.sub(joined, -32768)
            recent = { joined }
            recentLen = #joined
        end
    end

    -- the last `d` bytes of output, needed for a back-reference
    local function tail(d)
        local parts, need = {}, d
        for i = #recent, 1, -1 do
            local c = recent[i]
            local len = #c
            if len >= need then
                parts[#parts + 1] = string.sub(c, len - need + 1)
                need = 0
                break
            end
            parts[#parts + 1] = c
            need = need - len
        end
        if need > 0 then error("inflate: distance beyond output") end
        local buf = {}
        for i = #parts, 1, -1 do buf[#buf + 1] = parts[i] end
        return table.concat(buf)
    end

    local literal = {}

    local function flushLiterals()
        if #literal > 0 then
            push(table.concat(literal))
            literal = {}
        end
    end

    repeat
        local final = bits(1)
        local btype = bits(2)

        if btype == 0 then
            bitbuf, bitcnt = 0, 0
            local len = (string.byte(src, pos) or 0) + (string.byte(src, pos + 1) or 0) * 256
            pos = pos + 4
            push(string.sub(src, pos, pos + len - 1))
            pos = pos + len
        elseif btype == 1 or btype == 2 then
            local litTree, distTree

            if btype == 1 then
                local lengths = {}
                for i = 1, 144 do lengths[i] = 8 end
                for i = 145, 256 do lengths[i] = 9 end
                for i = 257, 280 do lengths[i] = 7 end
                for i = 281, 288 do lengths[i] = 8 end
                litTree = build(lengths, 288)
                local dl = {}
                for i = 1, 30 do dl[i] = 5 end
                distTree = build(dl, 30)
            else
                local hlit = bits(5) + 257
                local hdist = bits(5) + 1
                local hclen = bits(4) + 4

                local cl = {}
                for i = 1, 19 do cl[i] = 0 end
                for i = 1, hclen do cl[CL_ORDER[i] + 1] = bits(3) end
                local clTree = build(cl, 19)

                local lengths, idx = {}, 1
                while idx <= hlit + hdist do
                    local sym = decode(clTree)
                    if sym < 16 then
                        lengths[idx] = sym
                        idx = idx + 1
                    elseif sym == 16 then
                        local prev = lengths[idx - 1]
                        if prev == nil then error("inflate: repeat with no base") end
                        for _ = 1, 3 + bits(2) do lengths[idx] = prev; idx = idx + 1 end
                    elseif sym == 17 then
                        for _ = 1, 3 + bits(3) do lengths[idx] = 0; idx = idx + 1 end
                    else
                        for _ = 1, 11 + bits(7) do lengths[idx] = 0; idx = idx + 1 end
                    end
                end

                litTree = build(lengths, hlit)
                local dl = {}
                for i = 1, hdist do dl[i] = lengths[hlit + i] end
                distTree = build(dl, hdist)
            end

            while true do
                local sym = decode(litTree)
                if sym < 256 then
                    literal[#literal + 1] = string.char(sym)
                elseif sym == 256 then
                    flushLiterals()
                    break
                else
                    flushLiterals()
                    local li = sym - 256
                    if li < 1 or li > 29 then error("inflate: bad length symbol") end
                    local len = LEN_BASE[li] + (LEN_EXTRA[li] > 0 and bits(LEN_EXTRA[li]) or 0)

                    local ds = decode(distTree) + 1
                    if ds < 1 or ds > 30 then error("inflate: bad distance symbol") end
                    local dist = DIST_BASE[ds] + (DIST_EXTRA[ds] > 0 and bits(DIST_EXTRA[ds]) or 0)
                    if dist > recentLen then error("inflate: distance beyond output") end

                    local piece = tail(dist)
                    local copied
                    if len <= dist then
                        copied = string.sub(piece, 1, len)
                    else
                        copied = string.sub(string.rep(piece, math.ceil(len / dist)), 1, len)
                    end
                    push(copied)
                end
            end
        else
            error("inflate: bad block type")
        end
    until final == 1

    return table.concat(out)
end

return { inflate = inflate, base64 = base64decode }
