# when guests decide to move, they should pick a goal
# point some distance D away and have a probability p
# of getting to their goal. So, when they are in goal mode
# at every time step, they have a 1 - q probabiliy of
# getting side tracked, where q^(D/time_step) = p

# When people talk to people they like, the other person
# should randomly not engage


map_ = !(f, xs) --> 
  for x in xs
    f x

maxOn = (c, x, y) --> if c x <= c y then x else y
minOn = (c, x, y) --> if c x <= c y then x else y
maximumOn = (c, xs) -->
  maxVal = xs[0]
  maxCmp = c maxVal

  for x in xs
    xCmp = c x
    if xCmp > maxCmp
      maxVal = x
      maxCmp = xCmp
  return maxVal

randBool = -> Math.random! > 0.5

const DRUNK_DEC = 0.01
const DRUNK_INC = 50 * DRUNK_DEC
const WIDTH = 10
const SIGHT_RADIUS = 0.05 * WIDTH
const TALK_RADIUS = 0.05 * WIDTH
const TALK_STAY_CUTOFF = 3
const TALK_INC = 0.1
const WALK_SPEED = 0.01

class Vector
  (@x, @y) ->

  length: -> Math.sqrt <| @x^2 + @y^2

  minus: (v2) -> new Vector (@x - v2.x), (@y - v2.y)

  plus: (v2) -> new Vector (@x + v2.x), (@y + v2.y)

  scale: (k) -> new Vector (@x * k), (@y * k)

  dot: (v2) -> (@x * v2.x) + (@y * v2.y)

  distanceTo: (v2) -> v2.minus this .length!

class Region
  (@northWest, @southEast) ->

  contains: (pt) ->
    @northWest.x < pt.x < @southEast.y && @northWest.y < pt.y < @southEast.y


randRange = (a, b) ->
  Math.floor(a + (b - a) * Math.random!)

randomLocation = ->
  x = WIDTH * Math.random!
  y = WIDTH * Math.random!
  new Vector x, y

randomGuest = (numGuests) ->
  desires = {talk: {total: randRange(0, 10)}, drink: randRange(0, 10), dance: randRange(0, 10)}
  desires.talk.people = [Math.random! for _ in [1 to numGuests]]
  new Person (randomLocation!), desires

class Party
  ({@barRegion, @danceRegion}) ->
    guests = [randomGuest! for _ in [1 to 10]]
    i = 0
    for g in guests
      g._id = i
      g.party = this
      i += 1
    @guests = guests
    @time = 0
    @guestDistances = [[] for _ in [0 to @guests.length]]
    @barCenterPt = (@barRegion.northWest.plus @barRegion.southEast).scale 0.5
    @danceCenterPt = (@danceRegion.northWest.plus @danceRegion.southEast).scale 0.5

  guestsInBall: (loc, radius) ->
    # [g for g in @guests | g.location.minus loc .length < radius]
    filter (.location.minus loc .length < radius), @guests

  isBarPoint: (loc) -> @barRegion.contains loc

  isDancePoint: (loc) -> @danceRegion.contains loc

  tick: ->
    n = @guests.length
    guests = @guests
    for i from 0 til n
      for j from (i + 1) til n
        dist = guests[i].location.minus guests[j].location .length!
        @guestDistances[i][j] = dist
        @guestDistances[j][i] = dist

    map_ (.tick!), @guests
    @time += 1

  typeOfLocation: (loc) ->
    | @isDancePoint loc => \dance
    | @isBarPoint loc   => \drink
    | otherwise         => \normal

class Person
  (@location, @desires) ->
    @inebriation = 0
    @goal = {type: 'wander', target: randomLocation}
    @desireFns = { 'talk': ~> @talkDesire()
                 , 'dance': ~> @danceDesire()
                 , 'drink': ~> @drinkDesire()}

  drinkDesire: -> @desires.drink - @inebriation

  danceDesire: -> @desires.dance - @amtDanced

  talkDesire: -> 
    @desires.talk.total - @amtTalked

  tick: ->
    party = @party
    @sideTrackProb = Math.random!
    @inebriation = max 0, (@inebriation - DRUNK_DEC)
    # for p in @desires.talk
    #   @desires.talk.p -= DRUNK_DEC

    # @performAction <| party.typeOfLocation @location

    # nearbyGuests = party.guestsInBall @location, SIGHT_RADIUS

    # talkStay = sum <| map ((g) -> @desires.talk.people[g._id]), nearbyGuests
    # drinkStay = if party.isBarPoint @location then @drinkDesire! else 0
    # danceStay = if party.isDancePoint @location then @danceDesire! else 0

    @goal = @newGoal!

    # if @goal.type is 'talk'
    #   for g in @party.guests
    #     @distances[g._id] = @location.distanceTo(g.location)

    @attemptGoal!

  # returns possibly new goal
  newGoal: ->
    # add switching goals if another desire gets much bigger
    if @goalIsSatisfied! || Math.random! < @sideTrackProb
      newGoalType = maximumOn ((x) ~> @desireFns[x]()), ['talk', 'drink', 'dance']
      goal = {type: newGoalType, value: @desires[newGoalType]}
      # you want to talk to someone who's close and also who you have a high desire to talk to
      goal.target = switch newGoalType
        | 'talk' => ~> 
          g = maximumOn ((g) ~> @party.guestDistances[@_id][g._id] *
                                @desires.talk.people[g._id]),
                        @party.guests
          g.location
        | 'drink' =>
          barCenterPt = @party.barCenterPt
          -> barCenterPt
        | 'dance' =>
          danceCenterPt = @party.danceCenterPt
          -> danceCenterPt
      return goal
    else
      return @goal


  nearbyGuests: ->
    dists = @party.guestDistances[@_id]
    [g for g in @party.guests when dists[g._id] < TALK_RADIUS]

  attemptGoal: ->
    console.log 'attemptGoal'
    if @goal.type is 'talk'
      nearbyGuests = @nearbyGuests!
      talkStay = sum <| map ((g) ~> @desires.talk.people[g._id]), nearbyGuests
      if talkStay > TALK_STAY_CUTOFF
        @goal.value -= 1
        @desires.talk.total -= talkStay
      else
        @moveToward @goal.target!
    else
      @desires.talk.total += TALK_INC
      locType = @party.typeOfLocation @location
      atPlace = locType is @goal.type
      if atPlace
        this.(locType)()
        @goal.value -= 1
      else
        @moveToward @goal.target!
    console.log 'unattemptGoal'

  moveToward: (loc) ->
    @location = loc.minus @location .scale WALK_SPEED

  performAction: (locType) -> switch locType
    | \dance    => @dance!
    | \drink      => @drink!
    # | otherwise => @talk! # unsure what this should be really

  goalIsSatisfied: -> switch @goal.type
    | 'wander'  => randBool!
    | otherwise => @goal.value <= 0 # covers 'dance', 'drink', 'talk'

  drink: ->
    @inebriation += DRUNK_INC
    @desires.dance += DRUNK_INC
    # for p in @desires.talk
    #   @desires.talk.people.p += DRUNK_INC

  dance: ->
    @amtDanced += 1
    console.log 'dance!'
    for guest in @nearbyGuests!
      guest.desires.talk[@_id] += 1
    console.log 'undance!'


defaultBar = new Region (new Vector 0, WIDTH), (new Vector WIDTH, 0)
defaultDanceFloor = new Region (new Vector WIDTH, 2 * WIDTH), (new Vector 2 * WIDTH, WIDTH)
defaultParty = new Party {barRegion: defaultBar, danceRegion: defaultDanceFloor}
