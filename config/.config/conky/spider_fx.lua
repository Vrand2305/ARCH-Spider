require 'cairo'

local RED = {0.85, 0.05, 0.08}
local WINE = {0.50, 0.12, 0.12}

local function pick_color(name)
    if name == "wine" then return WINE end
    return RED
end

local function stroke_glow(cr, r, g, b, widths_alphas)
    for _, wa in ipairs(widths_alphas) do
        cairo_set_source_rgba(cr, r, g, b, wa[2])
        cairo_set_line_width(cr, wa[1])
        cairo_stroke_preserve(cr)
    end
    cairo_new_path(cr)
end

local function rounded_rect(cr, x, y, w, h, radius)
    cairo_new_path(cr)
    cairo_move_to(cr, x + radius, y)
    cairo_line_to(cr, x + w - radius, y)
    cairo_curve_to(cr, x + w, y, x + w, y, x + w, y + radius)
    cairo_line_to(cr, x + w, y + h - radius)
    cairo_curve_to(cr, x + w, y + h, x + w, y + h, x + w - radius, y + h)
    cairo_line_to(cr, x + radius, y + h)
    cairo_curve_to(cr, x, y + h, x, y + h, x, y + h - radius)
    cairo_line_to(cr, x, y + radius)
    cairo_curve_to(cr, x, y, x, y, x + radius, y)
    cairo_close_path(cr)
end

local function web(cr, cx, cy, radius, corner, alpha, color)
    local a0, a1
    if corner == "tl" then a0, a1 = 0, math.pi / 2
    elseif corner == "tr" then a0, a1 = math.pi / 2, math.pi
    elseif corner == "bl" then a0, a1 = -math.pi / 2, 0
    else a0, a1 = math.pi, 3 * math.pi / 2 end

    local strands = 7
    cairo_set_line_width(cr, 0.9)
    cairo_set_source_rgba(cr, color[1], color[2], color[3], alpha)
    for i = 0, strands do
        local a = a0 + (a1 - a0) * (i / strands)
        cairo_move_to(cr, cx, cy)
        cairo_line_to(cr, cx + math.cos(a) * radius, cy + math.sin(a) * radius)
    end
    cairo_stroke(cr)

    local rings = 4
    for ri = 1, rings do
        local r = radius * (ri / rings)
        cairo_new_path(cr)
        cairo_arc(cr, cx, cy, r, a0, a1)
        cairo_stroke(cr)
    end
end

local function spider(cr, x, y, scale, angle, alpha, color)
    cairo_save(cr)
    cairo_translate(cr, x, y)
    cairo_rotate(cr, angle)
    cairo_scale(cr, scale, scale)
    cairo_set_source_rgba(cr, 0.02, 0.0, 0.0, alpha)

    cairo_new_path(cr)
    cairo_arc(cr, 0, 1.2, 1.6, 0, 2 * math.pi)
    cairo_fill(cr)
    cairo_new_path(cr)
    cairo_arc(cr, 0, -1.2, 1.1, 0, 2 * math.pi)
    cairo_fill(cr)

    cairo_set_source_rgba(cr, color[1], color[2], color[3], alpha)
    cairo_set_line_width(cr, 0.35)
    for side = -1, 1, 2 do
        for leg = 0, 3 do
            local baseY = -0.6 + leg * 0.8
            local kx = side * 3.0
            local ky = baseY - 0.3 + leg * 0.1
            local ex = side * 5.5
            local ey = baseY - 0.4 + leg * 0.3
            cairo_move_to(cr, 0, baseY)
            cairo_curve_to(cr, kx, ky, kx, ky, ex, ey)
            cairo_stroke(cr)
        end
    end
    cairo_restore(cr)
end

local function scanlines(cr, x, y, w, h, alpha, color)
    cairo_set_source_rgba(cr, color[1], color[2], color[3], alpha)
    cairo_set_line_width(cr, 1)
    local shift = (os.clock() * 18) % 3
    local line = y + shift
    while line < y + h do
        cairo_move_to(cr, x, line)
        cairo_line_to(cr, x + w, line)
        line = line + 3
    end
    cairo_stroke(cr)
end

-- renders the full decorative panel (bg + glow border + web + crawling
-- spider + scanlines) into a PNG that conky then shows with $image.
-- corner: "tl","tr","bl","br" — where the web/spider sit.
function conky_render_panel(path, w, h, corner, intensity, style, deco)
    w, h, intensity = tonumber(w), tonumber(h), tonumber(intensity) or 1.0
    local radius = 14
    local color = pick_color(style)
    local glass = (style == "wine")
    local show_spider = (deco ~= "nospider")

    local cs = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, w, h)
    local cr = cairo_create(cs)

    rounded_rect(cr, 0, 0, w, h, radius)
    if glass then
        cairo_set_source_rgba(cr, 0.09, 0.02, 0.02, 0.95)
        cairo_fill_preserve(cr)
        cairo_set_source_rgba(cr, color[1], color[2], color[3], 0.6)
        cairo_set_line_width(cr, 1.2)
        cairo_stroke_preserve(cr)
        cairo_new_path(cr)
    else
        cairo_set_source_rgba(cr, 0.04, 0.0, 0.01, 0.55)
        cairo_fill_preserve(cr)
        stroke_glow(cr, color[1], color[2], color[3], {{9, 0.12}, {5, 0.22}, {2, 1.0}})
    end

    local cx, cy
    if corner == "tl" then cx, cy = 0, 0
    elseif corner == "tr" then cx, cy = w, 0
    elseif corner == "bl" then cx, cy = 0, h
    else cx, cy = w, h end
    local web_radius = math.min(w, h) * 0.6

    web(cr, cx, cy, web_radius, corner, 0.4 * intensity, color)

    if show_spider then
        local t = os.clock()
        local phase = (math.sin(t * 0.6) + 1) / 2
        local dist = web_radius * (0.25 + 0.6 * phase)
        local ang
        if corner == "tl" then ang = math.pi / 4
        elseif corner == "tr" then ang = 3 * math.pi / 4
        elseif corner == "bl" then ang = -math.pi / 4
        else ang = -3 * math.pi / 4 end
        local sx = cx + math.cos(ang) * dist
        local sy = cy + math.sin(ang) * dist
        spider(cr, sx, sy, 3.2, t * 0.3, 0.95 * intensity, color)
    end

    scanlines(cr, 0, 0, w, h, glass and 0.025 or 0.045, color)

    cairo_surface_write_to_png(cs, path)

    cairo_destroy(cr)
    cairo_surface_destroy(cs)
    return ''
end
