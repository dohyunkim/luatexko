-- luatexko.lua
--
-- Copyright (c) 2013-2019 Dohyun Kim <nomos at ktug org>
--                         Soojin Nam <jsunam at gmail com>
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
  date        = '2019/05/25',
  version     = '2.1',
  description = 'typesetting Korean with LuaTeX',
  author      = 'Dohyun Kim, Soojin Nam',
  license     = 'LPPL v1.3+',
}

luatexko = luatexko or {}
local luatexko = luatexko

local dimensions      = node.dimensions
local end_of_math     = node.end_of_math
local getglue         = node.getglue
local getnext         = node.getnext
local getprev         = node.getprev
local getproperty     = node.getproperty
local has_attribute   = node.has_attribute
local has_glyph       = node.has_glyph
local insert_after    = node.insert_after
local insert_before   = node.insert_before
local nodecopy        = node.copy
local nodecount       = node.count
local nodefree        = node.free
local nodeid          = node.id
local nodenew         = node.new
local noderemove      = node.remove
local nodeslide       = node.slide
local nodesubtype     = node.subtype
local nodewrite       = node.write
local rangedimensions = node.rangedimensions
local setglue         = node.setglue
local setproperty     = node.setproperty
local unset_attribute = node.unset_attribute

local fontcurrent   = font.current
local fontfonts     = font.fonts
local fontgetfont   = font.getfont
local getparameters = font.getparameters

local texcount = tex.count
local texround = tex.round
local texset   = tex.set
local texsp    = tex.sp

local stringformat = string.format

local tableconcat = table.concat
local tableinsert = table.insert
local tableunpack = table.unpack

local add_to_callback     = luatexbase.add_to_callback
local attributes          = luatexbase.attributes
local call_callback       = luatexbase.call_callback
local create_callback     = luatexbase.create_callback
local module_warning      = luatexbase.module_warning
local new_user_whatsit    = luatexbase.new_user_whatsit
local new_user_whatsit_id = luatexbase.new_user_whatsit_id
local registernumber      = luatexbase.registernumber

local function warning (...)
  return module_warning("luatexko", stringformat(...))
end

local dirid     = nodeid"dir"
local discid    = nodeid"disc"
local glueid    = nodeid"glue"
local glyphid   = nodeid"glyph"
local hlistid   = nodeid"hlist"
local kernid    = nodeid"kern"
local mathid    = nodeid"math"
local penaltyid = nodeid"penalty"
local ruleid    = nodeid"rule"
local vlistid   = nodeid"vlist"
local whatsitid = nodeid"whatsit"
local literal_whatsit = nodesubtype"pdf_literal"
local user_whatsit    = nodesubtype"user_defined"
local directmode = 2
local fontkern   = 0
local userkern   = 1
local italcorr   = 3
local lua_number = 100
local lua_value  = 108
local spaceskip  = 13
local nohyphen = registernumber"l@nohyphenation" or -1 -- verbatim

local hangulfontattr   = attributes.luatexkohangulfontattr
local hanjafontattr    = attributes.luatexkohanjafontattr
local fallbackfontattr = attributes.luatexkofallbackfontattr
local autojosaattr     = attributes.luatexkoautojosaattr
local classicattr      = attributes.luatexkoclassicattr
local dotemphattr      = attributes.luatexkodotemphattr
local rubyattr         = attributes.luatexkorubyattr

local vert_classic = 1
local SC_classic   = 2

local function is_hanja (c)
  return c >= 0x3400 and c <= 0xA4C6
  or     c >= 0xF900 and c <= 0xFAD9
  or     c >= 0x20000 and c <= 0x2FFFD
  or     c >= 0x2E81 and c <= 0x2FD5
end

local function is_hangul (c)
  return c >= 0xAC00 and c <= 0xD7A3
end

local function is_chosong (c)
  return c >= 0x1100 and c <= 0x115F
  or     c >= 0xA960 and c <= 0xA97C
end

local function is_jungsong (c)
  return c >= 0x1160 and c <= 0x11A7
  or     c >= 0xD7B0 and c <= 0xD7C6
end

local function is_jongsong (c)
  return c >= 0x11A8 and c <= 0x11FF
  or     c >= 0xD7CB and c <= 0xD7FB
end

local hangul_tonemark = {
  [0x302E] = true, [0x302F] = true,
}

local function is_unicode_var_sel (c)
  return c >= 0xFE00  and c <= 0xFE0F
  or     c >= 0xE0100 and c <= 0xE01EF
end

local function is_cjk_combining (c)
  return c >= 0x302A and c <= 0x302F
  or     c >= 0x3099 and c <= 0x309C
  or     c >= 0xFF9E and c <= 0xFF9F
  or     is_unicode_var_sel(c)
end

local function is_noncjkletter (c)
  return c >= 0x30 and c <= 0x39
  or     c >= 0x41 and c <= 0x5A
  or     c >= 0x61 and c <= 0x7A
  or     c >= 0xC0 and c <= 0xD6
  or     c >= 0xD8 and c <= 0xF6
  or     c >= 0xF8 and c <= 0x10FC
  or     c >= 0x1200 and c <= 0x1FFE
  or     c >= 0xA4D0 and c <= 0xA877
  or     c >= 0xAB01 and c <= 0xABBF
  or     c >= 0xFB00 and c <= 0xFDFD
  or     c >= 0xFE70 and c <= 0xFEFC
end

local function is_kana (c)
  return c >= 0x3041 and c <= 0x3096
  or     c >= 0x30A1 and c <= 0x30FA
  or     c >= 0x31F0 and c <= 0x31FF
  or     c >= 0xFF66 and c <= 0xFF6F
  or     c >= 0xFF71 and c <= 0xFF9D
  or     c == 0x309F or c == 0x30FF
  or     c >= 0x1B000 and c <= 0x1B16F
end

local function is_hangul_jamo (c)
  return is_hangul(c)
  or     is_chosong(c)
  or     is_jungsong(c)
  or     is_jongsong(c)
  or     c >= 0x3131 and c <= 0x318E
end

local stretch_f, shrink_f = 5/100, 3/100 -- should be consistent for ruby

local function get_font_data (fontid)
  return fontgetfont(fontid) or fontfonts[fontid] or {}
end

local function get_font_param (f, key)
  local t
  if type(f) == "number" then
    t = getparameters(f)
    if t and t[key] then
      return t[key]
    end
    f = get_font_data(f)
  end
  if type(f) == "table" then
    t = f.parameters
    return t and t[key]
  end
end

local function get_en_size (f)
  local quad = get_font_param(f, "quad")
  return quad and quad/2 or 327680
end

local function char_in_font(fontdata, char)
  if type(fontdata) == "number" then
    fontdata = get_font_data(fontdata)
  end
  if fontdata.characters then
    return fontdata.characters[char]
  end
end

local function option_in_font (fontdata, optionname)
  if type(fontdata) == "number" then
    fontdata = get_font_data(fontdata)
  end
  if fontdata.shared then
    return fontdata.shared.features[optionname]
  end
end

local function my_node_props (n)
  local t = getproperty(n)
  if not t then
    t = {}
    setproperty(n, t)
  end
  t.luatexko = t.luatexko or {}
  return t.luatexko
end

-- font fallback

local force_hangul = {
  [0x21] = true, -- !
  [0x27] = true, -- '
  [0x28] = true, -- (
  [0x29] = true, -- )
  [0x2C] = true, -- ,
  [0x2E] = true, -- .
  [0x3A] = true, -- :
  [0x3B] = true, -- ;
  [0x3F] = true, -- ?
  [0x60] = true, -- `
  [0xB7] = true, -- ·
  [0x2014] = true, -- —
  [0x2015] = true, -- ―
  [0x2018] = true, -- ‘
  [0x2019] = true, -- ’
  [0x201C] = true, -- “
  [0x201D] = true, -- ”
  [0x2026] = true, -- …
  [0x203B] = true, -- ※
}
luatexko.forcehangulchars = force_hangul

local forcehf_f, forcehf_id = new_user_whatsit("forcehf","luatexko")

local function update_force_hangul (value)
  local what = forcehf_f()
  what.type  = lua_value -- function
  what.value = value
  nodewrite(what)
end
luatexko.updateforcehangul = update_force_hangul

local active_processes = {}

local char_font_options = {
  interhangul     = {},
  interlatincjk   = {},
  intercharacter  = {},
  hangulspaceskip = {},
  tonemarkwidth   = {},
}

local function hangul_space_skip (curr, newfont)
  if curr.lang ~= nohyphen then
    local n = getnext(curr)
    if n and n.id == glueid and n.subtype == spaceskip then
      local params = getparameters(curr.font)
      local oldwd, oldst, oldsh, oldsto, oldsho = getglue(n)
      if params
        and oldwd == params.space
        and oldst == params.space_stretch
        and oldsh == params.space_shrink
        and oldsto == 0
        and oldsho == 0 then -- not user's spaceskip

        local newwd = char_font_options.hangulspaceskip[newfont]
        if newwd == nil then
          local newsp = nodecopy(curr)
          newsp.char, newsp.font = 32, newfont
          newsp = nodes.simple_font_handler(newsp)
          newwd = newsp and newsp.width or false
          if newwd then
            newwd = { texround(newwd), texround(newwd/2), texround(newwd/3) }
          end
          char_font_options.hangulspaceskip[newfont] = newwd
          if newsp then
            nodefree(newsp)
          end
        end
        if newwd then
          setglue(n, newwd[1], newwd[2], newwd[3])
        end
      end
    end
  end
end

local function process_fonts (head)
  local curr = head
  while curr do
    local id = curr.id
    if id == glyphid then
      local props = my_node_props(curr)
      if not props.unicode then

        local c = curr.char

        if is_unicode_var_sel(c) then
          local p = getprev(curr)
          if p.id == glyphid and curr.font ~= p.font then
            hangul_space_skip(curr, p.font)
            curr.font = p.font
          end
        else
          local hf  = has_attribute(curr, hangulfontattr) or false
          local hjf = has_attribute(curr, hanjafontattr)  or false
          local fontdata  = get_font_data(curr.font)
          local format    = fontdata.format
          local no_legacy = format == "opentype" or format == "truetype"
          if hf and no_legacy and force_hangul[c] and curr.lang ~= nohyphen then
            curr.font = hf
          elseif hf and luatexko.hangulbyhangulfont and is_hangul_jamo(c) then
            hangul_space_skip(curr, hf)
            curr.font = hf
          elseif hjf and luatexko.hanjabyhanjafont and is_hanja(c) then
            hangul_space_skip(curr, hjf)
            curr.font = hjf
          elseif not char_in_font(fontdata, c) then
            local fbf = has_attribute(curr, fallbackfontattr) or false
            for _,f in ipairs{ hf, hjf, fbf } do
              if f and char_in_font(f, c) then
                hangul_space_skip(curr, f)
                curr.font = f
                break
              end
            end
          end
        end

        if not active_processes.reorderTM
          and hangul_tonemark[c]
          and option_in_font(curr.font, "script") == "hang" then
          luatexko.activate("reorderTM") -- activate reorderTM here
          active_processes.reorderTM = true
        end

        props.unicode = c
      end
    elseif id == discid then
      curr.pre     = process_fonts(curr.pre)
      curr.post    = process_fonts(curr.post)
      curr.replace = process_fonts(curr.replace)
    elseif id == mathid then
      curr = end_of_math(curr)
    elseif id == whatsitid
      and curr.subtype == user_whatsit
      and curr.user_id == forcehf_id
      and curr.type == lua_value then

      local value = curr.value
      if type(value) == "function" then
        value()
      end
    end
    curr = getnext(curr)
  end
  return head
end

-- linebreak

local intercharclass = { [0] =
  { [0] = nil,    {1,1},  nil,    {.5,.5} },
  { [0] = nil,    nil,    nil,    {.5,.5} },
  { [0] = {1,1},  {1,1},  nil,    {.5,.5}, nil,    {1,1},  {1,1} },
  { [0] = {.5,.5},{.5,.5},{.5,.5},{1,.5},  {.5,.5},{.5,.5},{.5,.5} },
  { [0] = {1,0},  {1,0},  nil,    {1.5,.5},nil,    {1,0},  {1,0} },
  { [0] = nil,    {1,1},  nil,    {.5,.5} },
  { [0] = {1,1},  {1,1},  nil,    {.5,.5} },
}

local charclass = setmetatable({
  [0x2018] = 1, [0x201C] = 1, [0x2329] = 1, [0x3008] = 1,
  [0x300A] = 1, [0x300C] = 1, [0x300E] = 1, [0x3010] = 1,
  [0x3014] = 1, [0x3016] = 1, [0x3018] = 1, [0x301A] = 1,
  [0x301D] = 1, [0xFE17] = 1, [0xFE35] = 1, [0xFE37] = 1,
  [0xFE39] = 1, [0xFE3B] = 1, [0xFE3D] = 1, [0xFE3F] = 1,
  [0xFE41] = 1, [0xFE43] = 1, [0xFE47] = 1, [0xFF08] = 1,
  [0xFF3B] = 1, [0xFF5B] = 1, [0xFF5F] = 1, [0xFF62] = 1,
  --
  [0x2019] = 2, [0x201D] = 2, [0x232A] = 2, [0x3001] = 2,
  [0x3009] = 2, [0x300B] = 2, [0x300D] = 2, [0x300F] = 2,
  [0x3011] = 2, [0x3015] = 2, [0x3017] = 2, [0x3019] = 2,
  [0x301B] = 2, [0x301E] = 2, [0x301F] = 2, [0xFE10] = 2,
  [0xFE11] = 2, [0xFE18] = 2, [0xFE36] = 2, [0xFE38] = 2,
  [0xFE3A] = 2, [0xFE3C] = 2, [0xFE3E] = 2, [0xFE40] = 2,
  [0xFE42] = 2, [0xFE44] = 2, [0xFE48] = 2, [0xFF09] = 2,
  [0xFF0C] = 2, [0xFF3D] = 2, [0xFF5D] = 2, [0xFF60] = 2,
  [0xFF63] = 2, [0xFF64] = 2,
  --
  [0x00B7] = 3, [0x30FB] = 3, [0xFF1A] = 3, [0xFF1B] = 3,
  [0xFF65] = 3,
  --
  [0x3002] = 4, [0xFE12] = 4, [0xFF0E] = 4, [0xFF61] = 4,
  --
  [0x2015] = 5, [0x2025] = 5, [0x2026] = 5, [0xFE19] = 5,
  [0xFE30] = 5, [0xFE31] = 5,
  --
  [0xFE15] = 6, [0xFE16] = 6, [0xFF01] = 6, [0xFF1F] = 6,
}, { __index = function() return 0 end })

local SC_charclass = setmetatable({
  [0xFF01] = 4, [0xFF1A] = 4, [0xFF1B] = 4, [0xFF1F] = 4,
}, { __index = function(_,c) return charclass[c] end })

local vert_charclass = setmetatable({
  [0xFF1A] = 5, -- 0xFE13
  [0xFF1B] = 5, -- 0xFE14
}, { __index = function(_,c) return charclass[c] end })

local function get_char_class (c, classic)
  if classic == vert_classic then
    return vert_charclass[c]
  elseif classic == SC_classic then
    return SC_charclass[c]
  end
  return charclass[c]
end

local breakable_after = setmetatable({
  [0x21] = true,   [0x22] = true,   [0x25] = true,   [0x27] = true,
  [0x29] = true,   [0x2C] = true,   [0x2D] = true,   [0x2E] = true,
  [0x3A] = true,   [0x3B] = true,   [0x3E] = true,   [0x3F] = true,
  [0x5D] = true,   [0x7D] = true,   [0x7E] = true,   [0xBB] = true,
  [0x2013] = true, [0x2014] = true, [0x25A1] = true, [0x25CB] = true,
  [0x2E80] = true, [0x3003] = true, [0x3005] = true, [0x3007] = true,
  [0x301C] = true, [0x3035] = true, [0x303B] = true, [0x303C] = true,
  [0x309D] = true, [0x309E] = true, [0x30A0] = true, [0x30FC] = true,
  [0x30FD] = true, [0x30FE] = true, [0xFE13] = true, [0xFE14] = true,
  [0xFE32] = true, [0xFE50] = true, [0xFE51] = true, [0xFE52] = true,
  [0xFE54] = true, [0xFE55] = true, [0xFE57] = true, [0xFE57] = true,
  [0xFE58] = true, [0xFE5A] = true, [0xFE5C] = true, [0xFE5E] = true,
  [0xFF1E] = true, [0xFF5E] = true, [0xFF70] = true,
},{ __index = function (_,c)
  return is_hangul_jamo(c) and not is_chosong(c)
  or is_noncjkletter(c)
  or is_hanja(c)
  or is_cjk_combining(c)
  or is_kana(c)
  or charclass[c] >= 2
end })
luatexko.breakableafter = breakable_after

local breakable_before = setmetatable({
  [0x28] = true,   [0x3C] = true,   [0x5B] = true,   [0x60] = true,
  [0x7B] = true,   [0xAB] = true,   [0x25A1] = true, [0x25CB] = true,
  [0x3007] = true, [0xFE59] = true, [0xFE5B] = true, [0xFE5D] = true,
  [0xFF1C] = true,
  -- small kana
  [0x3041] = 1000, [0x3043] = 1000, [0x3045] = 1000, [0x3047] = 1000,
  [0x3049] = 1000, [0x3063] = 1000, [0x3083] = 1000, [0x3085] = 1000,
  [0x3087] = 1000, [0x308E] = 1000, [0x3095] = 1000, [0x3096] = 1000,
  [0x30A1] = 1000, [0x30A3] = 1000, [0x30A5] = 1000, [0x30A7] = 1000,
  [0x30A9] = 1000, [0x30C3] = 1000, [0x30E3] = 1000, [0x30E5] = 1000,
  [0x30E7] = 1000, [0x30EE] = 1000, [0x30F5] = 1000, [0x30F6] = 1000,
  [0x31F0] = 1000, [0x31F1] = 1000, [0x31F2] = 1000, [0x31F3] = 1000,
  [0x31F4] = 1000, [0x31F5] = 1000, [0x31F6] = 1000, [0x31F7] = 1000,
  [0x31F8] = 1000, [0x31F9] = 1000, [0x31FA] = 1000, [0x31FB] = 1000,
  [0x31FC] = 1000, [0x31FD] = 1000, [0x31FE] = 1000, [0x31FF] = 1000,
  [0xFF67] = 1000, [0xFF68] = 1000, [0xFF69] = 1000, [0xFF6A] = 1000,
  [0xFF6B] = 1000, [0xFF6C] = 1000, [0xFF6D] = 1000, [0xFF6E] = 1000,
  [0xFF6F] = 1000,  [0x1B150] = 1000, [0x1B151] = 1000, [0x1B152] = 1000,
  [0x1B164] = 1000, [0x1B165] = 1000, [0x1B166] = 1000, [0x1B167] = 1000,
},{ __index = function(_,c)
  return is_hangul_jamo(c) and not is_jungsong(c) and not is_jongsong(c)
  or is_hanja(c)
  or is_kana(c)
  or charclass[c] == 1
end
})
luatexko.breakablebefore = breakable_before

local allowbreak_false_nodes = {
  [hlistid]   = true,
  [vlistid]   = true,
  [ruleid]    = true,
  [discid]    = true,
  [glueid]    = true,
  [penaltyid] = true,
}

local function is_blocking_node (curr)
  local id, subtype = curr.id, curr.subtype
  return allowbreak_false_nodes[id] or id == kernid and subtype == userkern
end

local function ruby_char_font (rb)
  local n, c, f = has_glyph(rb.list), 0, 0
  if n then
    c, f = my_node_props(n).unicode or n.char, n.font or 0
    if is_chosong(c) or hangul_tonemark[c] then
      c = 0xAC00
    end
  end
  return c, f
end

local function get_actualtext (curr)
  local actual = my_node_props(curr).startactualtext
  if type(actual) == "table" then
     return actual[0], actual[1], actual[#actual]
  end
end

local function goto_end_actualtext (curr)
  local n = getnext(curr)
  while n do
    if n.id == whatsitid
      and n.mode == directmode
      and my_node_props(n).endactualtext then
      curr = n
      break
    end
    n = getnext(n)
  end
  return curr
end

local function fontdata_opt_dim (fd, optname)
  local dim = option_in_font(fd, optname)
  if dim then
    local m, u = dim:match"(.+)(e[mx])%s*$"
    if m and u then
      if u == "em" then
        dim = m * fd.parameters.quad
      else
        dim = m * fd.parameters.x_height
      end
    else
      dim = texsp(dim)
    end
    return dim
  end
end

local function get_font_opt_dimen (fontid, optionname)
  local t = char_font_options[optionname]
  local dim = t and t[fontid]
  if dim == nil then
    local fd = get_font_data(fontid)
    dim = fontdata_opt_dim(fd, optionname)
    t[fontid] = dim or false -- cache
  end
  return dim
end

local function insert_glue_before (head, curr, par, br, brb, classic, ict, dim)
  local pn = nodenew(penaltyid)
  if not br then
    pn.penalty = 10000
  elseif type(brb) == "number" then
    pn.penalty = brb
  elseif par and nodecount(glyphid, curr) <= 2 then
    pn.penalty = 1000 -- supress orphan
  else
    pn.penalty = 50
  end

  dim = dim or 0
  local gl = nodenew(glueid)
  local en = get_en_size(curr.font)
  if ict then
    en = classic and en or en/4
    setglue(gl, en * ict[1] + dim, nil, en * ict[2])
  else
    setglue(gl, dim, en * stretch_f, en * shrink_f)
  end

  head = insert_before(head, curr, pn)
  return insert_before(head, curr, gl)
end

local function maybe_linebreak (head, curr, pc, pcl, cc, old, fid, par)
  local ccl = get_char_class(cc, old)
  if pc and cc and curr.lang ~= nohyphen then
    local ict = intercharclass[pcl][ccl]
    local brb = breakable_before[cc]
    local br  = brb and breakable_after[pc]
    local dim = get_font_opt_dimen(fid, "intercharacter")
    if ict or br or dim and (pcl >= 1 or ccl >= 1) then
      head = insert_glue_before(head, curr, par, br, brb, old, ict, dim)
    end
  end
  return head, cc, ccl
end

local function process_linebreak (head, par)
  local curr, pc, pcl = head, false, 0
  while curr do
    local id = curr.id
    if id == glyphid then
      local cc = my_node_props(curr).unicode or curr.char
      local old = has_attribute(curr, classicattr)
      head, pc, pcl = maybe_linebreak(head, curr, pc, pcl, cc, old, curr.font, par)

    elseif id == hlistid and has_attribute(curr, rubyattr) then
      local cc, fi = ruby_char_font(curr) -- rubybase
      local old = has_attribute(curr, classicattr)
      head, pc, pcl = maybe_linebreak(head, curr, pc, pcl, cc, old, fi, par)

    elseif id == whatsitid and curr.mode == directmode then
      local glyf, cc, fin = get_actualtext(curr)
      if cc and fin and glyf then
        local old = has_attribute(glyf, classicattr)
        head = maybe_linebreak(head, curr, pc, pcl, cc, old, glyf.font, par)
        pc, pcl, curr = fin, 0, goto_end_actualtext(curr)
      end

    elseif id == mathid then
      pc, pcl, curr = 0x30, 0, end_of_math(curr)
    elseif id == dirid then
      pc, pcl = curr.dir:sub(1,1) == "-" and 0x30, 0 -- pop dir
    elseif is_blocking_node(curr) then
      pc, pcl = false, 0
    end
    curr = getnext(curr)
  end
  return head
end

-- compress punctuations

local function process_glyph_width (head)
  local curr = head
  while curr do
    local id = curr.id
    if id == glyphid then
      if curr.lang ~= nohyphen
        and option_in_font(curr.font, "compresspunctuations") then

        local cc = my_node_props(curr).unicode or curr.char
        local old = has_attribute(curr, classicattr)
        local class = get_char_class(cc, old)
        if class >= 1 and class <= 4 and
          (old or cc < 0x2000 or cc > 0x202F) then -- exclude general puncts

          local gpos = class == 1 and getprev(curr) or getnext(curr)
          gpos = gpos and gpos.id == kernid and gpos.subtype == fontkern

          if not gpos then
            local wd = get_en_size(curr.font) - curr.width
            if wd ~= 0 then
              local k = nodenew(kernid) -- fontkern (subtype 0) is default
              k.kern = class == 3 and wd/2 or wd
              if class == 1 then
                head = insert_before(head, curr, k)
              elseif class == 2 or class == 4 then
                head, curr = insert_after(head, curr, k)
              else
                local k2 = nodecopy(k)
                head = insert_before(head, curr, k)
                head, curr = insert_after(head, curr, k2)
              end
            end
          end
        end
      end
    elseif id == mathid then
      curr = end_of_math(curr)
    end
    curr = getnext(curr)
  end
  return head
end

-- interhangul & interlatincjk

local function is_cjk (c)
  return is_hangul_jamo(c)
  or     is_hanja(c)
  or     is_cjk_combining(c)
  or     is_kana(c)
  or     charclass[c] >= 1
  or     rawget(breakable_before, c) and c >= 0x2000
  or     rawget(breakable_after,  c) and c >= 0x2000
end

local function do_interhangul_option (head, curr, pc, c, fontid, par)
  local cc = (is_hangul(c) or is_chosong(c)) and 1 or 0

  if cc*pc == 1 and curr.lang ~= nohyphen then
    local dim = get_font_opt_dimen(fontid, "interhangul")
    if dim then
      head = insert_glue_before(head, curr, par, true, true, false, false, dim)
    end
  end

  return head, cc
end

local function process_interhangul (head, par)
  local curr, pc = head, 0
  while curr do
    local id = curr.id
    if id == glyphid then
      local c = my_node_props(curr).unicode or curr.char
      head, pc = do_interhangul_option(head, curr, pc, c, curr.font, par)

      if is_chosong(c) then
        pc = 0
      elseif is_jungsong(c) or is_jongsong(c) or hangul_tonemark[c] then
        pc = 1
      end

    elseif id == hlistid and has_attribute(curr, rubyattr) then
      local c, fi = ruby_char_font(curr)
      head, pc = do_interhangul_option(head, curr, pc, c, fi, par)

    elseif id == whatsitid and curr.mode == directmode then
      local glyf, c = get_actualtext(curr)
      if c and glyf then
        head = do_interhangul_option(head, curr, pc, c, glyf.font, par)
        pc, curr = 1, goto_end_actualtext(curr)
      end

    elseif id == mathid then
      pc, curr = 0, end_of_math(curr)
    elseif is_blocking_node(curr) or id == dirid then
      pc = 0
    end
    curr = getnext(curr)
  end
  return head
end

local function do_interlatincjk_option (head, curr, pc, pf, c, cf, par)
  local cc = is_cjk(c) and 1 or is_noncjkletter(c) and 2 or 0
  local brb = cc == 2 or breakable_before[c] -- numletter != br_before

  if brb and cc*pc == 2 and curr.lang ~= nohyphen then
    local fontid = cc == 1 and cf or pf
    local dim = get_font_opt_dimen(fontid, "interlatincjk")
    if dim then
      head = insert_glue_before(head, curr, par, true, brb, false, false, dim)
    end
  end

  return head, cc, cf
end

local function process_interlatincjk (head, par)
  local curr, pc, pf = head, 0, 0
  while curr do
    local id = curr.id
    if id == glyphid then
      local c = my_node_props(curr).unicode or curr.char
      head, pc, pf = do_interlatincjk_option(head, curr, pc, pf, c, curr.font, par)
      pc = breakable_after[c] and pc or 0

    elseif id == hlistid and has_attribute(curr, rubyattr) then
      local c, cf = ruby_char_font(curr)
      head, pc, pf = do_interlatincjk_option(head, curr, pc, pf, c, cf, par)

    elseif id == whatsitid and curr.mode == directmode then
      local glyf, c = get_actualtext(curr)
      if c and glyf then
        head, pc, pf = do_interlatincjk_option(head, curr, pc, pf, c, glyf.font, par)
        curr = goto_end_actualtext(curr)
      end

    elseif id == mathid then
      if pc == 1 then
        head = do_interlatincjk_option(head, curr, pc, pf, 0x30, pf, par)
      end
      pc, curr = 2, end_of_math(curr)

    elseif id == dirid then
      if pc == 1 and curr.dir:sub(1,1) == "+" then
        head = do_interlatincjk_option(head, curr, pc, pf, 0x30, pf, par)
        pc = 0
      end

    elseif is_blocking_node(curr) then
      pc = 0
    end
    curr = getnext(curr)
  end
  return head
end

-- remove classic spaces

local function process_remove_spaces (head)
  local curr, opt_name, to_free = head, "removeclassicspaces", {}
  while curr do
    local id = curr.id
    if id == glueid then
      if curr.subtype == spaceskip and has_attribute(curr, classicattr) then

        for k, v in pairs{ p = getprev(curr), n = getnext(curr) } do
          local ok
          while v do
            local vid = v.id
            if vid ~= whatsitid -- skip whatsit or kern except userkern
              and ( vid ~= kernid or v.subtype == userkern ) then

              local vchar, vfont
              if vid == glyphid and v.lang ~= nohyphen then
                vchar, vfont = v.char, v.font
              elseif vid == hlistid and has_attribute(v, rubyattr) then
                vchar, vfont = ruby_char_font(v)
              end
              if vchar and vfont and option_in_font(vfont, opt_name) then
                ok = is_cjk(vchar)
              end

              break
            end
            v = k == "p" and getprev(v) or getnext(v)
          end
          if ok then
            head = noderemove(head, curr)
            tableinsert(to_free, curr)
            break
          end
        end
      end
    elseif id == mathid then
      curr = end_of_math(curr)
    end
    curr = getnext(curr)
  end
  for _,v in ipairs(to_free) do nodefree(v) end
  return head
end

-- josa

local josa_table = {
    --          리을,   중성,   종성
    [0xAC00] = {0xC774, 0xAC00, 0xC774}, -- 가 = 이, 가, 이
    [0xC740] = {0xC740, 0xB294, 0xC740}, -- 은 = 은, 는, 은
    [0xC744] = {0xC744, 0xB97C, 0xC744}, -- 을 = 을, 를, 을
    [0xC640] = {0xACFC, 0xC640, 0xACFC}, -- 와 = 과, 와, 과
    [0xC73C] = {nil,    nil,    0xC73C}, -- 으(로) =   ,  , 으
    [0xC774] = {0xC774, nil,    0xC774}, -- 이(라) = 이,  , 이
}

local josa_code = setmetatable({
    [0x30] = 3,   [0x31] = 1,   [0x33] = 3,   [0x36] = 3,
    [0x37] = 1,   [0x38] = 1,   [0x4C] = 1,   [0x4D] = 3,
    [0x4E] = 3,   [0x6C] = 1,   [0x6D] = 3,   [0x6E] = 3,
    [0x2160] = 1, [0x2162] = 3, [0x2165] = 3, [0x2166] = 1,
    [0x2167] = 1, [0x2169] = 3, [0x216A] = 1, [0x216C] = 3,
    [0x216D] = 3, [0x216E] = 3, [0x216F] = 3, [0x2170] = 1,
    [0x2172] = 3, [0x2175] = 3, [0x2176] = 1, [0x2177] = 1,
    [0x2179] = 3, [0x217A] = 1, [0x217C] = 3, [0x217D] = 3,
    [0x217E] = 3, [0x217F] = 3, [0x2460] = 1, [0x2462] = 3,
    [0x2465] = 3, [0x2466] = 1, [0x2467] = 1, [0x2469] = 3,
    [0x246A] = 1, [0x246C] = 3, [0x246F] = 3, [0x2470] = 1,
    [0x2471] = 1, [0x2473] = 3, [0x2474] = 1, [0x2476] = 3,
    [0x2479] = 3, [0x247A] = 1, [0x247B] = 1, [0x247D] = 3,
    [0x247E] = 1, [0x2480] = 3, [0x2483] = 3, [0x2484] = 1,
    [0x2485] = 1, [0x2487] = 3, [0x2488] = 1, [0x248A] = 3,
    [0x248D] = 3, [0x248E] = 1, [0x248F] = 1, [0x2491] = 3,
    [0x2492] = 1, [0x2494] = 3, [0x2497] = 3, [0x2498] = 1,
    [0x2499] = 1, [0x249B] = 3, [0x24A7] = 1, [0x24A8] = 3,
    [0x24A9] = 3, [0x24C1] = 1, [0x24C2] = 3, [0x24C3] = 3,
    [0x24DB] = 1, [0x24DC] = 3, [0x24DD] = 3, [0x3139] = 1,
    [0x3203] = 1, [0x3263] = 1, [0xFF10] = 3, [0xFF11] = 1,
    [0xFF13] = 3, [0xFF16] = 3, [0xFF17] = 1, [0xFF18] = 1,
    [0xFF2C] = 1, [0xFF2D] = 3, [0xFF2E] = 3, [0xFF4C] = 1,
    [0xFF4D] = 3, [0xFF4E] = 3,
},{ __index = function(_,c)
  if is_hangul(c) then
    c = (c - 0xAC00) % 28 + 0x11A7
  end
  if is_chosong(c) then
    return c == 0x1105 and 1 or 3
  elseif is_jungsong(c) then
    return c ~= 0x1160 and 2
  elseif is_jongsong(c) then
    return c == 0x11AF and 1 or 3
  elseif is_noncjkletter(c) and c <= 0x7A
    or c >= 0x2160 and c <= 0x217F -- roman
    or c >= 0x2460 and c <= 0x24E9 -- ①
    or c >= 0x314F and c <= 0x3163 or c >= 0x3187 and c <= 0x318E -- ㅏ
    or c >= 0x320E and c <= 0x321E -- ㈎
    or c >= 0x326E and c <= 0x327F -- ㉮
    or c >= 0xFF10 and c <= 0xFF19 -- ０
    or c >= 0xFF21 and c <= 0xFF3A -- Ａ
    or c >= 0xFF41 and c <= 0xFF5A -- ａ
    then return 2
  elseif c >= 0x3131 and c <= 0x314E or c >= 0x3165 and c <= 0x3186 -- ㄱ
    or c >= 0x3200 and c <= 0x320D -- ㈀
    or c >= 0x3260 and c <= 0x326D -- ㉠
    then return 3
  end
end })

local ignore_parens = false

local function prevjosacode (n, parenlevel)
  local parenlevel, josacode = parenlevel or 0
  while n do
    local id = n.id
    if id == glyphid then
      local c = my_node_props(n).unicode or n.char -- beware hlist/vlist
      if ignore_parens and c == 0x29 then
        parenlevel = parenlevel + 1
      elseif ignore_parens and c == 0x28 then
        parenlevel = parenlevel - 1
      elseif parenlevel <= 0 then
        josacode = josa_code[c]
        if josacode then break end
      end
    elseif id == hlistid or id == vlistid then
      local list = n.list
      if list then
        josacode, parenlevel = prevjosacode(nodeslide(list), parenlevel)
        if josacode then break end
      end
    end
    n = getprev(n)
  end
  return josacode, parenlevel
end

local function process_josa (head)
  local curr, tofree = head, {}
  while curr do
    local id = curr.id
    if id == glyphid then
      local autojosaattr = has_attribute(curr, autojosaattr)
      if autojosaattr then
        local cc = curr.char
        if cc == 0xC774 then
          local n = getnext(curr)
          if n and n.char and is_hangul(n.char) then
          else
            cc = 0xAC00
          end
        end
        local t = josa_table[cc]
        if t then
          ignore_parens = autojosaattr > 0
          cc = t[prevjosacode(getprev(curr)) or 3]
          if cc then
            curr.char = cc
          else
            head = noderemove(head, curr)
            tableinsert(tofree, curr)
          end
        end
        unset_attribute(curr, autojosaattr)
      end
    elseif id == mathid then
      curr = end_of_math(curr)
    end
    curr = getnext(curr)
  end
  for _,v in ipairs(tofree) do nodefree(v) end
  return head
end

-- dotemph

local dotemphbox = {}
luatexko.dotemphbox = dotemphbox

local function process_dotemph (head, tofree)
  local curr, outer, tofree = head, not tofree, tofree or {}
  while curr do
    local id = curr.id
    if id == glyphid then
      local dotattr = has_attribute(curr, dotemphattr)
      if dotattr then
        local c = my_node_props(curr).unicode or curr.char
        if is_hangul(c) or is_hanja(c) or is_chosong(c) or is_kana(c) then
          local currwd = curr.width
          if currwd >= get_en_size(curr.font) then
            local box = nodecopy(dotemphbox[dotattr])
            local shift = (currwd - box.width)/2
            if shift ~= 0 then
              local list = box.list
              local k = nodenew(kernid)
              k.kern = shift
              box.list = insert_before(list, list, k)
            end
            box.width = 0
            head = insert_before(head, curr, box)
            tofree[dotattr] = true
          end
        end
        unset_attribute(curr, dotemphattr)
      end
    elseif id == hlistid then
      local list = curr.list
      if list then
        curr.list, tofree = process_dotemph(list, tofree)
      end
    end
    curr = getnext(curr)
  end
  if outer then
    for k in pairs(tofree) do nodefree(dotemphbox[k]) end
  end
  return head, tofree
end

-- uline

local uline_f, uline_id = new_user_whatsit("uline","luatexko")
local no_uline_id = new_user_whatsit_id("no_uline","luatexko")

local function ulboundary (i, n, subtype)
  local what = uline_f()
  if n then
    what.type  = lua_value -- table
    what.value = { i, nodecopy(n), subtype }
  else
    what.type  = lua_number
    what.value = i
  end
  nodewrite(what)
end
luatexko.ulboundary = ulboundary

local white_nodes = {
  [glueid]    = true,
  [penaltyid] = true,
  [kernid]    = true,
  [whatsitid] = true,
}

function skip_white_nodes (n, ltr)
  local nextnode = ltr and getnext or getprev
  while n do
    if not white_nodes[n.id] then break end
    n = nextnode(n)
  end
  return n
end

local function draw_uline (head, curr, parent, t, final)
  local start, list, subtype = t.start or head, t.list, t.subtype
  start = skip_white_nodes(start, true)
  if final then
    nodeslide(start) -- to get correct getprev.
  end
  curr  = skip_white_nodes(curr)
  curr  = getnext(curr) or curr
  local len = parent and rangedimensions(parent, start, curr)
                     or  dimensions(start, curr) -- it works?!
  if len and len ~= 0 then
    local g = nodenew(glueid)
    setglue(g, len)
    g.subtype = subtype
    g.leader = final and list or nodecopy(list)
    local k = nodenew(kernid)
    k.kern = -len
    head = insert_before(head, start, g)
    head = insert_before(head, start, k)
  end
  return head
end

local function process_uline (head, parent, items, level)
  local curr, items, level = head, items or {}, level or 0
  while curr do
    local id = curr.id
    if id == whatsitid
      and curr.subtype == user_whatsit
      and curr.user_id == uline_id then

      local value = curr.value
      if curr.type == lua_value then
        local count, list, subtype = tableunpack(value)
        items[count] = {
          start   = curr,
          list    = list,
          subtype = subtype,
          level   = level,
        }
      elseif items[value] then
        head = draw_uline(head, curr, parent, items[value], true)
        items[value] = nil
      end

      curr.user_id = no_uline_id -- avoid multiple run
    elseif id == hlistid then
      local list = curr.list
      if list then
        curr.list, items = process_uline(list, curr, items, level+1)
      end
    end
    curr = getnext(curr)
  end

  curr = nodeslide(head)
  for i, t in pairs(items) do
    if level == t.level then
      head = draw_uline(head, curr, parent, t)
      t.start = nil
    end
  end
  return head, items
end

-- ruby

local rubybox = {}
luatexko.rubybox = rubybox

local function process_ruby_pre_linebreak (head)
  local curr = head
  while curr do
    local id = curr.id
    if id == hlistid then
      local rubyid = has_attribute(curr, rubyattr)
      if rubyid then
        local ruby_t = rubybox[rubyid]
        if ruby_t[3] then -- rubyoverlap
          local side = (ruby_t[1].width - curr.width)/2
          if side > 0 then -- ruby is wide
            local k, r = nodenew(kernid), nodenew(ruleid)
            k.subtype, k.kern = userkern, -side
            r.width, r.height, r.depth = side, 0, 0
            local k2, r2 = nodecopy(k), nodecopy(r)
            head = insert_before(head, curr, k)
            head = insert_before(head, curr, r)
            head, curr = insert_after(head, curr, r2)
            head, curr = insert_after(head, curr, k2)
          end
          ruby_t[3] = false
        end
      end
    elseif id == mathid then
      curr = end_of_math(curr)
    end
    curr = getnext(curr)
  end
  return head
end

local function process_ruby_post_linebreak (head)
  local curr = head
  while curr do
    if curr.id == hlistid then
      local rubyid = has_attribute(curr, rubyattr)
      if rubyid then
        local ruby_t = rubybox[rubyid]
        local ruby = ruby_t and ruby_t[1]
        if ruby then
          local side = (curr.width - ruby.width)/2
          if side ~= 0 then
            local list = ruby.list
            local k = nodenew(kernid)
            k.kern = side
            ruby.list = insert_before(list, list, k)
          end
          ruby.width = 0
          local _, f = ruby_char_font(curr)
          local ascender = get_font_param(f, "ascender") or curr.height
          ruby.shift = -ascender - ruby.depth - ruby_t[2] -- rubysep
          head = insert_before(head, curr, ruby)
        end
        ruby_t = nil
        unset_attribute(curr, rubyattr)
      else
        local list = curr.list
        if list then
          curr.list = process_ruby_post_linebreak(list)
        end
      end
    end
    curr = getnext(curr)
  end
  return head
end

-- reorder tone marks

local function conv_tounicode (uni)
  if uni < 0x10000 then
    return stringformat("%04X", uni)
  else -- surrogate
    uni = uni - 0x10000
    local high = uni // 0x400 + 0xD800
    local low  = uni %  0x400 + 0xDC00
    return stringformat("%04X%04X", high, low)
  end
end

local function pdfliteral_direct_actual (syllable)
  local data
  if syllable then
    local t = {}
    for _,v in ipairs(syllable) do
      tableinsert(t, conv_tounicode(v))
    end
    data = stringformat("/Span<</ActualText<FEFF%s>>>BDC", tableconcat(t))
  else
    data = "EMC"
  end
  local what = nodenew(whatsitid, literal_whatsit)
  what.mode = directmode
  what.data = data
  if syllable then
    my_node_props(what).startactualtext = syllable
  else
    my_node_props(what).endactualtext = true
  end
  return what
end

local function get_tonemark_width (curr, uni)
  local fontid = curr.font
  local hwidth = char_font_options.tonemarkwidth[fontid]
  if not hwidth then
    -- check horizontal width; vertical width is mostly non-zero
    local fontdata     = get_font_data(fontid)
    local shared       = fontdata.shared      or {}
    local rawdata      = shared.rawdata       or {}
    local descriptions = rawdata.descriptions or {}
    local description  = descriptions[uni]    or {}
    hwidth = description.width or 0
    char_font_options.tonemarkwidth[fontid] = hwidth
  end
  return hwidth
end

local function process_reorder_tonemarks (head)
  local curr = head
  while curr do
    local id = curr.id
    if id == glyphid and option_in_font(curr.font, "script") == "hang" then
      local fontdata = get_font_data(curr.font)
      local uni = my_node_props(curr).unicode or curr.char
      if is_hangul(uni) or is_chosong(uni) or uni == 0x25CC then

        local syllable = { [0]=curr, uni }

        local n = getnext(curr)
        while n do
          local nid = n.id
          if nid == glyphid then
            local u = my_node_props(n).unicode or n.char
            if   is_jungsong(u)
              or is_jongsong(u)
              or hangul_tonemark[u] then
              tableinsert(syllable, u)
              curr, uni = n, u
            else
              break
            end
          elseif nid ~= kernid or n.subtype == userkern then
            break
          end
          n = getnext(n)
        end

        if #syllable > 1
          and hangul_tonemark[uni]
          and get_tonemark_width(curr, uni) ~= 0 then

          local ini, fin = syllable[0], curr
          local actual = pdfliteral_direct_actual(syllable)
          local endactual = pdfliteral_direct_actual()
          head = insert_before(head, ini, actual)
          head, curr = insert_after(head, curr, endactual)

          head = noderemove(head, fin)
          head = insert_before(head, ini, fin)
        end

      elseif hangul_tonemark[uni] -- isolated tone mark
        and char_in_font(fontdata, 0x25CC) then

        local dotcircle = nodecopy(curr)
        dotcircle.char = 0x25CC
        if get_tonemark_width(curr, uni) ~= 0 then
          local actual = pdfliteral_direct_actual{ [0]=curr, uni }
          local endactual = pdfliteral_direct_actual()
          head = insert_before(head, curr, actual)
          head, curr = insert_after(head, curr, dotcircle)
          head, curr = insert_after(head, curr, endactual)
        else
          head = insert_before(head, curr, dotcircle)
        end
      end
    elseif id == whatsitid
      and curr.mode == directmode
      and my_node_props(curr).startactualtext then

      curr = goto_end_actualtext(curr)

    elseif id == mathid then
      curr = end_of_math(curr)
    end
    curr = getnext(curr)
  end
  return head
end

-- vertical font

local streamreader = utilities.files
local openfile     = streamreader.open
local closefile    = streamreader.close
local readstring   = streamreader.readstring
local readulong    = streamreader.readcardinal4
local readushort   = streamreader.readcardinal2
local readfixed    = streamreader.readfixed4
local readshort    = streamreader.readinteger2
local setpos       = streamreader.setposition

local function get_otf_tables (f, subfont)
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

local function read_maxp (f, t)
  if f and t then
    setpos(f, t.offset)
    return {
      version   = readfixed(f),
      numglyphs = readushort(f),
    }
  end
end

local function read_vhea (f, t)
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

local function read_vmtx (f, t, numofheights, numofglyphs)
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

local tsb_font_data = {}

local function get_tsb_table (filename, subfont)
  subfont = tonumber(subfont) or 1
  local key = stringformat("%s::%s", filename, subfont)
  if tsb_font_data[key] then
    return tsb_font_data[key]
  end
  local f = openfile(filename, true) -- true: zero-based
  if f then
    local vmtx
    local tables = get_otf_tables(f, subfont)
    if tables then
      local vhea = read_vhea(f, tables.vhea)
      local numofheights = vhea and vhea.numheights
      local maxp = read_maxp(f, tables.maxp)
      local numofglyphs = maxp and maxp.numglyphs
      vmtx = read_vmtx(f, tables.vmtx, numofheights, numofglyphs)
    end
    closefile(f)
    tsb_font_data[key] = vmtx
    return vmtx
  end
end

local function process_vertical_font (fontdata)
  local subfont = fontdata.specification and fontdata.specification.sub
  local tsb_tab = get_tsb_table(fontdata.filename, subfont)
  if not tsb_tab then
    warning("Vertical metrics table (vmtx) not found in the font\n"..
    "`%s'", fontdata.fontname)
    return
  end

  local shared       = fontdata.shared or {}
  local descriptions = shared.rawdata and shared.rawdata.descriptions or {}
  local parameters   = fontdata.parameters or {}
  local scale    = parameters.factor or 655.36
  local quad     = parameters.quad or 655360
  local ascender = parameters.ascender or quad*0.8
  local goffset  = fontdata_opt_dim(fontdata, "charraise")
  if not goffset then
    goffset  = (parameters.x_height or quad/2) / 2
  end
  for i,v in pairs(fontdata.characters) do
    local voff = goffset - (v.width or 0)/2
    local bbox = descriptions[i] and descriptions[i].boundingbox or {0,0,0,0}
    local gid  = v.index
    local tsb  = tsb_tab[gid].tsb
    local hoff = tsb and (bbox[4] + tsb) * scale or ascender
    v.commands = {
      { "down", -voff },
      { "right", hoff },
      { "pdf", "q 0 1 -1 0 0 0 cm" },
      { "push" },
      { "char", i },
      { "pop" },
      { "pdf", "Q" },
    }
    local vw = tsb_tab[gid].ht
    v.width  = vw and vw * scale or quad
    local ht = bbox[3] * scale + voff
    local dp = bbox[1] * scale + voff
    v.height = ht > 0 and  ht or nil
    v.depth  = dp < 0 and -dp or nil
  end
  local spacechar = char_in_font(fontdata, 32)
  if spacechar then
    parameters.space         = spacechar.width
    parameters.space_stretch = spacechar.width/2
    parameters.space_shrink  = spacechar.width/2
  end

  local res = fontdata.resources or {}
  local fea = shared.features or {}
  fea.kern = nil  -- only for horizontal writing
  fea.vert = true -- should be activated by default
  local seq = res.sequences or {}
  for _,v in ipairs(seq) do
    local fea = v.features or {}
    if fea.vhal or fea.vkrn or fea.valt or fea.vpal or fea.vert then
      if v.type == "gpos_single" then
        for _,vv in pairs(v.steps or {}) do
          for _,vvv in pairs(vv.coverage or {}) do
            if type(vvv) == "table" and #vvv == 4 then
              vvv[1], vvv[2], vvv[3], vvv[4], vvv[5] =
              -vvv[2], vvv[1], vvv[4], vvv[3], 0 -- last 0 to avoid multiple run
            end
          end
        end
      elseif v.type == "gpos_pair" then
        for _,vv in pairs(v.steps or {}) do
          for _,vvv in pairs(vv.coverage or {}) do
            for _,vvvv in pairs(vvv) do
              for _,vvvvv in pairs(vvvv) do
                if type(vvvvv) == "table" and #vvvvv == 4 then
                  vvvvv[1], vvvvv[2], vvvvv[3], vvvvv[4], vvvvv[5] =
                  -vvvvv[2], vvvvv[1], vvvvv[4], vvvvv[3], 0
                end
              end
            end
          end
        end
      end
    end
  end
end

-- charraise

local function process_charriase_font (fontdata)
  local raise = fontdata_opt_dim(fontdata, "charraise")
  if raise then
    local shared = fontdata.shared or {}
    local descriptions = shared.rawdata and shared.rawdata.descriptions or {}
    local scale = fontdata.parameters.factor or 655.36
    for i, v in pairs( fontdata.characters ) do
      v.commands = {
        {"down", -raise },
        {"char", i},
      }
      local bbox = descriptions[i] and descriptions[i].boundingbox or {0,0,0,0}
      local ht = bbox[4] * scale + raise
      local dp = bbox[2] * scale + raise
      v.height = ht > 0 and  ht or nil
      v.depth  = dp < 0 and -dp or nil
    end
  end
end

-- fake italic correctioin

local function process_fake_slant_corr (head) -- for font fallback
  local curr = head
  while curr do
    local id = curr.id
    if id == kernid then
      if curr.subtype == italcorr and curr.kern == 0 then
        local p = getprev(curr)
        while p do -- skip jungsong/jongsong
          if p.id == glyphid and p.width < get_en_size(p.font) then
            local c = my_node_props(p).unicode or p.char
            if not is_jungsong(c) and not is_jongsong(c) then
              break
            end
          elseif p.id == whatsitid
            and p.mode == directmode
            and my_node_props(p).endactualtext then -- skip
          else
            break
          end
          p = getprev(p)
        end
        if p.id == glyphid then
          local fontdata = get_font_data(p.font)
          if fontdata.slant and fontdata.slant > 0 then
            local italic = char_in_font(fontdata, p.char).italic
            if italic then
              curr.kern = italic
            end
          end
        end
      end
    elseif id == mathid then
      curr = end_of_math(curr)
    end
    curr = getnext(curr)
  end
  return head
end

local function process_fake_slant_font (fontdata)
  local fsl = fontdata.slant
  if fsl and fsl > 0 then
    fsl = fsl/1000
    local params = fontdata.parameters or {}
    params.slant = (params.slant or 0) + fsl*65536 -- slant per point
    local scale  = params.factor or 655.36
    local shared = fontdata.shared or {}
    local descriptions = shared.rawdata and shared.rawdata.descriptions or {}
    for i, v in pairs(fontdata.characters) do
      local bbox = descriptions[i] and descriptions[i].boundingbox or {0,0,0,0}
      local italic = (v.height or 0) * fsl - (v.width or 0) + bbox[3]*scale
      if italic > 0 then
        v.italic = italic
      end
    end
  end
end

-- wrap up

local pass_fun = function(...) return ... end
create_callback("luatexko_pre_hpack", "data", pass_fun)
create_callback("luatexko_pre_prelinebreak", "data", pass_fun)
create_callback("luatexko_post_hpack", "data", pass_fun)
create_callback("luatexko_post_prelinebreak", "data", pass_fun)

add_to_callback("hpack_filter", function(h)
  h = process_fonts(h)
  h = call_callback("luatexko_pre_hpack", h)
  h = call_callback("luatexko_post_hpack", h)
  return process_linebreak(h)
end, "luatexko.hpack_filter.pre_rendering", 1)

add_to_callback("pre_linebreak_filter", function(h)
  h = process_fonts(h)
  h = call_callback("luatexko_pre_prelinebreak", h, true)
  h = call_callback("luatexko_post_prelinebreak", h, true)
  return process_linebreak(h, true)
end, "luatexko.pre_linebreak_filter.pre_rendering", 1)

local font_opt_procs = {
  removeclassicspaces = {
    luatexko_pre_hpack        = process_remove_spaces,
    luatexko_pre_prelinebreak = process_remove_spaces,
  },
  interhangul = {
    luatexko_post_hpack        = process_interhangul,
    luatexko_post_prelinebreak = process_interhangul,
  },
  interlatincjk = {
    luatexko_post_hpack        = process_interlatincjk,
    luatexko_post_prelinebreak = process_interlatincjk,
  },
  compresspunctuations = {
    hpack_filter         = process_glyph_width,
    pre_linebreak_filter = process_glyph_width,
  },
  slant = {
    hpack_filter         = process_fake_slant_corr,
    pre_linebreak_filter = process_fake_slant_corr,
  },
}

local function process_patch_font (fontdata)
  for name, procs in pairs( font_opt_procs ) do
    if not active_processes[name] and option_in_font(fontdata, name) then
      for cbnam, cbfun in pairs( procs ) do
        add_to_callback(cbnam, cbfun, "luatexko."..cbnam.."."..name)
      end
      active_processes[name] = true
    end
  end

  if not active_processes.expansion
    and option_in_font(fontdata, "expansion") then
    texset("global", "adjustspacing", 2)
    active_processes.expansion = true
  end

  if option_in_font(fontdata, "protrusion") then
    if not active_processes.protrusion then
      texset("global", "protrudechars", 2)
      active_processes.protrusion = true
    end
    if not active_processes[fontdata.fontname] and
      option_in_font(fontdata, "compresspunctuations") then
      warning("Both `compresspunctuations' and `protrusion' are\n"..
      "enabled for the font `%s'.\n"..
      "Beware that this could result in bad justifications.\n",
      fontdata.fontname)
      active_processes[fontdata.fontname] = true
    end
  end

  if option_in_font(fontdata, "vertical") then
    process_vertical_font(fontdata)
  elseif option_in_font(fontdata, "charraise") then
    process_charriase_font(fontdata)
  end

  if option_in_font(fontdata, "slant") then
    process_fake_slant_font(fontdata)
  end
end

add_to_callback("luaotfload.patch_font", process_patch_font,
"luatexko.patch_font")

local auxiliary_procs = {
  dotemph = {
    hpack_filter = process_dotemph,
    vpack_filter = process_dotemph,
  },
  uline   = {
    hpack_filter = process_uline,
    vpack_filter = process_uline,
  },
  ruby    = {
    pre_linebreak_filter = process_ruby_pre_linebreak,
    hpack_filter         = process_ruby_post_linebreak,
    vpack_filter         = process_ruby_post_linebreak,
  },
  autojosa = {
    luatexko_pre_hpack        = process_josa,
    luatexko_pre_prelinebreak = process_josa,
  },
  reorderTM = {
    luatexko_pre_hpack        = process_reorder_tonemarks,
    luatexko_pre_prelinebreak = process_reorder_tonemarks,
  },
}

local function activate (name)
  for cbnam, cbfun in pairs( auxiliary_procs[name] ) do
    local fun
    if cbnam == "hpack_filter" then
      fun = function(h, gc)
        if gc == "align_set" then
          h = cbfun(h)
        end
        return h
      end
    else
      fun = function(h)
        h = cbfun(h)
        return h
      end
    end
    add_to_callback(cbnam, fun, "luatexko."..cbnam.."."..name)
  end
end
luatexko.activate = activate

-- aux functions

local function current_has_hangul_chars (cnt)
  texcount[cnt] = char_in_font(fontcurrent(), 0xAC00) and 1 or 0
end
luatexko.currenthashangulchars = current_has_hangul_chars

local function get_gid_of_charslot (fd, slot)
  if type(fd) == "number" then
    fd = get_font_data(fd)
  end
  local character = fd.characters[slot]
  return character and character.index
end
luatexko.get_gid_of_charslot = get_gid_of_charslot

local function get_charslots_of_gid (fd, gid)
  if type(fd) == "number" then
    fd = get_font_data(fd)
  end
  local t = {}
  for i, v in pairs(fd.characters) do
    if v.index == gid then
      table.insert(t, i)
    end
  end
  return t
end
luatexko.get_charslots_of_gid = get_charslots_of_gid
