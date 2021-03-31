def test_place_ant_randomly(args, assert)
  ant = Ant.place_new(args)
  ant2 = Ant.place_new(args)

  assert.true! ant.position != ant2.position, 'position was same'
  assert.true! Ant.orientation(ant) != Ant.orientation(ant2), 'orientation was same'
end

def test_place_ant_with_values(args, assert)
  ant = Ant.place_new(args, position: [200, 200], orientation: [1, 0])

  assert.equal! ant.position, [200, 200], 'position was different'
  assert.equal! Ant.orientation(ant).map(&:round), [1, 0], 'orientation was different'
end

def test_ants_will_wander_around_randomly(args, assert)
  ant = Ant.place_new(args)

  orientation_before = Ant.orientation(ant)
  position_before = ant.position.dup
  Ant.update_all(args)

  assert.true! orientation_before != Ant.orientation(ant), 'orientation was same'
  assert.true! position_before != ant.position, 'position was same'
end

def test_ants_will_see_food_close_in_front(args, assert)
  ant = Ant.place_new(args, position: [200, 200], orientation: [1, 0])
  food = Food.place_new(args, position: [250, 200])

  Ant.update_all(args)

  assert.equal! Ant.targeted_food(args, ant), food, 'did not target right food'
end

$gtk.reset 100
$gtk.log_level = :off
