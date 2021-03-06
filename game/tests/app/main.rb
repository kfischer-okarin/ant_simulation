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

def test_ants_will_not_see_food_too_far_away(args, assert)
  ant = Ant.place_new(args, position: [200, 200], orientation: [1, 0])
  food = Food.place_new(args, position: [350, 200])

  Ant.update_all(args)

  assert.equal! Ant.targeted_food(args, ant), nil, 'did unexpectedly target food'
end

def test_ants_will_not_see_food_behind(args, assert)
  ant = Ant.place_new(args, position: [200, 200], orientation: [1, 0])
  food = Food.place_new(args, position: [150, 200])

  Ant.update_all(args)

  assert.equal! Ant.targeted_food(args, ant), nil, 'did unexpectedly target food'
end

def test_ants_will_move_towards_targeted_food(args, assert)
  ant = Ant.place_new(args, position: [200, 200], orientation: [1, 0])
  food = Food.place_new(args, position: [300, 200])
  distance_before = GTK::Geometry.distance(ant.position, food.position)

  Ant.target_food(ant, food)
  Ant.update_all(args)

  assert.true! GTK::Geometry.distance(ant.position, food.position) < distance_before, 'did not move closer to food'
end

def test_ants_will_take_target_food_in_front_of_them(args, assert)
  ant = Ant.place_new(args, position: [200, 200], orientation: [1, 0])
  food = Food.place_new(args, position: [210, 200])

  Ant.target_food(ant, food)
  Ant.update_all(args)

  assert.equal! Ant.carried_food(args, ant), food, 'did not carry the food'
end

def test_ants_move_carried_food_with_them(args, assert)
  ant = Ant.place_new(args, position: [200, 200], orientation: [1, 0])
  food = Food.place_new(args, position: [210, 200])
  position_before = food.position.dup

  Ant.carry_food(ant, food)
  Ant.update_all(args)

  assert.true! food.position != position_before, 'food did not move'
end

$gtk.reset 100
$gtk.log_level = :off
