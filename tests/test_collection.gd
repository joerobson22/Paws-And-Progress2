extends TestCase

const ANIMALS := [{"id": "dog"}, {"id": "cat"}, {"id": "snail"}]
const GIFTS := [
	{"id": "dog_a", "animal": "dog"},
	{"id": "dog_b", "animal": "dog", "slot": "hat"},
	{"id": "cat_a", "animal": "cat"},
	{"id": "cat_b", "animal": "cat", "slot": "top"},
]


func test_nothing_found() -> void:
	var p := Collection.progress({}, GIFTS, ANIMALS)
	eq(p, {"found": 0, "gifts": 4, "tables": 0, "animals": 2, "cosmetics": 0, "wearables": 2}, "a fresh start")


func test_discovered_counts_gifts_traded_away() -> void:
	var p := Collection.progress({"dog_a": 0, "cat_a": 3}, GIFTS, ANIMALS)
	eq(p["found"], 2, "a gift you've had stays discovered")


func test_a_table_needs_every_gift() -> void:
	eq(Collection.progress({"dog_a": 1}, GIFTS, ANIMALS)["tables"], 0, "one of the dog's two")
	eq(Collection.progress({"dog_a": 1, "dog_b": 1}, GIFTS, ANIMALS)["tables"], 1, "both of the dog's")
	eq(Collection.progress({"dog_a": 0, "dog_b": 0, "cat_a": 1, "cat_b": 1}, GIFTS, ANIMALS)["tables"], 2, "traded away still counts")
	eq(Collection.progress({}, GIFTS, ANIMALS)["animals"], 2, "an animal without gifts isn't a table")


func test_cosmetics_are_wearable_gifts_you_have() -> void:
	eq(Collection.progress({"dog_b": 1, "cat_b": 0}, GIFTS, ANIMALS)["cosmetics"], 1, "only the one you still have")
	eq(Collection.progress({"dog_a": 5}, GIFTS, ANIMALS)["cosmetics"], 0, "a gift you can't wear")


func test_fraction() -> void:
	eq(Collection.fraction(1, 4), 0.25)
	eq(Collection.fraction(0, 0), 0.0, "nothing to have")
	eq(Collection.fraction(5, 4), 1.0, "never more than all of it")
