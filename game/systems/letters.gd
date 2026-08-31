class_name Letters
extends RefCounted
## THE COMPANY'S POST, AS A STUB. Slice 3 of this phase builds the mailbox, the Mail page
## and the StoryBeat resources that fill them; this is the fixed text slice 1 needs so that
## delivering a pony produces a receipt rather than a silence, and so that the creation
## screen can be tested against the promise that every letter renders with the longest name
## the name box will accept.
##
## THE REGISTER IS CHEERFUL CORPORATE. Company copy reads like an HR poster: exclamation
## marks, a thank you, a number that is slightly the wrong kind of number to be pleased
## about. It is funny for a long time. Nothing here is grim, and nothing here explains
## anything; the horror is that the player re-reads these later.
##
## Static only, no scene, no state. Every string here is player facing, so none of it
## carries an em dash or a double hyphen, and test_letters.gd asserts that rather than
## trusting it.

enum Id { WELCOME, RECEIPT_STOCK, RECEIPT_NAMED, QUOTA_REMINDER, COLLECTION_NOTICE,
	COLLECTOR_VISIT }

## The longest name the creation screen's name box accepts, and therefore the longest one
## every template below has to render inside LINE_WIDTH. Mirrored by
## PlayerLook.MAX_NAME_LENGTH, which is where the name box reads it from.
const MAX_NAME_LENGTH := 16

## The widest a rendered line may be. The Depot panel and the toast both wrap at this, so a
## template that overflows is a template that gets cut off on somebody's screen.
const LINE_WIDTH := 58

const SENDER := "Cloudsdale Weather Corporation"


static func ids() -> Array[int]:
	return [Id.WELCOME, Id.RECEIPT_STOCK, Id.RECEIPT_NAMED, Id.QUOTA_REMINDER,
		Id.COLLECTION_NOTICE, Id.COLLECTOR_VISIT]


## `params` may carry: name, count, credit, pony, quota, balance, upkeep, punishment.
## A missing one renders as its own placeholder rather than as an error, because a letter
## that fails to render is a letter the player never sees and never knows she missed.
static func render(id: int, params: Dictionary) -> Dictionary:
	var who: String = str(params.get("name", "Valued Partner"))
	var count: int = int(params.get("count", 1))
	var credit: int = int(params.get("credit", 0))
	var pony: String = str(params.get("pony", "a pony"))
	var quota: int = int(params.get("quota", 0))
	var balance: int = int(params.get("balance", 0))
	var upkeep: int = int(params.get("upkeep", 0))
	var punishment: String = str(params.get("punishment", "a courtesy visit"))

	match id:
		Id.WELCOME:
			return _letter("Welcome to the family!", [
				"Dear %s," % who,
				"",
				"Congratulations on your new ranch! Here is how a",
				"partner turns a field of ponies into bits.",
				"",
				"1. CATCH a pony. Hold the beam on her until the",
				"   outer ring fills, then let go.",
				"2. PEN her. Build a paddock on a plot and walk her",
				"   in; a happy pony makes gems.",
				"3. COLLECT the gems she leaves in the pen.",
				"4. SELL them at the Market for bits.",
				"",
				"Your sponsorship balance stands at %d bits, and it" % balance,
				"grows on its own every collection day.",
				"We expect %d ponies delivered to the Depot each" % quota,
				"period. Bits do not settle that; ponies do.",
				"",
				"Together we make the weather!",
				"",
				"Warmly, Sponsorship Services",
			])
		Id.RECEIPT_STOCK:
			return _letter("Shipment received", [
				"Dear %s," % who,
				"",
				"Your %s shipment! Cloudsdale thanks you." % ordinal(count),
				"Unregistered stock, condition: excellent.",
				"Credit applied to your balance: %d bits." % credit,
				"",
				"Keep up the great work!",
			])
		Id.RECEIPT_NAMED:
			return _letter("Shipment received, with thanks", [
				"Dear %s," % who,
				"",
				"Your %s shipment! What a find." % ordinal(count),
				"Registered arrival: %s." % pony,
				"Shipment quality: excellent. Yield: outstanding.",
				"Credit applied to your balance: %d bits." % credit,
				"",
				"You are in the top tier of partners this period!",
			])
		Id.QUOTA_REMINDER:
			return _letter("A friendly reminder", [
				"Dear %s," % who,
				"",
				"Just a note that %d ponies are expected this" % quota,
				"period, and we have %d so far. No pressure!" % count,
				"Partners who meet quota sleep so much better.",
				"",
				"Yours in weather, Sponsorship Services",
			])
		Id.COLLECTION_NOTICE:
			return _letter("Your statement is ready", [
				"Dear %s," % who,
				"",
				"Collection day! Upkeep of %d bits has been" % upkeep,
				"added to your account, along with the usual",
				"small service charge. Your balance is now",
				"%d bits. Thank you for choosing Cloudsdale!" % balance,
			])
		Id.COLLECTOR_VISIT:
			return _letter("A visit from your account manager", [
				"Dear %s," % who,
				"",
				"Our records show the last period fell short.",
				"As the statement warned, an associate has",
				"called this morning regarding",
				"%s." % punishment,
				"Everything is reversible! Simply pay, or ship.",
				"",
				"We know you will bounce right back.",
			])
	return _letter("", [])


static func _letter(title: String, body: Array) -> Dictionary:
	var lines: Array[String] = []
	for line in body:
		lines.append(String(line))
	return {"sender": SENDER, "title": title, "body": lines}


## "1st", "2nd", "3rd", "4th", and the three English exceptions in the teens. Public
## because the Depot toast counts shipments too, and two orderings of the same rule in two
## files is one of them being wrong.
static func ordinal(n: int) -> String:
	var tens: int = absi(n) % 100
	if tens >= 11 and tens <= 13:
		return "%dth" % n
	match absi(n) % 10:
		1:
			return "%dst" % n
		2:
			return "%dnd" % n
		3:
			return "%drd" % n
	return "%dth" % n
