-- luatexko.lua
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

module('luatexko', package.seeall)

local err,warn,info,log = luatexbase.provides_module({
  name	      = 'luatexko',
  date	      = '2013/05/19',
  version     = '1.1',
  description = 'Korean linebreaking and font-switching',
  author      = 'Dohyun Kim',
  license     = 'LPPL v1.3+',
})

local stringbyte	= string.byte
local stringgsub	= string.gsub
local stringchar	= string.char
local stringfind	= string.find
local stringmatch	= string.match
local stringgmatch	= string.gmatch
local stringformat	= string.format
local mathfloor		= math.floor
local tex_round		= tex.round
local tex_sp		= tex.sp
local fontdefine	= font.define

local fontdata		= fonts.hashes.identifiers
local font_define_func	= callback.find("define_font")
local utf8char		= unicode.utf8.char

local remove_node	= node.remove
local insert_before	= node.insert_before
local insert_after	= node.insert_after
local copy_node		= node.copy
local traverse_id	= node.traverse_id
local traverse		= node.traverse
local has_attribute	= node.has_attribute
local unset_attribute	= node.unset_attribute
local set_attribute	= node.set_attribute
local nodecount		= node.count
local nodeslide		= node.slide
local nodedimensions	= node.dimensions
local nodetail		= node.tail

local finemathattr	= luatexbase.attributes.finemathattr
local cjtypesetattr	= luatexbase.attributes.cjtypesetattr
local dotemphattr	= luatexbase.attributes.dotemphattr
local autojosaattr	= luatexbase.attributes.autojosaattr
local luakorubyattr	= luatexbase.attributes.luakorubyattr
local hangfntattr	= luatexbase.attributes.hangfntattr
local hanjfntattr	= luatexbase.attributes.hanjfntattr
local luakoglueattr	= luatexbase.new_attribute("luakoglueattr")
local luakounicodeattr	= luatexbase.new_attribute("luakounicodeattr")
local quoteraiseattr	= luatexbase.new_attribute("quoteraiseattr")

local add_to_callback	= luatexbase.add_to_callback

local gluenode		= node.id("glue")
local gluespecnode	= node.id("glue_spec")
local glyphnode		= node.id("glyph")
local discnode		= node.id("disc")
local mathnode		= node.id("math")
local hlistnode		= node.id("hlist")
local vlistnode		= node.id("vlist")
local kernnode		= node.id("kern")
local penaltynode	= node.id("penalty")
local rulenode		= node.id("rule")
local whatsitnode	= node.id("whatsit")
local whatsitspecial	= node.subtype("special")

local new_glue 		= node.new(gluenode)
local new_glue_spec 	= node.new(gluespecnode)
local new_penalty 	= node.new(penaltynode)
local new_kern 		= node.new(kernnode,1)
local new_rule 		= node.new(rulenode)

local emsize = 655360

dotemphnode	= {}
rubynode	= {}
ulinebox	= {}
hanjafontforhanja = false

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
--     한자	 (	   )	     ·	       .	—	  ?	    한글      초성	중종성	  latin
{[0] = nil,	 {.5,.5},  nil,	     {.25,.25},nil,	nil,	  nil,	    nil,      nil,	nil,	  nil,	    }, --한자
{[0] = nil,	 nil,	   nil,	     {.25,.25},nil,	nil,	  nil,	    nil,      nil,	nil,	  nil,	    }, -- (
{[0] = {.5,.5},	 {.5,.5},  nil,	     {.25,.25},nil,	{.5,.5},  {.5,.5},  {.25,.25},{.25,.25},{.25,.25},{.5,.5},  }, -- )
{[0] = {.25,.25},{.25,.25},{.25,.25},{.5,.25},{.25,.25},{.25,.25},{.25,.25},{.25,.25},{.25,.25},{.25,.25},{.25,.25},}, -- ·
{[0] = {.5,0},	 {.5,0},   nil,	     {.75,.25},nil,	{.5,0},   {.5,0},   {.5,0},   {.5,0},	{.5,0},   {.5,0},   }, -- .
{[0] = nil,	 {.5,.5},  nil,	     {.25,.25},nil,	nil,	  nil,	    nil,      nil,	nil,	  nil,	    }, -- —
{[0] = {.5,.5},	 {.5,.5},  nil,	     {.25,.25},nil,	nil,	  nil,	    {.5,.5},  {.5,.5},	{.5,.5},  {.5,.5},  }, -- ?
--
{[0] = nil,	 {.25,.25},nil,	     {.25,.25},nil,	nil,	  nil,	    nil,      nil,	nil,	  nil,	    }, --한글
{[0] = nil,	 {.25,.25},nil,	     {.25,.25},nil,	nil,	  nil,	    nil,      nil,	nil,	  nil,	    }, --초성
{[0] = nil,	 {.25,.25},nil,	     {.25,.25},nil,	nil,	  nil,	    nil,      nil,	nil,	  nil,	    }, --중종성
{[0] = nil,	 {.5,.5},  nil,	     {.25,.25},nil,	nil,	  nil,	    nil,      nil,	nil,	  nil,	    }, --latin
}

local latin_fullstop = {
  [0x2e] = 1,
  [0x21] = 2,
  [0x3f] = 2,
  [0x2026] = 1, -- \ldots
}

local latin_quotes = {
  [0x0028] = 0x0029, -- ( )
  [0x2018] = 0x2019, -- ‘ ’
  [0x201C] = 0x201D, -- “ ”
}

local josa_list = { -- automatic josa selection
  --	    리을,	중성,	종성
  [0xAC00] = {0xC774,	0xAC00,	0xC774}, -- 가 = 이, 가, 이
  [0xC740] = {0xC740,	0xB294,	0xC740}, -- 은 = 은, 는, 은
  [0xC744] = {0xC744, 	0xB97C,	0xC744}, -- 을 = 을, 를, 을
  [0xC640] = {0xACFC,	0xC640,	0xACFC}, -- 와 = 과, 와, 과
  [0xC73C] = {-1,	-1,	0xC73C}, -- 으(로) =   ,  , 으
  [0xC774] = {0xC774,	-1,	0xC774}, -- 이(라) = 이,  , 이
}

local josa_code = {
  [0x30]	= 3, -- 0
  [0x31]	= 1, -- 1
  [0x33]	= 3, -- 3
  [0x36]	= 3, -- 6
  [0x37]	= 1, -- 7
  [0x38]	= 1, -- 8
  [0x4C]	= 1, -- L
  [0x4D]	= 3, -- M
  [0x4E]	= 3, -- N
  [0x6C]	= 1, -- l
  [0x6D]	= 3, -- m
  [0x6E]	= 3, -- n
  [0xFB02]	= 1, -- ﬂ
  [0xFB04]	= 1, -- ﬄ
  ng		= 3,
  ap		= 3,
  up		= 3,
  at		= 3,
  et		= 3,
  it		= 3,
  ot		= 3,
  ut		= 3,
  ok		= 3,
  ic		= 3,
  le		= 1,
  ime		= 3,
  ine		= 3,
  ack		= 3,
  ick		= 3,
  oat		= 2,
  TEX		= 3,
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
  --	or  c == 0x2018  or  c == 0x2019
  --	or  c == 0x201C  or  c == 0x201D
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

local function get_cjk_class (ch, cjtype)
  if ch then
    if is_hangul(ch) then return 7 end	      -- hangul = 7
    if is_chosong(ch) then return 8 end	      -- jamo LC = 8
    if is_jungjongsong(ch) then return 9 end  -- jamo VL, TC, TM = 9
    local c = is_cjk_k(ch) and 0 or 10	      -- hanja = 0; latin = 10
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
  return nil
end

local function get_font_table (fid)
  if fid then
    if fontdata[fid] then
      return fontdata[fid]
    else
      return font.getfont(fid)
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
  if curr.char > 0 and curr.char < 0xF0000 then return curr.char end
  local uni = has_attribute(curr, luakounicodeattr)
  if uni then return uni end
  return curr.char
end

----------------------------
-- cjk linebreak and spacing
----------------------------
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
    curr = curr.next
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
    curr = curr.prev
  end
  return prevchar, prevfont
end

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
  if has_attribute(curr,finemathattr) == 1 then -- not ttfamily
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
  if curr.id == glyphnode and has_attribute(curr,finemathattr) == 1 then -- not ttfamily
    if c < 10 then -- not ttfamily
      local nn, raise = curr.next, nil
      while nn do
	if nn.id == glyphnode and currfont ~= nn.font and latin_fullstop[nn.char] then
	  if not raise then
	    raise = get_font_feature(currfont, "punctraise")
	    raise = raise and tex_sp(raise)
	  end
	  if raise then
	    nn.yoffset = nn.yoffset or 0
	    nn.yoffset = nn.yoffset + raise
	  end
	  nn = nn.next
	elseif nn.id == kernnode then
	  nn = nn.next
	else
	  break
	end
      end
    elseif latin_quotes[currchar] and not has_attribute(curr,quoteraiseattr) then
      local nn, raise, cjkfont, depth, todotbl = curr.next, nil, nil, 1, {curr}
      while nn do
	if nn.id == glyphnode then
	  if latin_quotes[nn.char] == latin_quotes[currchar] then
	    depth = depth + 1
	    todotbl[#todotbl + 1] = nn
	  elseif nn.char == latin_quotes[currchar] then
	    depth = depth - 1
	    todotbl[#todotbl + 1] = nn
	    if depth == 0 then
	      if raise and nn.font == currfont and cjkfont ~= currfont then
		for _,n in ipairs(todotbl) do
		  n.yoffset = n.yoffset or 0
		  n.yoffset = n.yoffset + raise
		end
	      end
	      for _,n in ipairs(todotbl) do
		set_attribute(n, quoteraiseattr, 1)
	      end
	      break
	    end
	  elseif not raise then
	    if get_cjk_class(get_unicode_char(nn)) < 10 then
	      raise = get_font_feature(nn.font, "quoteraise")
	      raise = raise and tex_sp(raise)
	      if raise then cjkfont = nn.font end
	    end
	  end
	end
	nn = nn.next
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
      elseif p < 10 and c < 10 and p ~= 8 and c ~= 9 then
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
      elseif p < 10 and c < 10 and p ~= 8 and c ~= 9 then
	interhanjaskip(head,curr,was_penalty)
      end
    end
  end
  -- for dot emphasis
  if has_attribute(curr,dotemphattr)
    and c ~= 0
    and c ~= 7
    and p ~= 8
    and c ~= 8 then
    unset_attribute(curr,dotemphattr)
  end

  return currchar,currfont
end

local function cjk_spacing_linebreak (head)
  local prevchar,prevfont = nil,nil
  for curr in traverse(head) do
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
	  prevchar,prevfont = nil,nil
	else
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
  end
end

------------------------------------
-- remove japanese/chinese spaceskip
------------------------------------
local function remove_cj_spaceskip (head)
  for curr in traverse_id(gluenode,head) do
    local cjattr = has_attribute(curr,cjtypesetattr)
    local prv, nxt = curr.prev, curr.next
    if cjattr and cjattr > 0 and prv and nxt then
      local prevclass, prevchar, prevfont, nextclass
      if prv.id == hlistnode or prv.id == vlistnode then
	prevclass = get_hlist_class_last(prv)
      else
	-- what is this strange kern before \text??
	if prv.id == kernnode and prv.kern == 0 then
	  prv = prv.prev
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
end

----------------------------------
-- compress fullwidth punctuations
----------------------------------
local function compress_fullwidth_punctuations (head)
  for curr in traverse_id(glyphnode,head) do
    local uni = get_unicode_char(curr)
    local class = uni and get_cjk_class(uni, has_attribute(curr, cjtypesetattr))
    local chr = get_font_char(curr.font, curr.char)
    if chr and class and class >= 1 and class <= 4 then
      local width = curr.width or 655360
      emsize = get_font_emsize(curr.font)
      local ensize = emsize/2
      local oneoften = emsize/10
      local bbox = get_char_boundingbox(curr.font, curr.char)
      if not bbox then return head end --
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
	local leftwidth,leftmargin = get_ruby_side_width(basewidth,rubywidth,curr.prev)
	if leftwidth > 0 then
	  curr.width = curr.width + leftwidth
	end
	if leftmargin > 0 then
	  rubynode[attr].leftmargin = leftmargin
	end
	local rightwidth,rightmargin = get_ruby_side_width(basewidth,rubywidth,curr.next)
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
	if curr.next then
	  if curr.next.id == gluenode then
	    insert_after(head,curr,get_kernnode(-margin))
	    head = zero_width_rule_with_dir(head,curr)
	    insert_after(head,curr,get_kernnode(margin))
	  elseif curr.next.id == penaltynode and curr.next.penalty < 10000 then
	    insert_after(head,curr.next,get_kernnode(-margin))
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
local function inject_char_widow_penalty (head,curr,uni,pv,cjattr)
  if uni and prebreakpenalty[uni] ~= 10000 then
    local class = get_cjk_class(uni, cjattr)
    if class and class < 9 then
      if curr.prev and curr.prev.id == rulenode then
	curr = curr.prev
      end
      if curr.prev and curr.prev.id == gluenode then
	curr = curr.prev
      end
      if curr.prev and curr.prev.id == penaltynode then
	if curr.prev.penalty < pv then
	  curr.prev.penalty = pv
	end
      else
	insert_before(head,curr,get_penaltynode(pv))
      end
      return true
    end
  end
end

local function discourage_char_widow (head,curr)
  while curr do
    local cjattr = has_attribute(curr,cjtypesetattr)
    local pv =  cjattr and 500 or 5000
    if curr.id == glyphnode then
      emsize = get_font_emsize(curr.font)
      local width = curr.width or 0
      if width >= 2*emsize then return end
      local uni = get_unicode_char(curr)
      if inject_char_widow_penalty(head,curr,uni,pv,cjattr) then
	return true
      end
    elseif curr.id == hlistnode and curr.id == vlistnode then
      local width = curr.width or 0
      local uni,fid = get_hlist_class_first(curr)
      emsize = get_font_emsize(fid)
      if width >= 2*emsize then return end
      if inject_char_widow_penalty(head,curr,uni,pv,cjattr) then
	return true
      end
    end
    if not curr.prev then return end
    curr = curr.prev
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
  local file = kpse.find_file(file)
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

-- 1 : 리을,	2 : 중성,    3 : 종성
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

local function get_josaprevs(curr,josaprev)
  while curr do
    if curr.id == glyphnode then
      local chr = get_unicode_char(curr)
      if xspcode[chr]
	or inhibitxspcode[chr]
	or prebreakpenalty[chr]
	or postbreakpenalty[chr]
	or chr == 0x302E	-- tone mark
	or chr == 0x302F then	-- tone mark
	--skip
      else
	josaprev[#josaprev + 1] = chr
      end
    elseif curr.id == hlistnode or curr.id == vlistnode then
      josaprev = get_josaprevs(nodeslide(curr.head),josaprev)
    end
    if #josaprev == 3 then break end
    curr = curr.prev
  end
  return josaprev
end

local function korean_autojosa (head)
  for curr in traverse_id(glyphnode,head) do
    if has_attribute(curr,autojosaattr) and has_attribute(curr,finemathattr) then
      local josaprev = {}
      josaprev = get_josaprevs(curr.prev,josaprev)
      local josacode = get_josacode(josaprev)
      local thischar = get_unicode_char(curr)
      if thischar == 0xC774 then
	if curr.next
	  and curr.next.id == glyphnode
	  and get_unicode_char(curr.next) == 0xB77C then
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
local function hangulspaceskip (engfont, hfontid, nglue)
  local eng = engfont.parameters
  if not eng then return end
  local spec = nglue.spec
  if not spec then return end
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

local hangulfontlist = {}

local function font_substitute(head)
  for curr in traverse_id(glyphnode, head) do
    local eng = get_font_table(curr.font)
    local engfontchar = get_font_char(curr.font, curr.char)
    if not eng then -- no font table of plain tex cm font
      engfontchar = get_cjk_class(curr.char) == 10
    end
    if curr.char and not engfontchar then
      local korid  = false
      local hangul = has_attribute(curr, hangfntattr)
      local hanja  = has_attribute(curr, hanjfntattr)
      local ftable = {hangul, hanja}
      if hanjafontforhanja then
	local uni = get_unicode_char(curr)
	uni = uni and get_cjk_class(uni)
	if uni and uni < 7 then ftable = {hanja, hangul} end
      end
      for _,fid in ipairs(ftable) do
	if fid then
	  local c = get_font_char(fid, curr.char)
	  if c then
	    korid = true
	    curr.font = fid
	    -- adjust next glue by hangul font space
	    local nxt = curr.next
	    if hangulmain and nxt and nxt.id == gluenode and nxt.subtype and nxt.subtype == 0 then
	      local sp,st,sh = hangulspaceskip(eng, fid, nxt)
	      if sp and st and sh then
		nxt.spec.width   = sp
		nxt.spec.stretch = st
		nxt.spec.shrink  = sh
	      end
	    end
	    --- charraise option charraise
	    local charraise = get_font_feature(fid, "charraise")
	    if charraise then
	      charraise = tex_sp(charraise)
	      curr.yoffset = curr.yoffset and (curr.yoffset + charraise) or charraise
	    end
	    ---
	    break
	  end
	end
      end
      if not korid then
	warn("!Missing character: %s U+%04X", utf8char(curr.char),curr.char)
      end
    end
  end
  return head
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


------------------------------------
-- vetical typesetting: EXPERIMENTAL -- don't use this
------------------------------------
---[[no vwidth in luaotfload v2
local tsbtable = {}

local function read_tsb_table(filename)-- for ttx-generated vmtx table
  if tsbtable[filename] then
    return tsbtable[filename]
  end
  local filepath = kpse.find_file(filename)
  if not filepath then return end
  local file = io.open(filepath, "r")
  if not file then return end
  local tsbtb = {}
  local patt = 'name="(.-)" height="(.-)" tsb="(.-)"'
  while true do
    local l = file:read("*line")
    if not l then break end
    for name, height, tsb in stringgmatch(l,patt) do
      tsbtb[name] = {}
      tsbtb[name].height = height
      tsbtb[name].tsb = tsb
    end
  end
  file:close()
  tsbtable[filename] = tsbtb
  return tsbtb
end

local function cjk_vertical_font (vf)
  if not vf.shared then return end
  if not vf.shared.features then return end
  if not vf.shared.features["vertical"] then return end
  if vf.type == "virtual" then return end

  --- for read-ttx
  local filename = vf.filename
  filename = stringgsub(filename,".*/","")
  filename = stringgsub(filename,"[tToO][tT][fF]$","ttx")
  local tsbtable = read_tsb_table(filename)
  if not tsbtable then
    warn("Cannot read %s. Aborting vertical typesetting.",filename)
    return
  end
  ---

  local tmp = table.copy(vf) -- fastcopy takes time too long.
  local id = fontdefine(tmp)

  local hash = vf.properties and vf.properties.hash and vf.properties.hash..' @ vertical'
  hash = hash or (vf.name and vf.size and vf.name..' @ '..vf.size..' @ vertical')

  vf.properties = vf.properties or {}
  vf.properties.hash = vf.properties.hash or ""
  vf.properties.hash = hash
  vf.type = 'virtual'
  vf.fonts = {{ id = id }}
  local quad = vf.parameters and vf.parameters.quad or 655360
  local descriptions = vf.shared and vf.shared.rawdata and vf.shared.rawdata.descriptions
  local ascender = vf.parameters and vf.parameters.ascender
  local factor = vf.parameters and vf.parameters.factor
  local halfxht = (vf.parameters and vf.parameters.x_height and vf.parameters.x_height/2) or quad/4
  for i,v in pairs(vf.characters) do
    local dsc = descriptions[i]
    local gname = dsc.name
    -- local vw = dsc and dsc.vwidth
    --- for read-ttx
    local vw = tsbtable and tsbtable[gname] and tsbtable[gname].height
    local tsb = tsbtable and tsbtable[gname] and tsbtable[gname].tsb
    if not vw and dsc.index then
      local cid = stringformat("cid%05d", dsc.index)
      vw = tsbtable and tsbtable[cid] and tsbtable[cid].height
      tsb = tsbtable and tsbtable[cid] and tsbtable[cid].tsb
    end
    tsb = tsb and factor and tsb*factor
    ---
    vw = vw and factor and vw * factor
    vw = vw or quad
    local vh = dsc and dsc.boundingbox and dsc.boundingbox[3]
    vh = vh and factor and vh * factor
    vh = vh and vh - quad/2 or quad/2
    vh = vh + halfxht
    vh = vh > 0 and vh or nil
    local vd = dsc and dsc.boundingbox and dsc.boundingbox[1]
    vd = vd and factor and vd * factor
    vd = vd and quad/2 - vd or quad/2
    vd = vd - halfxht
    vd = vd > 0 and vd or nil
    local bb4 = dsc and dsc.boundingbox and dsc.boundingbox[4]
    bb4 = bb4 and factor and bb4*factor
    local asc = bb4 and tsb and bb4 + tsb
    asc = asc or ascender
    v.commands = {
      {'right', asc}, -- bbox4 + top_side_bearing! But, tsb not available!
      {'down', halfxht},
      {'special', 'pdf: q 0 1 -1 0 0 0 cm'},
      {'push'},
      {'char', i},
      {'pop'},
      {'special', 'pdf: Q'},
    }
    v.width = vw
    v.height = vh
    v.depth = vd
  end
  return vf
end

local function activate_vertical_virtual (tfmdata,value)
  if value then
    add_to_callback("luaotfload.patch_font",
    cjk_vertical_font,
    "luatexko.vetical_virtual_font")
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
--no vwidth in luaotfload v2]]

----------------------------------
-- add to callback : pre-linebreak
----------------------------------
add_to_callback('hpack_filter', function(head)
  assign_unicode_codevalue(head)
  korean_autojosa(head)
  remove_cj_spaceskip(head)
  font_substitute(head)
  return head
end, 'luatexko.hpack_filter_first',1)

add_to_callback('hpack_filter', function(head)
  get_ruby_side_kern(head)
  cjk_spacing_linebreak(head)
  spread_ruby_base_box(head)
  head = compress_fullwidth_punctuations(head)
  -- head = no_ruby_at_margin(head)
  return head
end, 'luatexko.hpack_filter')

add_to_callback('pre_linebreak_filter', function(head)
  assign_unicode_codevalue(head)
  korean_autojosa(head)
  remove_cj_spaceskip(head)
  font_substitute(head)
  return head
end, 'luatexko.pre_linebreak_filter_first',1)

add_to_callback('pre_linebreak_filter', function(head)
  get_ruby_side_kern(head)
  cjk_spacing_linebreak(head)
  spread_ruby_base_box(head)
  head = compress_fullwidth_punctuations(head)
  discourage_char_widow(head, nodeslide(head))
  head = no_ruby_at_margin(head)
  return head
end, 'luatexko.pre_linebreak_filter')


--------------------------
-- dot emphasis (드러냄표)
--------------------------
local function after_linebreak_dotemph (head)
  for curr in traverse(head) do
    if curr.id == hlistnode then -- hlist may be nested!!!
      after_linebreak_dotemph(curr.head)
    elseif curr.id == glyphnode then
      local attr = has_attribute(curr,dotemphattr)
      if attr and attr > 0 then
	local d = copy_node(dotemphnode[attr])
	local dot = d.head
	d.head = get_kernnode(-curr.width/2-d.width/2)
	d.head.next = dot
	d.width = 0
	insert_after(head,curr,d)
	unset_attribute(curr,dotemphattr)
      end
    end
  end
end

-------------------------------
-- ruby: post-linebreak routine
-------------------------------
local function after_linebreak_ruby (head)
  for curr in traverse_id(hlistnode,head) do
    after_linebreak_ruby(curr.head) -- hlist may be nested!!!
    local attr = has_attribute(curr,luakorubyattr)
    if attr then
      local ruby = rubynode[attr][1]
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
      remove_node(head,nd)
    end
  end
end

local function after_linebreak_underline(head,glueorder,glueset,gluesign,ulinenum)
  local ulstart = ulinenum and head or false
  if ulstart and ulstart.id == gluenode then ulstart = ulstart.next end
  for curr in traverse(head) do
    if curr.id == hlistnode then
      ulinenum = after_linebreak_underline(curr.head,curr.glue_order,curr.glue_set,curr.glue_sign,ulinenum)
    elseif curr.id == whatsitnode and curr.subtype == whatsitspecial
      and curr.data then
      if stringfind(curr.data,"luako:ulinebegin=") then
	ulinenum = tonumber(stringmatch(curr.data,"(%d+)"))
	ulstart = curr
      elseif ulstart and ulinenum
	and stringfind(curr.data,'luako:ulineend') then
	local wd = nodedimensions(glueset,gluesign,glueorder,ulstart,curr)
	draw_underline(head,curr,wd,ulinenum,ulstart)
	ulinebox[ulinenum] = nil
	ulinenum = nil
      end
    end
    if ulstart and ulinenum and curr == nodetail(head) then
      local wd = nodedimensions(glueset,gluesign,glueorder,ulstart,curr)
      draw_underline(head,curr,wd,ulinenum,ulstart)
    end
  end
  return ulinenum
end

-----------------------------------
-- add to callback : post-linebreak
-----------------------------------
add_to_callback('vpack_filter', function(head)
  after_linebreak_dotemph(head)
  after_linebreak_ruby(head)
  after_linebreak_underline(head)
  return true
end, 'luatexko.vpack_filter')

add_to_callback("post_linebreak_filter", function(head)
  after_linebreak_dotemph(head)
  after_linebreak_ruby(head)
  after_linebreak_underline(head)
  return true
end, 'luatexko.post_linebreak_filter')

