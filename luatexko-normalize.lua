-- luatexko-normalize.lua
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
  name        = "luatexko-normalize",
  version     = "3.3",
  date        = "2021/07/10",
  author      = "Dohyun Kim, Soojin Nam",
  description = "Hangul normalization",
  license     = "LPPL v1.3+",
})

luatexko = luatexko or {}
luatexko.normalize = luatexko.normalize or {}
local luatexkonormalize = luatexko.normalize

local utf8codes   = utf8.codes
local utf8char    = utf8.char
local tableinsert = table.insert
local tableappend = table.append
local tableunpack = table.unpack

local normalize = require'lua-uni-normalize'

local jamotocjamo = {
  ccho = {
    [0x1100] = 0x3131,
    [0x1101] = 0x3132,
    -- [0x11AA] = 0x3133,
    [0x1102] = 0x3134,
    -- [0x11AC] = 0x3135,
    -- [0x11AD] = 0x3136,
    [0x1103] = 0x3137,
    [0x1104] = 0x3138,
    [0x1105] = 0x3139,
    -- [0x11B0] = 0x313A,
    -- [0x11B1] = 0x313B,
    -- [0x11B2] = 0x313C,
    -- [0x11B3] = 0x313D,
    -- [0x11B4] = 0x313E,
    -- [0x11B5] = 0x313F,
    [0x111A] = 0x3140,
    [0x1106] = 0x3141,
    [0x1107] = 0x3142,
    [0x1108] = 0x3143,
    [0x1121] = 0x3144,
    [0x1109] = 0x3145,
    [0x110A] = 0x3146,
    [0x110B] = 0x3147,
    [0x110C] = 0x3148,
    [0x110D] = 0x3149,
    [0x110E] = 0x314A,
    [0x110F] = 0x314B,
    [0x1110] = 0x314C,
    [0x1111] = 0x314D,
    [0x1112] = 0x314E,
    [0x1114] = 0x3165,
    [0x1115] = 0x3166,
    -- [0x11C7] = 0x3167,
    -- [0x11C8] = 0x3168,
    -- [0x11CC] = 0x3169,
    -- [0x11CE] = 0x316A,
    -- [0x11D3] = 0x316B,
    -- [0x11D7] = 0x316C,
    -- [0x11D9] = 0x316D,
    [0x111C] = 0x316E,
    -- [0x11DD] = 0x316F,
    -- [0x11DF] = 0x3170,
    [0x111D] = 0x3171,
    [0x111E] = 0x3172,
    [0x1120] = 0x3173,
    [0x1122] = 0x3174,
    [0x1123] = 0x3175,
    [0x1127] = 0x3176,
    [0x1129] = 0x3177,
    [0x112B] = 0x3178,
    [0x112C] = 0x3179,
    [0x112D] = 0x317A,
    [0x112E] = 0x317B,
    [0x112F] = 0x317C,
    [0x1132] = 0x317D,
    [0x1136] = 0x317E,
    [0x1140] = 0x317F,
    [0x1147] = 0x3180,
    [0x114C] = 0x3181,
    -- [0x11F1] = 0x3182,
    -- [0x11F2] = 0x3183,
    [0x1157] = 0x3184,
    [0x1158] = 0x3185,
    [0x1159] = 0x3186,
  },
  cjung = {
    [0x1161] = 0x314F,
    [0x1162] = 0x3150,
    [0x1163] = 0x3151,
    [0x1164] = 0x3152,
    [0x1165] = 0x3153,
    [0x1166] = 0x3154,
    [0x1167] = 0x3155,
    [0x1168] = 0x3156,
    [0x1169] = 0x3157,
    [0x116A] = 0x3158,
    [0x116B] = 0x3159,
    [0x116C] = 0x315A,
    [0x116D] = 0x315B,
    [0x116E] = 0x315C,
    [0x116F] = 0x315D,
    [0x1170] = 0x315E,
    [0x1171] = 0x315F,
    [0x1172] = 0x3160,
    [0x1173] = 0x3161,
    [0x1174] = 0x3162,
    [0x1175] = 0x3163,
    -- [0x1160] = 0x3164,
    [0x1184] = 0x3187,
    [0x1185] = 0x3188,
    [0x1188] = 0x3189,
    [0x1191] = 0x318A,
    [0x1192] = 0x318B,
    [0x1194] = 0x318C,
    [0x119E] = 0x318D,
    [0x11A1] = 0x318E,
  }
}

local function is_hangul (c)
  return c >= 0xAC00 and c <= 0xD7A3
end

local function is_modern_jong (c)
  return c >= 0x11A8 and c <= 0x11C2
end

local function is_old_jong (c)
  return c >= 0x11C3 and c <= 0x11FF
  or     c >= 0xD7CB and c <= 0xD7FB
end

local function is_jongsong (c)
  return is_modern_jong(c) or is_old_jong(c)
end

local function syllable2jamo (s) -- integer -> table
    local t = {}
    s = s - 0xAC00
    t[1] = s // 588 + 0x1100
    t[2] = s % 588 // 28 + 0x1161
    local jong = s % 28
    if jong ~= 0 then
      t[3] = jong + 0x11A7
    end
    return t
end

local hanguldecompose = normalize.NFD

-- LV | LVT, T  -> L, V, T+
local function flush_syllable_jong (t, s)
  if #s == 2 then
    tableappend(t, syllable2jamo( s[1] ))
    tableinsert(t, s[2])
  else
    tableappend(t, s)
  end
  return t, {}
end

local function compose_hanguldecompose (buffer) -- string -> table
  local t, s = {}, {}
  for _, c in utf8codes(buffer) do
    if #s == 1 and is_jongsong(c) then
      tableinsert(s, c)
    else
      t, s = flush_syllable_jong(t, s)
      tableinsert(is_hangul(c) and s or t, c)
    end
  end
  t = flush_syllable_jong(t, s)
  return t
end

-- L, VF -> CL
local function flush_cjamocho (t, s)
  if #s == 2 then
    tableinsert(t, jamotocjamo.ccho[ s[1] ])
  else
    tableappend(t, s)
  end
  return t, {}
end

local function compose_jamo_chosong (ot)
  local t, s = {}, {}
  for _, c in ipairs(ot) do
    if #s == 1 and c == 0x1160 then
      tableinsert(s, c)
    else
      t, s = flush_cjamocho(t, s)
      tableinsert(jamotocjamo.ccho[c] and s or t, c)
    end
  end
  t = flush_cjamocho(t, s)
  return t
end

-- LF, V, ^T -> CV, ^T
local function flush_cjamojung (t, s)
  if #s == 2 then
    tableinsert(t, jamotocjamo.cjung[ s[2] ])
  else
    tableappend(t, s)
  end
  return t, {}
end

local function compose_jamo_jungsong (ot)
  local t, s = {}, {}
  for _, c in ipairs(ot) do
    if #s == 1 and jamotocjamo.cjung[c] or #s == 2 and is_jongsong(c) then
      tableinsert(s, c)
    else
      t, s = flush_cjamojung(t, s)
      tableinsert(c == 0x115F and s or t, c)
    end
  end
  t = flush_cjamojung(t, s)
  return t
end

local function hangulcompose (buffer)
  buffer = normalize.NFC(buffer)

  local t = compose_hanguldecompose(buffer)
  t = compose_jamo_chosong (t)
  t = compose_jamo_jungsong(t)

  return utf8char(tableunpack(t))
end

local loaded = false
local add_to_callback = luatexbase.add_to_callback
local remove_from_callback = luatexbase.remove_from_callback

local function unload()
  if loaded then
    remove_from_callback('process_input_buffer', 'luatexko.hangul_normalize')
    loaded = false
  end
end
luatexkonormalize.unload = unload

local function compose()
  unload()
  add_to_callback('process_input_buffer', hangulcompose, 'luatexko.hangul_normalize')
  loaded = true
end
luatexkonormalize.compose = compose

local function decompose()
  unload()
  add_to_callback('process_input_buffer', hanguldecompose, 'luatexko.hangul_normalize')
  loaded = true
end
luatexkonormalize.decompose = decompose
