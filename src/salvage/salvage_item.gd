extends RefCounted
## One piece of salvage. Scene-free. `base` is what the suit estimates; `value` is what it's really worth,
## known only at the payslip.

var id := 0
var kind := ""
var klass := ""            # "small", "medium", "heavy"
var word := ""
var base := 0
var value := 0
var prize := false
var at := Vector2.ZERO     # where it lies when nobody has it
var taken_by := 0          # player ID holding or lifting it; 0 is nobody
