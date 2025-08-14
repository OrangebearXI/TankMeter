_addon.name = 'TankMeter'
_addon.author = 'Orangebear'
_addon.version = '1.0.7'
_addon.commands = {'tankmeter','tm'}

local res    = require('resources')
local texts  = require('texts')
local config = require('config')
local bit    = require('bit')

local defaults = {
  ui = {
    main_visible = true, mini_visible = true,
    x = 300, y = 150, mini_x = 300, mini_y = 120,
    locked = false,
    font = 'Segoe UI', size = 8, bold = false,
    color = {r=255,g=255,b=255,a=255},
    stroke = {width=1, alpha=255, color={r=70,g=100,b=140}}, -- user preferred stroke color
    bg = {alpha=170, color={r=30,g=30,b=30}},
    lh = 1.35, pad = 10, gap = 28, wiggle = 6
  },
  behavior = { include_shadows_in_denominator = false }
}

local settings = config.load(defaults)

local totals = {
  opportunities=0, blocked=0, parried=0, evaded=0, shadows=0,
  phys_hits=0, phys_damage_sum=0, phys_block_min=nil, phys_block_max=0, phys_max=0,
  mag_hits=0,  mag_damage_sum=0,  mag_max=0,
  max_hit_overall=0,
}

local columns = {
  {key='name',  h1='Name',    h2=''},
  {key='blk',   h1='Block',   h2='%'},
  {key='par',   h1='Parry',   h2='%'},
  {key='evd',   h1='EvaMiss', h2='%'},
  {key='tb',    h1='Tot.',    h2='Block'},
  {key='bmin',  h1='Block',   h2='Min'},
  {key='bmax',  h1='Block',   h2='Max'},
  {key='avgp',  h1='Avg.',    h2='Phys Hit'},
  {key='avgm',  h1='Avg.',    h2='Mag Hit'},
  {key='max',   h1='Max',     h2='Hit'},
}

local header1, header2, data_cells = {}, {}, {}
local mini_h1, mini_v1, mini_h2, mini_v2
local measure
local col_w = {}
local row_last = {}
local mini_last = {'0.0%','0.0%'}
local dirty_layout = true

local PRIM_BG_MAIN, PRIM_BG_MINI = 'tm_bg_main','tm_bg_mini'

local function pct(n,d) if not d or d==0 then return '0.0%' end return string.format('%.1f%%',(n/d)*100) end

local function ensure_measure()
  if measure then return end
  measure = texts.new('',{font=settings.ui.font,size=settings.ui.size})
  measure:pos(-10000,-10000)
  measure:bg_visible(false)
  measure:stroke_width(settings.ui.stroke.width)
  measure:stroke_alpha(settings.ui.stroke.alpha)
  local sc = settings.ui.stroke.color
  measure:stroke_color(sc.r,sc.g,sc.b)
  measure:show()
end

local function style_header(t)
  t:font(settings.ui.font); t:size(settings.ui.size); t:bold(settings.ui.bold)
  local c = settings.ui.color; t:color(c.r or 255, c.g or 255, c.b or 255)
  t:stroke_width(settings.ui.stroke.width); t:stroke_alpha(settings.ui.stroke.alpha)
  local sc = settings.ui.stroke.color; t:stroke_color(sc.r, sc.g, sc.b)
  t:bg_visible(false)
end

local function style_data(t)
  t:font(settings.ui.font); t:size(settings.ui.size); t:bold(false)
  t:color(255,255,255)
  t:stroke_width(1); t:stroke_alpha(0)
  t:bg_visible(false)
end

local function new_header() local t = texts.new(''); style_header(t); return t end
local function new_data()   local t = texts.new(''); style_data(t);   return t end

local function set_main_visible(vis)
  settings.ui.main_visible = vis
  windower.prim.set_visibility(PRIM_BG_MAIN, vis)
  for i=1,#columns do
    if vis then header1[i]:show(); header2[i]:show(); data_cells[i]:show()
    else header1[i]:hide(); header2[i]:hide(); data_cells[i]:hide() end
  end
  if vis then dirty_layout = true end
end

local function create_ui()
  for i=1,#columns do
    header1[i]   = new_header()
    header2[i]   = new_header()
    data_cells[i]= new_data()
  end
  for i,c in ipairs(columns) do header1[i]:text(c.h1); header2[i]:text(c.h2) end
  header1[1]:draggable(not settings.ui.locked)

  mini_h1 = new_header(); mini_h1:text('Block% ')
  mini_v1 = new_data();   mini_v1:text(mini_last[1])
  mini_h2 = new_header(); mini_h2:text('  Parry% ')
  mini_v2 = new_data();   mini_v2:text(mini_last[2])

  local drag = not settings.ui.locked
  mini_h1:draggable(drag); mini_v1:draggable(false); mini_h2:draggable(false); mini_v2:draggable(false)

  windower.prim.create(PRIM_BG_MAIN)
  windower.prim.create(PRIM_BG_MINI)
  local bgc = settings.ui.bg.color
  windower.prim.set_color(PRIM_BG_MAIN, settings.ui.bg.alpha, bgc.r, bgc.g, bgc.b)
  windower.prim.set_color(PRIM_BG_MINI, settings.ui.bg.alpha, bgc.r, bgc.g, bgc.b)

  ensure_measure()
  dirty_layout = true
  set_main_visible(settings.ui.main_visible)
  windower.prim.set_visibility(PRIM_BG_MINI, settings.ui.mini_visible)
end

local function current_row()
  local me = windower.ffxi.get_player()
  local name = me and me.name or 'You'
  local opp = totals.opportunities
  local avgp = totals.phys_hits>0 and math.floor(totals.phys_damage_sum/totals.phys_hits+0.5) or 0
  local avgm = totals.mag_hits>0 and math.floor(totals.mag_damage_sum/totals.mag_hits+0.5) or 0
  return {
    name,
    pct(totals.blocked,opp),
    pct(totals.parried,opp),
    pct(totals.evaded,opp),
    tostring(totals.blocked),
    totals.phys_block_min and tostring(totals.phys_block_min) or 'n/a',
    tostring(totals.phys_block_max or 0),
    tostring(avgp),
    tostring(avgm),
    tostring(totals.max_hit_overall or 0),
  }
end

local function text_width(s)
  ensure_measure(); measure:text(s or ''); return select(1,measure:extents()) or 0
end

local function measure_cols(initial)
  local row = current_row()
  for i,c in ipairs(columns) do
    if initial or not col_w[i] then
      local w1 = text_width(c.h1)
      local w2 = text_width(c.h2)
      local w3 = text_width(row[i])
      local w = math.max(w1,w2,w3)
      if i == 1 then
        local wname = text_width(string.rep('W', 17))
        w = math.max(w, wname)
      end
      col_w[i] = math.ceil(w + settings.ui.size + settings.ui.gap + settings.ui.wiggle)
    else
      local w = text_width(row[i])
      local need = math.ceil(w + settings.ui.size + settings.ui.gap + settings.ui.wiggle)
      if need > col_w[i] then col_w[i] = need; dirty_layout = true end
    end
  end
end

local function layout_main()
  local x,y = settings.ui.x, settings.ui.y
  local lh = math.floor(settings.ui.size*settings.ui.lh)
  local pad = settings.ui.pad
  local curx = x
  for i,_ in ipairs(columns) do
    header1[i]:pos(curx, y)
    header2[i]:pos(curx, y+lh)
    data_cells[i]:pos(curx, y+lh*3)
    curx = curx + (col_w[i] or 60)
  end
  local total_w = curx - x
  local total_h = pad*2 + lh*4
  windower.prim.set_position(PRIM_BG_MAIN, x - pad, y - pad)
  windower.prim.set_size(PRIM_BG_MAIN, total_w, total_h)
  dirty_layout = false
end

local function render_main()
  if not settings.ui.main_visible then
    windower.prim.set_visibility(PRIM_BG_MAIN,false)
    for i=1,#columns do header1[i]:hide(); header2[i]:hide(); data_cells[i]:hide() end
    return
  end
  windower.prim.set_visibility(PRIM_BG_MAIN,true)
  local row = current_row()
  for i=1,#columns do
    if row_last[i] ~= row[i] then
      data_cells[i]:text(row[i])
      row_last[i] = row[i]
      measure_cols(false)
    end
  end
  if dirty_layout then layout_main() end
end

-- Mini layout
local function layout_mini()
  local x,y = settings.ui.mini_x, settings.ui.mini_y
  local w1 = text_width('Block% ')
  local wv1 = text_width(mini_last[1])
  local w2 = text_width('  Parry% ')
  local wv2 = text_width(mini_last[2])

  mini_h1:pos(x, y)
  mini_v1:pos(x + w1, y)
  mini_h2:pos(x + w1 + wv1, y)
  mini_v2:pos(x + w1 + wv1 + w2, y)

  local pad = settings.ui.pad
  local total_w = w1 + wv1 + w2 + wv2
  windower.prim.set_position(PRIM_BG_MINI, x - pad, y - pad)
  windower.prim.set_size(PRIM_BG_MINI, total_w + pad*2, math.floor(settings.ui.size*settings.ui.lh) + pad*2)
end

local function render_mini()
  if not settings.ui.mini_visible then
    mini_h1:hide(); mini_v1:hide(); mini_h2:hide(); mini_v2:hide()
    windower.prim.set_visibility(PRIM_BG_MINI,false); return
  end
  windower.prim.set_visibility(PRIM_BG_MINI,true)

  local opp = totals.opportunities
  local v1 = pct(totals.blocked,opp)
  local v2 = pct(totals.parried,opp)

  if mini_last[1] ~= v1 then mini_last[1] = v1; mini_v1:text(v1) end
  if mini_last[2] ~= v2 then mini_last[2] = v2; mini_v2:text(v2) end

  mini_h1:show(); mini_v1:show(); mini_h2:show(); mini_v2:show()
  layout_mini()
end

local function refresh_layout()
  for _,t in ipairs(header1) do style_header(t) end
  for _,t in ipairs(header2) do style_header(t) end
  for _,t in ipairs(data_cells) do style_data(t) end
  style_header(mini_h1); style_data(mini_v1); style_header(mini_h2); style_data(mini_v2)
  header1[1]:draggable(not settings.ui.locked)
  mini_h1:draggable(not settings.ui.locked); mini_v1:draggable(false); mini_h2:draggable(false); mini_v2:draggable(false)

  ensure_measure(); measure_cols(true); dirty_layout = true; layout_main(); layout_mini(); render_main(); render_mini()
end

local last_hx, last_hy, last_mx, last_my
windower.register_event('prerender', function()
  if not settings.ui.locked then
    local hx,hy = header1[1]:pos()
    if hx and hy and (hx ~= last_hx or hy ~= last_hy) then
      settings.ui.x, settings.ui.y = hx, hy
      last_hx, last_hy = hx, hy
      dirty_layout = true
      config.save(settings)
    end
    local mx,my = mini_h1:pos()
    if mx and my and (mx ~= last_mx or my ~= last_my) then
      settings.ui.mini_x, settings.ui.mini_y = mx, my
      last_mx, last_my = mx, my
      layout_mini()
      config.save(settings)
    end
  end
  render_main(); render_mini()
end)

local function is_shadow(msg_id)
  local m = res.action_messages[msg_id]; if not m or not m.en then return false end
  local s = m.en:lower(); return s:find('shadow') ~= nil
end

local function is_miss_like(msg_id)
  local m = res.action_messages[msg_id]; if not m or not m.en then return false end
  local s = m.en:lower(); return s:find('miss') or s:find('evade')
end

local function is_damage_msg(msg_id)
  local m = res.action_messages[msg_id]; if not m or not m.en then return false end
  return m.en:lower():find('damage') ~= nil
end

local function handle_action(act)
  local me = windower.ffxi.get_player(); if not me or not act or not act.targets then return end
  for _,t in ipairs(act.targets) do
    if t.id == me.id then
      for _,a in ipairs(t.actions) do
        local r = a.reaction or 0
        local dmg = tonumber(a.param) or 0
        local msg = a.message or 0
        local cat = act.category or 0

        local evaded = bit.band(r,0x01) > 0
        local parry  = bit.band(r,0x02) > 0
        local block  = bit.band(r,0x04) > 0
        local hitbit = bit.band(r,0x08) > 0
        local shadow = is_shadow(msg)
        local missed = is_miss_like(msg) ~= nil
        local dmgmsg = is_damage_msg(msg)

        if evaded or parry or block or hitbit or missed then
          if not shadow or settings.behavior.include_shadows_in_denominator then
            totals.opportunities = totals.opportunities + 1
          end
        end

        if block then
          totals.blocked = totals.blocked + 1
          if dmgmsg and dmg > 0 then
            totals.phys_block_min = totals.phys_block_min and math.min(totals.phys_block_min, dmg) or dmg
            totals.phys_block_max = math.max(totals.phys_block_max, dmg)
          end
        end
        if parry then totals.parried = totals.parried + 1 end
        if evaded or missed then totals.evaded = totals.evaded + 1 end

        if dmgmsg and dmg > 0 then
          if cat == 4 then
            totals.mag_hits = totals.mag_hits + 1; totals.mag_damage_sum = totals.mag_damage_sum + dmg; totals.mag_max = math.max(totals.mag_max, dmg)
          else
            totals.phys_hits = totals.phys_hits + 1; totals.phys_damage_sum = totals.phys_damage_sum + dmg; totals.phys_max = math.max(totals.phys_max, dmg)
          end
          totals.max_hit_overall = math.max(totals.max_hit_overall, dmg)
        end

        if shadow then totals.shadows = totals.shadows + 1 end
      end
    end
  end
end

windower.register_event('action', handle_action)

windower.register_event('load', function()
  create_ui(); measure_cols(true); layout_main(); layout_mini(); render_main(); render_mini()
end)

windower.register_event('addon command', function(cmd, ...)
  cmd = (cmd or 'help'):lower(); local args = {...}

  if cmd=='help' then
    windower.add_to_chat(207,'TankMeter, main on|off, mini on|off, lock on|off, pos x y, minipos x y, font <name>, size <n>, alpha <0..255>'); return
  end

  if cmd=='main' then
    local sw=args[1] and args[1]:lower()
    if sw=='on' then set_main_visible(true)
    elseif sw=='off' then set_main_visible(false) end
  elseif cmd=='mini' then
    local sw=args[1] and args[1]:lower()
    if sw=='on' then settings.ui.mini_visible=true elseif sw=='off' then settings.ui.mini_visible=false end
    windower.prim.set_visibility(PRIM_BG_MINI, settings.ui.mini_visible)
  elseif cmd=='lock' then
    local sw=args[1] and args[1]:lower(); if sw=='on' then settings.ui.locked=true elseif sw=='off' then settings.ui.locked=false end
    header1[1]:draggable(not settings.ui.locked)
    mini_h1:draggable(not settings.ui.locked); mini_v1:draggable(false); mini_h2:draggable(false); mini_v2:draggable(false)
  elseif cmd=='pos' then
    local x=tonumber(args[1]) local y=tonumber(args[2]); if x and y then settings.ui.x=x settings.ui.y=y dirty_layout = true end
  elseif cmd=='minipos' then
    local x=tonumber(args[1]) local y=tonumber(args[2]); if x and y then settings.ui.mini_x=x settings.ui.mini_y=y layout_mini() end
  elseif cmd=='font' then
    local f=table.concat(args,' '); if #f>0 then settings.ui.font=f refresh_layout() end
  elseif cmd=='size' or cmd=='fontsize' then
    local s=tonumber(args[1]); if s then settings.ui.size=s refresh_layout() end
  elseif cmd=='alpha' then
    local a=tonumber(args[1]); if a then a=math.max(0, math.min(255, math.floor(a)))
      settings.ui.bg.alpha = a
      local bgc=settings.ui.bg.color
      windower.prim.set_color(PRIM_BG_MAIN, a, bgc.r, bgc.g, bgc.b)
      windower.prim.set_color(PRIM_BG_MINI, a, bgc.r, bgc.g, bgc.b)
    end
  else
    windower.add_to_chat(207,'TankMeter, unknown command. //tm help')
  end

  config.save(settings)
end)

windower.register_event('unload', function()
  windower.prim.delete(PRIM_BG_MAIN); windower.prim.delete(PRIM_BG_MINI)
end)
