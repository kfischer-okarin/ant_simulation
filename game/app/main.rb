require 'lib/debug_mode.rb'
require 'lib/extra_keys.rb'

ZOOM_FACTOR = 2

MAX_SPEED = 80
STEER_STRENGTH = 80
WANDER_STRENGTH = 0.1
CELL_SIZE = 40
VIEW_RADIUS = 100

DT = 1 / 60

def outside_screen?(position)
  position.x.negative? || position.x >= 1280 || position.y.negative? || position.y >= 720
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

def build_cells
  (1280 / CELL_SIZE).map_with_index {
    (720 / CELL_SIZE).map_with_index { {} }
  }
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
    path: 'food.png',
    carried: false
  ).tap { |result|
    result.attr_sprite
  }
end

def build_home_pheromone(args)
  args.state.new_entity_strict(
    :home_pheromone,
    position: [0, 0],
    w: 3 * ZOOM_FACTOR,
    h: 3 * ZOOM_FACTOR,
    path: 'pheromone.png',
    r: 89, g: 125, b: 206,
    amount: 100
  ).tap { |result|
    result.attr_sprite
  }
end

def random_position
  [rand * 1280, rand * 720]
end

def random_orientation
  rand_angle = rand * Math::PI * 2
  [Math.sin(rand_angle), Math.cos(rand_angle)]
end

module Ant
  class << self
    def place_new(args, position: nil, orientation: nil)
      args.state.new_entity_strict(
        :ant,
        x: 0,
        y: 0,
        position: position&.dup || random_position,
        w: 15 * ZOOM_FACTOR,
        h: 16 * ZOOM_FACTOR,
        path: 'ant.png',
        angle: 0,
        angle_anchor_x: 0.5,
        angle_anchor_y: 0.5,
        v: [0, 0],
        acceleration: [0, 0],
        goal_direction: orientation&.dup || random_orientation,
        target_food_id: nil,
        carried_food_id: nil
      ).tap { |ant|
        ant.attr_sprite
        update_render_position(ant)

        set_orientation(ant, ant.goal_direction)

        ants(args) << ant
      }
    end

    def orientation(ant)
      angle = -ant.angle.to_radians
      [Math.sin(angle), Math.cos(angle)]
    end

    def set_orientation(ant, orientation)
      ant.angle = -Math.atan2(orientation.x, orientation.y).to_degrees
    end

    def target_food(ant, food)
      ant.target_food_id = food.entity_id
    end

    def untarget_food(ant)
      ant.target_food_id = nil
    end

    def targeted_food(args, ant)
      return unless ant.target_food_id

      Food.with_id(args, ant.target_food_id)
    end

    def carried_food(args, ant)
      return unless ant.carried_food_id

      Food.with_id(args, ant.carried_food_id)
    end

    def carry_food(ant, food)
      food.carried = true
      ant.carried_food_id = food.entity_id
      untarget_food(ant)
    end

    def update_all(args)
      ants(args).each do |ant|
        change_goal_direction_randomly(args, ant)
        target_food = find_target_food(args, ant)
        turn_towards_object(ant, target_food) if target_food
        turn_ant_towards_goal_direction(ant)
        move_ant(ant)

        front = position_in_front_of_ant(ant)
        back = [ant.position.x + ant.position.x - front.x, ant.position.y + ant.position.y - front.y]
        handle_take_food(args, ant, front, target_food) if target_food
        carried_food = Ant.carried_food(args, ant)
        handle_carry_food(front, carried_food) if carried_food
        if args.tick_count.mod_zero? 10
          handle_collision(args, ant, front)
          handle_drop_home_pheromone(args, ant, back)
        end
      end
    end

    private

    def ants(args)
      args.state.ants ||= []
    end

    def turn_towards_object(ant, object)
      ant.goal_direction.x = object.position.x - ant.position.x
      ant.goal_direction.y = object.position.y - ant.position.y
      normalize_vector!(ant.goal_direction)
    end

    def handle_take_food(args, ant, front, target_food)
      square_distance = (target_food.position.x - front.x)**2 + (target_food.position.y - front.y)**2
      return unless square_distance < 100

      carry_food(ant, target_food)
      remove_from_map_cell(args, target_food)
    end

    def handle_carry_food(front, carried_food)
      carried_food.position.x = front.x
      carried_food.position.y = front.y
      update_render_position(carried_food)
    end
  end
end

module Food
  class << self
    def place_new(args, position: nil)
      args.state.new_entity_strict(
        :food,
        position: position&.dup || random_position,
        w: 12 * ZOOM_FACTOR,
        h: 12 * ZOOM_FACTOR,
        path: 'food.png',
        carried: false
      ).tap { |food|
        food.attr_sprite

        update_render_position(food)
        add_to_map_cell(args, food)
        add_to_objects(args, food)
      }
    end

    def with_id(args, id)
      get_entities_of_type(args, :food)[id]
    end
  end
end

def setup(args)
  args.state.nest = build_nest(args)
  nest_position = args.state.nest.position
  50.times do
    Ant.place_new(args, position: nest_position)
  end
  args.state.cursor = { w: 12 * ZOOM_FACTOR, h: 12 * ZOOM_FACTOR, path: 'food.png' }.sprite
  args.state.colliders = [
    [-100, -100, 1480, 100],
    [-100, 720, 1480, 100],
    [-100, -100, 100, 920],
    [1280, -100, 100, 920]
  ]
  args.state.new_pheromones = []
  args.state.second_buffer = false
  args.outputs[:pheromone_map].background_color = [0, 0, 0, 0]
  args.outputs[:pheromone_map2].background_color = [0, 0, 0, 0]
end

def update_cursor_position(args)
  cursor = args.state.cursor
  cursor.x = args.inputs.mouse.x - cursor.w.half
  cursor.y = args.inputs.mouse.y - cursor.h.half
end

def get_map_cells(args)
  args.state.cells ||= build_cells
end

def get_map_cell(args, position)
  get_map_cells(args)[position.x.div(CELL_SIZE)][position.y.div(CELL_SIZE)]
end

def get_entities_of_type(args, type)
  args.state.objects ||= { food: {}, home_pheromone: {} }
  args.state.objects[type] ||= {}
end

def add_to_objects(args, entity)
  get_entities_of_type(args, entity.entity_type)[entity.entity_id] = entity
end

def add_to_map_cell(args, entity)
  cell = get_map_cell(args, entity.position)
  cell[entity.entity_type] ||= []
  cell[entity.entity_type] << entity.entity_id
end

def remove_from_map_cell(args, entity)
  cell = get_map_cell(args, entity.position)
  return unless cell[entity.entity_type]

  cell[entity.entity_type].delete entity.entity_id
end

def all_entities_in_rect(args, entity_type, rect)
  left = [0, rect.left.div(CELL_SIZE)].max
  right = [1280 / CELL_SIZE - 1, rect.right.div(CELL_SIZE)].min
  bottom = [0, rect.bottom.div(CELL_SIZE)].max
  top = [720 / CELL_SIZE - 1, rect.top.div(CELL_SIZE)].min
  cells = get_map_cells(args)
  entities = get_entities_of_type(args, entity_type)

  Enumerator.new do |yielder|
    (left..right).each do |x|
      (bottom..top).each do |y|
        (cells[x][y][entity_type] || []).each do |entity_id|
          yielder << entities[entity_id]
        end
      end
    end
  end
end

def all_entities_in_circle(args, entity_type, center, radius)
  all_entities_in_rect(args, entity_type, [center.x - radius, center.y - radius, radius * 2, radius * 2]).select { |entity|
    (entity.position.x - center.x)**2 + (entity.position.y - center.y)**2 <= radius**2
  }
end

def find_target_food(args, ant)
  target_food = Ant.targeted_food(args, ant)
  if target_food
    return target_food unless target_food.carried

    Ant.untarget_food(ant)
  end

  target_food = all_entities_in_circle(args, :food, ant.position, VIEW_RADIUS).select { |food|
    next if food.carried

    food_direction = [food.position.x - ant.position.x, food.position.y - ant.position.y]
    dot_product(Ant.orientation(ant), food_direction).positive?
  }.sample

  Ant.target_food(ant, target_food) if target_food

  target_food
end

def handle_mouse_click(args)
  return unless args.mouse.click

  Food.place_new(args, position: [args.mouse.x, args.mouse.y])
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
  Ant.set_orientation(ant, ant.v)
end

def change_goal_direction_randomly(args, ant)
  rand_angle = rand * Math::PI * 2
  ant.goal_direction.x += Math.sin(rand_angle) * WANDER_STRENGTH
  ant.goal_direction.y += Math.cos(rand_angle) * WANDER_STRENGTH
  normalize_vector!(ant.goal_direction)
end

def position_in_front_of_ant(ant)
  [ant.position.x, ant.position.y].tap { |result|
    angle = -ant.angle.to_radians
    result.x += Math.sin(angle) * ant.h.half
    result.y += Math.cos(angle) * ant.h.half
  }
end

def handle_collision(args, ant, front)
  collider = args.state.colliders.find { |collider| front.inside_rect? collider }
  return unless collider

  if ant.position.y >= collider.bottom && ant.position.y <= collider.top
    ant.v.x *= -1
    ant.goal_direction.x *= -1
  else
    ant.v.y *= -1
    ant.goal_direction.y *= -1
  end
end

def handle_drop_home_pheromone(args, ant, back)
  return
  return if ant.carried_food_id || outside_screen?(back)

  pheromone = build_home_pheromone(args)
  pheromone.position.x = back.x
  pheromone.position.y = back.y
  update_render_position(pheromone)
  add_to_map_cell(args, pheromone)
  add_to_objects(args, pheromone)
  args.state.new_pheromones << pheromone.entity_id
end

def render_new_pheromones(args)
  if args.state.second_buffer
    previous_target_name = :pheromone_map
    target = args.outputs[:pheromone_map2]
  else
    previous_target_name = :pheromone_map2
    target = args.outputs[:pheromone_map]
  end

  alpha = args.tick_count.mod_zero?(5) ? 250 : 255
  target.background_color = [0, 0, 0, 0]
  target.primitives << { x: 0, y: 0, w: 1280, h: 720, path: previous_target_name, a: alpha }.sprite
  pheromones = get_entities_of_type(args, :home_pheromone)
  args.state.new_pheromones.each do |entity_id|
    target.primitives << pheromones[entity_id]
  end
  args.state.new_pheromones.clear
end

def tick(args)
  setup(args) if args.tick_count.zero?
  return if args.tick_count < 2

  update_cursor_position(args)
  handle_mouse_click(args)
  Ant.update_all(args)

  args.outputs.background_color = [117, 113, 97]
  args.outputs.primitives << get_entities_of_type(args, :food).each_value
  render_new_pheromones(args)
  args.outputs.primitives << [0, 0, 1280, 720, args.state.second_buffer ? :pheromone_map2 : :pheromone_map].sprite
  args.state.second_buffer = !args.state.second_buffer
  args.outputs.primitives << args.state.ants
  args.outputs.primitives << args.state.nest
  args.outputs.primitives << args.state.cursor
end

$gtk.reset
$gtk.hide_cursor
