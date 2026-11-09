class_name CourtArt
extends RefCounted
## THE ROYALS ON THE COURT CARDS (Fable AAA review round 1: "blackjack face cards are a tan
## rectangle with a letter instead of an illustrated royal"). Jack, Queen and King are painted
## here as Equestrian royals, in the deck's own palette:
##   - THE JACK is a Royal Guard: a gold helmet with a crest in the suit's colour, a gold
##     gorget, and his spear at his shoulder.
##   - THE QUEEN is a Celestia-style alicorn: a white coat, a long horn, a gold tiara and
##     peytral, a wing at her shoulder and the flowing four colour mane.
##   - THE KING is a crowned stallion: a tan coat, an auburn mane and beard, a gold crown, an
##     ermine collar over a robe in the suit's colour, a gold chain and medallion.
## Each is a bust facing left in the top half of a gold framed panel, and the same bust turned
## half a turn in the bottom half, the way a printed court card reads from either end.
##
## PAINTED AS VECTOR MARKUP, IN CODE. The figures need curves (a mane, a muzzle, a plume) that
## a polygon list draws badly at 60 px, so this file writes SVG path markup and has Godot's own
## rasteriser (Image.load_svg_from_string, the one game/ui/icon_set.gd uses) draw it at the
## size the card is shown. No file on disk: the markup is built here, and a test can read it.
##
## The robe, plume and gem take the suit's colour: crimson for hearts and diamonds, plum for
## spades and clubs, so a King of Hearts and a King of Spades differ at a glance.

## Rank index (Blackjack's card % 13) of each court card.
const JACK := 10
const QUEEN := 11
const KING := 12

## The panel's shape, width to height. draw_card() sizes the panel to this so nothing stretches.
const ASPECT := 100.0 / 224.0

const GOLD := "#F5C542"
const GOLD_DEEP := "#B8862B"
const GOLD_LIGHT := "#FFE9A3"
const LINE := "#3A2440"
const CREAM := "#FBF3DF"
const CREAM_DEEP := "#EFDDB4"
const WHITE := "#FFFFFF"

## Robe colours per suit: hearts, diamonds, spades, clubs.
const ROBE := ["#C23340", "#C23340", "#5C296B", "#5C296B"]
const ROBE_DEEP := ["#7E1C27", "#7E1C27", "#381745", "#381745"]

static var _cache := {}


## True for the three ranks this file paints.
static func is_court(rank: int) -> bool:
	return rank >= JACK and rank <= KING


## The card's royal, rasterised `px_width` pixels wide (height from ASPECT), cached per size.
static func texture(rank: int, suit: int, px_width: int) -> ImageTexture:
	px_width = clampi(px_width, 32, 512)
	var key := "%d/%d/%d" % [rank, suit, px_width]
	if _cache.has(key):
		return _cache[key]
	var img := Image.new()
	if img.load_svg_from_string(svg(rank, suit), float(px_width) / 100.0) != OK:
		push_warning("CourtArt: the %d of suit %d did not rasterise" % [rank, suit])
		img = Image.create(px_width, int(px_width / ASPECT), false, Image.FORMAT_RGBA8)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## The whole panel as SVG markup: frame, ground, the bust twice and the suit pips.
static func svg(rank: int, suit: int) -> String:
	suit = clampi(suit, 0, 3)
	var half := _ground(suit) + _figure(rank, suit)
	var out := PackedStringArray()
	out.append('<svg xmlns="http://www.w3.org/2000/svg" width="100" height="224" viewBox="0 0 100 224">')
	out.append('<defs><clipPath id="h"><rect x="3" y="3" width="94" height="109"/></clipPath>')
	out.append('<radialGradient id="g" cx="0.5" cy="0.62" r="0.7"><stop offset="0" stop-color="%s"/>' % CREAM)
	out.append('<stop offset="1" stop-color="%s"/></radialGradient></defs>' % CREAM_DEEP)
	out.append('<rect x="1.5" y="1.5" width="97" height="221" rx="7" fill="%s" stroke="%s" stroke-width="3"/>' % [CREAM, GOLD_DEEP])
	out.append('<g clip-path="url(#h)">%s</g>' % half)
	out.append('<g transform="rotate(180 50 112)"><g clip-path="url(#h)">%s</g></g>' % half)
	# The divider: a gold band across the middle, as a printed card's diagonal is.
	out.append('<rect x="3" y="109.5" width="94" height="5" fill="%s" stroke="%s" stroke-width="1"/>' % [GOLD, GOLD_DEEP])
	out.append('<rect x="5.5" y="5.5" width="89" height="213" rx="4" fill="none" stroke="%s" stroke-width="1.4" opacity="0.8"/>' % GOLD)
	out.append('</svg>')
	return "".join(out)


## The ground behind one half: a warm glow, a faint gold lattice, and the suit pip in the
## upper corner in front of the royal's face.
static func _ground(suit: int) -> String:
	var s := '<rect x="0" y="0" width="100" height="112" fill="url(#g)"/>'
	var lattice := ""
	for i: int in range(-6, 8):
		var x := float(i) * 16.0
		lattice += "M%s,0 L%s,112 M%s,0 L%s,112 " % [x, x + 56.0, x + 56.0, x]
	s += '<path d="%s" stroke="%s" stroke-width="0.8" opacity="0.28" fill="none"/>' % [lattice, GOLD_DEEP]
	s += _pip(suit, 14.0, 16.0, 15.0)
	return s


## One suit pip centred at (cx, cy), `size` across, in the suit's ink.
static func _pip(suit: int, cx: float, cy: float, size: float) -> String:
	var ink: String = "#C72933" if suit < 2 else "#1C1A24"
	var d := ""
	match suit:
		0:
			d = "M50,88 C20,66 4,50 4,32 C4,16 16,6 29,6 C39,6 46,12 50,22 C54,12 61,6 71,6 C84,6 96,16 96,32 C96,50 80,66 50,88 Z"
		1:
			d = "M50,2 C60,20 74,36 92,48 C74,60 60,76 50,94 C40,76 26,60 8,48 C26,36 40,20 50,2 Z"
		2:
			d = "M50,4 C80,28 96,42 96,58 C96,72 84,80 72,80 C63,80 56,75 53,70 C55,80 60,88 68,94 L32,94 C40,88 45,80 47,70 C44,75 37,80 28,80 C16,80 4,72 4,58 C4,42 20,28 50,4 Z"
		_:
			d = "M50,6 C62,6 71,15 71,27 C71,33 69,37 66,41 C70,39 74,38 77,38 C89,38 97,47 97,58 C97,70 88,78 77,78 C67,78 59,72 55,64 C56,76 61,86 68,94 L32,94 C39,86 44,76 45,64 C41,72 33,78 23,78 C12,78 3,70 3,58 C3,47 11,38 23,38 C26,38 30,39 34,41 C31,37 29,33 29,27 C29,15 38,6 50,6 Z"
	var k := size / 100.0
	return '<path transform="translate(%s %s) scale(%s)" d="%s" fill="%s"/>' % [
		cx - size * 0.5, cy - size * 0.5, k, d, ink]


## The bust, in a 100 by 80 box with the base of the neck on its bottom edge, scaled into the
## half panel so the crest, horn and crown have the band above the head to themselves.
static func _figure(rank: int, suit: int) -> String:
	var body := ""
	match rank:
		JACK:
			body = _jack(suit)
		QUEEN:
			body = _queen(suit)
		_:
			body = _king(suit)
	return '<g transform="translate(-6 22) scale(1.13)" stroke-linejoin="round" stroke-linecap="round">%s</g>' % body


# --- the shared pony ------------------------------------------------------------------------

const HEAD := "M52,14 C64,13 74,22 74,34 C74,40 72,44 70,47 C74,58 80,70 84,80 L30,80 C34,70 38,62 40,56 C34,57 26,56 22,51 C18,47 18,40 22,37 C26,33 30,28 34,22 C38,16 45,14 52,14 Z"
const JAW_SHADE := "M40,56 C48,58 60,54 70,47 C72,54 74,60 76,64 C64,66 50,64 38,62 Z"


static func _head(coat: String, shade: String, iris: String, lashes: bool, brow: bool) -> String:
	var s := '<path d="%s" fill="%s" stroke="%s" stroke-width="2.4"/>' % [HEAD, coat, LINE]
	s += '<path d="%s" fill="%s" opacity="0.7"/>' % [JAW_SHADE, shade]
	# A soft light on the brow and the muzzle, so the head reads as round.
	s += '<ellipse cx="48" cy="22" rx="9" ry="4" fill="%s" opacity="0.55" transform="rotate(-12 48 22)"/>' % WHITE
	s += '<ellipse cx="25" cy="40" rx="3.5" ry="2.2" fill="%s" opacity="0.45"/>' % WHITE
	# The big eye, the way the show draws one: a tall white, a coloured iris, a pupil, a glint.
	s += '<ellipse cx="41" cy="33" rx="7" ry="9.2" fill="%s" stroke="%s" stroke-width="1.6" transform="rotate(-8 41 33)"/>' % [WHITE, LINE]
	s += '<ellipse cx="39.6" cy="34" rx="5" ry="7" fill="%s" transform="rotate(-8 39.6 34)"/>' % iris
	s += '<ellipse cx="39.2" cy="35" rx="2.7" ry="4" fill="%s"/>' % LINE
	s += '<circle cx="37.4" cy="30.6" r="2" fill="%s"/>' % WHITE
	s += '<circle cx="41.4" cy="38.6" r="0.9" fill="%s"/>' % WHITE
	s += '<path d="M33.5,26.5 C37,22.4 45,22 48.6,27" fill="none" stroke="%s" stroke-width="2.4"/>' % LINE
	if lashes:
		s += '<path d="M34.2,25.6 L30.2,22.6 M36.4,23.8 L33.6,19.6 M39.4,22.9 L38.2,18.6" fill="none" stroke="%s" stroke-width="1.8"/>' % LINE
	if brow:
		s += '<path d="M33,21.5 L46,24" fill="none" stroke="%s" stroke-width="2.2"/>' % LINE
	s += '<path d="M22.6,42.6 C23.6,41 25.2,41 25.8,42.8" fill="none" stroke="%s" stroke-width="1.6"/>' % LINE
	s += '<path d="M23.4,49 C26,51 29,51.2 31.4,49.4" fill="none" stroke="%s" stroke-width="1.6"/>' % LINE
	return s


static func _ear(coat: String, inner: String) -> String:
	return ('<path d="M57,17 L61,1 L71,19 Z" fill="%s" stroke="%s" stroke-width="2.2"/>' % [coat, LINE]) \
		+ ('<path d="M60,15 L62,6.5 L67,17 Z" fill="%s"/>' % inner)


# --- the three royals -----------------------------------------------------------------------

static func _jack(suit: int) -> String:
	var coat := "#E4E8F1"
	var shade := "#B9C0D3"
	var plume: String = ROBE[suit]
	var plume_deep: String = ROBE_DEEP[suit]
	var s := ""
	# His spear, behind him: a shaft over his shoulder and a gold head.
	s += '<path d="M93,84 L86,-16" stroke="%s" stroke-width="5.2"/>' % LINE
	s += '<path d="M93,84 L86,-16" stroke="#9A6A3C" stroke-width="3"/>'
	s += '<path d="M86,-22 L91,-10 L86,-6 L81,-10 Z" fill="%s" stroke="%s" stroke-width="1.6"/>' % [GOLD, LINE]
	s += _head(coat, shade, "#3F6FB5", false, true)
	# The helmet: a gold bowl over his skull, a cheek guard, a rim along his brow.
	s += '<path d="M33,25 C36,12 49,7 60,8 C71,9 78,19 77,32 L75,45 C70,41 65,36 61,31 C55,27 44,25 33,25 Z" fill="%s" stroke="%s" stroke-width="2.4"/>' % [GOLD, LINE]
	s += '<path d="M60,31 C65,36 69,42 71,48 L63,49 C61,43 57,37 53,33 Z" fill="%s" stroke="%s" stroke-width="2"/>' % [GOLD_DEEP, LINE]
	s += '<path d="M38,15 C46,10 56,9 64,11" fill="none" stroke="%s" stroke-width="3" opacity="0.9"/>' % GOLD_LIGHT
	s += '<path d="M33,25 C44,24 54,27 61,31" fill="none" stroke="%s" stroke-width="2.6"/>' % GOLD_DEEP
	# The crest: a stiff brush in the suit's colour, from his brow back over the bowl.
	s += '<path d="M42,11 C48,-6 70,-11 86,2 C80,5 74,9 71,13 C62,8 51,8 42,11 Z" fill="%s" stroke="%s" stroke-width="2.2"/>' % [plume, LINE]
	s += '<path d="M50,6 C54,-1 60,-4 66,-5 M58,6 C62,0 68,-3 74,-3 M66,8 C70,3 75,1 80,1" fill="none" stroke="%s" stroke-width="1.6" opacity="0.8"/>' % plume_deep
	s += '<circle cx="44" cy="20" r="3.4" fill="%s" stroke="%s" stroke-width="1.4"/>' % [plume, LINE]
	# The gorget: a gold collar over his chest with a band and a sun boss.
	s += '<path d="M16,82 C22,69 36,63 51,62 C67,61 83,67 94,82 Z" fill="%s" stroke="%s" stroke-width="2.4"/>' % [GOLD, LINE]
	s += '<path d="M20,77 C34,68 66,66 90,76" fill="none" stroke="%s" stroke-width="4.5"/>' % plume
	s += '<path d="M24,69 C36,64 58,63 80,68" fill="none" stroke="%s" stroke-width="2" opacity="0.9"/>' % GOLD_LIGHT
	s += _sun(52.0, 72.0, 5.4)
	return s


static func _queen(suit: int) -> String:
	var coat := "#FFFBF7"
	var shade := "#E4D8EE"
	var gem: String = ROBE[suit]
	var s := ""
	# The flowing mane behind her: teal, blue, pink and green, as Celestia's is.
	s += '<path d="M46,12 C52,-12 86,-16 98,6 C106,22 96,40 100,56 C102,66 108,74 104,82 L74,82 C70,66 80,52 76,38 C73,26 64,17 50,16 Z" fill="#5FC7C0" stroke="%s" stroke-width="2.2"/>' % LINE
	s += '<path d="M52,10 C62,-6 84,-8 92,8 C98,22 88,40 92,56 C94,66 98,74 96,82" fill="none" stroke="#7E9BEA" stroke-width="5"/>'
	s += '<path d="M56,12 C66,1 80,2 86,13 C90,24 82,42 86,58 C88,68 90,74 88,82" fill="none" stroke="#EE93C6" stroke-width="4.4"/>'
	s += '<path d="M60,15 C68,8 76,10 79,18 C82,28 76,44 79,60 C80,70 82,76 81,82" fill="none" stroke="#86D8A6" stroke-width="3.6"/>'
	# Her wing, folded at the shoulder.
	s += '<path d="M70,72 C78,58 94,52 106,56 C100,60 102,63 96,66 C101,68 99,72 93,73 C96,76 91,80 84,82 L72,82 Z" fill="%s" stroke="%s" stroke-width="2.2"/>' % [coat, LINE]
	s += '<path d="M80,68 C86,63 93,60 100,59 M82,74 C87,70 92,68 96,67" fill="none" stroke="%s" stroke-width="1.4"/>' % shade
	s += _ear(coat, "#F2C9DE")
	s += _head(coat, shade, "#B2508F", true, false)
	# The horn, long and spiralled.
	s += '<path d="M41,16 L33,-17 L50,13 Z" fill="%s" stroke="%s" stroke-width="2.2"/>' % [coat, LINE]
	s += '<path d="M38,5 L45,2 M36,-3 L42,-5 M35,-10 L39,-11" fill="none" stroke="%s" stroke-width="1.5"/>' % shade
	# A forelock sweeping over her brow, in front of the horn's root.
	s += '<path d="M52,13 C44,10 36,14 32,24 C38,20 44,20 48,22 C47,18 50,15 56,15 Z" fill="#5FC7C0" stroke="%s" stroke-width="2"/>' % LINE
	s += '<path d="M50,13.5 C44,13 39,16 35,21" fill="none" stroke="#EE93C6" stroke-width="2.2"/>'
	# The tiara: gold points on a band, a gem at its heart.
	s += '<path d="M38,22 L39,12 L44,16 L47,6 L51,15 L57,10 L58,19 C51,17 44,18 38,22 Z" fill="%s" stroke="%s" stroke-width="1.8"/>' % [GOLD, LINE]
	s += '<path d="M47,13 L50,16.5 L47,20 L44,16.5 Z" fill="#7A3FA0" stroke="%s" stroke-width="1"/>' % LINE
	# The peytral: a broad gold collar and a gem in the suit's colour.
	s += '<path d="M28,82 C32,71 44,66 56,66 C67,66 77,70 82,82 Z" fill="%s" stroke="%s" stroke-width="2.4"/>' % [GOLD, LINE]
	s += '<path d="M32,74 C42,68 62,67 78,73" fill="none" stroke="%s" stroke-width="2" opacity="0.9"/>' % GOLD_LIGHT
	s += '<path d="M55,68 L61,74.5 L55,81 L49,74.5 Z" fill="%s" stroke="%s" stroke-width="1.6"/>' % [gem, LINE]
	s += '<path d="M53.6,71.2 L55,69.8 L56.4,71.2" fill="none" stroke="%s" stroke-width="1.2"/>' % WHITE
	return s


static func _king(suit: int) -> String:
	var coat := "#E3BC8A"
	var shade := "#B98A5C"
	var mane := "#7A3528"
	var mane_light := "#A9553D"
	var robe: String = ROBE[suit]
	var robe_deep: String = ROBE_DEEP[suit]
	var s := ""
	s += _ear(coat, "#E7A98E")
	s += _head(coat, shade, "#3F6FB5", false, true)
	# His mane, down the back of his neck.
	s += '<path d="M54,13 C67,9 81,16 83,30 C85,42 90,52 88,66 C82,60 77,52 72,45 C74,34 68,22 56,18 Z" fill="%s" stroke="%s" stroke-width="2.2"/>' % [mane, LINE]
	s += '<path d="M62,15 C72,16 78,24 79,34 C80,44 83,52 84,58" fill="none" stroke="%s" stroke-width="2"/>' % mane_light
	# The robe, then the ermine collar over it.
	s += '<path d="M12,82 C18,69 34,62 51,61 C68,60 84,66 96,82 Z" fill="%s" stroke="%s" stroke-width="2.4"/>' % [robe, LINE]
	s += '<path d="M30,82 C34,74 40,70 46,68 M72,82 C70,74 66,70 60,68" fill="none" stroke="%s" stroke-width="2"/>' % robe_deep
	s += '<path d="M17,76 C25,66 38,62.5 51,62 C65,61.5 79,65 91,74" fill="none" stroke="%s" stroke-width="9"/>' % LINE
	s += '<path d="M17,76 C25,66 38,62.5 51,62 C65,61.5 79,65 91,74" fill="none" stroke="%s" stroke-width="6.4"/>' % WHITE
	for p: Vector2 in [Vector2(24, 69.5), Vector2(36, 64.5), Vector2(66, 63.5), Vector2(80, 67.5)]:
		s += '<path d="M%s,%s l-1.4,3.4 l1.4,-1 l1.4,1 Z" fill="%s"/>' % [p.x, p.y - 1.6, LINE]
	# His beard, over the collar.
	s += '<path d="M24,52 C27,60 30,66 28,74 C35,68 40,62 41,56 C35,57 29,56 24,52 Z" fill="%s" stroke="%s" stroke-width="2"/>' % [mane, LINE]
	# A gold chain and a medallion.
	s += '<path d="M38,66 C42,73 47,76 52,77 C58,76 63,72 66,66" fill="none" stroke="%s" stroke-width="1.8" stroke-dasharray="2 1.4"/>' % GOLD
	s += _sun(52.0, 76.0, 4.6)
	# The forelock under the crown.
	s += '<path d="M48,15 C41,16 36,22 37,29 C41,24 46,22 52,21 Z" fill="%s" stroke="%s" stroke-width="1.8"/>' % [mane, LINE]
	# The crown: five points with pearls, a band set with the suit's stones.
	s += '<path d="M38,19 L34,1 L42,9 L48,-4 L55,8 L63,-2 L66,13 C57,12 46,14 38,19 Z" fill="%s" stroke="%s" stroke-width="2.2"/>' % [GOLD, LINE]
	s += '<path d="M38,19 C46,14 57,12 66,13 L66,18 C57,17 47,19 39,24 Z" fill="%s" stroke="%s" stroke-width="1.8"/>' % [GOLD_DEEP, LINE]
	for p: Vector2 in [Vector2(34, 1), Vector2(48, -4), Vector2(63, -2)]:
		s += '<circle cx="%s" cy="%s" r="2.4" fill="%s" stroke="%s" stroke-width="1.2"/>' % [p.x, p.y, WHITE, LINE]
	for p: Vector2 in [Vector2(45, 18), Vector2(53, 16.4), Vector2(61, 15.8)]:
		s += '<circle cx="%s" cy="%s" r="1.9" fill="%s"/>' % [p.x, p.y, robe]
	s += '<path d="M42,11 L47,4 M55,9 L60,4" fill="none" stroke="%s" stroke-width="1.4"/>' % GOLD_LIGHT
	return s


## A small gold sun boss: a disc with eight short rays.
static func _sun(cx: float, cy: float, r: float) -> String:
	var rays := ""
	for i: int in 8:
		var a := TAU * float(i) / 8.0
		rays += "M%s,%s L%s,%s " % [cx + cos(a) * r * 0.9, cy + sin(a) * r * 0.9,
			cx + cos(a) * r * 1.5, cy + sin(a) * r * 1.5]
	return ('<path d="%s" stroke="%s" stroke-width="1.6"/>' % [rays, GOLD_DEEP]) \
		+ ('<circle cx="%s" cy="%s" r="%s" fill="%s" stroke="%s" stroke-width="1.4"/>' % [cx, cy, r, GOLD_LIGHT, LINE])
