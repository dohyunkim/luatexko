-- luatexko.lua
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

luatexbase.provides_module {
  name        = 'luatexko',
  date        = '2019/04/06',
  version     = '1.24',
  description = 'Korean linebreaking and font-switching',
  author      = 'Dohyun Kim, Soojin Nam',
  license     = 'LPPL v1.3+',
}

luatexko        = luatexko or {}
local luatexko  = luatexko

local dotemphnode,rubynode  = {},{}
luatexko.dotemphnode        = dotemphnode
luatexko.rubynode           = rubynode

local stringbyte    = string.byte
local stringchar    = string.char
local stringformat  = string.format
local mathfloor     = math.floor
local tex_round     = tex.round
local tex_sp        = tex.sp
local texcount      = tex.count
local fontdefine    = font.define

local kpse_find_file = kpse.find_file

local fontdata = fonts.hashes.identifiers

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
local luakoulineattr    = luatexbase.new_attribute("luakoulineattr")

local function warn (...)
  return luatexbase.module_warning("luatexko", stringformat(...))
end

local function add_to_callback (name, func, desc, pos)
  local t = {{func, desc}}
  if pos then
    for i,v in ipairs(luatexbase.callback_descriptions(name)) do
      if i >= pos then
        t[#t+1] = {luatexbase.remove_from_callback(name, v)}
      end
    end
  end
  for i,v in ipairs(t) do
    luatexbase.add_to_callback(name, v[1], v[2])
  end
end

local glue_type_space = 13
local kern_type_itlc  = 3

local discnode        = node.id("disc")
local gluenode        = node.id("glue")
local glyphnode       = node.id("glyph")
local mathnode        = node.id("math")
local hlistnode       = node.id("hlist")
local vlistnode       = node.id("vlist")
local kernnode        = node.id("kern")
local penaltynode     = node.id("penalty")
local rulenode        = node.id("rule")
local whatsitnode     = node.id("whatsit")
local user_whatsit    = node.subtype("user_defined")
local n_copy_list     = node.copy_list

local nodedirect        = node.direct
local d_getdisc         = nodedirect.getdisc
local d_todirect        = nodedirect.todirect
local d_tonode          = nodedirect.tonode
local d_has_field       = nodedirect.has_field
local d_copy_node       = nodedirect.copy
local d_getid           = nodedirect.getid
local d_getfield        = nodedirect.getfield
local d_setfield        = nodedirect.setfield
local d_getsubtype      = nodedirect.getsubtype
local d_setsubtype      = nodedirect.setsubtype
local d_getchar         = nodedirect.getchar
local d_setchar         = nodedirect.setchar
local d_getfont         = nodedirect.getfont
local d_getlist         = nodedirect.getlist
local d_setlist         = nodedirect.setlist
local d_getnext         = nodedirect.getnext
local d_setnext         = nodedirect.setnext
local d_getprev         = nodedirect.getprev
local d_setprev         = nodedirect.setprev
local d_setleader       = nodedirect.setleader
local d_getglue         = nodedirect.getglue
local d_setglue         = nodedirect.setglue
local d_has_attribute   = nodedirect.has_attribute
local d_set_attribute   = nodedirect.set_attribute
local d_unset_attribute = nodedirect.unset_attribute
local d_traverse        = nodedirect.traverse
local d_traverse_id     = nodedirect.traverse_id
local d_insert_before   = nodedirect.insert_before
local d_insert_after    = nodedirect.insert_after
local d_remove_node     = nodedirect.remove
local d_nodenew         = nodedirect.new
local d_nodecount       = nodedirect.count
local d_end_of_math     = nodedirect.end_of_math
local d_nodetail        = nodedirect.slide -- tail seems to be no good
local d_nodedimensions  = nodedirect.dimensions
local d_nodefree        = nodedirect.free
local d_nodewrite       = nodedirect.write
local d_node_zero_glue  = nodedirect.is_zero_glue

local emsize = 655360

local cjkclass = {
  [0x2018] = 1, -- ‘
  [0x201C] = 1, -- “
  [0x2329] = 1, -- 〈
  [0x3008] = 1, -- 〈
  [0x300A] = 1, -- 《
  [0x300C] = 1, -- 「
  [0x300E] = 1, -- 『
  [0x3010] = 1, -- 【
  [0x3014] = 1, -- 〔
  [0x3016] = 1, -- 〖
  [0x3018] = 1, -- 〘
  [0x301A] = 1, -- 〚
  [0x301D] = 1, -- 〝
  [0xFE17] = 1, -- ︗
  [0xFE35] = 1, -- ︵
  [0xFE37] = 1, -- ︷
  [0xFE39] = 1, -- ︹
  [0xFE3B] = 1, -- ︻
  [0xFE3D] = 1, -- ︽
  [0xFE3F] = 1, -- ︿
  [0xFE41] = 1, -- ﹁
  [0xFE43] = 1, -- ﹃
  [0xFE47] = 1, -- ﹇
  [0xFF08] = 1, -- （
  [0xFF3B] = 1, -- ［
  [0xFF5B] = 1, -- ｛
  [0xFF5F] = 1, -- ｟
  [0xFF62] = 1, -- ｢ half
  [0x2019] = 2, -- ’
  [0x201D] = 2, -- ”
  [0x232A] = 2, -- 〉
  [0x3001] = 2, -- 、
  [0x3009] = 2, -- 〉
  [0x300B] = 2, -- 》
  [0x300D] = 2, -- 」
  [0x300F] = 2, -- 』
  [0x3011] = 2, -- 】
  [0x3015] = 2, -- 〕
  [0x3017] = 2, -- 〗
  [0x3019] = 2, -- 〙
  [0x301B] = 2, -- 〛
  [0x301E] = 2, -- 〞
  [0x301F] = 2, -- 〟
  [0xFE10] = 2, -- ︐
  [0xFE11] = 2, -- ︑
  [0xFE18] = 2, -- ︘
  [0xFE36] = 2, -- ︶
  [0xFE38] = 2, -- ︸
  [0xFE3A] = 2, -- ︺
  [0xFE3C] = 2, -- ︼
  [0xFE3E] = 2, -- ︾
  [0xFE40] = 2, -- ﹀
  [0xFE42] = 2, -- ﹂
  [0xFE44] = 2, -- ﹄
  [0xFE48] = 2, -- ﹈
  [0xFF09] = 2, -- ）
  [0xFF0C] = 2, -- ，
  [0xFF3D] = 2, -- ］
  [0xFF5D] = 2, -- ｝
  [0xFF60] = 2, -- ｠
  [0xFF63] = 2, -- ｣ half
  [0xFF64] = 2, -- ､ half
  [0x00B7] = 3, -- ·
  [0x30FB] = 3, -- ・
  [0xFF1A] = 3, -- ：
  [0xFF1B] = 3, -- ；
  [0xFF65] = 3, -- ･ half
  [0x3002] = 4, -- 。
  [0xFE12] = 4, -- ︒
  [0xFF0E] = 4, -- ．
  [0xFF61] = 4, -- ｡ half
  [0x2015] = 5, -- ―
  [0x2025] = 5, -- ‥
  [0x2026] = 5, -- …
  [0xFE19] = 5, -- ︙
  [0xFE30] = 5, -- ︰
  [0xFE31] = 5, -- ︱
  [0xFE15] = 6, -- ︕
  [0xFE16] = 6, -- ︖
  [0xFF01] = 6, -- ！
  [0xFF1F] = 6, -- ？
}

local inhibitxspcode = setmetatable({
  [0x002D] = 0, -- - hyphen minus
  [0x003C] = 0, -- <
  [0x003E] = 1, -- >
  [0x00B0] = 1, -- °
  [0x2032] = 1, -- ′
  [0x2033] = 1, -- ″
  [0x25CC] = 2, -- dotted circle
  [0x3012] = 2, -- 〒
  [0x301C] = 0, -- 〜
  [0xFE14] = 1, -- ︔
  [0xFF1B] = 1, -- ；
  [0xFFE5] = 0, -- ￥
},{
  __index = function (_,c)
    if cjkclass[c] == 1 then
      return 2
    elseif cjkclass[c] == 2 or cjkclass[c] == 4 or cjkclass[c] == 6 then
      return 1
    elseif cjkclass[c] == 5 then
      return 0
    end
  end
})

local postbreakpenalty = setmetatable({
  [0x0023] = 500,
  [0x0024] = 500,
  [0x0025] = 500,
  [0x0026] = 500,
  [0x0028] = 10000,
  [0x003C] = 10000, -- <
  [0x005B] = 10000,
  [0x0060] = 10000,
  [0x007B] = 10000, -- {
  [0x00AB] = 10000, -- «
  [0x2013] = 50, -- en-dash
  [0x2014] = 50, -- em-dash
  [0xFF03] = 200,
  [0xFF04] = 200,
  [0xFF05] = 200,
  [0xFF06] = 200,
  [0xFF40] = 10000, -- ｀
},{
  __index = function (_,c)
    if cjkclass[c] == 1 then
      return 10000
    end
  end
})

local prebreakpenalty = setmetatable({
  [0x0021] = 10000,
  [0x0022] = 10000,
  [0x0027] = 10000,
  [0x0029] = 10000,
  [0x002A] = 5000, -- 500, -- *
  [0x002B] = 5000, -- 500, -- +
  [0x002C] = 10000,
  [0x002D] = 10000,
  [0x002E] = 10000,
  [0x002F] = 5000, -- 500, -- /
  [0x003A] = 10000,
  [0x003B] = 10000,
  [0x003E] = 10000, -- >
  [0x003F] = 10000,
  [0x005D] = 10000,
  [0x007D] = 10000, -- }
  [0x00B4] = 10000, -- ´
  [0x00BB] = 10000, -- »
  [0x2013] = 10000, -- –
  [0x2014] = 10000, -- —
  [0x2025] = 5000, -- 250, -- ‥
  [0x2026] = 5000, -- 250, -- …
  [0x2212] = 5000, -- 200, -- −  minus sign
  [0x3005] = 10000, -- 々
  [0x301C] = 10000, -- 〜
  [0x3035] = 10000, -- 〵
  [0x303B] = 10000, -- 〻
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
  [0x3095] = 150,
  [0x3096] = 150,
  [0x309B] = 10000, -- ゛
  [0x309C] = 10000, -- ゜
  [0x309D] = 10000, -- ゝ
  [0x309E] = 10000, -- ゞ
  [0x30A0] = 10000, -- ゠
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
  [0x30FC] = 10000, -- ー
  [0x30FD] = 10000, -- ヽ
  [0x30FE] = 10000, -- ヾ
  [0xFE13] = 10000, -- ︓
  [0xFE14] = 10000, -- ︔
  [0xFE19] = 5000, -- 250, -- ︙
  [0xFE30] = 5000, -- 250, -- ︰
  [0xFE32] = 10000, -- ︲
  [0xFF0B] = 5000, -- 200, -- ＋
  [0xFF1D] = 5000, -- 200, -- ＝
  [0xFF9E] = 10000, -- ﾞ
  [0xFF9F] = 10000, -- ﾟ
},{
  __index = function (_,c)
    if cjkclass[c] and cjkclass[c] > 1 then
      return 10000
    end
  end
})

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

local function d_get_gluenode (...)
  local g = d_nodenew(gluenode)
  d_setglue(g, ...)
  return g
end

local function d_get_penaltynode (n)
  local p = d_nodenew(penaltynode)
  d_setfield(p,"penalty", n or 0)
  return p
end

local function d_get_kernnode (n)
  local k = d_nodenew(kernnode,1)
  d_setfield(k,"kern", n or 0)
  return k
end

local function d_get_rulenode (w,h,d)
  local r = d_nodenew(rulenode)
  d_setfield(r,"width",  w or 0)
  d_setfield(r,"height", h or 0)
  d_setfield(r,"depth",  d or 0)
  return r
end

local function d_make_luako_glue(...)
  local glue = d_get_gluenode(...)
  d_set_attribute(glue,luakoglueattr,1)
  return glue
end

local function is_cjk_k (c)
  return (c >= 0x2E80  and c <= 0x9FFF )
  or (c >= 0xF900  and c <= 0xFAFF )
  or (c >= 0xFE10  and c <= 0xFE1F )
  or (c >= 0xFE30  and c <= 0xFE4F )
  or (c >= 0xFF00  and c <= 0xFFEF )
  or (c >= 0x20000 and c <= 0x2FFFD)
  or  c == 0x00B0  or  c == 0x2015
  --  or  c == 0x2018  or  c == 0x2019
  --  or  c == 0x201C  or  c == 0x201D
  or  c == 0x2026  or  c == 0x2032
  or  c == 0x2033
end

local function is_hanja (c)
  return (c >= 0x3400 and c <= 0x9FFF )
  or (c >= 0xF900 and c <= 0xFAFF )
  or (c >= 0x20000 and c <= 0x2FFFD)
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

local type1fonts = {}

local function get_font_table (fid)
  if fid then
    if fontdata[fid] then
      return fontdata[fid]
    elseif type1fonts[fid] then
      return type1fonts[fid]
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

local function d_get_unicode_char(curr)
  local uni = d_getchar(curr) or 0
  if (uni > 0xFF and uni < 0xE000) or (uni > 0xF8FF and uni < 0xF0000) then
    return uni -- no pua. no nanumgtm
  end
  if uni < 0xE000 or (uni > 0xF8FF and uni < 0xF0000) then -- no pua
    local uchr = get_font_char(d_getfont(curr), uni)
    uchr = uchr and uchr.tounicode
    uchr = uchr and uchr:sub(1,4) -- seems ok for old hangul
    if uchr then return tonumber(uchr,16) end
  end
  local uatt = d_has_attribute(curr, luakounicodeattr)
  if uatt then return uatt end
  return uni
end

local function d_get_hlist_char_first (hlist)
  local curr = d_getlist(hlist)
  while curr do
    local currid = d_getid(curr)
    if currid == glyphnode then
      local c,f = d_get_unicode_char(curr), d_getfont(curr)
      if c then return c,f end
    elseif currid == hlistnode or currid == vlistnode then
      local c,f = d_get_hlist_char_first(curr)
      if c then return c,f end
    elseif currid == gluenode then
      if not d_node_zero_glue(curr) then return end
    end
    curr = d_getnext(curr)
  end
end

local function d_get_hlist_char_last (hlist,c,f)
  local curr = d_nodetail(d_getlist(hlist))
  while curr do
    local currid = d_getid(curr)
    if currid == glyphnode then
      c, f = d_get_unicode_char(curr), d_getfont(curr)
      if c and not is_unicode_vs(c) then break end -- bypass VS
    elseif currid == hlistnode or currid == vlistnode then
      c, f = d_get_hlist_char_last(curr)
      if c then break end
    elseif currid == gluenode then
      if not d_node_zero_glue(curr) then break end
    end
    curr = d_getprev(curr)
  end
  return c, f
end

----------------------------
-- cjk linebreak and spacing
----------------------------
local function kanjiskip (head,curr)
  d_insert_before(head,curr,d_make_luako_glue(0, emsize*0.1, emsize*0.02))
end

local function xkanjiskip (head,curr)
  if d_has_attribute(curr,finemathattr) == 0 then -- ttfamily
    kanjiskip(head,curr)
  else
    d_insert_before(head,curr,d_make_luako_glue(0.25*emsize, emsize*0.15, emsize*0.06))
  end
end

local function interhangulskip (head,curr,currfont,prevfont,was_penalty)
  local width = 0
  local interhangul = get_font_feature(currfont, "interhangul")
  if interhangul and currfont == prevfont then
    width = tex_sp(interhangul)
  end
  if not was_penalty then
    d_insert_before(head,curr,d_get_penaltynode(50))
  end
  d_insert_before(head,curr,d_make_luako_glue(width, emsize*0.04, emsize*0.02))
end

local function interhanjaskip (head,curr,was_penalty)
  if not was_penalty then
    d_insert_before(head,curr,d_get_penaltynode(50))
  end
  d_insert_before(head,curr,d_make_luako_glue(0, emsize*0.04, emsize*0.02))
end

local function koreanlatinskip (head,curr,currfont,prevfont,was_penalty)
  local width = 0 -- default: 0em
  if (d_has_attribute(curr,finemathattr) or 0) > 0 then -- not ttfamily
    local latincjk = get_font_feature(currfont, "interlatincjk")
    if not latincjk then
      latincjk = get_font_feature(prevfont, "interlatincjk")
    end
    if latincjk then
      width = tex_sp(latincjk)
    end
  end
  if not was_penalty then
    d_insert_before(head,curr,d_get_penaltynode(50))
  end
  d_insert_before(head,curr,d_make_luako_glue(width, emsize*0.04, emsize*0.02))
end

local function cjk_insert_nodes(head,curr,currchar,currfont,prevchar,prevfont,was_penalty)
  local currentcjtype = d_has_attribute(curr,cjtypesetattr)
  local p = get_cjk_class(prevchar, currentcjtype)
  local c = get_cjk_class(currchar, currentcjtype)
  ---[[raise latin puncts
  if d_getid(curr) == glyphnode and (d_has_attribute(curr,finemathattr) or 0) > 0 and c < 10 then -- not ttfamily
    local nn, raise = d_getnext(curr), nil
    while nn do
      local nnid = d_getid(nn)
      if nnid == glyphnode and latin_fullstop[d_getchar(nn)] then
        if not raise then
          raise = get_font_feature(currfont, "punctraise")
          raise = raise and tex_sp(raise)
        end
        if raise then
          local yoff = d_getfield(nn,"yoffset") or 0
          d_setfield(nn,"yoffset", yoff + raise)
        end
        nn = d_getnext(nn)
      elseif nnid == kernnode then
        nn = d_getnext(nn)
      else
        break
      end
    end
  end
  --raise latin puncts]]
  if c == 5 and p == 5 then -- skip ------ ......
    return currchar,currfont
  end
  if p and p < 10 and prebreakpenalty[currchar] then
    was_penalty = true
    d_insert_before(head,curr,d_get_penaltynode(prebreakpenalty[currchar]))
  elseif c and c < 10 and postbreakpenalty[prevchar] then
    was_penalty = true
    d_insert_before(head,curr,d_get_penaltynode(postbreakpenalty[prevchar]))
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
        d_insert_before(head,curr,d_make_luako_glue(width, stretch, shrink))
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
  local prevchar,prevfont,was_penalty,prevfine = nil,nil,nil,nil
  local curr = head
  while curr do
    local currfine = d_has_attribute(curr,finemathattr)
    if currfine then
      local currid = d_getid(curr)
      if currid == gluenode then
        prevchar,prevfont,prevfine = nil,nil,nil
        d_unset_attribute(curr,finemathattr)
      elseif currid == glyphnode then
        local currfont = d_getfont(curr)
        emsize = get_font_emsize(currfont)
        local uni = d_get_unicode_char(curr)
        if uni and not is_unicode_vs(uni) then -- bypass VS
          if prevfine and prevfine > 0 and currfine == 0 then
            d_set_attribute(curr, finemathattr, 1)
          end
          prevchar,prevfont = cjk_insert_nodes(head,curr,uni,currfont,prevchar,prevfont,was_penalty)
          prevfine = currfine
        end
        d_unset_attribute(curr,finemathattr)
      elseif currid == mathnode then
        local currchar = 0
        local currsurround, currsubtype = d_getfield(curr,"surround"), d_getsubtype(curr)
        if currsurround and currsurround > 0 then
          currchar = 0x4E00
        end
        if currsubtype == 0 then
          cjk_insert_nodes(head,curr,currchar,nil,prevchar,prevfont,was_penalty)
          curr = d_end_of_math(curr)
          if not curr then break end
          prevchar,prevfont,prevfine = currchar,nil,nil
        end
        d_unset_attribute(curr,finemathattr)
      elseif currid == hlistnode or currid == vlistnode then
        local firstchr, firstfid = d_get_hlist_char_first(curr)
        if firstchr then
          cjk_insert_nodes(head,curr,firstchr,firstfid,prevchar,prevfont,was_penalty)
        end
        prevchar,prevfont = d_get_hlist_char_last(curr,prevchar,prevfont)
        if d_getlist(curr) then prevfine = nil end -- empty box preserves prevfine.
        d_unset_attribute(curr,finemathattr)
      end
      was_penalty = currid == penaltynode
    else
      if d_getid(curr) == glyphnode and prevfine and prevfine > 0 then -- fitst glyph in verb
        d_set_attribute(curr, finemathattr, 1)
        cjk_insert_nodes(head,curr,0,nil,prevchar,prevfont,was_penalty)
        d_unset_attribute(curr,finemathattr)
        prevchar,prevfont,prevfine = 0,nil,nil -- treat \verb as latin character.
      end
    end
    curr = d_getnext(curr)
  end
end

------------------------------------
-- remove japanese/chinese spaceskip
------------------------------------
local function remove_cj_spaceskip (head)
  local curr, prevfont = head, nil
  while curr do
    local currid,currsubtype = d_getid(curr), d_getsubtype(curr)
    if currid == mathnode and currsubtype == 0 then
      curr = d_end_of_math(curr)
    elseif currid == gluenode and currsubtype == glue_type_space then -- do not touch on xspaceskip for now
      local cjattr = d_has_attribute(curr,cjtypesetattr)
      local prv, nxt = d_getprev(curr), d_getnext(curr)
      if cjattr and cjattr > 0 and prv and nxt then
        local prevclass, prevchar, nextclass
        local prvid, nxtid = d_getid(prv), d_getid(nxt)
        if prvid == hlistnode or prvid == vlistnode then
          prevclass = get_cjk_class(d_get_hlist_char_last(prv), cjattr)
        else
          -- what is this strange kern before \text??
          if prvid == kernnode and d_getfield(prv,"kern") == 0 then
            prv = d_getprev(prv)
          end
          if prvid == glyphnode then
            prevchar, prevfont = d_getchar(prv), d_getfont(prv)
            if is_unicode_vs(prevchar) then prv = d_getprev(prv) end -- bypass VS
            prevclass = get_cjk_class(d_get_unicode_char(prv), cjattr)
          end
        end
        if nxtid == glyphnode then
          nextclass = get_cjk_class(d_get_unicode_char(nxt), cjattr)
        elseif nxtid == hlistnode or nxtid == vlistnode then
          nextclass = get_cjk_class(d_get_hlist_char_first(nxt), cjattr)
        end
        if (prevclass and prevclass < 10) or (nextclass and nextclass < 10) then
          d_remove_node(head,curr)
          d_nodefree(curr)
          curr = nxt
        end
      end
    end
    curr = d_getnext(curr)
  end
end

----------------------------------
-- compress fullwidth punctuations
----------------------------------
local function check_next_halt_kern (head, curr)
  -- glyph halt_kern glue -> glyph halt_kern rule glue
  local nn = d_getnext(curr)
  if nn and d_getid(nn) == kernnode and d_getnext(nn) then
    d_insert_after(head, nn, d_get_rulenode(0))
  end
end

local function check_prev_halt_kern (head, curr)
  local pn = d_getprev(curr)
  if pn and d_getid(pn) == kernnode and d_getprev(pn) then
    -- glue halt_kern glyph -> glue rule halt_kern glyph
    head = d_insert_before(head, pn, d_get_rulenode(0))
  elseif pn and d_getid(pn) == gluenode and d_has_attribute(pn, luakoglueattr) then
    -- halt_kern ko_glue glyph -> ko_glue rule halt_kern glyph
    local ppn = d_getprev(pn)
    if d_getid(ppn) == kernnode then
      head = d_remove_node(head, ppn)
      head = d_insert_before(head, curr, ppn)
      head = d_insert_before(head, ppn, d_get_rulenode(0))
    end
  end
  return head
end

local function compress_fullwidth_punctuations (head)
  for curr in d_traverse_id(glyphnode,head) do
    local currfont, currchar = d_getfont(curr), d_getchar(curr)
    local cjtype = d_has_attribute(curr, cjtypesetattr)
    local uni = d_get_unicode_char(curr)
    local class = uni and get_cjk_class(uni, cjtype or 0) -- include U+201C ...
    local chr = get_font_char(currfont, currchar)
    if chr and class and class >= 1 and class <= 4 then
      local halt_on = get_font_feature(currfont,'halt') or get_font_feature(currfont,'vhal')
      local width = d_getfield(curr,"width") or 655360
      emsize = get_font_emsize(currfont)
      local ensize = emsize/2
      local oneoften = emsize/10
      local bbox = get_char_boundingbox(currfont, currchar)
      bbox = bbox or {ensize-oneoften, ensize-oneoften, ensize+oneoften, ensize+oneoften}
      if class == 2 or class == 4 then
        local wd
        if get_font_feature(currfont,'vertical') then
          wd = ensize<width and ensize-width or 0
        else
          wd = (bbox[3] < ensize) and ensize-width or bbox[3]-width+oneoften
          if not cjtype and wd > 0 then wd = 0 end
        end
        if chr.right_protruding then
          -- kern is a breakpoint if followed by a glue
          if not halt_on then
            d_insert_after(head, curr, d_get_kernnode(wd))
          end
        else
          if halt_on then
            check_next_halt_kern(head, curr)
          else
            d_insert_after(head, curr, d_get_rulenode(wd))
          end
        end
      elseif class == 1 then
        local wd
        if get_font_feature(currfont,'vertical') then
          wd = ensize<width and ensize-width or 0
        else
          wd = (width-bbox[1] < ensize) and ensize-width or -bbox[1]+oneoften
          if not cjtype and wd > 0 then wd = 0 end
        end
        if chr.left_protruding then
          if not halt_on then
            head = d_insert_before(head, curr, d_get_kernnode(wd))
          end
        else
          if halt_on then
            head = check_prev_halt_kern(head, curr)
          else
            head = d_insert_before(head, curr, d_get_rulenode(wd))
          end
        end
      elseif class == 3 then
        local lwd, rwd
        local quarter, thirdquarter, halfwd = ensize/2, ensize*1.5, width/2
        if get_font_feature(currfont,'vertical') then
          rwd = quarter<halfwd and quarter-halfwd or 0
          lwd = rwd
        else
          rwd = (bbox[3] < thirdquarter) and quarter-halfwd or bbox[3]-width
          lwd = (width-bbox[1] < thirdquarter) and quarter-halfwd or -bbox[1]
        end
        if chr.left_protruding then
          if not halt_on then
            head = d_insert_before(head, curr, d_get_kernnode(lwd))
          end
        else
          if halt_on then -- there's already penalty 10000
            head = check_prev_halt_kern(head, curr)
          else
            head = d_insert_before(head, curr, d_get_rulenode(lwd))
          end
        end
        if chr.right_protruding then
          if not halt_on then
            d_insert_after (head, curr, d_get_kernnode(rwd))
          end
        else
          if halt_on then
            check_next_halt_kern(head, curr)
          else
            d_insert_after (head, curr, d_get_rulenode(rwd))
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
  local to_free = {}
  for curr in d_traverse_id(gluenode,head) do
    local wd = d_getglue(curr) or 0
    if d_has_attribute(curr,luakoglueattr) then
      d_setglue(curr, wd + extrawidth)
    else
      head = d_insert_before(head,curr,d_get_kernnode(wd+extrawidth))
      head = d_remove_node(head,curr)
      to_free[#to_free + 1] = curr
    end
  end
  if #to_free > 0 then
    for _,v in ipairs(to_free) do d_nodefree(v) end
  end
  return head
end

local function spread_ruby_base_box (head)
  for curr in d_traverse_id(hlistnode,head) do
    local attr = d_has_attribute(curr,luakorubyattr)
    local rubyoverlap = attr and rubynode[attr][3]
    if attr and not rubyoverlap then
      local ruby = d_todirect(rubynode[attr][1])
      local currwidth, rubywidth = d_getfield(curr,"width"), d_getfield(ruby,"width")
      if ruby and rubywidth > currwidth then
        local basehead = d_getlist(curr)
        local numofglues = d_nodecount(gluenode,basehead)
        local extrawidth = (rubywidth - currwidth)/(numofglues + 1)
        if numofglues > 0 then
          basehead = spread_ruby_box(basehead,extrawidth)
        end
        local leading = d_get_kernnode(extrawidth/2)
        d_setfield(curr,"width", rubywidth)
        d_setnext(leading, basehead)
        d_setlist(curr, leading)
      end
    end
  end
end

local function get_ruby_side_width (basewidth,rubywidth,adjacent)
  local width,margin = (rubywidth-basewidth)/2, 0
  if adjacent then
    if d_getid(adjacent) == glyphnode then
      local uni = d_get_unicode_char(adjacent)
      if is_unicode_vs(uni) then -- bypass VS
        uni = d_get_unicode_char(d_getprev(adjacent))
      end
      if not is_hanja(uni) then
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
  for curr in d_traverse_id(hlistnode,head) do
    local attr = d_has_attribute(curr,luakorubyattr)
    local rubyoverlap = attr and rubynode[attr][3]
    if rubyoverlap then
      local currwidth = d_getfield(curr,"width")
      local basewidth = currwidth
      local ruby = d_todirect(rubynode[attr][1])
      local rubywidth = d_getfield(ruby,"width")
      if currwidth < rubywidth then
        local _,fid = d_get_hlist_char_first(curr)
        emsize = get_font_emsize(fid)
        local leftwidth,leftmargin = get_ruby_side_width(basewidth,rubywidth,d_getprev(curr))
        if leftwidth > 0 then
          currwidth = currwidth + leftwidth
          d_setfield(curr,"width", currwidth)
        end
        if leftmargin > 0 then
          rubynode[attr].leftmargin = leftmargin
        end
        local rightwidth,rightmargin = get_ruby_side_width(basewidth,rubywidth,d_getnext(curr))
        if rightwidth > 0 then
          currwidth = currwidth + rightwidth
          d_setfield(curr,"width", currwidth)
        end
        if rightmargin > 0 then
          rubynode[attr].rightmargin = rightmargin
        end
        rubynode[attr].rightshift = rightwidth - leftwidth
        local totalspace = leftwidth+rightwidth
        if totalspace > 0 then
          local currhead = d_getlist(curr)
          local numofglues = d_nodecount(gluenode,currhead)
          local extrawidth = totalspace/(numofglues + 1)
          if numofglues > 0 then
            currhead = spread_ruby_box(currhead,extrawidth)
          end
          local leading = d_get_kernnode(extrawidth*(leftwidth/totalspace))
          d_setnext(leading, currhead)
          d_setlist(curr, leading)
        end
      end
    end
  end
end

local function zero_width_rule_with_dir (head,curr,before)
  local rule = d_get_rulenode(0)
  d_setfield(rule,"dir", d_getfield(curr,"dir"))
  if before then
    head = d_insert_before(head,curr,rule)
  else
    d_insert_after(head,curr,rule)
  end
  return head
end

local function no_ruby_at_margin(head)
  for curr in d_traverse_id(hlistnode,head) do
    local attr = d_has_attribute(curr,luakorubyattr)
    if attr then
      local margin = rubynode[attr].leftmargin
      if margin then
        head = d_insert_before(head,curr,d_get_kernnode(-margin))
        head = zero_width_rule_with_dir(head,curr,true) -- before
        head = d_insert_before(head,curr,d_get_kernnode(margin))
      end
      margin = rubynode[attr].rightmargin
      if margin then
        local nn = d_getnext(curr)
        if nn then
          local nnid = d_getid(nn)
          if nnid == gluenode then
            d_insert_after(head,curr,d_get_kernnode(-margin))
            head = zero_width_rule_with_dir(head,curr)
            d_insert_after(head,curr,d_get_kernnode(margin))
          elseif nnid == penaltynode and d_getfield(nn,"penalty") < 10000 then
            d_insert_after(head,nn,d_get_kernnode(-margin))
            head = zero_width_rule_with_dir(head,curr)
            d_insert_after(head,curr,d_get_kernnode(margin))
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
      local pv = cjattr and 500 or 5000
      local np = d_getprev(curr)
      if np and d_getid(np) == rulenode then
        curr = np; np = d_getprev(curr)
      end
      if np and d_getid(np) == gluenode then
        curr = np; np = d_getprev(curr)
      end
      if np and d_getid(np) == penaltynode then
        curr = np
        local currpenalty = d_getfield(curr,"penalty")
        if currpenalty < pv and currpenalty > 0 then -- bypass \\ case
          d_setfield(curr,"penalty", pv)
        end
      elseif curr and d_getid(curr) == gluenode then
        head, curr = d_insert_before(head,curr,d_get_penaltynode(pv))
      end
    end
  end
  return curr
end

local function discourage_char_widow (head,curr)
  while curr do
    if curr == head then return end
    local currid = d_getid(curr)
    if currid == glyphnode then
      emsize = get_font_emsize(d_getfont(curr))
      local remwd = d_nodedimensions(curr)
      if remwd > 2*emsize then return end
      local cjattr = d_has_attribute(curr,cjtypesetattr)
      local uni = d_get_unicode_char(curr)
      curr = inject_char_widow_penalty(head,curr,uni,cjattr)
    elseif currid == hlistnode and currid == vlistnode then
      local remwd = d_nodedimensions(curr)
      local uni,fid = d_get_hlist_char_first(curr)
      emsize = get_font_emsize(fid)
      if remwd > 2*emsize then return end
      local cjattr = d_has_attribute(curr,cjtypesetattr)
      curr = inject_char_widow_penalty(head,curr,uni,cjattr)
    end
    curr = d_getprev(curr)
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

local hanja2hangul
local function initialize_hanja2hangul ()
  hanja2hangul = {}
  hanja2hangul = get_hanja_hangul_table(hanja2hangul,"hanja_hangul.tab",0x4E00)
  hanja2hangul = get_hanja_hangul_table(hanja2hangul,"hanjaexa_hangul.tab",0x3400)
  hanja2hangul = get_hanja_hangul_table(hanja2hangul,"hanjacom_hangul.tab",0xF900)
end

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
    if not hanja2hangul then initialize_hanja2hangul() end
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
    local currid = d_getid(curr)
    if currid == glyphnode then
      local chr = d_get_unicode_char(curr)
      -- ignore chars inside parentheses (KTS workshop 2013.11.09)
      if ignoreparens and chr == 0x29 then -- right parenthesis
        halt = halt + 1
      elseif ignoreparens and chr == 0x28 then -- left parenthesis
        halt = halt - 1
      elseif xspcode[chr]
        or inhibitxspcode[chr]
        or prebreakpenalty[chr]
        or postbreakpenalty[chr]
        or is_unicode_vs(chr) -- bypass VS
        or chr == 0x302E  -- tone mark
        or chr == 0x302F then  -- tone mark
        --skip
      elseif halt <= 0 then
        josaprev[#josaprev + 1] = chr
      end
    elseif currid == hlistnode or currid == vlistnode then
      josaprev = get_josaprevs(d_nodetail(d_getlist(curr)),josaprev,ignoreparens,halt)
    end
    if #josaprev == 3 then break end
    curr = d_getprev(curr)
  end
  return josaprev
end

local function korean_autojosa (head)
  local to_free = {}
  for curr in d_traverse_id(glyphnode,head) do
    local josaattr = d_has_attribute(curr,autojosaattr)
    if josaattr and d_has_attribute(curr,finemathattr) then
      local ignoreparens = josaattr > 1 and true or false
      local josaprev = {}
      josaprev = get_josaprevs(d_getprev(curr),josaprev,ignoreparens)
      local josacode = get_josacode(josaprev)
      local thischar = d_get_unicode_char(curr)
      if thischar == 0xC774 then
        local nn, nc = d_getnext(curr)
        if nn and d_getid(nn) == glyphnode then
          nc = d_get_unicode_char(nn)
        end
        if nc and nc >= 0xAC00 and nc <= 0xD7A3 then
          d_setchar(curr, josa_list[0xC774][josacode])
        else
          d_setchar(curr, josa_list[0xAC00][josacode])
        end
      elseif thischar and josa_list[thischar] then
        d_setchar(curr, josa_list[thischar][josacode])
      end
    end
    if d_getchar(curr) < 0 then
      d_remove_node(head,curr)
      to_free[#to_free + 1] = curr
    end
  end
  if #to_free > 0 then
    for _,v in ipairs(to_free) do d_nodefree(v) end
  end
end

------------------------------
-- switch to hangul/hanja font
------------------------------
local function hangulspaceskip (engfont, hfontid, glue)
  local eng = engfont.parameters
  if not eng then return end
  local gsp, gst, gsh, gsto, gsho = d_getglue(glue)
  if gsto ~= 0 or gsho ~= 0 then return end
  local esp, est, esh = eng.space, eng.space_stretch, eng.space_shrink
  esp = esp and tex_round(esp)
  est = est and tex_round(est)
  esh = esh and tex_round(esh)
  if esp == gsp and est == gst and esh == gsh then else return end
  local hf = get_font_table(hfontid)
--  if hf and hf.encodingbytes == 2 then else return end
  return gsp, hf
end

local function virtual_unifont (prefix,size)
  local data = {
    name       = prefix.."vf",
    type       = "virtual",
    fonts      = {},
    characters = {},
  }
  local fonts = data.fonts
  local chars = data.characters
  for index = 0, 255 do
    local name = string.format(prefix.."%02x", index)
    if kpse_find_file(name,"tfm") then
      local tfm = font.read_tfm(name, size)
      data.parameters = data.parameters or tfm.parameters
      fonts[#fonts+1] = { name=name, size=size }
      local fid = #fonts
      local zro = 256 * index
      for i,v in pairs(tfm.characters) do
        local slot = zro + i
        chars[slot] = v
        chars[slot].commands = { { "slot", fid, i } }
      end
    end
  end
  return data
end

local function nanumtype1font(curr)
  local currchar, currfont = d_getchar(curr), d_getfont(curr)
  if currchar > 0xFFFF then return end
  local fnt_t  = get_font_table(currfont)
  if not fnt_t then return end
  local family = (d_has_attribute(curr,finemathattr) or 0) > 1 and not is_hanja(currchar) and "nanummj" or "nanumgt"
  local series = fnt_t.shared and
                 fnt_t.shared.rawdata and
                 fnt_t.shared.rawdata.metadata and
                 fnt_t.shared.rawdata.metadata.pfmweight
  if series then
    series = series > 500 and "b" or "m"
  else
    series = fnt_t.name:find("^cmb") and "b" or "m"
  end
  local shape  = fnt_t.parameters.slant > 0 and "o" or ""
  local prefix = stringformat("%s%s%s",family,series,shape)
  local fsize  = fnt_t.size or 655360
  local fspec  = stringformat("%s@%d",prefix,fsize)
  local fontid = type1fonts[fspec]
  if fontid == nil then -- bypass false
    local fontdata = virtual_unifont(prefix, fsize)
    fontid = fontdata and fontdefine(fontdata)
    if fontid then
      type1fonts[fspec]  = fontid
      type1fonts[fontid] = fontdata
    else
      type1fonts[fspec] = false
    end
  end
  return fontid
end

local function font_substitute(head)
  local curr = head
  while curr do
    local currid = d_getid(curr)
    if currid == glyphnode then
      local currchar, currfont = d_getchar(curr), d_getfont(curr)
      if currchar then
        if is_unicode_vs(currchar) then -- ideograph variation selectors
          local prev = d_getprev(curr)
          local prevfont = d_getid(prev) == glyphnode and d_getfont(prev)
          if prevfont ~= currfont then
            d_setfield(curr, "font", prevfont) -- sync font
          end
        else
          local myfontchar, forcehangul, forcehanja
          local eng = currfont and get_font_table(currfont)
          if eng and eng.encodingbytes and eng.encodingbytes == 2 -- exclude type1
            and hangulpunctuations[currchar] and d_has_attribute(curr, hangulpunctsattr)
            and (d_has_attribute(curr, finemathattr) or 0) > 0 -- not ttfamily
            and not get_font_char(currfont, 0xAC00) then -- exclude hangul font
          else
            if luatexko.hangulfontforhangul or luatexko.hanjafontforhanja then
              local uni = d_get_unicode_char(curr)
              uni = uni and get_cjk_class(uni) or 10
              if uni < 7 then
                forcehanja = luatexko.hanjafontforhanja
              elseif uni < 10 then
                forcehangul = luatexko.hangulfontforhangul
              end
            end
            if not forcehangul and not forcehanja then
              myfontchar = get_font_char(currfont, currchar)
            end
          end
          if not myfontchar then
            local hangul    = d_has_attribute(curr, hangulfntattr)
            local hanja     = d_has_attribute(curr, hanjafntattr)
            local fallback  = d_has_attribute(curr, fallbackfntattr)
            local ftable    = {hangul, hanja, fallback}
            if forcehanja then ftable = {hanja, hangul, fallback} end
            local fid
            for i = 1,3 do
              fid = ftable[i]
              myfontchar = fid and get_font_char(fid, currchar)
              if myfontchar then break end
            end
            if not myfontchar and not hangulpunctuations[currchar] then
              fid = nanumtype1font(curr)
              myfontchar = fid and get_font_char(fid, currchar)
            end
            if myfontchar then
              d_setfield(curr,"font",fid)
              --- charraise option charraise
              local charraise = get_font_feature(fid, "charraise")
              if charraise then
                charraise = tex_sp(charraise)
                local curryoffset = d_getfield(curr,"yoffset") or 0
                d_setfield(curr,"yoffset", charraise + curryoffset)
              end
              ---
              local nxt = d_getnext(curr)
              local nxtid = nxt and d_getid(nxt)
              if nxtid == glyphnode and is_unicode_vs(d_getchar(nxt)) then
                nxt = d_getnext(nxt)
                nxtid = nxt and d_getid(nxt)
              end
              if eng and nxtid then
                local nxtsubtype = d_getsubtype(nxt)
                -- adjust next glue by hangul font space
                if nxtid == gluenode and nxtsubtype == glue_type_space and get_font_char(fid,32) then
                  local oldwd, ft = hangulspaceskip(eng, fid, nxt)
                  if oldwd and ft then
                    local newwd = ft.space_char_width
                    if not newwd then
                      local newsp = d_tonode(d_copy_node(curr))
                      newsp.char = 32
                      newsp = nodes.simple_font_handler(newsp)
                      newwd = newsp and newsp.width
                      ft.space_char_width = newwd
                      node.free(newsp)
                    end
                    if newwd and oldwd ~= newwd then
                      d_setglue(nxt, newwd, newwd/2, newwd/3)
                    end
                  end
                -- adjust next italic correction kern
                elseif nxtid == kernnode and nxtsubtype == kern_type_itlc and d_getfield(nxt,"kern") == 0 then
                  local ksl = get_font_table(fid).parameters.slant
                  if ksl and ksl > 0 then
                    d_setfield(nxt,"kern", myfontchar.italic or 0)
                  end
                end
              end
            end
          end
        end
      end
    elseif currid == mathnode then
      if d_getsubtype(curr) == 0 then
        curr = d_end_of_math(curr)
      end
    elseif currid == discnode then
      local pre, post, replace = d_getdisc(curr)
      if pre     then font_substitute(pre)     end
      if post    then font_substitute(post)    end
      if replace then font_substitute(replace) end
    end
    curr = d_getnext(curr)
  end
end

-----------------------------
-- reserve unicode code point
-----------------------------
local function assign_unicode_codevalue (head)
  for curr in d_traverse_id(glyphnode, head) do
    d_set_attribute(curr, luakounicodeattr, d_getchar(curr))
  end
end

-----------------------------
-- reorder hangul tone marks
-----------------------------
local function reorderTM (head)
  local curr, todo = head, nil
  while curr do
    local nid = d_getid(curr)
    if nid == glyphnode then
      local uni = d_get_unicode_char(curr)
      if uni == 0x302E or uni == 0x302F then
        local tmgl = get_font_char(d_getfont(curr), uni)
        local tmwidth = tmgl and tmgl.width or 0
        if todo then
          if tmwidth > 0 then
            local tm = curr
            head, curr = d_remove_node(head, curr)
            d_setprev(tm, nil) -- prev might survive!
            head = d_insert_before(head, todo, tm)
            curr = d_getprev(curr)
          end
        elseif get_font_char(d_getfont(curr), 0x25CC) then
          local u25CC = d_copy_node(curr)
          d_setchar(u25CC, 0x25CC)
          if tmwidth > 0 then
            head, curr = d_insert_after(head, curr, u25CC)
          else
            head = d_insert_before(head, curr, u25CC)
          end
        end
        todo = nil
      elseif is_hangul(uni) or is_chosong(uni) or uni == 0x25CC then
        todo = curr
      elseif is_jungjongsong(uni) then
      else
        todo = nil
      end
    elseif nid == kernnode then
    else
      todo = nil
    end
    curr = d_getnext(curr)
  end
  return head
end

----------------------------------
-- add to callback : pre-linebreak
----------------------------------

add_to_callback("hpack_filter", function(head)
  head = d_todirect(head)
  assign_unicode_codevalue(head)
  korean_autojosa(head)
  remove_cj_spaceskip(head)
  font_substitute(head)
  return d_tonode(head)
end, 'luatexko.hpack_filter_first', 1)

add_to_callback('hpack_filter', function(head)
  head = d_todirect(head)
  if texcount["luakorubyattrcnt"]>0 then get_ruby_side_kern(head) end
  cjk_spacing_linebreak(head)
  if texcount["luakorubyattrcnt"]>0 then spread_ruby_base_box(head) end
  head = compress_fullwidth_punctuations(head)
  -- head = no_ruby_at_margin(head)
  head = reorderTM(head)
  return d_tonode(head)
end, 'luatexko.hpack_filter')

add_to_callback('pre_linebreak_filter', function(head)
  head = d_todirect(head)
  assign_unicode_codevalue(head)
  korean_autojosa(head)
  remove_cj_spaceskip(head)
  font_substitute(head)
  return d_tonode(head)
end, 'luatexko.pre_linebreak_filter_first', 1)

add_to_callback('pre_linebreak_filter', function(head)
  head = d_todirect(head)
  if texcount["luakorubyattrcnt"]>0 then get_ruby_side_kern(head) end
  cjk_spacing_linebreak(head)
  if texcount["luakorubyattrcnt"]>0 then spread_ruby_base_box(head) end
  head = compress_fullwidth_punctuations(head)
  discourage_char_widow(head, d_nodetail(head))
  if texcount["luakorubyattrcnt"]>0 then head = no_ruby_at_margin(head) end
  head = reorderTM(head)
  return d_tonode(head)
end, 'luatexko.pre_linebreak_filter')


--------------------------
-- dot emphasis (드러냄표)
--------------------------
local function after_linebreak_dotemph (head, to_free)
  local outer = not to_free
  to_free = to_free or {}
  for curr in d_traverse(head) do
    local currid = d_getid(curr)
    if currid == hlistnode then -- hlist may be nested!!!
      d_setlist(curr, after_linebreak_dotemph(d_getlist(curr), to_free))
    elseif currid == glyphnode then
      local attr = d_has_attribute(curr,dotemphattr)
      if attr and attr > 0 then
        local cc = get_cjk_class(d_get_unicode_char(curr))
        if cc and (cc == 0 or cc == 7 or cc == 8) then
          local basewd = d_getfield(curr,"width") or 0
          if cc == 8 then -- check next char for old hangul jung/jongseong
            local nn = d_getnext(curr)
            while nn do
              if d_getid(nn) ~= glyphnode then break end
              local uni = d_get_unicode_char(nn)
              local nc = get_cjk_class(uni)
              if nc and nc == 9 and uni ~= 0x302E and uni ~= 0x302F then
                basewd = basewd + (d_getfield(nn,"width") or 0)
              else
                break
              end
              nn = d_getnext(nn)
            end
          end
          local dbox = d_todirect(dotemphnode[attr])
          local d = d_copy_node(dbox)
          local dwidth = d_getfield(d,"width")
          local dot = d_get_kernnode(basewd/2-dwidth/2)
          d_setnext(dot, d_getlist(d))
          d_setlist(d, dot)
          d_setfield(d,"width", 0)
          head = d_insert_before(head,curr,d)
          to_free[dbox] = true
        end
        d_unset_attribute(curr,dotemphattr)
      end
    end
  end
  if outer then
    for k in pairs(to_free) do d_nodefree(k) end
  end
  return head
end

-------------------------------
-- ruby: post-linebreak routine
-------------------------------
local function after_linebreak_ruby (head)
  for curr in d_traverse_id(hlistnode,head) do
    after_linebreak_ruby(d_getlist(curr)) -- hlist may be nested!!!
    local attr = d_has_attribute(curr,luakorubyattr)
    if attr then
      local ruby = rubynode[attr] and d_todirect(rubynode[attr][1])
      if ruby then
        local currwidth, rubywidth = d_getfield(curr,"width"), d_getfield(ruby,"width")
        local currheight = d_getfield(curr,"height")
        if rubywidth < currwidth then
          local rubyhead = d_getlist(ruby)
          local numofglues = d_nodecount(gluenode,rubyhead)
          local extrawidth = (currwidth - rubywidth)/(numofglues + 1)
          d_setfield(ruby,"width", currwidth - extrawidth/2)
          if numofglues > 0 then
            d_setlist(ruby, spread_ruby_box(rubyhead,extrawidth))
          end
        else
          local right = rubynode[attr].rightshift or 0
          d_setfield(ruby,"width", currwidth + (rubywidth-currwidth+right)/2)
        end
        d_setfield(ruby,"shift", -currheight-rubynode[attr][2])
        d_insert_after(head,curr,ruby)
        d_insert_after(head,curr,d_get_kernnode(-d_getfield(ruby,"width")))
      end
      rubynode[attr] = nil
      d_unset_attribute(curr,luakorubyattr)
    end
  end
end

---------------------
-- underline emphasis
---------------------

local uline_start_id = luatexbase.new_whatsit("luako_uline_start")
local uline_stop_id  = luatexbase.new_whatsit("luako_uline_stop")
local function uline_boundary (num, list)
  local n = d_nodenew(whatsitnode, user_whatsit)
  d_setfield(n, "user_id", list and uline_start_id or uline_stop_id)
  d_setfield(n, "type", 110) -- node list
  d_setfield(n, "value", n_copy_list(list))
  d_set_attribute(n, luakoulineattr, num)
  d_nodewrite(n)
end
luatexko.uline_boundary = uline_boundary

local skippable = {
  [gluenode   ] = true,
  [penaltynode] = true,
  [kernnode   ] = true,
  [whatsitnode] = true,
}
local function draw_underline(head,curr,glueset,gluesign,glueorder,ubox,start)
  start = start or head
  while start do
    if not skippable[d_getid(start)] then break end
    start = d_getnext(start)
  end
  while curr do
    local p = d_getprev(curr)
    if not skippable[d_getid(p)] then break end
    curr = p
  end
  local width = d_nodedimensions(glueset,gluesign,glueorder,start,curr)
  if width and width > 0 then
    local glue = d_get_gluenode(width)
    d_setsubtype(glue, 101) -- cleaders
    d_setleader(glue, d_copy_node(ubox))
    head = d_insert_before(head, start, glue)
    head = d_insert_before(head, start, d_get_kernnode(-width))
  end
  return head
end

local function after_linebreak_underline(head,glueorder,glueset,gluesign,ulstart,level)
  ulstart, level = ulstart or {}, level or 0

  for curr in d_traverse(head) do
    local currid = d_getid(curr)
    if currid == hlistnode then
      local newhead
      newhead, ulstart = after_linebreak_underline(
        d_getlist(curr),
        d_getfield(curr,"glue_order"),
        d_getfield(curr,"glue_set"),
        d_getfield(curr,"glue_sign"),
        ulstart,
        level+1)
      d_setlist(curr, newhead)
    elseif currid == whatsitnode and d_getsubtype(curr) == user_whatsit then
      local attr = d_has_attribute(curr, luakoulineattr)
      local whatsit_type = d_getfield(curr, "type")
      if attr and whatsit_type == 110 then
        local user_id = d_getfield(curr, "user_id")
        if user_id == uline_start_id then
          local list = d_getfield(curr, "value")
          ulstart[attr] = { start = curr, list = list, level = level }
        elseif user_id == uline_stop_id and ulstart[attr] then
          local ubox, start = ulstart[attr].list, ulstart[attr].start
          head = draw_underline(head,curr,glueset,gluesign,glueorder,ubox,start)
          ulstart[attr] = nil
        end
        d_unset_attribute(curr,luakoulineattr)
      end
    end
  end

  local curr = d_nodetail(head)
  for i, v in pairs(ulstart) do
    local ubox, start = v.list, v.start
    if ubox and level == v.level then
      head = draw_underline(head,curr,glueset,gluesign,glueorder,ubox,start)
      ulstart[i].start = nil
    end
  end

  return head, ulstart
end

-----------------------------------
-- add to callback : post-linebreak
-----------------------------------
add_to_callback('vpack_filter', function(head)
  head = d_todirect(head)
  if texcount["luakodotemphcnt"]>0 then head = after_linebreak_dotemph(head) end
  if texcount["luakorubyattrcnt"]>0 then after_linebreak_ruby(head) end
  if texcount["luakoulineboxcnt"]>0 then head = after_linebreak_underline(head) end
  return d_tonode(head)
end, 'luatexko.vpack_filter')

add_to_callback('hpack_filter', function(head, groupcode)
  if groupcode == "align_set" then
    head = d_todirect(head)
    if texcount["luakodotemphcnt"]>0 then head = after_linebreak_dotemph(head) end
    if texcount["luakorubyattrcnt"]>0 then after_linebreak_ruby(head) end
    if texcount["luakoulineboxcnt"]>0 then head = after_linebreak_underline(head) end
    head = d_tonode(head)
  end
  return head
end, 'luatexko.hpack_filter.postlinebreak')


------------------------------------
-- vertical typesetting: EXPERIMENTAL
------------------------------------
local streamreader = utilities.files
local openfile     = streamreader.open
local closefile    = streamreader.close
local readstring   = streamreader.readstring
local readulong    = streamreader.readcardinal4
local readushort   = streamreader.readcardinal2
local readfixed    = streamreader.readfixed4
local readshort    = streamreader.readinteger2
local setpos       = streamreader.setposition

local function getotftables (f, subfont)
  if f then
    local sfntversion = readstring(f,4)
    if sfntversion == "ttcf" then
      local ttcversion = readfixed(f)
      local numfonts   = readulong(f)
      if subfont >= 1 and subfont <= numfonts then
        local offsets = {}
        for i = 1, numfonts do
          offsets[i] = readulong(f)
        end
        setpos(f, offsets[subfont])
        sfntversion = readstring(f,4)
      end
    end
    if sfntversion == "OTTO" or sfntversion == "true" or sfntversion == "\0\1\0\0" then
      local numtables     = readushort(f)
      local searchrange   = readushort(f)
      local entryselector = readushort(f)
      local rangeshift    = readushort(f)
      local tables        = {}
      for i= 1, numtables do
        local tag = readstring(f,4)
        tables[tag] = {
          checksum = readulong(f),
          offset   = readulong(f),
          length   = readulong(f),
        }
      end
      return tables
    end
  end
end

local function readmaxp (f, t)
  if f and t then
    setpos(f, t.offset)
    return {
      version   = readfixed(f),
      numglyphs = readushort(f),
    }
  end
end

local function readvhea (f, t)
  if f and t then
    setpos(f, t.offset)
    return {
      version               = readfixed(f),
      ascent                = readshort(f),
      descent               = readshort(f),
      lineGap               = readshort(f),
      advanceheightmax      = readshort(f),
      mintopsidebearing     = readshort(f),
      minbottomsidebrearing = readshort(f),
      ymaxextent            = readshort(f),
      caretsloperise        = readshort(f),
      caretsloperun         = readshort(f),
      caretoffset           = readshort(f),
      reserved1             = readshort(f),
      reserved2             = readshort(f),
      reserved3             = readshort(f),
      reserved4             = readshort(f),
      metricdataformat      = readshort(f),
      numheights            = readushort(f),
    }
  end
end

local function readvmtx (f, t, numofheights, numofglyphs)
  if f and t and numofheights and numofglyphs then
    setpos(f, t.offset)
    local vmtx = {}
    local height = 0
    for i = 0, numofheights-1 do
      height = readushort(f)
      vmtx[i] = {
        ht  = height,
        tsb = readshort(f),
      }
    end
    for i = numofheights, numofglyphs-1 do
      vmtx[i] = {
        ht  = height,
        tsb = readshort(f),
      }
    end
    return vmtx
  end
end

local tsbtable

local function get_tsb_table (filename, subfont)
  subfont = tonumber(subfont) or 1
  local key = stringformat("%s::%s", filename, subfont)
  if tsbtable[key] then
    return tsbtable[key]
  end
  local f = openfile(filename, true) -- true: zero-based
  if f then
    local vmtx
    local tables = getotftables(f, subfont)
    if tables then
      local vhea = readvhea(f, tables.vhea)
      local numofheights = vhea and vhea.numheights
      local maxp = readmaxp(f, tables.maxp)
      local numofglyphs = maxp and maxp.numglyphs
      vmtx = readvmtx(f, tables.vmtx, numofheights, numofglyphs)
    end
    closefile(f)
    tsbtable[key] = vmtx
    return vmtx
  end
end

local function cjk_vertical_font (vf)
  if not vf.shared then return end
  if not vf.shared.features then return end
  if not vf.shared.features["vertical"] then return end
  if vf.type == "virtual" then return end

  local subfont  = vf.specification and vf.specification.sub
  local tsbtable = get_tsb_table(vf.filename, subfont)
  if not tsbtable then
    warn("%s does not have vertical metric info", vf.fontname)
    return
  end

  local params    = vf.parameters   or {}
  local shared    = vf.shared       or {}
  local quad      = params.quad     or 655360
  local ascender  = params.ascender or quad*0.8
  local descender = params.descender or quad*0.2
  local factor    = params.factor   or 655.36
  local xheight   = params.x_height or quad/2
  local goffset   = xheight/2 - quad/2
  local descriptions = shared.rawdata and shared.rawdata.descriptions
  local spbp = 65536*(7227/7200)
  for i,v in pairs(vf.characters) do
    local dsc     = descriptions[i]
    local gl      = v.index
    local tsb_gl  = tsbtable and tsbtable[gl]
    local vw      = tsb_gl and tsb_gl.ht; vw = vw and vw * factor or quad
    local tsb     = tsb_gl and tsb_gl.tsb
    local bb4     = dsc and dsc.boundingbox and dsc.boundingbox[4]
    local asc     = bb4 and tsb and (bb4+tsb)*factor or ascender
    local hw      = v.width or quad
    local offset  = hw/2 + goffset
    local vh      = hw > 0 and hw or 0
    asc = asc/spbp; offset = offset/spbp
    v.commands = {
      {'special', stringformat('pdf:q 0 1 -1 0 %.3f %.3f cm', asc, -offset)},
      {'push'},
      {'char',    i},
      {'pop'},
      {'special', 'pdf:Q'},
    }
    v.width   = vw
    v.height  = vh*(ascender/quad)
    v.depth   = vh*(descender/quad)
    v.italic  = nil
  end
  --- vertical gpos
  local res = vf.resources or {}
  if res.verticalgposhack then
    return -- avoid multiple running
  end
  local fea = shared.features or {}
  fea.kern = nil  -- only for horizontal typesetting
  fea.vert = true -- should be activated by default
  local seq = res.sequences or {}
  for _,v in ipairs(seq) do
    local fea = v.features or {}
    if fea.vhal or fea.vkrn or fea.valt or fea.vpal or fea.vert then
      if v.type == "gpos_single" then
        for _,vv in pairs(v.steps or{}) do
          local cover = vv.coverage or {}
          for iii,vvv in pairs(cover) do
            if type(vvv) == "table" and #vvv == 4 then
              cover[iii] = { -vvv[2], vvv[1], vvv[4], vvv[3], 0 }
            end
          end
        end
      elseif v.type == "gpos_pair" then
        for _,vv in pairs(v.steps or {}) do
          for _,vvv in pairs(vv.coverage or {}) do
            for _,vvvv in pairs(vvv) do
              for iiiii,vvvvv in pairs(vvvv) do
                if type(vvvvv) == "table" and #vvvvv == 4 then
                  -- last 0 to avoid multiple round
                  vvvv[iiiii] = { -vvvvv[2], vvvvv[1], vvvvv[4], vvvvv[3], 0 }
                end
              end
            end
          end
        end
      end
    end
  end
  res.verticalgposhack = true
end

local otffeatures = fonts.constructors.newfeatures("otf")
otffeatures.register {
  name         = "vertical",
  description  = "vertical typesetting",
  initializers = {
    node = function (tfmdata,value)
      if value and not tsbtable then
        tsbtable  = {}
        add_to_callback("luaotfload.patch_font",cjk_vertical_font,"luatexko.vertical_virtual_font")
      end
    end
  }
}

------------------------------------
-- no embedding
------------------------------------
local function dontembedthisfont (tfmdata, value)
  if value == "no" then
    fonts.constructors.dontembed[tfmdata.properties.filename] = 1
  end
end

otffeatures.register {
  name        = "embedding",
  description = "dont embed this font",
  initializers = {
    base = dontembedthisfont,
    node = dontembedthisfont,
  }
}

------------------------------------
-- italic correction for fake-slant font
------------------------------------
local function fakeslant_itlc (tfmdata)
  local slfactor = tfmdata.parameters.slantfactor
  if slfactor and slfactor > 0 then else return end
  tfmdata.parameters.slant = slfactor * 65536
  local chrs = tfmdata.characters
  for i,v in pairs(chrs) do
    local italic = v.height * slfactor
    if italic > 0 then
      chrs[i].italic = italic
    end
  end
end

add_to_callback("luaotfload.patch_font", fakeslant_itlc, "luatexko.fakeslant_itlc")

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
