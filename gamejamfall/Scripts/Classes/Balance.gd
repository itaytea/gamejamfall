class_name Balance
extends RefCounted

#character randomization
const PORTRAIT_COUNT := 1
const BASE_COUNT := 4
const CLOTHES_COUNT := 14
const FACE_COUNT := 10
const HAIR_COUNT := 18
const DIALOGUE_SET_COUNT := 6

#
const FORAGE_DAYS := 2
const GARDEN_YIELD := 3
const POOR_HARVEST_YIELD := 2
const FORAGE_MIN := 3
const FORAGE_MAX := 4
const MAX_RESIDENTS := 5
const GARDEN_PLOTS := 2                      # C: only this many gardeners produce food; extras do nothing
const ROAD_INFECT_CHANCE := 0.2             # foragers can catch it on the road (the player isn't told)
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

#cure
const RESEARCH_MIN := 5.0                    # research % gained per researcher per night (random in this range)
const RESEARCH_MAX := 8.0
const LAB_DAYS := 4                          # trip to the old EPA building, there and back
const LAB_DEATH_CHANCE := 0.25               # chance the lab-goer dies on the road (plus road infection, like foragers)
const SYNTH_NIGHTS := 3                      # nights in a row one person must synthesize (and survive) to win

#hidden attributes (the player is never told who has one)
const ATTRIBUTE_CHANCE := 0.4                # chance a new person has one (about 2-3 on a full farm)
const GREEDY_STEAL_CHANCE := 0.35            # per night at home: greedy resident takes food
const GREEDY_STEAL_MIN := 1
const GREEDY_STEAL_MAX := 2
const FIGHT_CHANCE := 0.15                   # per night at home: belligerent resident starts a fight
const FIGHT_KILL_CHANCE := 0.3               # chance a fight kills the other person
const SUPERSPREADER_INFECTS := 2             # people a superspreader infects when they die
const TATTLE_CHANCE := 0.35                  # on a night with a theft or a survived fight: someone points a finger
const TATTLE_TRUTH_CHANCE := 0.5             # true = a bystander accuses the culprit; false = the culprit accuses someone innocent
