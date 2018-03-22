# Take a view
# for each object in the view that is also a view
# wrap in in parens
# load its code in the parens
# check again until all views are gone
# depth first search seems the most effective here
# may have errors if things are named the same but I dont think so?
# the problem is identifying view objects that are being used across the entire thing, which the TSQL object qualification stuff seems pretty good at doing
# alternately you could split every word, join to the views, expand, join, expand, until there is no child rows

# first, take a query, arbitrary
$Query = "Select * from dbo.v_nestedView v join dbo.not_well_named_view vv on v.view_id = vv.view_id"

# against a target server, evaluate and return the objects that are views
# Ahhh, this would fail for CTE views... fun, unless you add a select * from them or something shitty like that
# and for correlated subqueries this fails... yeah shit