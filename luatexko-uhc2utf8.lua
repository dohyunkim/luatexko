-- luatexko-uhc2utf8.lua
--
-- Copyright (c) 2013-2021  Dohyun Kim  <nomos at ktug org>
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
  version     = "3.3",
  date        = "2021/07/10",
  author      = "Dohyun Kim, Soojin Nam",
  description = "UHC (CP949) input encoding",
  license     = "LPPL v1.3+",
})

luatexko = luatexko or {}
luatexko.uhc2utf8 = luatexko.uhc2utf8 or {}
local luatexkouhc2utf8 = luatexko.uhc2utf8

local kpse_find_file = kpse.find_file
local add_to_callback = luatexbase.add_to_callback
local remove_from_callback = luatexbase.remove_from_callback

local function get_uhc_uni_table()
  local t_uhc2ucs = {}
  local file = kpse_find_file("KSCms-UHC-UCS2","cmap files")
  if file then
    file = io.open(file, "r")
    while true do
      local line = file:read"*line"
      if not line then break end
      local ea,eb,uni = line:match"<(%x+)>%s+<(%x+)>%s+<(%x+)>"
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

local function uhc_to_utf8 (buffer)
  if not buffer then return end
  if utf8.len(buffer) then return end -- check if buffer is already utf-8
  buffer = buffer:gsub("([\129-\253])([\65-\254])", function(a, b)
    local u = t_uhc2ucs[a:byte() * 256 + b:byte()]
    if u then
      return utf8.char(u)
    end
  end)
  return buffer
end

local function startconvert ()
  add_to_callback('process_input_buffer', uhc_to_utf8, 'luatexko.uhctoutf8', 1)
end
luatexkouhc2utf8.startconvert = startconvert

local function stopconvert ()
  remove_from_callback('process_input_buffer', 'luatexko.uhctoutf8')
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
  local t = {}
  for _, u in utf8.codes(name) do
    if u >= 0xA1 and u <= 0xFFE6 then
      local c = t_ucs2uhc[u]
      if c then
        t[#t + 1] = c // 256
        t[#t + 1] = c %  256
      else
        t[#t + 1] = u
      end
    else
      t[#t + 1] = u
    end
  end
  return string.char(table.unpack(t))
end

local function uhc_find_file (file, ...)
  local f = kpse_find_file(file, ...)
  if f then return f end
  f = utf8_to_uhc(file)
  return f and kpse_find_file(f, ...)
end

local function start_uhc_filename ()
  add_to_callback('find_read_file', function(id, name) return uhc_find_file(name) end, 'luatexko.touhc_findreadfile')
  add_to_callback('find_image_file', uhc_find_file, 'luatexko.touhc_findimagefile')
  kpse.find_file = uhc_find_file
end
luatexkouhc2utf8.start_uhc_filename = start_uhc_filename

local function stop_uhc_filename ()
  remove_from_callback('find_read_file', 'luatexko.touhc_findreadfile')
  remove_from_callback('find_image_file', 'luatexko.touhc_findimagefile')
  kpse.find_file = kpse_find_file
end
luatexkouhc2utf8.stop_uhc_filename = stop_uhc_filename
