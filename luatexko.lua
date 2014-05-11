-- luatexko.lua
--
-- Copyright (c) 2013-2014 Dohyun Kim  <nomos at ktug org>
--
-- This work may be distributed and/or modified under the
-- conditions of the LaTeX Project Public License, either version 1.3c
-- of this license or (at your option) any later version.
-- The latest version of this license is in
--   http://www.latex-project.org/lppl.txt
-- and version 1.3c or later is part of all distributions of LaTeX
-- version 2006/05/20 or later.

local err,warn,info,log = luatexbase.provides_module({
  name        = 'luatexko',
  date        = '2014/05/11',
  version     = 1.5,
  description = 'Korean linebreaking and font-switching',
  author      = 'Dohyun Kim',
  license     = 'LPPL v1.3+',
})

luatexko        = luatexko or {}
local luatexko  = luatexko

local dotemphnode,rubynode,ulinebox = {},{},{}
luatexko.dotemphnode        = dotemphnode
luatexko.rubynode           = rubynode
luatexko.ulinebox           = ulinebox

local stringbyte    = string.byte
local stringgsub    = string.gsub
local stringchar    = string.char
local stringfind    = string.find
local stringmatch   = string.match
local stringformat  = string.format
local string_sub    = string.sub
local mathfloor     = math.floor
local tex_round     = tex.round
local tex_sp        = tex.sp
local texcount      = tex.count
local fontdefine    = font.define

local kpse_find_file = kpse.find_file

local fontdata = fonts.hashes.identifiers

local remove_node     = node.remove
local insert_before   = node.insert_before
local insert_after    = node.insert_after
local copy_node       = node.copy
local traverse_id     = node.traverse_id
local traverse        = node.traverse
local has_attribute   = node.has_attribute
local unset_attribute = node.unset_attribute
local set_attribute   = node.set_attribute
local nodecount       = node.count
local nodeslide       = node.slide
local nodedimensions  = node.dimensions
local nodetail        = node.tail
local end_of_math     = node.end_of_math
local nodenext        = node.next
local nodeprev        = node.prev

local finemathattr      = luatexbase.attributes.finemathattr
local cjtypesetattr     = luatexbase.attributes.cjtypesetattr
local dotemphattr       = luatexbase.attributes.dotemphattr
local autojosaattr      = luatexbase.attributes.autojosaattr
local luakorubyattr     = luatexbase.attributes.luakorubyattr
local hangulfntattr     = luatexbase.attributes.hangulfntattr
local hanjafntattr      = luatexbase.attributes.hanjafntattr
local fallbackfntattr   = luatexbase.attributes.fallbackfntattr
local hangulpunctsattr  = luatexbase.attributes.hangulpunctsattr
local luakoglueattr     = luatexbase.new_attribute("luakoglueattr")
local luakounicodeattr  = luatexbase.new_attribute("luakounicodeattr")

local add_to_callback = luatexbase.add_to_callback

local gluenode        = node.id("glue")
local gluespecnode    = node.id("glue_spec")
local glyphnode       = node.id("glyph")
local mathnode        = node.id("math")
local hlistnode       = node.id("hlist")
local vlistnode       = node.id("vlist")
local kernnode        = node.id("kern")
local penaltynode     = node.id("penalty")
local rulenode        = node.id("rule")
local whatsitnode     = node.id("whatsit")
local whatsitspecial  = node.subtype("special")

local new_glue      = node.new(gluenode)
local new_glue_spec = node.new(gluespecnode)
local new_penalty   = node.new(penaltynode)
local new_kern      = node.new(kernnode,1)
local new_rule      = node.new(rulenode)

local emsize = 655360

local cjkclass = {
  [0x2018] = 1, -- ‘
  [0x201C] = 1, -- “
  [0xFF08] = 1, -- （
  [0xFE35] = 1, -- （ vert
  [0x3014] = 1, -- 〔
  [0xFE39] = 1, -- 〔 vert
  [0xFF3B] = 1, -- ［
  [0xFE47] = 1, -- ［ vert
  [0xFF5B] = 1, -- ｛
  [0xFE37] = 1, -- ｛ vert
  [0x3008] = 1, -- 〈
  [0xFE3F] = 1, -- 〈 vert
  [0x300A] = 1, -- 《
  [0xFE3D] = 1, -- 《 vert
  [0x300C] = 1, -- 「
  [0xFE41] = 1, -- 「 vert
  [0x300E] = 1, -- 『
  [0xFE43] = 1, -- 『 vert
  [0x3010] = 1, -- 【
  [0xFE3B] = 1, -- 【 vert
  [0x3001] = 2, -- 、
  [0xFE11] = 2, -- 、 vert
  [0xFF0C] = 2, -- ，
  [0xFE10] = 2, -- ， vert
  [0x2019] = 2, -- ’
  [0x201D] = 2, -- ”
  [0xFF09] = 2, -- ）
  [0xFE36] = 2, -- ） vert
  [0x3015] = 2, -- 〕
  [0xFE3A] = 2, -- 〕 vert
  [0xFF3D] = 2, -- ］
  [0xFE48] = 2, -- ］ vert
  [0xFF5D] = 2, -- ｝
  [0xFE38] = 2, -- ｝ vert
  [0x3009] = 2, -- 〉
  [0xFE40] = 2, -- 〉 vert
  [0x300B] = 2, -- 》
  [0xFE3E] = 2, -- 》 vert
  [0x300D] = 2, -- 」
  [0xFE42] = 2, -- 」 vert
  [0x300F] = 2, -- 』
  [0xFE44] = 2, -- 』 vert
  [0x3011] = 2, -- 】
  [0xFE3C] = 2, -- 】 vert
  [0x00B7] = 3, -- ·
  [0x30FB] = 3, -- ・
  [0xFF1A] = 3, -- ：
  [0xFE13] = 3, -- ： vert
  [0xFF1B] = 3, -- ；
  [0xFE14] = 3, -- ； vert
  [0x3002] = 4, -- 。
  [0xFE12] = 4, -- 。 vert
  [0xFF0E] = 4, -- ．
  [0x2015] = 5, --  ―
  [0x2026] = 5, -- …
  [0xFE19] = 5, -- … vert
  [0x2025] = 5, -- ‥
  [0xFE30] = 5, -- ‥ vert
  [0xFF1F] = 6, -- ？
  [0xFF01] = 6, -- ！
}

local inhibitxspcode = {
  [0x002D] = 0, -- - hyphen minus
  [0x003C] = 0, -- <
  [0x003E] = 1, -- >
  [0x00B0] = 1,
  [0x2015] = 0,
  [0x2018] = 2,
  [0x2019] = 1,
  [0x201C] = 2,
  [0x201D] = 1,
  [0x2026] = 0,
  [0xFE19] = 0,
  [0x2032] = 1,
  [0x2033] = 1,
  [0x3001] = 1,
  [0xFE11] = 1,
  [0x3002] = 1,
  [0xFE12] = 1,
  [0x3008] = 2,
  [0xFE3F] = 2,
  [0x3009] = 1,
  [0xFE40] = 1,
  [0x300A] = 2,
  [0xFE3D] = 2,
  [0x300B] = 1,
  [0xFE3E] = 1,
  [0x300C] = 2,
  [0xFE41] = 2,
  [0x300D] = 1,
  [0xFE42] = 1,
  [0x300E] = 2,
  [0xFE43] = 2,
  [0x300F] = 1,
  [0xFE44] = 1,
  [0x3010] = 2,
  [0xFE3B] = 2,
  [0x3011] = 1,
  [0xFE3C] = 1,
  [0x3012] = 2, -- 〒
  [0x3014] = 2,
  [0xFE39] = 2,
  [0x3015] = 1,
  [0xFE3A] = 1,
  [0x301C] = 0,
  [0xFF08] = 2,
  [0xFE35] = 2,
  [0xFF09] = 1,
  [0xFE36] = 1,
  [0xFF0C] = 1,
  [0xFE10] = 1,
  [0xFF0E] = 1,
  [0xFF1B] = 1,
  [0xFE14] = 1,
  [0xFF1F] = 1,
  [0xFF3B] = 2,
  [0xFE47] = 2,
  [0xFF3D] = 1,
  [0xFE48] = 1,
  [0xFF5B] = 2,
  [0xFE37] = 2,
  [0xFF5D] = 1,
  [0xFE38] = 1,
  [0xFFE5] = 0,
}

local postbreakpenalty = {
  [0x0023] = 500,
  [0x0024] = 500,
  [0x0025] = 500,
  [0x0026] = 500,
  [0x0028] = 10000,
  [0x003C] = 10000, -- <
  [0x005B] = 10000,
  [0x0060] = 10000,
  [0x2013] = 50, -- en-dash
  [0x2014] = 50, -- em-dash
  [0x2018] = 10000,
  [0x201C] = 10000,
  [0x3008] = 10000,
  [0xFE3F] = 10000,
  [0x300A] = 10000,
  [0xFE3D] = 10000,
  [0x300C] = 10000,
  [0xFE41] = 10000,
  [0x300E] = 10000,
  [0xFE43] = 10000,
  [0x3010] = 10000,
  [0xFE3B] = 10000,
  [0x3014] = 10000,
  [0xFE39] = 10000,
  [0xFF03] = 200,
  [0xFF04] = 200,
  [0xFF05] = 200,
  [0xFF06] = 200,
  [0xFF08] = 10000,
  [0xFE35] = 10000,
  [0xFF3B] = 10000,
  [0xFE47] = 10000,
  [0xFF40] = 10000,
  [0xFF5B] = 10000,
  [0xFE37] = 10000,
}

local prebreakpenalty = {
  [0x0021] = 10000,
  [0x0022] = 10000,
  [0x0027] = 10000,
  [0x0029] = 10000,
  [0x002A] = 500,
  [0x002B] = 500,
  [0x002C] = 10000,
  [0x002D] = 10000,
  [0x002E] = 10000,
  [0x002F] = 500,
  [0x003A] = 10000,
  [0x003B] = 10000,
  [0x003E] = 10000, -- >
  [0x003F] = 10000,
  [0x005D] = 10000,
  [0x00B4] = 10000,
  [0x00B7] = 10000, -- ·
  [0x2013] = 10000, -- –
  [0x2014] = 10000, -- —
  [0x2015] = 10000,
  [0x2019] = 10000,
  [0x201D] = 10000,
  [0x2025] = 250,
  [0xFE30] = 250,
  [0x2026] = 250,
  [0xFE19] = 250,
  [0x2212] = 200,
  [0x3001] = 10000,
  [0xFE11] = 10000,
  [0x3002] = 10000,
  [0xFE12] = 10000,
  [0x3005] = 10000,
  [0x3009] = 10000,
  [0xFE40] = 10000,
  [0x300B] = 10000,
  [0xFE3E] = 10000,
  [0x300D] = 10000,
  [0xFE42] = 10000,
  [0x300F] = 10000,
  [0xFE44] = 10000,
  [0x3011] = 10000,
  [0xFE3C] = 10000,
  [0x3015] = 10000,
  [0xFE3A] = 10000,
  [0x3041] = 150,
  [0x3043] = 150,
  [0x3045] = 150,
  [0x3047] = 150,
  [0x3049] = 150,
  [0x3063] = 150,
  [0x3083] = 150,
  [0x3085] = 150,
  [0x3087] = 150,
  [0x308E] = 150,
  [0x309B] = 10000,
  [0x309C] = 10000,
  [0x30A1] = 150,
  [0x30A3] = 150,
  [0x30A5] = 150,
  [0x30A7] = 150,
  [0x30A9] = 150,
  [0x30C3] = 150,
  [0x30E3] = 150,
  [0x30E5] = 150,
  [0x30E7] = 150,
  [0x30EE] = 150,
  [0x30F5] = 150,
  [0x30F6] = 150,
  [0x30FB] = 10000,
  [0x30FC] = 10000,
  [0xFF01] = 10000,
  [0xFF09] = 10000,
  [0xFE36] = 10000,
  [0xFF0B] = 200,
  [0xFF0C] = 10000,
  [0xFE10] = 10000,
  [0xFF0E] = 10000,
  [0xFF1A] = 10000,
  [0xFE13] = 10000,
  [0xFF1B] = 10000,
  [0xFE14] = 10000,
  [0xFF1D] = 200,
  [0xFF1F] = 10000,
  [0xFF3D] = 10000,
  [0xFE48] = 10000,
  [0xFF5D] = 10000,
  [0xFE38] = 10000,
}

local xspcode = {
  [0x0027] = 2,
  [0x0028] = 1,
  [0x0029] = 2,
  [0x002C] = 2,
  [0x002E] = 2,
  [0x003B] = 2,
  [0x005B] = 1,
  [0x005D] = 2,
  [0x0060] = 1,
}

local cjk_glue_spec = { [0] =
--     한자      (         )         ·         .         —         ?         한글      초성      중종성    latin
{[0] = nil,      {.5,.5},  nil,      {.25,.25},nil,      nil,      nil,      nil,      nil,      nil,      nil,      }, --한자
{[0] = nil,      nil,      nil,      {.25,.25},nil,      nil,      nil,      nil,      nil,      nil,      nil,      }, -- (
{[0] = {.5,.5},  {.5,.5},  nil,      {.25,.25},nil,      {.5,.5},  {.5,.5},  {.25,.25},{.25,.25},{.25,.25},{.5,.5},  }, -- )
{[0] = {.25,.25},{.25,.25},{.25,.25},{.5,.25}, {.25,.25},{.25,.25},{.25,.25},{.25,.25},{.25,.25},{.25,.25},{.25,.25},}, -- ·
{[0] = {.5,0},   {.5,0},   nil,      {.75,.25},nil,      {.5,0},   {.5,0},   {.5,0},   {.5,0},   {.5,0},   {.5,0},   }, -- .
{[0] = nil,      {.5,.5},  nil,      {.25,.25},nil,      nil,      nil,      nil,      nil,      nil,      nil,      }, -- —
{[0] = {.5,.5},  {.5,.5},  nil,      {.25,.25},nil,      nil,      nil,      {.5,.5},  {.5,.5},  {.5,.5},  {.5,.5},  }, -- ?
--
{[0] = nil,      {.25,.25},nil,      {.25,.25},nil,      nil,      nil,      nil,      nil,      nil,      nil,      }, --한글
{[0] = nil,      {.25,.25},nil,      {.25,.25},nil,      nil,      nil,      nil,      nil,      nil,      nil,      }, --초성
{[0] = nil,      {.25,.25},nil,      {.25,.25},nil,      nil,      nil,      nil,      nil,      nil,      nil,      }, --중종성
{[0] = nil,      {.5,.5},  nil,      {.25,.25},nil,      nil,      nil,      nil,      nil,      nil,      nil,      }, --latin
}

local latin_fullstop = {
  [0x2e] = 1, -- .
  --  [0x21] = 2, -- !
  --  [0x2c] = 2, -- ,
  --  [0x3f] = 2, -- ?
  --  [0x2026] = 1, -- \ldots
}

local hangulpunctuations = luatexko.hangulpunctuations or {
  [0x21] = true, -- !
  [0x27] = true, -- '
  [0x28] = true, -- (
  [0x29] = true, -- )
  [0x2C] = true, -- ,
  -- [0x2D] = true, -- -
  [0x2E] = true, -- .
  [0x3A] = true, -- :
  [0x3B] = true, -- ;
  [0x3C] = true, -- <
  [0x3E] = true, -- >
  [0x3F] = true, -- ?
  [0x5B] = true, -- [
  [0x5D] = true, -- ]
  [0x60] = true, -- `
  [0x7B] = true, -- {
  [0x7D] = true, -- }
  [0xB7] = true, -- periodcentered
  -- [0x2014] = true, -- emdash
  -- [0x2015] = true, -- horizontal bar
  [0x2018] = true, -- quoteleft
  [0x2019] = true, -- quoteright
  [0x201C] = true, -- quotedblleft
  [0x201D] = true, -- quotedblright
  [0x2026] = true, -- ellipsis
  [0x203B] = true, -- ※
}
luatexko.hangulpunctuations = hangulpunctuations

local josa_list = {
  --          리을,   중성,   종성
  [0xAC00] = {0xC774, 0xAC00, 0xC774}, -- 가 = 이, 가, 이
  [0xC740] = {0xC740, 0xB294, 0xC740}, -- 은 = 은, 는, 은
  [0xC744] = {0xC744, 0xB97C, 0xC744}, -- 을 = 을, 를, 을
  [0xC640] = {0xACFC, 0xC640, 0xACFC}, -- 와 = 과, 와, 과
  [0xC73C] = {-1,     -1,     0xC73C}, -- 으(로) =   ,  , 으
  [0xC774] = {0xC774, -1,     0xC774}, -- 이(라) = 이,  , 이
}

local josa_code = {
  [0x30]    = 3, -- 0
  [0x31]    = 1, -- 1
  [0x33]    = 3, -- 3
  [0x36]    = 3, -- 6
  [0x37]    = 1, -- 7
  [0x38]    = 1, -- 8
  [0x4C]    = 1, -- L
  [0x4D]    = 3, -- M
  [0x4E]    = 3, -- N
  [0x6C]    = 1, -- l
  [0x6D]    = 3, -- m
  [0x6E]    = 3, -- n
  [0xFB02]  = 1, -- ﬂ
  [0xFB04]  = 1, -- ﬄ
  ng        = 3,
  ap        = 3,
  up        = 3,
  at        = 3,
  et        = 3,
  it        = 3,
  ot        = 3,
  ut        = 3,
  ok        = 3,
  ic        = 3,
  le        = 1,
  ime       = 3,
  ine       = 3,
  ack       = 3,
  ick       = 3,
  oat       = 2,
  TEX       = 3,
  -- else 2
}

local function get_gluenode (w,st,sh)
  local g = copy_node(new_glue)
  local s = copy_node(new_glue_spec)
  s.width, s.stretch, s.shrink = w or 0, st or 0, sh or 0
  g.spec = s
  return g
end

local function get_penaltynode (n)
  local p = copy_node(new_penalty)
  p.penalty = n or 0
  return p
end

local function get_kernnode (n)
  local k = copy_node(new_kern)
  k.kern = n or 0
  return k
end

local function get_rulenode (w,h,d)
  local r = copy_node(new_rule)
  r.width, r.height, r.depth = w or 0, h or 0, d or 0
  return r
end

local function make_luako_glue(...)
  local glue = get_gluenode(...)
  set_attribute(glue,luakoglueattr,1)
  return glue
end

local function is_cjk_k (c)
  return (c >= 0x2E80  and c <= 0x9FFF )
  or (c >= 0xF900  and c <= 0xFAFF )
  or (c >= 0xFE10  and c <= 0xFE1F )
  or (c >= 0xFE30  and c <= 0xFE4F )
  or (c >= 0xFF00  and c <= 0xFFEF )
  or (c >= 0x20000 and c <= 0x2A6DF)
  or (c >= 0x2F800 and c <= 0x2FA1F)
  or  c == 0x00B0  or  c == 0x2015
  --  or  c == 0x2018  or  c == 0x2019
  --  or  c == 0x201C  or  c == 0x201D
  or  c == 0x2026  or  c == 0x2032
  or  c == 0x2033
end

local function is_hanja (c)
  return (c >= 0x3400 and c <= 0x9FFF )
  or (c >= 0xF900 and c <= 0xFAFF )
  or (c >= 0x20000 and c <= 0x2A6DF)
  or (c >= 0x2F800 and c <= 0x2FA1F)
end

local function is_hangul (c)
  return (c >= 0xAC00 and c <= 0xD7A3)
end

local function is_chosong (c)
  return (c >= 0x1100 and c <= 0x115F)
  or (c >= 0xA960 and c <= 0xA97C)
end

local function is_jungjongsong (c)
  return (c >= 0x1160 and c <= 0x11FF)
  or (c >= 0xD7B0 and c <= 0xD7Fb)
  or c == 0x302E  or  c == 0x302F -- tone marks
end

local function is_unicode_vs (c)
  return (c >= 0xFE00  and c <= 0xFE0F )
      or (c >= 0xE0100 and c <= 0xE01EF)
end

local function get_cjk_class (ch, cjtype)
  if ch then
    if is_hangul(ch) then return 7 end        -- hangul = 7
    if is_chosong(ch) then return 8 end       -- jamo LC = 8
    if is_jungjongsong(ch) then return 9 end  -- jamo VL, TC, TM = 9
    local c = is_cjk_k(ch) and 0 or 10        -- hanja = 0; latin = 10
    if cjkclass[ch] then c = cjkclass[ch] end -- cjkclass 1 .. 6
    if cjtype then
      if cjtype == 2 and
        (ch == 0xFF1F or ch == 0xFF01 or ch == 0xFF1A or ch == 0xFF1B) then
        c = 4 -- simplified chinese ？ ！
      end
    else
      if ch == 0x2018 or ch == 0x2019 or ch == 0x201C or ch == 0x201D then
        c = 10 -- korean “ ” ‘ ’
      end
    end
    return c
  end
end

local function get_font_table (fid)
  if fid then
    if fontdata[fid] then
      return fontdata[fid]
    else
      return font.fonts[fid]
    end
  end
end

local function get_font_char (fid, chr)
  local f = get_font_table(fid)
  return chr and f and f.characters and f.characters[chr]
end

local function get_font_emsize(fid)
  local f = get_font_table(fid)
  return (f and f.parameters and f.parameters.quad) or emsize
end

local function get_font_feature (fid, name)
  local f = get_font_table(fid)
  return f and f.shared and f.shared.features and f.shared.features[name]
end

local function get_char_boundingbox(fid, chr)
  local f = get_font_table(fid)
  local glbox = f and f.shared
  glbox = glbox and glbox.rawdata
  glbox = glbox and glbox.descriptions
  glbox = glbox and glbox[chr] and glbox[chr].boundingbox
  if glbox then
    local factor, bbox = f.parameters and f.parameters.factor or 655.36, {}
    for i,v in ipairs(glbox) do
      bbox[i] = v * factor
    end
    return bbox
  end
end

local function get_unicode_char(curr)
  local uni = curr.char
  if (uni > 0xFF and uni < 0xE000) or (uni > 0xF8FF and uni < 0xF0000) then
    return uni -- no pua. no nanumgtm??
  end
  -- tounicode is now reliable. backend is fixed
  uni = get_font_char(curr.font, curr.char)
  uni = uni and uni.tounicode
  uni = uni and string_sub(uni,1,4) -- seems ok for old hangul
  if uni then return tonumber(uni,16) end
  uni = has_attribute(curr, luakounicodeattr)
  if uni then return uni end
  return curr.char
end

local function get_hlist_class_first (hlist)
  local curr = hlist.head
  while curr do
    if curr.id == glyphnode then
      local c,f = get_unicode_char(curr), curr.font
      if c then return c,f end
    elseif curr.id == hlistnode or curr.id == vlistnode then
      local c,f = get_hlist_class_first(curr)
      if c then return c,f end
    elseif curr.id == gluenode then
      if curr.spec and curr.spec.width ~= 0 then return end
    end
    curr = nodenext(curr)
  end
end

local function get_hlist_class_last (hlist,prevchar,prevfont)
  local curr = nodeslide(hlist.head)
  while curr do
    if curr.id == glyphnode then
      local c,f = get_unicode_char(curr), curr.font
      if c then return c,f end
    elseif curr.id == hlistnode or curr.id == vlistnode then
      local c,f = get_hlist_class_last(curr)
      if c then return c,f end
    elseif curr.id == gluenode then
      if curr.spec and curr.spec.width ~= 0 then return end
    end
    curr = nodeprev(curr)
  end
  return prevchar, prevfont
end

----------------------------
-- cjk linebreak and spacing
----------------------------
local function kanjiskip (head,curr)
  insert_before(head,curr,make_luako_glue(0, emsize*0.1, emsize*0.02))
end

local function xkanjiskip (head,curr)
  if has_attribute(curr,finemathattr) == 0 then -- ttfamily
    kanjiskip(head,curr)
  else
    insert_before(head,curr,make_luako_glue(0.25*emsize, emsize*0.15, emsize*0.06))
  end
end

local function interhangulskip (head,curr,currfont,prevfont,was_penalty)
  local width = 0
  local interhangul = get_font_feature(currfont, "interhangul")
  if interhangul and currfont == prevfont then
    width = tex_sp(interhangul)
  end
  if not was_penalty then
    insert_before(head,curr,get_penaltynode(50))
  end
  insert_before(head,curr,make_luako_glue(width, emsize*0.04, emsize*0.02))
end

local function interhanjaskip (head,curr,was_penalty)
  if not was_penalty then
    insert_before(head,curr,get_penaltynode(50))
  end
  insert_before(head,curr,make_luako_glue(0, emsize*0.04, emsize*0.02))
end

local function koreanlatinskip (head,curr,currfont,prevfont,was_penalty)
  local width = 0 -- default: 0em
  if (has_attribute(curr,finemathattr) or 0) > 0 then -- not ttfamily
    local latincjk = get_font_feature(currfont, "interlatincjk")
    if not latincjk then
      latincjk = get_font_feature(prevfont, "interlatincjk")
    end
    if latincjk then
      width = tex_sp(latincjk)
    end
  end
  if not was_penalty then
    insert_before(head,curr,get_penaltynode(50))
  end
  insert_before(head,curr,make_luako_glue(width, emsize*0.04, emsize*0.02))
end

local function cjk_insert_nodes(head,curr,currchar,currfont,prevchar,prevfont)
  local was_penalty = false
  local currentcjtype = has_attribute(curr,cjtypesetattr)
  local p = get_cjk_class(prevchar, currentcjtype)
  local c = get_cjk_class(currchar, currentcjtype)
  ---[[raise latin puncts
  if curr.id == glyphnode and (has_attribute(curr,finemathattr) or 0) > 0 and c < 10 then -- not ttfamily
    local nn, raise = nodenext(curr), nil
    while nn do
      if nn.id == glyphnode and latin_fullstop[nn.char] then
        if not raise then
          raise = get_font_feature(currfont, "punctraise")
          raise = raise and tex_sp(raise)
        end
        if raise then
          nn.yoffset = (nn.yoffset or 0) + raise
        end
        nn = nodenext(nn)
      elseif nn.id == kernnode then
        nn = nodenext(nn)
      else
        break
      end
    end
  end
  --raise latin puncts]]
  if prebreakpenalty[currchar] then
    was_penalty = true
    insert_before(head,curr,get_penaltynode(prebreakpenalty[currchar]))
  elseif postbreakpenalty[prevchar] then
    was_penalty = true
    insert_before(head,curr,get_penaltynode(postbreakpenalty[prevchar]))
  end
  ---[[ kern is a breakpoint if followed by a glue: protrusion and compress_fullwidth_punctuations
  if (c and c == 1) or (p and p >= 2 and p <= 6) then was_penalty = true end
  --]]
  if p and c then
    if currentcjtype then
      if cjk_glue_spec[p] and cjk_glue_spec[p][c] then
        local width   = emsize * cjk_glue_spec[p][c][1]
        local stretch = 0
        local shrink  = emsize * cjk_glue_spec[p][c][2]
        insert_before(head,curr,make_luako_glue(width, stretch, shrink))
      elseif p < 10 and c < 9 then -- break between chosong and chosong
        kanjiskip(head,curr)
      elseif (p < 10 and c == 10) or (p == 10 and c < 10) then
        if xspcode[currchar] then
          if xspcode[currchar] % 2 == 1 then
            xkanjiskip(head,curr)
          end
        elseif xspcode[prevchar] then
          if xspcode[prevchar] > 1 then
            xkanjiskip(head,curr)
          end
        elseif inhibitxspcode[currchar] then -- 3, 2
          if inhibitxspcode[currchar] > 1 then
            xkanjiskip(head,curr)
          end
        elseif inhibitxspcode[prevchar] then -- 3, 1
          if inhibitxspcode[prevchar] % 2 == 1 then
            xkanjiskip(head,curr)
          end
        else
          xkanjiskip(head,curr)
        end
      end
    else
      if (p < 10 and c == 10) or (p == 10 and c < 10) then
        if xspcode[currchar] then
          if xspcode[currchar] % 2 == 1 then
            koreanlatinskip(head,curr,currfont,prevfont,was_penalty)
          end
        elseif xspcode[prevchar] then
          if xspcode[prevchar] > 1 then
            koreanlatinskip(head,curr,currfont,prevfont,was_penalty)
          end
        elseif inhibitxspcode[currchar] then -- 3, 2
          if inhibitxspcode[currchar] > 1 then
            koreanlatinskip(head,curr,currfont,prevfont,was_penalty)
          end
        elseif inhibitxspcode[prevchar] then -- 3, 1
          if inhibitxspcode[prevchar] % 2 == 1 then
            koreanlatinskip(head,curr,currfont,prevfont,was_penalty)
          end
        else
          koreanlatinskip(head,curr,currfont,prevfont,was_penalty)
        end
      elseif cjk_glue_spec[p] and cjk_glue_spec[p][c] then
        koreanlatinskip(head,curr,currfont,prevfont,was_penalty)
      elseif p == 7 and c == 7 then
        interhangulskip(head,curr,currfont,prevfont,was_penalty)
      elseif p < 10 and c < 9 then -- break between chosong and chosong
        interhanjaskip(head,curr,was_penalty)
      end
    end
  end
  return currchar,currfont
end

local function cjk_spacing_linebreak (head)
  local prevchar,prevfont = nil,nil
  local curr = head
  while curr do
    if has_attribute(curr,finemathattr) then
      if curr.id == gluenode then
        prevchar,prevfont = nil,nil
        unset_attribute(curr,finemathattr)
      elseif curr.id == glyphnode then
        emsize = get_font_emsize(curr.font)
        local uni = get_unicode_char(curr)
        if uni then
          prevchar,prevfont = cjk_insert_nodes(head,curr,uni,curr.font,prevchar,prevfont)
        end
        unset_attribute(curr,finemathattr)
      elseif curr.id == mathnode then
        local currchar = 0
        if curr.surround and curr.surround > 0 then
          currchar = 0x4E00
        end
        if curr.subtype == 0 then
          cjk_insert_nodes(head,curr,currchar,nil,prevchar,prevfont)
          curr = end_of_math(curr)
          if not curr then break end
          prevchar,prevfont = currchar,nil
        end
        unset_attribute(curr,finemathattr)
      elseif curr.id == hlistnode or curr.id == vlistnode then
        local firstchr, firstfid = get_hlist_class_first(curr)
        if firstchr then
          cjk_insert_nodes(head,curr,firstchr,firstfid,prevchar,prevfont)
        end
        prevchar,prevfont = get_hlist_class_last(curr,prevchar,prevfont)
        unset_attribute(curr,finemathattr)
      end
    else
      prevchar,prevfont = 0,nil -- treat \verb as latin character.
    end
    curr = nodenext(curr)
  end
end

------------------------------------
-- remove japanese/chinese spaceskip
------------------------------------
local function remove_cj_spaceskip (head)
  local curr, prevfont = head, nil
  while curr do
    if curr.id == mathnode and curr.subtype == 0 then
      curr = end_of_math(curr)
    elseif curr.id == gluenode then
      local cjattr = has_attribute(curr,cjtypesetattr)
      local prv, nxt = nodeprev(curr), nodenext(curr)
      if cjattr and cjattr > 0 and prv and nxt then
        local prevclass, prevchar, nextclass
        if prv.id == hlistnode or prv.id == vlistnode then
          prevclass = get_hlist_class_last(prv)
        else
          -- what is this strange kern before \text??
          if prv.id == kernnode and prv.kern == 0 then
            prv = nodeprev(prv)
          end
          if prv.id == glyphnode then
            prevclass = get_cjk_class(get_unicode_char(prv), cjattr)
            prevchar, prevfont = prv.char, prv.font
          end
        end
        if nxt.id == glyphnode then
          nextclass = get_cjk_class(get_unicode_char(nxt), cjattr)
        elseif nxt.id == hlistnode or nxt.id == vlistnode then
          nextclass = get_hlist_class_first(nxt)
        end
        if (prevclass and prevclass < 10) or (nextclass and nextclass < 10) then
          local subtype = curr.subtype
          if subtype == 13 then -- do not touch on xspaceskip for now
            remove_node(head,curr)
          else -- before \text?? spaceskip is replaced by glue type 0
            local spec = curr.spec
            local csp = spec and spec.width
            local cst = spec and spec.stretch
            local csh = spec and spec.shrink
            local fp = get_font_table(prevfont)
            fp = fp and fp.parameters
            local sp = fp and fp.space
            local st = fp and fp.space_stretch
            local sh = fp and fp.space_shrink
            sp = sp and tex_round(sp)
            st = st and tex_round(st)
            sh = sh and tex_round(sh)
            if prevchar and prevchar >= 65 and prevchar <= 90 then
              st = st and mathfloor(st*(999/1000))
              sh = sh and mathfloor(sh*(1001/1000))
            end
            if sp == csp and st == cst and sh == csh then
              remove_node(head,curr)
            end
          end
        end
      end
    end
    curr = nodenext(curr)
  end
end

----------------------------------
-- compress fullwidth punctuations
----------------------------------
local function compress_fullwidth_punctuations (head)
  for curr in traverse_id(glyphnode,head) do
    if get_font_feature(curr.font,'halt') or get_font_feature(curr.font,'vhal') then
    else
      local uni = get_unicode_char(curr)
      local class = uni and get_cjk_class(uni, has_attribute(curr, cjtypesetattr))
      local chr = get_font_char(curr.font, curr.char)
      if chr and class and class >= 1 and class <= 4 then
        local width = curr.width or 655360
        emsize = get_font_emsize(curr.font)
        local ensize = emsize/2
        local oneoften = emsize/10
        local bbox = get_char_boundingbox(curr.font, curr.char)
        bbox = bbox or {ensize-oneoften, ensize-oneoften, ensize+oneoften, ensize+oneoften}
        if class == 2 or class == 4 then
          local wd
          if get_font_feature(curr.font,'vertical') then
            wd = ensize<width and ensize-width or 0
          else
            wd = (bbox[3] < ensize) and ensize-width or bbox[3]-width+oneoften
          end
          if chr.right_protruding then
            -- kern is a breakpoint if followed by a glue
            insert_after(head, curr, get_kernnode(wd))
          else
            insert_after(head, curr, get_rulenode(wd))
          end
        elseif class == 1 then
          local wd
          if get_font_feature(curr.font,'vertical') then
            wd = ensize<width and ensize-width or 0
          else
            wd = (width-bbox[1] < ensize) and ensize-width or -bbox[1]+oneoften
          end
          if chr.left_protruding then
            head = insert_before(head, curr, get_kernnode(wd))
          else
            head = insert_before(head, curr, get_rulenode(wd))
          end
        elseif class == 3 then
          local lwd, rwd
          local quarter, thirdquarter, halfwd = ensize/2, ensize*1.5, width/2
          if get_font_feature(curr.font,'vertical') then
            rwd = quarter<halfwd and quarter-halfwd or 0
            lwd = rwd
          else
            rwd = (bbox[3] < thirdquarter) and quarter-halfwd or bbox[3]-width
            lwd = (width-bbox[1] < thirdquarter) and quarter-halfwd or -bbox[1]
          end
          if chr.left_protruding then
            head = insert_before(head, curr, get_kernnode(lwd))
          else
            head = insert_before(head, curr, get_rulenode(lwd))
          end
          if chr.right_protruding then
            insert_after (head, curr, get_kernnode(rwd))
          else
            insert_after (head, curr, get_rulenode(rwd))
          end
        end
      end
    end
  end
  return head -- should be returned!
end

------------------------------
-- ruby: pre-linebreak routine
------------------------------
local function spread_ruby_box(head,extrawidth)
  for curr in traverse_id(gluenode,head) do
    if curr.spec then
      if has_attribute(curr,luakoglueattr) then
        curr.spec.width = curr.spec.width + extrawidth
      else
        head = insert_before(head,curr,get_kernnode(curr.spec.width+extrawidth))
        head = remove_node(head,curr)
      end
    end
  end
  return head
end

local function spread_ruby_base_box (head)
  for curr in traverse_id(hlistnode,head) do
    local attr = has_attribute(curr,luakorubyattr)
    local rubyoverlap = attr and rubynode[attr][3]
    if attr and not rubyoverlap then
      local ruby = rubynode[attr][1]
      if ruby and ruby.width > curr.width then
        local basehead = curr.head
        local numofglues = nodecount(gluenode,basehead)
        local extrawidth = (ruby.width - curr.width)/(numofglues + 1)
        if numofglues > 0 then
          basehead = spread_ruby_box(basehead,extrawidth)
        end
        local leading  = get_kernnode(extrawidth/2)
        curr.width = ruby.width
        leading.next = basehead
        curr.head = leading
      end
    end
  end
end

local function get_ruby_side_width (basewidth,rubywidth,adjacent)
  local width,margin = (rubywidth-basewidth)/2, 0
  if adjacent then
    if adjacent.id == glyphnode then
      if not is_hanja(get_unicode_char(adjacent)) then
        width = (rubywidth-basewidth-emsize)/2
        if width > 0 then
          margin = emsize/2
        else
          width,margin = 0,(rubywidth-basewidth)/2
        end
      end
    end
  end
  return width,margin
end

local function get_ruby_side_kern (head)
  for curr in traverse_id(hlistnode,head) do
    local attr = has_attribute(curr,luakorubyattr)
    local rubyoverlap = attr and rubynode[attr][3]
    if rubyoverlap then
      local basewidth = curr.width
      local rubywidth = rubynode[attr][1].width
      if curr.width < rubywidth then
        local _,fid = get_hlist_class_first(curr)
        emsize = get_font_emsize(fid)
        local leftwidth,leftmargin = get_ruby_side_width(basewidth,rubywidth,nodeprev(curr))
        if leftwidth > 0 then
          curr.width = curr.width + leftwidth
        end
        if leftmargin > 0 then
          rubynode[attr].leftmargin = leftmargin
        end
        local rightwidth,rightmargin = get_ruby_side_width(basewidth,rubywidth,nodenext(curr))
        if rightwidth > 0 then
          curr.width = curr.width + rightwidth
        end
        if rightmargin > 0 then
          rubynode[attr].rightmargin = rightmargin
        end
        rubynode[attr].rightshift = rightwidth - leftwidth
        local totalspace = leftwidth+rightwidth
        if totalspace > 0 then
          local numofglues = nodecount(gluenode,curr.head)
          local extrawidth = totalspace/(numofglues + 1)
          if numofglues > 0 then
            curr.head = spread_ruby_box(curr.head,extrawidth)
          end
          local leading = get_kernnode(extrawidth*(leftwidth/totalspace))
          leading.next = curr.head
          curr.head = leading
        end
      end
    end
  end
end

local function zero_width_rule_with_dir (head,curr,before)
  local rule = get_rulenode(0)
  rule.dir = curr.dir
  if before then
    head = insert_before(head,curr,rule)
  else
    insert_after(head,curr,rule)
  end
  return head
end

local function no_ruby_at_margin(head)
  for curr in traverse_id(hlistnode,head) do
    local attr = has_attribute(curr,luakorubyattr)
    if attr then
      local margin = rubynode[attr].leftmargin
      if margin then
        head = insert_before(head,curr,get_kernnode(-margin))
        head = zero_width_rule_with_dir(head,curr,true) -- before
        head = insert_before(head,curr,get_kernnode(margin))
      end
      margin = rubynode[attr].rightmargin
      if margin then
        local nn = nodenext(curr)
        if nn then
          if nn.id == gluenode then
            insert_after(head,curr,get_kernnode(-margin))
            head = zero_width_rule_with_dir(head,curr)
            insert_after(head,curr,get_kernnode(margin))
          elseif nn.id == penaltynode and nn.penalty < 10000 then
            insert_after(head,nn,get_kernnode(-margin))
            head = zero_width_rule_with_dir(head,curr)
            insert_after(head,curr,get_kernnode(margin))
          end
        end
      end
    end
  end
  return head
end

------------------------------
-- discourage character orphan
------------------------------
local function inject_char_widow_penalty (head,curr,uni,cjattr)
  if uni and prebreakpenalty[uni] ~= 10000 then
    local class = get_cjk_class(uni, cjattr)
    if class and class < 9 then
      local pv =  cjattr and 500 or 5000
      local np = nodeprev(curr)
      if np and np.id == rulenode then
        curr = np; np = nodeprev(curr)
      end
      if np and np.id == gluenode then
        curr = np; np = nodeprev(curr)
      end
      if np and np.id == penaltynode then
        curr = np
        if curr.penalty < pv then
          curr.penalty = pv
        end
      elseif curr and curr.id == gluenode then
        head, curr = insert_before(head,curr,get_penaltynode(pv))
      end
    end
  end
  return curr
end

local function discourage_char_widow (head,curr)
  while curr do
    if curr == head then return end
    if curr.id == glyphnode then
      emsize = get_font_emsize(curr.font)
      local remwd = node.dimensions(curr)
      if remwd > 2*emsize then return end
      local cjattr = has_attribute(curr,cjtypesetattr)
      local uni = get_unicode_char(curr)
      curr = inject_char_widow_penalty(head,curr,uni,cjattr)
    elseif curr.id == hlistnode and curr.id == vlistnode then
      local remwd = node.dimensions(curr)
      local uni,fid = get_hlist_class_first(curr)
      emsize = get_font_emsize(fid)
      if remwd > 2*emsize then return end
      local cjattr = has_attribute(curr,cjtypesetattr)
      curr = inject_char_widow_penalty(head,curr,uni,cjattr)
    end
    curr = nodeprev(curr)
  end
end

---------------------------
-- automatic josa selection
---------------------------
local function syllable2jamo (code)
  local code = code - 0xAC00
  local L = 0x1100 + mathfloor(code / 588)
  local V = 0x1161 + mathfloor((code % 588) / 28)
  local T = 0x11A7 + code % 28
  if T == 0x11A7 then T = nil end
  return L, V, T
end

local function number2josacode (n)
  n = n % 10 + stringbyte("0")
  if josa_code[n] then return josa_code[n] end
  return nil -- 2
end

local function latin2josacode (n)
  n = n + stringbyte("a")
  if josa_code[n] then return josa_code[n] end
  return nil -- 2
end

for c = 0x2160, 0x216B do -- Ⅰ
  josa_code[c] = number2josacode(c - 0x215F)
end
for c = 0x2170, 0x217B do -- ⅰ
  josa_code[c] = number2josacode(c - 0x216F)
end
for c = 0x2460, 0x2473 do -- ①
  josa_code[c] = number2josacode(c - 0x245F)
end
for c = 0x2474, 0x2487 do -- ⑴
  josa_code[c] = number2josacode(c - 0x2473)
end
for c = 0x2488, 0x249B do -- ⒈
  josa_code[c] = number2josacode(c - 0x2487)
end
for c = 0x249C, 0x24B5 do -- ⒜
  josa_code[c] = latin2josacode(c - 0x249C)
end
for c = 0x24B6, 0x24CF do --  Ⓐ
  josa_code[c] = latin2josacode(c - 0x24B6)
end
for c = 0x24D0, 0x24E9 do --  ⓐ
  josa_code[c] = latin2josacode(c - 0x24D0)
end
for c = 0x3131, 0x314E do -- ㄱ
  josa_code[c] = 3
end
josa_code[0x3139] = 1 -- ㄹ
for c = 0x3165, 0x3186 do
  josa_code[c] = 3
end
for c = 0x3200, 0x320D do -- ㈀
  josa_code[c] = 3
end
josa_code[0x3203] = 1 -- ㈃
for c = 0x3260, 0x327F do -- ㉠
  josa_code[c] = 3
end
josa_code[0x3263] = 1 -- ㉣
for c = 0xFF10, 0xFF19 do -- ０
  josa_code[c] = number2josacode(c - 0xFF10)
end
for c = 0xFF21, 0xFF3A do -- Ａ
  josa_code[c] = latin2josacode(c - 0xFF21)
end
for c = 0xFF41, 0xFF5A do -- ａ
  josa_code[c] = latin2josacode(c - 0xFF41)
end

local function jamo2josacode(code)
  if code and code > 0x11A7 then
    if code == 0x11AF then return 1 end
    return 3
  end
  return 2
end

local function get_hanja_hangul_table (table,file,init)
  local i = 0
  local file = kpse_find_file(file)
  if not file then return table end
  file = io.open(file, "r")
  if not file then return table end
  while true do
    local d = file:read("*number")
    if not d then break end
    table[init + i] = d
    i = i + 1
  end
  file:close()
  return table
end

local hanja2hangul = { }
hanja2hangul = get_hanja_hangul_table(hanja2hangul,"hanja_hangul.tab",0x4E00)
hanja2hangul = get_hanja_hangul_table(hanja2hangul,"hanjaexa_hangul.tab",0x3400)
hanja2hangul = get_hanja_hangul_table(hanja2hangul,"hanjacom_hangul.tab",0xF900)

-- 1 : 리을,  2 : 중성,    3 : 종성
local function get_josacode (prevs)
  local code = prevs[1] -- last char
  if not code then return 2 end
  if is_hangul(code) then -- hangul syllable
    local _, _, T = syllable2jamo(code)
    return jamo2josacode(T)
  end
  if is_jungjongsong(code) then return jamo2josacode(code) end
  if (code >= 0x3400 and code <= 0x9FA5)
    or (code >= 0xF900 and code <= 0xFA2D) then
    local _, _, T = syllable2jamo(hanja2hangul[code])
    return jamo2josacode(T)
  end
  -- latin
  if prevs[1] < 0x80
    and prevs[2] and prevs[2] < 0x80
    and prevs[3] and prevs[3] < 0x80 then
    local liii = stringchar(prevs[3], prevs[2], prevs[1])
    if josa_code[liii] then return josa_code[liii] end
  end
  if prevs[1] < 0x80
    and prevs[2] and prevs[2] < 0x80 then
    local lii = stringchar(prevs[2], prevs[1])
    if josa_code[lii] then return josa_code[lii] end
  end
  if josa_code[code] then return josa_code[code] end
  return 2
end

local function get_josaprevs(curr,josaprev,ignoreparens,halt)
  if type(halt) ~= "number" then halt = 0 end
  while curr do
    if curr.id == glyphnode then
      local chr = get_unicode_char(curr)
      -- ignore chars inside parentheses (KTS workshop 2013.11.09)
      if ignoreparens and chr == 0x29 then -- right parenthesis
        halt = halt + 1
      elseif ignoreparens and chr == 0x28 then -- left parenthesis
        halt = halt - 1
      elseif xspcode[chr]
        or inhibitxspcode[chr]
        or prebreakpenalty[chr]
        or postbreakpenalty[chr]
        or chr == 0x302E  -- tone mark
        or chr == 0x302F then  -- tone mark
        --skip
      elseif halt <= 0 then
        josaprev[#josaprev + 1] = chr
      end
    elseif curr.id == hlistnode or curr.id == vlistnode then
      josaprev = get_josaprevs(nodeslide(curr.head),josaprev,ignoreparens,halt)
    end
    if #josaprev == 3 then break end
    curr = nodeprev(curr)
  end
  return josaprev
end

local function korean_autojosa (head)
  for curr in traverse_id(glyphnode,head) do
    if has_attribute(curr,autojosaattr) and has_attribute(curr,finemathattr) then
      local ignoreparens = has_attribute(curr,autojosaattr) > 1 and true or false
      local josaprev = {}
      josaprev = get_josaprevs(nodeprev(curr),josaprev,ignoreparens)
      local josacode = get_josacode(josaprev)
      local thischar = get_unicode_char(curr)
      if thischar == 0xC774 then
        local nn = nodenext(curr)
        if nn and nn.id == glyphnode and get_unicode_char(nn) == 0xB77C then
          curr.char = josa_list[0xC774][josacode]
        else
          curr.char = josa_list[0xAC00][josacode]
        end
      elseif thischar and josa_list[thischar] then
        curr.char = josa_list[thischar][josacode]
      end
    end
    if curr.char < 0 then remove_node(head,curr) end
  end
end

------------------------------
-- switch to hangul/hanja font
------------------------------
local function hangulspaceskip (engfont, hfontid, spec)
  local eng = engfont.parameters
  if not eng then return end
  if not spec then return end
  if spec.stretch_order ~= 0 or spec.shrink_order ~= 0 then return end
  local gsp, gst, gsh = spec.width, spec.stretch, spec.shrink
  local esp, est, esh = eng.space, eng.space_stretch, eng.space_shrink
  esp = esp and tex_round(esp)
  est = est and tex_round(est)
  esh = esh and tex_round(esh)
  if esp == gsp and est == gst and esh == gsh then else return end
  local hf = get_font_table(hfontid)
  if not hf then return end
  local hp = hf.parameters
  if not hp then return end
  local hsp,hst,hsh = hp.space,hp.space_stretch,hp.space_shrink
  if hsp and hst and hsh then else return end
  return tex_round(hsp), tex_round(hst), tex_round(hsh)
end

local type1fonts = {} -- due to too verbose log
local function nanumtype1font(curr)
  if curr.char > 0xFFFF then return end
  local fnt_t  = get_font_table(curr.font)
  local family = (has_attribute(curr,finemathattr) or 0) > 1 and not is_hanja(curr.char) and "nanummj" or "nanumgt"
  local series = fnt_t.shared and fnt_t.shared.rawdata.metadata.pfminfo.weight
  if series then
    series = series > 500 and "b" or "m"
  else
    series = stringfind(fnt_t.name,"^cmb") and "b" or "m"
  end
  local shape  = fnt_t.parameters.slant > 0 and "o" or ""
  local subfnt = stringformat("%s%s%s%02x",family,series,shape,curr.char/256)
  local fsize  = fnt_t.size or 655360
  local fspec  = stringformat("%s@%d",subfnt,fsize)
  local newfnt = type1fonts[fspec]
  local newchr = curr.char % 256
  local function ital_corr (curr,chr_t)
    if shape ~= "o" then return end
    local nxt = nodenext(curr)
    if nxt and nxt.id == kernnode and nxt.subtype == 1 and nxt.kern == 0 then
      nxt.kern = chr_t.italic or 0
    end
  end
  if newfnt then
    local fntchr = get_font_char(newfnt,newchr)
    if fntchr then
      curr.font, curr.char = newfnt, newchr
      ital_corr(curr,fntchr)
    end
  else
    local ft, id = fonts.constructors.readanddefine(subfnt,fsize)
    local fntchr = ft and ft.characters[newchr]
    if id and fntchr then
      type1fonts[fspec], curr.font, curr.char = id, id, newchr
      ital_corr(curr,fntchr)
    end
  end
end

local function font_substitute(head)
  local curr = head
  while curr do
    if curr.id == mathnode and curr.subtype == 0 then
        curr = end_of_math(curr)
    elseif curr.id == glyphnode then
      local eng = get_font_table(curr.font)
      local myfontchar = nil
      if eng and eng.encodingbytes and eng.encodingbytes == 2 -- exclude type1
        and hangulpunctuations[curr.char]
        and has_attribute(curr, hangulpunctsattr)
        and (has_attribute(curr, finemathattr) or 0) > 0 -- not ttfamily
        and not get_font_char(curr.font, 0xAC00) then -- exclude hangul font
      else
        myfontchar = get_font_char(curr.font, curr.char)
      end
      if curr.char and not myfontchar then
        local hangul = has_attribute(curr, hangulfntattr)
        local hanja  = has_attribute(curr, hanjafntattr)
        local fallback = has_attribute(curr,fallbackfntattr)
        local ftable = {hangul, hanja, fallback}
        if luatexko.hanjafontforhanja then
          local uni = get_unicode_char(curr)
          uni = uni and get_cjk_class(uni)
          if uni and uni < 7 then ftable = {hanja, hangul, fallback} end
        end
        for i = 1,3 do
          local fid = ftable[i]
          myfontchar = get_font_char(fid, curr.char)
          if myfontchar then
            curr.font = fid
            local nxt = nodenext(curr)
            if eng and nxt then
              -- adjust next glue by hangul font space
              if nxt.id == gluenode
                and nxt.subtype and nxt.subtype == 0
                and nxt.spec and nxt.spec.writable
                and get_font_char(fid,32) then
                local sp,st,sh = hangulspaceskip(eng, fid, nxt.spec)
                if sp and st and sh then
                  local hg = copy_node(nxt.spec)
                  hg.width, hg.stretch, hg.shrink = sp, st, sh
                  nxt.spec = hg
                end
              -- adjust next italic correction kern
              elseif nxt.id == kernnode
                and nxt.subtype == 1 and nxt.kern == 0 then
                local ksl = get_font_table(fid).parameters.slant
                if ksl and ksl > 0 then
                  nxt.kern = myfontchar.italic or 0
                end
              end
            end
            --- charraise option charraise
            local charraise = get_font_feature(fid, "charraise")
            if charraise then
              charraise = tex_sp(charraise)
              curr.yoffset = charraise + (curr.yoffset or 0)
            end
            ---
            break
          end
        end
        if not myfontchar then
          nanumtype1font(curr)
        end
      end
    end
    curr = nodenext(curr)
  end
end

-----------------------------
-- reserve unicode code point
-----------------------------
local function assign_unicode_codevalue (head)
  for curr in traverse_id(glyphnode, head) do
    set_attribute(curr, luakounicodeattr, curr.char)
  end
  return head
end

-----------------------------
-- reorder hangul tone marks
-----------------------------
local function reorderTM (head)
  for curr in traverse_id(glyphnode, head) do
    local uni = get_unicode_char(curr)
    if uni and (uni == 0x302E or uni == 0x302F) then
      local unichar = get_font_char(curr.font, uni)
      if unichar.width > 0 then
        local p = nodeprev(curr)
        while p do
          if p.id == glyphnode then
            local pc = get_cjk_class(get_unicode_char(p))
            if pc == 7 or pc == 8 then
              head = insert_before(head,p,copy_node(curr))
              head = remove_node(head,curr)
              break
            end
          elseif unichar.commands and p.id == kernnode then
            -- kerns in vertical typesetting mode
          else
            break
          end
          p = nodeprev(p)
        end
      end
    end
  end
  return head
end

-----------------------------
-- ideographic variation selector
-----------------------------
local function hanja_vs_support (head)
  for curr in traverse_id(glyphnode, head) do
    local cc = curr.char
    if is_unicode_vs(cc) then
      local prev = nodeprev(curr)
      if prev and prev.id == glyphnode then
        local f = get_font_table(prev.font)
        local ivs = f and f.resources and f.resources.variants
        ivs = ivs and ivs[cc] and ivs[cc][prev.char]
        -- !!! ARRRG! the font table doesn't have variants for non-BMP chars.
        if ivs then
          prev.char = ivs
          head = remove_node(head,curr)
        end
      end
    end
  end
  return head
end

----------------------------------
-- add to callback : pre-linebreak
----------------------------------
add_to_callback('hpack_filter', function(head)
  assign_unicode_codevalue(head)
  korean_autojosa(head)
  remove_cj_spaceskip(head)
  font_substitute(head)
  head = hanja_vs_support(head)
  return head
end, 'luatexko.hpack_filter_first',1)

add_to_callback('hpack_filter', function(head)
  if texcount["luakorubyattrcnt"]>0 then get_ruby_side_kern(head) end
  cjk_spacing_linebreak(head)
  if texcount["luakorubyattrcnt"]>0 then spread_ruby_base_box(head) end
  head = compress_fullwidth_punctuations(head)
  -- head = no_ruby_at_margin(head)
  head = reorderTM(head)
  return head
end, 'luatexko.hpack_filter')

add_to_callback('pre_linebreak_filter', function(head)
  assign_unicode_codevalue(head)
  korean_autojosa(head)
  remove_cj_spaceskip(head)
  font_substitute(head)
  head = hanja_vs_support(head)
  return head
end, 'luatexko.pre_linebreak_filter_first',1)

add_to_callback('pre_linebreak_filter', function(head)
  if texcount["luakorubyattrcnt"]>0 then get_ruby_side_kern(head) end
  cjk_spacing_linebreak(head)
  if texcount["luakorubyattrcnt"]>0 then spread_ruby_base_box(head) end
  head = compress_fullwidth_punctuations(head)
  discourage_char_widow(head, nodeslide(head))
  if texcount["luakorubyattrcnt"]>0 then head = no_ruby_at_margin(head) end
  head = reorderTM(head)
  return head
end, 'luatexko.pre_linebreak_filter')


--------------------------
-- dot emphasis (드러냄표)
--------------------------
local function after_linebreak_dotemph (head)
  for curr in traverse(head) do
    if curr.id == hlistnode then -- hlist may be nested!!!
      curr.head = after_linebreak_dotemph(curr.head)
    elseif curr.id == glyphnode then
      local attr = has_attribute(curr,dotemphattr)
      if attr and attr > 0 then
        local cc = get_cjk_class(get_unicode_char(curr))
        if cc and (cc == 0 or cc == 7 or cc == 8) then
          local basewd = curr.width or 0
          if cc == 8 then -- check next char for old hangul jung/jongseong
            local nn = nodenext(curr)
            while nn do
              if nn.id ~= glyphnode then break end
              local uni = get_unicode_char(nn)
              local nc = get_cjk_class(uni)
              if nc and nc == 9 and uni ~= 0x302E and uni ~= 0x302F then
                basewd = basewd + (nn.width or 0)
              else
                break
              end
              nn = nodenext(nn)
            end
          end
          local d = copy_node(dotemphnode[attr])
          local dot = d.head
          d.head = get_kernnode(basewd/2-d.width/2)
          d.head.next = dot
          d.width = 0
          head = insert_before(head,curr,d)
        end
        unset_attribute(curr,dotemphattr)
      end
    end
  end
  return head
end

-------------------------------
-- ruby: post-linebreak routine
-------------------------------
local function after_linebreak_ruby (head)
  for curr in traverse_id(hlistnode,head) do
    after_linebreak_ruby(curr.head) -- hlist may be nested!!!
    local attr = has_attribute(curr,luakorubyattr)
    if attr then
      local ruby = rubynode[attr] and rubynode[attr][1]
      if ruby then
        if ruby.width < curr.width then
          local rubyhead = ruby.head
          local numofglues = nodecount(gluenode,rubyhead)
          local extrawidth = (curr.width - ruby.width)/(numofglues + 1)
          ruby.width = curr.width - extrawidth/2
          if numofglues > 0 then
            ruby.head = spread_ruby_box(rubyhead,extrawidth)
          end
        else
          local right = rubynode[attr].rightshift or 0
          ruby.width = curr.width + (ruby.width-curr.width+right)/2
        end
        ruby.shift = -curr.height-rubynode[attr][2]
        insert_after(head,curr,ruby)
        insert_after(head,curr,get_kernnode(-ruby.width))
      end
      rubynode[attr] = nil
      unset_attribute(curr,luakorubyattr)
    end
  end
end

---------------------
-- underline emphasis
---------------------
local function draw_underline(head,curr,width,ulinenum,ulstart)
  if width and width > 0 then
    local glue   = get_gluenode(width)
    glue.subtype = 101 -- cleaders
    glue.leader  = copy_node(ulinebox[ulinenum])
    insert_before(head, curr, get_kernnode(-width))
    insert_before(head, curr, glue)
  end
  for _,nd in ipairs({ulstart,curr}) do
    if nd.id == whatsitnode
      and nd.subtype == whatsitspecial
      and nd.data
      and stringfind(nd.data,"luako:uline") then
      head = remove_node(head,nd)
    end
  end
  return head
end

local function after_linebreak_underline(head,glueorder,glueset,gluesign,ulinenum)
  local ulstart = ulinenum and head or false
  if ulstart and ulstart.id == gluenode then ulstart = nodenext(ulstart) end
  for curr in traverse(head) do
    if curr.id == hlistnode then
      curr.head,ulinenum = after_linebreak_underline(curr.head,curr.glue_order,curr.glue_set,curr.glue_sign,ulinenum)
    elseif curr.id == whatsitnode and curr.subtype == whatsitspecial
      and curr.data then
      if stringfind(curr.data,"luako:ulinebegin=") then
        ulinenum = tonumber(stringmatch(curr.data,"(%d+)"))
        ulstart = curr
      elseif ulstart and ulinenum
        and stringfind(curr.data,'luako:ulineend') then
        local wd = nodedimensions(glueset,gluesign,glueorder,ulstart,curr)
        head = draw_underline(head,curr,wd,ulinenum,ulstart)
        ulinebox[ulinenum] = nil
        ulinenum = nil
      end
    end
    if ulstart and ulinenum and curr == nodetail(head) then
      local wd = nodedimensions(glueset,gluesign,glueorder,ulstart,curr)
      head = draw_underline(head,curr,wd,ulinenum,ulstart)
    end
  end
  return head, ulinenum
end

-----------------------------------
-- add to callback : post-linebreak
-----------------------------------
add_to_callback('vpack_filter', function(head)
  if texcount["luakodotemphcnt"]>0 then head = after_linebreak_dotemph(head) end
  if texcount["luakorubyattrcnt"]>0 then after_linebreak_ruby(head) end
  if texcount["luakoulineboxcnt"]>0 then head = after_linebreak_underline(head) end
  return head
end, 'luatexko.vpack_filter')

add_to_callback("post_linebreak_filter", function(head)
  if texcount["luakodotemphcnt"]>0 then head = after_linebreak_dotemph(head) end
  if texcount["luakorubyattrcnt"]>0 then after_linebreak_ruby(head) end
  if texcount["luakoulineboxcnt"]>0 then head = after_linebreak_underline(head) end
  return head
end, 'luatexko.post_linebreak_filter')


------------------------------------
-- vertical typesetting: EXPERIMENTAL
------------------------------------
local tsbtable, mytime, currtime, cachedir, lfsattributes, lfstouch

local function get_vwidth_tsb_table (filename,fontname)
  if tsbtable[fontname] then return tsbtable[fontname] end
  local cachefile = stringformat("%s/luatexko_vertical_metrics_%s.lua",
                                cachedir,stringgsub(fontname,"%W","_"))
  local cattr = lfs.isfile(cachefile) and lfsattributes(cachefile)
  local fonttime = lfsattributes(filename,"modification")
  if cattr and cattr.access > mytime and cattr.modification == fonttime then
    tsbtable[fontname] = dofile(cachefile)
    return tsbtable[fontname]
  end
  local metrics = nil
  local font = fontloader.open(filename,fontname)
  if font then
    metrics = fontloader.to_table(font)
    fontloader.close(font)
    local glyph_t = {}
    if metrics.subfonts then
      for _,v in ipairs(metrics.subfonts) do
        for ii,vv in pairs(v.glyphs) do
          glyph_t[ii] = { ht = vv.vwidth, tsb = vv.tsidebearing }
        end
      end
    else
      for i,v in ipairs(metrics.glyphs) do
        glyph_t[i] = { ht = v.vwidth, tsb = v.tsidebearing }
      end
    end
    if lfstouch then
      table.tofile(cachefile,glyph_t,"return")
      if not lfstouch(cachefile,currtime,fonttime) then
        warn("Writing cache file '%s' failed!",cachefile)
      end
    end
    tsbtable[fontname] = glyph_t
    return glyph_t
  end
end

local function cjk_vertical_font (vf)
  if not vf.shared then return end
  if not vf.shared.features then return end
  if not vf.shared.features["vertical"] then return end
  if vf.type == "virtual" then return end

  -- load font (again)
  local tsbtable = get_vwidth_tsb_table(vf.filename,vf.fontname)
  if not tsbtable then return end

  local tmp = table.copy(vf) -- fastcopy takes time too long.
  local id = fontdefine(tmp)

  vf.type = 'virtual'
  vf.fonts = {{ id = id }}
  local quad = vf.parameters and vf.parameters.quad or 655360
  local descriptions = vf.shared and vf.shared.rawdata and vf.shared.rawdata.descriptions
  local ascender = vf.parameters and vf.parameters.ascender or quad*0.8
  local factor = vf.parameters and vf.parameters.factor or 655.36
  local xheight = vf.parameters and vf.parameters.x_height or quad/2
  local goffset = xheight/2 - quad/2
  for i,v in pairs(vf.characters) do
    local dsc = descriptions[i]
    local gl = v.index
    -- from loaded font
    local vw  = tsbtable and tsbtable[gl] and tsbtable[gl].ht
    vw = vw and vw * factor or quad
    local tsb = tsbtable and tsbtable[gl] and tsbtable[gl].tsb
    local bb4 = dsc and dsc.boundingbox and dsc.boundingbox[4]
    local asc = bb4 and tsb and (bb4+tsb)*factor or ascender
    local hw = v.width or quad
    local offset = hw/2 + goffset
    local vh = hw > 0 and hw/2 or nil
    v.commands = {
      {'right', asc}, -- bbox4 + top_side_bearing
      {'down', offset},
      {'special', 'pdf: q 0 1 -1 0 0 0 cm'},
      {'push'},
      {'char', i},
      {'pop'},
      {'special', 'pdf: Q'},
    }
    v.width = vw
    v.height = vh
    v.depth = vh
  end
  --- vertical gpos
  local res = vf.resources or {}
  if res.verticalgposhack then
    return vf -- avoid multiple running
  end
  local vposkeys = {}
  local seq = res.sequences or {}
  for _,v in ipairs(seq) do
    if v.type == "gpos_single" and v.subtables then -- todo: gpos_pair...
      local feature = v.features or {}
      if feature.vhal or feature.vkrn or feature.valt or feature.vpal then
        for _,vv in ipairs(v.subtables) do
          vposkeys[#vposkeys+1] = vv
        end
      end
    end
  end
  local lookups = res.lookuphash or {}
  for _,v in ipairs(vposkeys) do
    local vp = lookups[v]
    if vp then
      for i,vv in pairs(vp) do
        if #vv == 4 then
          vp[i] = { -vv[2], vv[1], vv[4], vv[3] }
        end
      end
    end
  end
  res.verticalgposhack = true
  return vf
end

local function activate_vertical_virtual (tfmdata,value)
  local loaded = luatexbase.priority_in_callback("luaotfload.patch_font",
  "luatexko.vertical_virtual_font")
  if value and not loaded then
    require "fontloader"
    require "lfs"
    lfstouch      = lfs.touch
    lfsattributes = lfs.attributes
    tsbtable  = {}
    currtime  = os.time()
    mytime    = kpse_find_file("luatexko.lua")
    mytime    = mytime and lfsattributes(mytime,"modification")
    cachedir  = caches.getwritablepath("..","luatexko")
    add_to_callback("luaotfload.patch_font",
    cjk_vertical_font,
    "luatexko.vertical_virtual_font")
  end
end

local otffeatures = fonts.constructors.newfeatures("otf")
otffeatures.register {
  name         = "vertical",
  description  = "vertical typesetting",
  initializers = {
    node = activate_vertical_virtual,
  }
}

------------------------------------
-- italic correction for fake-slant font
------------------------------------
local function fakeslant_itlc (tfmdata)
  local slfactor = tfmdata.parameters.slantfactor
  if slfactor and slfactor > 0 then else return end
  tfmdata.parameters.slant = slfactor * 65536
  local factor = tfmdata.parameters.factor or 655.36
  local itlcoff = (tfmdata.shared.rawdata.metadata.uwidth or 40)/2 * factor
  local chrs = tfmdata.characters
  for i,v in pairs(chrs) do
    local italic = v.height * slfactor - itlcoff
    if italic > 0 then
      chrs[i].italic = italic
    end
  end
end

------------------------------------
-- tounicode for old hangul
------------------------------------
local function tounicode_oldhangul (tfmdata)
  local script = tfmdata.properties and tfmdata.properties.script
  if script ~= "hang" then return end
  local desc = tfmdata.shared and tfmdata.shared.rawdata and tfmdata.shared.rawdata.descriptions
  local chrs = tfmdata.characters
  if not desc or not chrs then return end
  if not chrs[0x1100] then return end
  local last = 0
  for _,v in ipairs({{0x1100,0x11FF},{0xA960,0xA97C},{0xD7B0,0xD7FB}}) do
    for i = v[1],v[2] do
      local ds = desc[i] and desc[i].slookups
      if ds then
        for _,s in pairs(ds) do
          if type(s) == "number" and s >= 0xF0000 and chrs[s] and not chrs[s].tounicode then
            chrs[s].tounicode = stringformat("%04X",i)
            last = s > last and s or last
          end
        end
      end
    end
  end
  if stringfind(tfmdata.fontname,"^HCR.+LVT") then
    local touni = "1112119E"
    for i = last+1, last+2 do
      local dsc,chr = desc[i],chrs[i]
      if dsc and chr and dsc.class == "ligature" and not chr.tounicode then
        chr.tounicode = touni
      end
      touni = touni.."11AB"
    end
  end
end

add_to_callback("luaotfload.patch_font",
  function(tfmdata)
    fakeslant_itlc(tfmdata)
    tounicode_oldhangul(tfmdata)
  end, "luatexko.font_patches")


------------------------------------
-- Actual Text
------------------------------------
local function actualtext (str)
  local t = {}
  for uni in string.utfvalues(str) do
    if uni < 0x10000 then
      t[#t+1] = stringformat("%04X",uni)
    else -- surrogate
      uni = uni - 0x10000
      t[#t+1] = stringformat("%04X%04X", uni/0x400+0xD800, uni%0x400+0xDC00)
    end
  end
  tex.sprint(stringformat("<FEFF%s>", table.concat(t)))
end
luatexko.actualtext = actualtext
