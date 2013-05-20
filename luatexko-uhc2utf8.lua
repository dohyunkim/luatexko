-- luatexko-uhc2utf8.lua
--
-- Copyright (c) 2013 Dohyun Kim  <nomos at ktug org>
--
-- This work may be distributed and/or modified under the
-- conditions of the LaTeX Project Public License, either version 1.3c
-- of this license or (at your option) any later version.
-- The latest version of this license is in
--   http://www.latex-project.org/lppl.txt
-- and version 1.3c or later is part of all distributions of LaTeX
-- version 2006/05/20 or later.

module('luatexkouhc2utf8', package.seeall)

luatexbase.provides_module({
  name        = "luatexko-uhc2utf8",
  version     = 1.0,
  date        = "2013/05/10",
  author      = "Dohyun Kim",
  description = "UHC (CP949) input encoding",
  license     = "LPPL v1.3+",
})

local find = string.find
local gsub = string.gsub
local byte = string.byte
local len = string.len
local format = string.format
local ugsub = unicode.utf8.gsub
local ubyte = unicode.utf8.byte
local uchar = unicode.utf8.char
local floor = math.floor
local isfile = lfs.isfile
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
      local _,_,ea,eb,uni = find(line,"<(%x+)>%s+<(%x+)>%s+<(%x+)>")
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

local uhc_to_utf8 = function(buffer)
  if not buffer then return end
  -- check if buffer is already utf-8; better solution?
  local t = gsub(buffer,"[\0-\127]","")
  t = gsub(t,"[\194-\223][\128-\191]","")
  t = gsub(t,"[\224-\239][\128-\191][\128-\191]","")
  t = gsub(t,"[\240-\244][\128-\191][\128-\191][\128-\191]","")
  if len(t) == 0 then return buffer end
  -- now convert to utf8
  buffer = gsub(buffer, "([\129-\253])([\65-\254])",
  function(a, b)
    a, b = byte(a), byte(b)
    local utf = t_uhc2ucs[a * 256 + b]
    if utf then return uchar(utf) end
  end)
  return buffer
end

function startconvert ()
  add_to_callback('process_input_buffer', uhc_to_utf8, 'luatexko-uhctoutf8', 1)
end

function stopconvert ()
  remove_from_callback('process_input_buffer', 'luatexko-uhctoutf8')
end

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
    if not c then return u end
    return format("%c%c", floor(c/256), c%256)
  end)
  return name
end

local function uhc_find_file (file, ...)
  local f = kpse_find_file(file, ...)
  if f then return f end
  f = utf8_to_uhc(file)
  f = f and kpse_find_file(f, ...)
  return f
end

function start_uhc_filename ()
  add_to_callback('find_read_file', function(id, name) return uhc_find_file(name) end, 'luatexko-touhc-findreadfile')
  add_to_callback('find_image_file', uhc_find_file, 'luatexko-touhc-findimagefile')
  kpse.find_file = uhc_find_file
end

function stop_uhc_filename ()
  remove_from_callback('find_read_file', 'luatexko-touhc-findreadfile')
  remove_from_callback('find_image_file', 'luatexko-touhc-findimagefile')
  kpse.find_file = kpse_find_file
end
