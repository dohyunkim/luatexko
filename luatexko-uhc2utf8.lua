-- luatexko-uhc2utf8.lua
--
-- Copyright (c) 2013-2019  Dohyun Kim  <nomos at ktug org>
--                          Soojin Nam  <jsunam at gmail com>
--
-- This work may be distributed and/or modified under the
-- conditions of the LaTeX Project Public License, either version 1.3c
-- of this license or (at your option) any later version.
-- The latest version of this license is in
--   http://www.latex-project.org/lppl.txt
-- and version 1.3c or later is part of all distributions of LaTeX
-- version 2006/05/20 or later.

luatexbase.provides_module({
  name        = "luatexko-uhc2utf8",
  version     = "1.23",
  date        = "2019/03/24",
  author      = "Dohyun Kim, Soojin Nam",
  description = "UHC (CP949) input encoding",
  license     = "LPPL v1.3+",
})

luatexkouhc2utf8 = luatexkouhc2utf8 or {}
local luatexkouhc2utf8 = luatexkouhc2utf8

local format = string.format
require "unicode"
local unicodeutf8 = unicode.utf8
local ugsub = unicodeutf8.gsub
local ubyte = unicodeutf8.byte
local uchar = unicodeutf8.char
local floor = math.floor
local kpse_find_file = kpse.find_file
local add_to_callback = luatexbase.add_to_callback
local remove_from_callback = luatexbase.remove_from_callback

local function get_uhc_uni_table()
  local t_uhc2ucs = {}
  local file = kpse_find_file("KSCms-UHC-UCS2","cmap files")
  if file then
    file = io.open(file, "r")
    while true do
      local line = file:read("*line")
      if not line then break end
      local ea,eb,uni = line:match("<(%x+)>%s+<(%x+)>%s+<(%x+)>")
      if ea and eb and uni then
        ea, eb, uni = tonumber(ea,16),tonumber(eb,16),tonumber(uni,16)
        for i=ea,eb do
          t_uhc2ucs[i] = uni
          uni = uni + 1
        end
      end
    end
    file:close()
  end
  return t_uhc2ucs
end

local t_uhc2ucs = t_uhc2ucs or get_uhc_uni_table()

local function not_utf8lowbyte(t)
  for _,v in ipairs(t) do
    -- rough checking
    if v < 0x80 or v > 0xBF then return true end
  end
  return false
end

local uhc_to_utf8 = function(buffer)
  if not buffer then return end
  -- check if buffer is already utf-8; better solution?
  local i, buflen = 1, buffer:len()+1
  while i < buflen do
    local a = buffer:byte(i)
    if a < 0x80 then
      i = i + 1
    elseif a < 0xC2 then
      break
    elseif a < 0xE0 then
      if not_utf8lowbyte({buffer:byte(i+1)}) then break end
      i = i + 2
    elseif a < 0xF0 then
      if not_utf8lowbyte({buffer:byte(i+1,i+2)}) then break end
      i = i + 3
    elseif a < 0xF5 then
      if not_utf8lowbyte({buffer:byte(i+1,i+3)}) then break end
      i = i + 4
    else
      break
    end
  end
  if i == buflen then return nil end
  -- now convert to utf8
  buffer = buffer:gsub("([\129-\253])([\65-\254])",
  function(a, b)
    local utf = t_uhc2ucs[a:byte() * 256 + b:byte()]
    if utf then return uchar(utf) end
  end)
  return buffer
end

local function startconvert ()
  add_to_callback('process_input_buffer', uhc_to_utf8, 'luatexko-uhctoutf8', 1)
end
luatexkouhc2utf8.startconvert = startconvert

local function stopconvert ()
  remove_from_callback('process_input_buffer', 'luatexko-uhctoutf8')
end
luatexkouhc2utf8.stopconvert = stopconvert

-----------------------------------------
-- Hangul Windows OS uses CP949 filenames
-----------------------------------------
local function get_uni_uhc_table()
  local t_ucs2uhc = {}
  for i,v in pairs(t_uhc2ucs) do
    t_ucs2uhc[v] = i
  end
  return t_ucs2uhc
end

local t_ucs2uhc = t_ucs2uhc or get_uni_uhc_table()

local function utf8_to_uhc (name)
  if not name then return end
  name = ugsub(name, "[\161-\239\191\166]", -- 00A1..FFE6
  function(u)
    local c = t_ucs2uhc[ubyte(u)]
    if c then
      return format("%c%c", floor(c/256), c%256)
    end
  end)
  return name
end

local function uhc_find_file (file, ...)
  local f = kpse_find_file(file, ...)
  if f then return f end
  f = utf8_to_uhc(file)
  return f and kpse_find_file(f, ...)
end

local function start_uhc_filename ()
  add_to_callback('find_read_file', function(id, name) return uhc_find_file(name) end, 'luatexko-touhc-findreadfile')
  add_to_callback('find_image_file', uhc_find_file, 'luatexko-touhc-findimagefile')
  kpse.find_file = uhc_find_file
end
luatexkouhc2utf8.start_uhc_filename = start_uhc_filename

local function stop_uhc_filename ()
  remove_from_callback('find_read_file', 'luatexko-touhc-findreadfile')
  remove_from_callback('find_image_file', 'luatexko-touhc-findimagefile')
  kpse.find_file = kpse_find_file
end
luatexkouhc2utf8.stop_uhc_filename = stop_uhc_filename
