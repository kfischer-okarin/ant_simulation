def test_ants_will_wander_around_randomly(args, assert)
  ant = place_new_ant(args)

  angle_before = ant.angle
  position_before = ant.position.dup
  update_ants(args)

  assert.true! angle_before != ant.angle, 'angle was same'
  assert.true! position_before != ant.position, 'position was same'
end

$gtk.reset 100
$gtk.log_level = :off
