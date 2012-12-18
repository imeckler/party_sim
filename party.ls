data Desire = Drink | Talk Person | Dance

const DRUNK_DEC = 0.01

class Vector
  (@x, @y) ->

  length: -> sqrt <| @x^2 + @y^2

  minus: (v2) -> new Vector (@x - v2.x), (@y - v2.y)

  plus: (v2) -> new Vector (@x + v2.x), (@y + v2.y)

  scale: (k) -> new Vector (@x * k), (@y * k)

  dot: (v2) -> (@x * v2.x) + (@y * v2.y)

class Party
  () ->

  guestsInBall: (loc, radius) ->
    [g for g in @guests | g.location.minus loc .length < radius]
    # filter (.location.minus loc .length < radius), @guests

  isBarPoint: (loc) -> @barRegion.contains loc

  isDancePoint: (loc) -> @danceRegion.contains loc

class Person
  (@location, @desires) ->
    @inebriation = 0
  

  drinkDesire: -> @desires.inebriation - @inebriation

  danceDesire: -> @desires.dance - @dancingness

  tick: (party) ->
    @inebriation = max 0 (@inebriation - DRUNK_DEC)
    for p in @desires.talk 
      @desires.talk.p -= DRUNK_DEC

    @performAction @location.type

    nearbyGuests = party.guestsInBall @location, SIGHT_RADIUS

    talkStay = sum <| map (@desires.talk.) nearbyGuests
    drinkStay = if party.isBarPoint @location then @drinkDesire! else 0
    danceStay = if party.isDancePoint @location then @desires.dance else 0

  performAction: (locType) -> switch locType
    | \danceFloor => @dance!
    | \bar        => @drink!
    | otherwise   => @talk! # unsure what this should be really

  drink: ->
    @inebriation += 1
    @desires.dance += 1 # ?
    @desires.talk.p += 1 for p in @desires.talk

  dance: ->
    @dancingness += 1
    for guest in party.guestsInBall @location, SIGHT_RADIUS
      guest.desires.talk[this] += 1


const CHARGE_CONSTANT = 1
distance = (p1, p2) -> sqrt <| (p1.x - p2.x)^2 + (p1.y - p2.y)^2
coulombForce = (q1, q2, p1, p2) --> CHARGE_CONSTANT * q1 * q2 / distance p1, p2
desireForce = coulombForce 1

zeroVector = new Vector 0 0

class PhysPerson
  (@location, @desires) ->
    @inebriation = 0

  tick: (party) ->
    drinkForce = 
      if not party.isBarPoint @location
      then party.barLocation.minus @location .scale @desires.drink
      else zeroVector

    danceForce =
      if not party.isDancePoint @location
      then desireForce @desires.drink, @location
      else zeroVector
