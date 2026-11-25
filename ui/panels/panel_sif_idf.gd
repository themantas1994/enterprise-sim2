extends PanelBase
## Panel `sif_idf`. Reads only the ids in its map entry; layout hints below match parts of id names.


func _group_defs() -> Array:
	return [
		["SIF GRID", ["sif_grid"]],
		["SIF GENERATORS", ["sif_gen"]],
		["SIF BACKUP", ["sif_backup"]],
		["IDF GRID", ["idf_grid"]],
		["IDF GENERATORS", ["idf_gen"]],
		["IDF BACKUP", ["idf_backup"]],
	]
