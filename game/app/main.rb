require 'lib/debug_mode.rb'
require 'lib/extra_keys.rb'

ZOOM_FACTOR = 2
FOOD_W = 6 * ZOOM_FACTOR
FOOD_HALF_W = FOOD_W.div(2)
FOOD_H = 6 * ZOOM_FACTOR
FOOD_HALF_H = FOOD_H.div(2)

ANT_W = 15 * ZOOM_FACTOR
ANT_HALF_W = ANT_W.div(2)
ANT_H = 16 * ZOOM_FACTOR
ANT_HALF_H = ANT_H.div(2)

MAX_SPEED = 80
STEER_STRENGTH = 80
WANDER_STRENGTH = 0.1

DT = 1 / 60

def center_of(rect)
  [rect.x + rect.w.div(2), rect.y + rect.h.div(2)]
end

def vector_length(x, y)
  Math.sqrt(x**2 + y**2)
end

def clamp_vector!(v, max_length)
  length = vector_length(v.x, v.y)
  if length > max_length
    v.x *= max_length / length
    v.y *= max_length / length
  end
  v
end

def normalize_vector!(v)
  length = vector_length(v.x, v.y)
  v.x /= length
  v.y /= length
  v
end

def normalized_vector(x, y)
  normalize_vector!([x, y])
end

def clamped_vector(x, y, max_length)
  clamp_vector! [x, y], max_length
end

def build_food(args)
  args.state.new_entity_strict(
    :food,
    w: FOOD_W,
    h: FOOD_H,
    path: 'food.png'
  ) do |entity|
    entity.attr_sprite
  end
end

def build_ant(args)
  args.state.new_entity_strict(
    :ant,
    x: 0,
    y: 0,
    w: 15 * ZOOM_FACTOR,
    h: 16 * ZOOM_FACTOR,
    path: 'ant.png',
    angle: 0,
    angle_anchor_x: 0.5,
    angle_anchor_y: 0.5,
    v: [0, 0],
    goal_direction: [0, 1],
  ) do |entity|
    entity.attr_sprite
  end
end

def setup(args)
  args.state.food = build_food(args)
  args.state.ants = 50.map_with_index {
    build_ant(args).tap { |ant|
      ant.x = 20 + rand * 1240
      ant.y = 20 + rand * 680
    }
  }
  args.state.colliders = [
    [-100, -100, 1480, 100],
    [-100, 720, 1480, 100],
    [-100, -100, 100, 920],
    [1280, -100, 100, 920]
  ]
end

def update_food_position(args)
  food = args.state.food
  food.x = args.inputs.mouse.x - FOOD_HALF_W
  food.y = args.inputs.mouse.y - FOOD_HALF_H
end

def turn_ant_towards_goal_direction(ant)
  desired_vx = ant.goal_direction.x * MAX_SPEED
  desired_vy = ant.goal_direction.y * MAX_SPEED
  acceleration = clamped_vector(
    (desired_vx - ant.v.x) * STEER_STRENGTH,
    (desired_vy - ant.v.y) * STEER_STRENGTH,
    STEER_STRENGTH
  )
  ant.v.x += acceleration.x * DT
  ant.v.y += acceleration.y * DT
  clamp_vector!(ant.v, MAX_SPEED)
end

def move_ant(ant)
  ant.x += ant.v.x * DT
  ant.y += ant.v.y * DT
  ant.angle = -Math.atan2(ant.v.x, ant.v.y).to_degrees
end

def follow_food(args, ant)
  food_x = args.state.food.x + args.state.food.w.div(2)
  food_y = args.state.food.y + args.state.food.h.div(2)
  ant.goal_direction = normalized_vector(
    food_x - (ant.x + ANT_HALF_W),
    food_y - (ant.y + ANT_HALF_H)
  )
end

def change_goal_direction_randomly(args, ant)
  rand_angle = rand * Math::PI * 2
  ant.goal_direction.x += Math.sin(rand_angle) * WANDER_STRENGTH
  ant.goal_direction.y += Math.cos(rand_angle) * WANDER_STRENGTH
  normalize_vector!(ant.goal_direction)
end

def handle_collision(args, ant)
  normalized_v = normalized_vector(ant.v.x, ant.v.y)
  ant_position = center_of(ant)
  front = [ant_position.x + normalized_v.x * ANT_HALF_H, ant_position.y + normalized_v.y * ANT_HALF_H]

  collider = args.state.colliders.find { |collider| front.inside_rect? collider }
  return unless collider

  if ant_position.y >= collider.bottom && ant_position.y <= collider.top
    ant.v.x *= -1
    ant.goal_direction.x *= -1
  else
    ant.v.y *= -1
    ant.goal_direction.y *= -1
  end
end

def update_ants(args)
  args.state.ants.each do |ant|
    change_goal_direction_randomly(args, ant)
    # follow_food(args, ant)
    turn_ant_towards_goal_direction(ant)
    handle_collision(args, ant) if args.tick_count.mod_zero? 10
    move_ant(ant)
  end
end

def tick(args)
  setup(args) if args.tick_count.zero?
  update_food_position(args)
  update_ants(args)

  args.outputs.background_color = [89, 125, 206]
  args.outputs.primitives << args.state.food
  args.outputs.primitives << args.state.ants
end

$gtk.reset
$gtk.hide_cursor
