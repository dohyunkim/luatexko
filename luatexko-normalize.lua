-- luatexko-normalize.lua
--
-- Copyright (c) 2013-2016  Dohyun Kim  <nomos at ktug org>
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
  version     = "1.12",
  date        = "2016/04/22",
  author      = "Dohyun Kim, Soojin Nam",
  description = "Hangul normalization",
  license     = "LPPL v1.3+",
})

luatexkonormalize = luatexkonormalize or {}
local luatexkonormalize = luatexkonormalize

local ncho  = "[\225\132\128-\225\132\146]"
local njung = "[\225\133\161-\225\133\181]"
local jong  = "[\225\134\168-\225\135\191\237\159\139-\237\159\187]"
local ojong = "[\225\135\131-\225\135\191\237\159\139-\237\159\187]"
local compathanja = "[\239\164\128-\239\168\139]"
local chanjatohanja = {
  [0xF900] = {0x8C48, 0xFE00},
  [0xF901] = {0x66F4, 0xFE00},
  [0xF902] = {0x8ECA, 0xFE00},
  [0xF903] = {0x8CC8, 0xFE00},
  [0xF904] = {0x6ED1, 0xFE00},
  [0xF905] = {0x4E32, 0xFE00},
  [0xF906] = {0x53E5, 0xFE00},
  [0xF907] = {0x9F9C, 0xFE00},
  [0xF908] = {0x9F9C, 0xFE01},
  [0xF909] = {0x5951, 0xFE00},
  [0xF90A] = {0x91D1, 0xFE00},
  [0xF90B] = {0x5587, 0xFE00},
  [0xF90C] = {0x5948, 0xFE00},
  [0xF90D] = {0x61F6, 0xFE00},
  [0xF90E] = {0x7669, 0xFE00},
  [0xF90F] = {0x7F85, 0xFE00},
  [0xF910] = {0x863F, 0xFE00},
  [0xF911] = {0x87BA, 0xFE00},
  [0xF912] = {0x88F8, 0xFE00},
  [0xF913] = {0x908F, 0xFE00},
  [0xF914] = {0x6A02, 0xFE00},
  [0xF915] = {0x6D1B, 0xFE00},
  [0xF916] = {0x70D9, 0xFE00},
  [0xF917] = {0x73DE, 0xFE00},
  [0xF918] = {0x843D, 0xFE00},
  [0xF919] = {0x916A, 0xFE00},
  [0xF91A] = {0x99F1, 0xFE00},
  [0xF91B] = {0x4E82, 0xFE00},
  [0xF91C] = {0x5375, 0xFE00},
  [0xF91D] = {0x6B04, 0xFE00},
  [0xF91E] = {0x721B, 0xFE00},
  [0xF91F] = {0x862D, 0xFE00},
  [0xF920] = {0x9E1E, 0xFE00},
  [0xF921] = {0x5D50, 0xFE00},
  [0xF922] = {0x6FEB, 0xFE00},
  [0xF923] = {0x85CD, 0xFE00},
  [0xF924] = {0x8964, 0xFE00},
  [0xF925] = {0x62C9, 0xFE00},
  [0xF926] = {0x81D8, 0xFE00},
  [0xF927] = {0x881F, 0xFE00},
  [0xF928] = {0x5ECA, 0xFE00},
  [0xF929] = {0x6717, 0xFE00},
  [0xF92A] = {0x6D6A, 0xFE00},
  [0xF92B] = {0x72FC, 0xFE00},
  [0xF92C] = {0x90CE, 0xFE00},
  [0xF92D] = {0x4F86, 0xFE00},
  [0xF92E] = {0x51B7, 0xFE00},
  [0xF92F] = {0x52DE, 0xFE00},
  [0xF930] = {0x64C4, 0xFE00},
  [0xF931] = {0x6AD3, 0xFE00},
  [0xF932] = {0x7210, 0xFE00},
  [0xF933] = {0x76E7, 0xFE00},
  [0xF934] = {0x8001, 0xFE00},
  [0xF935] = {0x8606, 0xFE00},
  [0xF936] = {0x865C, 0xFE00},
  [0xF937] = {0x8DEF, 0xFE00},
  [0xF938] = {0x9732, 0xFE00},
  [0xF939] = {0x9B6F, 0xFE00},
  [0xF93A] = {0x9DFA, 0xFE00},
  [0xF93B] = {0x788C, 0xFE00},
  [0xF93C] = {0x797F, 0xFE00},
  [0xF93D] = {0x7DA0, 0xFE00},
  [0xF93E] = {0x83C9, 0xFE00},
  [0xF93F] = {0x9304, 0xFE00},
  [0xF940] = {0x9E7F, 0xFE00},
  [0xF941] = {0x8AD6, 0xFE00},
  [0xF942] = {0x58DF, 0xFE00},
  [0xF943] = {0x5F04, 0xFE00},
  [0xF944] = {0x7C60, 0xFE00},
  [0xF945] = {0x807E, 0xFE00},
  [0xF946] = {0x7262, 0xFE00},
  [0xF947] = {0x78CA, 0xFE00},
  [0xF948] = {0x8CC2, 0xFE00},
  [0xF949] = {0x96F7, 0xFE00},
  [0xF94A] = {0x58D8, 0xFE00},
  [0xF94B] = {0x5C62, 0xFE00},
  [0xF94C] = {0x6A13, 0xFE00},
  [0xF94D] = {0x6DDA, 0xFE00},
  [0xF94E] = {0x6F0F, 0xFE00},
  [0xF94F] = {0x7D2F, 0xFE00},
  [0xF950] = {0x7E37, 0xFE00},
  [0xF951] = {0x964B, 0xFE00},
  [0xF952] = {0x52D2, 0xFE00},
  [0xF953] = {0x808B, 0xFE00},
  [0xF954] = {0x51DC, 0xFE00},
  [0xF955] = {0x51CC, 0xFE00},
  [0xF956] = {0x7A1C, 0xFE00},
  [0xF957] = {0x7DBE, 0xFE00},
  [0xF958] = {0x83F1, 0xFE00},
  [0xF959] = {0x9675, 0xFE00},
  [0xF95A] = {0x8B80, 0xFE00},
  [0xF95B] = {0x62CF, 0xFE00},
  [0xF95C] = {0x6A02, 0xFE01},
  [0xF95D] = {0x8AFE, 0xFE00},
  [0xF95E] = {0x4E39, 0xFE00},
  [0xF95F] = {0x5BE7, 0xFE00},
  [0xF960] = {0x6012, 0xFE00},
  [0xF961] = {0x7387, 0xFE00},
  [0xF962] = {0x7570, 0xFE00},
  [0xF963] = {0x5317, 0xFE00},
  [0xF964] = {0x78FB, 0xFE00},
  [0xF965] = {0x4FBF, 0xFE00},
  [0xF966] = {0x5FA9, 0xFE00},
  [0xF967] = {0x4E0D, 0xFE00},
  [0xF968] = {0x6CCC, 0xFE00},
  [0xF969] = {0x6578, 0xFE00},
  [0xF96A] = {0x7D22, 0xFE00},
  [0xF96B] = {0x53C3, 0xFE00},
  [0xF96C] = {0x585E, 0xFE00},
  [0xF96D] = {0x7701, 0xFE00},
  [0xF96E] = {0x8449, 0xFE00},
  [0xF96F] = {0x8AAA, 0xFE00},
  [0xF970] = {0x6BBA, 0xFE00},
  [0xF971] = {0x8FB0, 0xFE00},
  [0xF972] = {0x6C88, 0xFE00},
  [0xF973] = {0x62FE, 0xFE00},
  [0xF974] = {0x82E5, 0xFE00},
  [0xF975] = {0x63A0, 0xFE00},
  [0xF976] = {0x7565, 0xFE00},
  [0xF977] = {0x4EAE, 0xFE00},
  [0xF978] = {0x5169, 0xFE00},
  [0xF979] = {0x51C9, 0xFE00},
  [0xF97A] = {0x6881, 0xFE00},
  [0xF97B] = {0x7CE7, 0xFE00},
  [0xF97C] = {0x826F, 0xFE00},
  [0xF97D] = {0x8AD2, 0xFE00},
  [0xF97E] = {0x91CF, 0xFE00},
  [0xF97F] = {0x52F5, 0xFE00},
  [0xF980] = {0x5442, 0xFE00},
  [0xF981] = {0x5973, 0xFE00},
  [0xF982] = {0x5EEC, 0xFE00},
  [0xF983] = {0x65C5, 0xFE00},
  [0xF984] = {0x6FFE, 0xFE00},
  [0xF985] = {0x792A, 0xFE00},
  [0xF986] = {0x95AD, 0xFE00},
  [0xF987] = {0x9A6A, 0xFE00},
  [0xF988] = {0x9E97, 0xFE00},
  [0xF989] = {0x9ECE, 0xFE00},
  [0xF98A] = {0x529B, 0xFE00},
  [0xF98B] = {0x66C6, 0xFE00},
  [0xF98C] = {0x6B77, 0xFE00},
  [0xF98D] = {0x8F62, 0xFE00},
  [0xF98E] = {0x5E74, 0xFE00},
  [0xF98F] = {0x6190, 0xFE00},
  [0xF990] = {0x6200, 0xFE00},
  [0xF991] = {0x649A, 0xFE00},
  [0xF992] = {0x6F23, 0xFE00},
  [0xF993] = {0x7149, 0xFE00},
  [0xF994] = {0x7489, 0xFE00},
  [0xF995] = {0x79CA, 0xFE00},
  [0xF996] = {0x7DF4, 0xFE00},
  [0xF997] = {0x806F, 0xFE00},
  [0xF998] = {0x8F26, 0xFE00},
  [0xF999] = {0x84EE, 0xFE00},
  [0xF99A] = {0x9023, 0xFE00},
  [0xF99B] = {0x934A, 0xFE00},
  [0xF99C] = {0x5217, 0xFE00},
  [0xF99D] = {0x52A3, 0xFE00},
  [0xF99E] = {0x54BD, 0xFE00},
  [0xF99F] = {0x70C8, 0xFE00},
  [0xF9A0] = {0x88C2, 0xFE00},
  [0xF9A1] = {0x8AAA, 0xFE01},
  [0xF9A2] = {0x5EC9, 0xFE00},
  [0xF9A3] = {0x5FF5, 0xFE00},
  [0xF9A4] = {0x637B, 0xFE00},
  [0xF9A5] = {0x6BAE, 0xFE00},
  [0xF9A6] = {0x7C3E, 0xFE00},
  [0xF9A7] = {0x7375, 0xFE00},
  [0xF9A8] = {0x4EE4, 0xFE00},
  [0xF9A9] = {0x56F9, 0xFE00},
  [0xF9AA] = {0x5BE7, 0xFE01},
  [0xF9AB] = {0x5DBA, 0xFE00},
  [0xF9AC] = {0x601C, 0xFE00},
  [0xF9AD] = {0x73B2, 0xFE00},
  [0xF9AE] = {0x7469, 0xFE00},
  [0xF9AF] = {0x7F9A, 0xFE00},
  [0xF9B0] = {0x8046, 0xFE00},
  [0xF9B1] = {0x9234, 0xFE00},
  [0xF9B2] = {0x96F6, 0xFE00},
  [0xF9B3] = {0x9748, 0xFE00},
  [0xF9B4] = {0x9818, 0xFE00},
  [0xF9B5] = {0x4F8B, 0xFE00},
  [0xF9B6] = {0x79AE, 0xFE00},
  [0xF9B7] = {0x91B4, 0xFE00},
  [0xF9B8] = {0x96B8, 0xFE00},
  [0xF9B9] = {0x60E1, 0xFE00},
  [0xF9BA] = {0x4E86, 0xFE00},
  [0xF9BB] = {0x50DA, 0xFE00},
  [0xF9BC] = {0x5BEE, 0xFE00},
  [0xF9BD] = {0x5C3F, 0xFE00},
  [0xF9BE] = {0x6599, 0xFE00},
  [0xF9BF] = {0x6A02, 0xFE02},
  [0xF9C0] = {0x71CE, 0xFE00},
  [0xF9C1] = {0x7642, 0xFE00},
  [0xF9C2] = {0x84FC, 0xFE00},
  [0xF9C3] = {0x907C, 0xFE00},
  [0xF9C4] = {0x9F8D, 0xFE00},
  [0xF9C5] = {0x6688, 0xFE00},
  [0xF9C6] = {0x962E, 0xFE00},
  [0xF9C7] = {0x5289, 0xFE00},
  [0xF9C8] = {0x677B, 0xFE00},
  [0xF9C9] = {0x67F3, 0xFE00},
  [0xF9CA] = {0x6D41, 0xFE00},
  [0xF9CB] = {0x6E9C, 0xFE00},
  [0xF9CC] = {0x7409, 0xFE00},
  [0xF9CD] = {0x7559, 0xFE00},
  [0xF9CE] = {0x786B, 0xFE00},
  [0xF9CF] = {0x7D10, 0xFE00},
  [0xF9D0] = {0x985E, 0xFE00},
  [0xF9D1] = {0x516D, 0xFE00},
  [0xF9D2] = {0x622E, 0xFE00},
  [0xF9D3] = {0x9678, 0xFE00},
  [0xF9D4] = {0x502B, 0xFE00},
  [0xF9D5] = {0x5D19, 0xFE00},
  [0xF9D6] = {0x6DEA, 0xFE00},
  [0xF9D7] = {0x8F2A, 0xFE00},
  [0xF9D8] = {0x5F8B, 0xFE00},
  [0xF9D9] = {0x6144, 0xFE00},
  [0xF9DA] = {0x6817, 0xFE00},
  [0xF9DB] = {0x7387, 0xFE01},
  [0xF9DC] = {0x9686, 0xFE00},
  [0xF9DD] = {0x5229, 0xFE00},
  [0xF9DE] = {0x540F, 0xFE00},
  [0xF9DF] = {0x5C65, 0xFE00},
  [0xF9E0] = {0x6613, 0xFE00},
  [0xF9E1] = {0x674E, 0xFE00},
  [0xF9E2] = {0x68A8, 0xFE00},
  [0xF9E3] = {0x6CE5, 0xFE00},
  [0xF9E4] = {0x7406, 0xFE00},
  [0xF9E5] = {0x75E2, 0xFE00},
  [0xF9E6] = {0x7F79, 0xFE00},
  [0xF9E7] = {0x88CF, 0xFE00},
  [0xF9E8] = {0x88E1, 0xFE00},
  [0xF9E9] = {0x91CC, 0xFE00},
  [0xF9EA] = {0x96E2, 0xFE00},
  [0xF9EB] = {0x533F, 0xFE00},
  [0xF9EC] = {0x6EBA, 0xFE00},
  [0xF9ED] = {0x541D, 0xFE00},
  [0xF9EE] = {0x71D0, 0xFE00},
  [0xF9EF] = {0x7498, 0xFE00},
  [0xF9F0] = {0x85FA, 0xFE00},
  [0xF9F1] = {0x96A3, 0xFE00},
  [0xF9F2] = {0x9C57, 0xFE00},
  [0xF9F3] = {0x9E9F, 0xFE00},
  [0xF9F4] = {0x6797, 0xFE00},
  [0xF9F5] = {0x6DCB, 0xFE00},
  [0xF9F6] = {0x81E8, 0xFE00},
  [0xF9F7] = {0x7ACB, 0xFE00},
  [0xF9F8] = {0x7B20, 0xFE00},
  [0xF9F9] = {0x7C92, 0xFE00},
  [0xF9FA] = {0x72C0, 0xFE00},
  [0xF9FB] = {0x7099, 0xFE00},
  [0xF9FC] = {0x8B58, 0xFE00},
  [0xF9FD] = {0x4EC0, 0xFE00},
  [0xF9FE] = {0x8336, 0xFE00},
  [0xF9FF] = {0x523A, 0xFE00},
  [0xFA00] = {0x5207, 0xFE00},
  [0xFA01] = {0x5EA6, 0xFE00},
  [0xFA02] = {0x62D3, 0xFE00},
  [0xFA03] = {0x7CD6, 0xFE00},
  [0xFA04] = {0x5B85, 0xFE00},
  [0xFA05] = {0x6D1E, 0xFE00},
  [0xFA06] = {0x66B4, 0xFE00},
  [0xFA07] = {0x8F3B, 0xFE00},
  [0xFA08] = {0x884C, 0xFE00},
  [0xFA09] = {0x964D, 0xFE00},
  [0xFA0A] = {0x898B, 0xFE00},
  [0xFA0B] = {0x5ED3, 0xFE00},
  [0xFA2E] = {0x90DE, 0xFE00},
  [0xFA2F] = {0x96B7, 0xFE00},
}
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

require "unicode"
local unicodeutf8 = unicode.utf8
local gsub = unicodeutf8.gsub
local byte = unicodeutf8.byte
local char = unicodeutf8.char
local find = unicodeutf8.find
local concat = table.concat
local floor = math.floor
local add_to_callback = luatexbase.add_to_callback
local remove_from_callback = luatexbase.remove_from_callback

local jamo2syllable = function(l,v,t)
  if find(t,ojong) then return end
  l, v = byte(l), byte(v)
  local s = (l - 0x1100) * 21
  s = (s + v - 0x1161) * 28
  if t ~= "" then
    s = s + byte(t) - 0x11a7
  end
  return char(s + 0xac00)
end

local syllable2jamo = function(s)
    s = byte(s) - 0xac00
    local t = {}
    t[1] = char(floor(s / 588) + 0x1100)
    t[2] = char(floor(s % 588 / 28) + 0x1161)
    local jong = s % 28
    t[3] = jong > 0 and char(jong + 0x11a7) or nil
    return concat(t)
end

local hanguldecompose = function(buffer)
  return gsub(buffer, "[가-힣]", syllable2jamo)
end

local function hanjanormalize(c)
  local hanja = chanjatohanja[byte(c)]
  hanja = hanja and char(hanja[1], hanja[2])
  return hanja
end

local function jamo2cjamocho(c)
  local jamo = jamotocjamo.ccho[byte(c)]
  jamo = jamo and char(jamo)
  return jamo
end

local function jamo2cjamojung(c,t)
  if t ~= "" then return end
  local jamo = jamotocjamo.cjung[byte(c)]
  jamo = jamo and char(jamo)
  return jamo
end

local hangulcompose = function(buffer)
  buffer = gsub(buffer, "[가-힣]"..jong, hanguldecompose)
  buffer = gsub(buffer, "("..ncho..")("..njung..")("..jong.."?)", jamo2syllable)
  buffer = gsub(buffer,
    "([\225\132\128-\225\133\153])\225\133\160", jamo2cjamocho)
  buffer = gsub(buffer,
    "\225\133\159([\225\133\161-\225\134\161])("..jong.."?)", jamo2cjamojung)
  buffer = gsub(buffer, compathanja, hanjanormalize)
  return buffer
end

local loaded = false

local function unload()
  if loaded then
    remove_from_callback('process_input_buffer', 'luatexko-hangul-normalize')
    loaded = false
  end
end
luatexkonormalize.unload = unload

local function compose()
  unload()
  add_to_callback('process_input_buffer', hangulcompose, 'luatexko-hangul-normalize')
  loaded = true
end
luatexkonormalize.compose = compose

local function decompose()
  unload()
  add_to_callback('process_input_buffer', hanguldecompose, 'luatexko-hangul-normalize')
  loaded = true
end
luatexkonormalize.decompose = decompose
