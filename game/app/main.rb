require 'lib/debug_mode.rb'
require 'lib/extra_keys.rb'

ZOOM_FACTOR = 2

MAX_SPEED = 80
STEER_STRENGTH = 80
WANDER_STRENGTH = 0.1
CELL_SIZE = 40

DT = 1 / 60

def center_of(rect)
  [rect.x + rect.w.div(2), rect.y + rect.h.div(2)]
end

def vector_length(x, y)
  Math.sqrt(x**2 + y**2)
end

def dot_product(v1, v2)
  v1.x * v2.x + v1.y * v2.y
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

def update_render_position(entity)
  entity.x = entity.position.x - entity.w.div(2)
  entity.y = entity.position.y - entity.h.div(2)
end

def build_nest(args)
  args.state.new_entity_strict(
    :nest,
    position: [0, 0],
    w: 64,
    h: 64,
    path: 'nest.png'
  ).tap { |result|
    result.attr_sprite
    result.position.x = 200 + 880 * rand
    result.position.y = 200 + 320 * rand
    update_render_position(result)
  }
end

def build_food(args)
  args.state.new_entity_strict(
    :food,
    position: [0, 0],
    w: 12 * ZOOM_FACTOR,
    h: 12 * ZOOM_FACTOR,
    path: 'food.png'
  ).tap { |result|
    result.attr_sprite
  }
end

def build_ant(args)
  args.state.new_entity_strict(
    :ant,
    x: 0,
    y: 0,
    position: [0, 0],
    w: 15 * ZOOM_FACTOR,
    h: 16 * ZOOM_FACTOR,
    path: 'ant.png',
    angle: 0,
    angle_anchor_x: 0.5,
    angle_anchor_y: 0.5,
    v: [0, 0],
    acceleration: [0, 0],
    goal_direction: [0, 1]
  ).tap { |result|
    result.attr_sprite
    nest_position = args.state.nest.position
    result.position.x = nest_position.x
    result.position.y = nest_position.y
    update_render_position(result)

    rand_angle = rand * Math::PI * 2
    result.goal_direction.x = Math.sin(rand_angle) * WANDER_STRENGTH
    result.goal_direction.y = Math.cos(rand_angle) * WANDER_STRENGTH
  }
end

def setup(args)
  args.state.nest = build_nest(args)
  args.state.cursor = build_food(args)
  args.state.food = {}
  args.state.cells = (1280 / CELL_SIZE).map_with_index {
    (720 / CELL_SIZE).map_with_index { [] }
  }
  args.state.ants = 50.map_with_index { build_ant(args) }
  args.state.colliders = [
    [-100, -100, 1480, 100],
    [-100, 720, 1480, 100],
    [-100, -100, 100, 920],
    [1280, -100, 100, 920]
  ]
end

def update_cursor_position(args)
  cursor = args.state.cursor
  cursor.position.x = args.inputs.mouse.x
  cursor.position.y = args.inputs.mouse.y
  update_render_position(cursor)
end

def get_map_cell(args, position)
  args.state.cells[position.x.div(CELL_SIZE)][position.y.div(CELL_SIZE)]
end

def all_food_in_rect(args, rect)
  left = [0, rect.left.div(CELL_SIZE)].max
  right = [1280 / CELL_SIZE - 1, rect.right.div(CELL_SIZE)].min
  bottom = [0, rect.bottom.div(CELL_SIZE)].max
  top = [720 / CELL_SIZE - 1, rect.top.div(CELL_SIZE)].min
  cells = args.state.cells
  food = args.state.food

  Enumerator.new do |yielder|
    (left..right).each do |x|
      (bottom..top).each do |y|
        cells[x][y].each do |food_id|
          yielder << food[food_id]
        end
      end
    end
  end
end

def get_all_food_in_circle(args, center, radius)
  all_food_in_rect(args, [center.x - radius, center.y - radius, radius * 2, radius * 2]).select { |food|
    (food.x - center.x)**2 + (food.y - center.y)**2 <= radius**2
  }
end

def turn_towards_food(args, ant)
  food_in_radius = get_all_food_in_circle(args, ant.position, 50).select { |food|
    food_direction = [food.position.x - ant.position.x, food.position.y - ant.position.y]
    dot_product(ant.v, food_direction).positive?
  }.sample
  return unless food_in_radius

  ant.goal_direction.x = food_in_radius.x - ant.position.x
  ant.goal_direction.y = food_in_radius.y - ant.position.y
  normalize_vector!(ant.goal_direction)
end

def handle_mouse_click(args)
  return unless args.mouse.click

  cursor = args.state.cursor
  placed_food = build_food(args)
  placed_food.position.x = cursor.position.x
  placed_food.position.y = cursor.position.y
  update_render_position(placed_food)
  get_map_cell(args, placed_food) << placed_food.entity_id
  args.state.food[placed_food.entity_id] = placed_food
end

def turn_ant_towards_goal_direction(ant)
  ant.acceleration.x = (ant.goal_direction.x * MAX_SPEED - ant.v.x) * STEER_STRENGTH
  ant.acceleration.y = (ant.goal_direction.y * MAX_SPEED - ant.v.y) * STEER_STRENGTH
  clamp_vector!(ant.acceleration, STEER_STRENGTH)

  ant.v.x += ant.acceleration.x * DT
  ant.v.y += ant.acceleration.y * DT
  clamp_vector!(ant.v, MAX_SPEED)
end

def move_ant(ant)
  ant.position.x += ant.v.x * DT
  ant.position.y += ant.v.y * DT
  update_render_position(ant)
  ant.angle = -Math.atan2(ant.v.x, ant.v.y).to_degrees
end

def change_goal_direction_randomly(args, ant)
  rand_angle = rand * Math::PI * 2
  ant.goal_direction.x += Math.sin(rand_angle) * WANDER_STRENGTH
  ant.goal_direction.y += Math.cos(rand_angle) * WANDER_STRENGTH
  normalize_vector!(ant.goal_direction)
end

def handle_collision(args, ant)
  normalized_v = normalized_vector(ant.v.x, ant.v.y)
  ant_position = ant.position
  front = [ant_position.x + normalized_v.x * ant.h.half, ant_position.y + normalized_v.y * ant.h.half]

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
    turn_towards_food(args, ant)
    turn_ant_towards_goal_direction(ant)
    handle_collision(args, ant) if args.tick_count.mod_zero? 10
    move_ant(ant)
  end
end

def tick(args)
  setup(args) if args.tick_count.zero?
  update_cursor_position(args)
  handle_mouse_click(args)
  update_ants(args)

  args.outputs.background_color = [117, 113, 97]
  args.outputs.primitives << args.state.food.each_value
  args.outputs.primitives << args.state.ants
  args.outputs.primitives << args.state.nest
  args.outputs.primitives << args.state.cursor
end

$gtk.reset
$gtk.hide_cursor
