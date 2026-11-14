class_name Balance
extends RefCounted

const PORTRAIT_COUNT := 1
const DIALOGUE_SET_COUNT := 3


const FORAGE_DAYS := 2
const GARDEN_YIELD := 4
const POOR_HARVEST_YIELD := 3
const FORAGE_MIN := 9
const FORAGE_MAX := 12
const MAX_RESIDENTS := 7
const GARDEN_PLOTS := 2                      # C: only this many gardeners produce food; extras do nothing
const FORAGE_DEATH_CHANCE := 0.25            # B: chance a forager dies on the road (they never come back)

#disease parameters
const DISEASE_DAYS := 3
const VISITOR_INFECT_CHANCE := 0.5
const VISITOR_INFECT_CHANCE_PER_DAY := 0.02   # D: visitors get sicker as the outbreak spreads (capped by INFECT_CHANCE_CAP)
const NO_GUARD_INFECT_CHANCE := 0.7
const TEST_FAIL_CHANCE := 0.12              # A: a test can come back inconclusive (meal still spent)
const TEST_FALSE_NEGATIVE_CHANCE := 0.2      # A: an infected person can wrongly test Clear (the player isn't told)

const TEST_COST := 1
const EXILE_COST := 1
const MEALS_PER_PERSON := 1
const VISITORS_MIN := 1
const VISITORS_MAX := 2
const INFECT_CHANCE_CAP := 0.9
const EVENT_CHANCE := 0.3
