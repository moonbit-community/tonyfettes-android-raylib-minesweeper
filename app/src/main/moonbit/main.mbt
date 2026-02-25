// Minesweeper — Full-featured port from C++ to MoonBit
// Features: difficulty menu, touch gestures, camera zoom/pan, header bar, game over overlay

// ---- Helper functions ----

fn clamp(value : Float, min : Float, max : Float) -> Float {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}

fn float_max(a : Float, b : Float) -> Float {
  if a > b { a } else { b }
}

fn int_abs(x : Int) -> Int {
  if x < 0 { -x } else { x }
}

fn vector2_distance(a : @raylib.Vector2, b : @raylib.Vector2) -> Float {
  let dx = a.x - b.x
  let dy = a.y - b.y
  (dx * dx + dy * dy).sqrt()
}

// ---- Color constants ----

let number_colors : Array[@raylib.Color] = [
  @raylib.blank,                             // 0 - not used
  @raylib.blue,                              // 1
  @raylib.darkgreen,                         // 2
  @raylib.red,                               // 3
  @raylib.darkblue,                          // 4
  @raylib.maroon,                            // 5
  @raylib.Color::new(0, 128, 128, 255),      // 6 - Teal
  @raylib.black,                             // 7
  @raylib.gray,                              // 8
]

// ---- Game state constants ----

let state_menu : Int = 0

let state_playing : Int = 1

let state_won : Int = 2

let state_lost : Int = 3

let state_about : Int = 4

// ---- Gesture state constants ----

let touch_none : Int = 0

let tap_or_hold : Int = 1

let gesture_pan : Int = 2

let gesture_pinch : Int = 3

// ---- Cell ----

struct Cell {
  mut has_mine : Bool
  mut is_revealed : Bool
  mut is_flagged : Bool
  mut neighbor_mines : Int
}

fn Cell::new() -> Cell {
  { has_mine: false, is_revealed: false, is_flagged: false, neighbor_mines: 0 }
}

// ---- Board helpers ----

fn cell_index(row : Int, col : Int, cols : Int) -> Int {
  row * cols + col
}

fn is_valid_cell(row : Int, col : Int, rows : Int, cols : Int) -> Bool {
  row >= 0 && row < rows && col >= 0 && col < cols
}

fn place_mines(
  board : Array[Cell],
  rows : Int,
  cols : Int,
  total_mines : Int,
  safe_row : Int,
  safe_col : Int,
) -> Unit {
  let mut placed = 0
  while placed < total_mines {
    let idx = @raylib.get_random_value(0, rows * cols - 1)
    let r = idx / cols
    let c = idx % cols
    if int_abs(r - safe_row) <= 1 && int_abs(c - safe_col) <= 1 {
      continue
    }
    if board[idx].has_mine {
      continue
    }
    board[idx].has_mine = true
    placed = placed + 1
  }
  // Count neighbor mines
  for r = 0; r < rows; r = r + 1 {
    for c = 0; c < cols; c = c + 1 {
      let idx = cell_index(r, c, cols)
      if board[idx].has_mine {
        continue
      }
      let mut count = 0
      for dr = -1; dr <= 1; dr = dr + 1 {
        for dc = -1; dc <= 1; dc = dc + 1 {
          let nr = r + dr
          let nc = c + dc
          if is_valid_cell(nr, nc, rows, cols) && board[cell_index(nr, nc, cols)].has_mine {
            count = count + 1
          }
        }
      }
      board[idx].neighbor_mines = count
    }
  }
}

fn reveal_cell(
  board : Array[Cell],
  rows : Int,
  cols : Int,
  row : Int,
  col : Int,
  revealed_count : Ref[Int],
) -> Bool {
  // Returns true if mine was hit
  if not(is_valid_cell(row, col, rows, cols)) {
    return false
  }
  let idx = cell_index(row, col, cols)
  if board[idx].is_revealed || board[idx].is_flagged {
    return false
  }
  board[idx].is_revealed = true
  revealed_count.val = revealed_count.val + 1
  if board[idx].has_mine {
    // Reveal all mines
    for i = 0; i < rows * cols; i = i + 1 {
      if board[i].has_mine {
        board[i].is_revealed = true
      }
    }
    return true
  }
  // BFS flood fill for zero-neighbor cells
  if board[idx].neighbor_mines == 0 {
    let queue : Array[(Int, Int)] = [(row, col)]
    let mut head = 0
    while head < queue.length() {
      let (cr, cc) = queue[head]
      head = head + 1
      for dr = -1; dr <= 1; dr = dr + 1 {
        for dc = -1; dc <= 1; dc = dc + 1 {
          let nr = cr + dr
          let nc = cc + dc
          if not(is_valid_cell(nr, nc, rows, cols)) {
            continue
          }
          let ni = cell_index(nr, nc, cols)
          if board[ni].is_revealed || board[ni].is_flagged || board[ni].has_mine {
            continue
          }
          board[ni].is_revealed = true
          revealed_count.val = revealed_count.val + 1
          if board[ni].neighbor_mines == 0 {
            queue.push((nr, nc))
          }
        }
      }
    }
  }
  false
}

fn toggle_flag(board : Array[Cell], rows : Int, cols : Int, row : Int, col : Int, flag_count : Ref[Int]) -> Unit {
  if not(is_valid_cell(row, col, rows, cols)) {
    return
  }
  let idx = cell_index(row, col, cols)
  if board[idx].is_revealed {
    return
  }
  board[idx].is_flagged = not(board[idx].is_flagged)
  if board[idx].is_flagged {
    flag_count.val = flag_count.val + 1
  } else {
    flag_count.val = flag_count.val - 1
  }
}

// ---- Main ----

fn main {
  @raylib.init_window(0, 0, "Minesweeper")
  @raylib.set_target_fps(60)
  @raylib.set_exit_key(0)

  // Screen dimensions
  let screen_width : Ref[Int] = { val: @raylib.get_screen_width() }
  let screen_height : Ref[Int] = { val: @raylib.get_screen_height() }
  let header_height : Ref[Float] = { val: Float::from_int(screen_height.val) * 0.08 }

  // Game state
  let game_state : Ref[Int] = { val: state_menu }
  let rows : Ref[Int] = { val: 0 }
  let cols : Ref[Int] = { val: 0 }
  let total_mines : Ref[Int] = { val: 0 }
  let revealed_count : Ref[Int] = { val: 0 }
  let flag_count : Ref[Int] = { val: 0 }
  let first_click : Ref[Bool] = { val: true }
  let timer : Ref[Float] = { val: 0.0 }

  // Board (max size: 16*30 = 480)
  let board : Ref[Array[Cell]] = { val: [] }

  // Layout
  let cell_size : Ref[Float] = { val: 0.0 }
  let offset_x : Ref[Float] = { val: 0.0 }
  let offset_y : Ref[Float] = { val: 0.0 }

  // Camera
  let cam_offset_x : Ref[Float] = { val: 0.0 }
  let cam_offset_y : Ref[Float] = { val: 0.0 }
  let cam_target_x : Ref[Float] = { val: 0.0 }
  let cam_target_y : Ref[Float] = { val: 0.0 }
  let cam_zoom : Ref[Float] = { val: 1.0 }
  let min_zoom : Ref[Float] = { val: 1.0 }
  let max_zoom : Ref[Float] = { val: 1.0 }

  // Touch / gesture state
  let touch_start_x : Ref[Float] = { val: 0.0 }
  let touch_start_y : Ref[Float] = { val: 0.0 }
  let touch_timer : Ref[Float] = { val: 0.0 }
  let long_press_triggered : Ref[Bool] = { val: false }
  let gesture_decided : Ref[Bool] = { val: false }
  let active_gesture : Ref[Int] = { val: touch_none }
  let gesture_move_dist : Ref[Float] = { val: 0.0 }

  // Pinch state
  let pinch_start_dist : Ref[Float] = { val: 0.0 }
  let pinch_start_zoom : Ref[Float] = { val: 0.0 }

  // Pan state
  let pan_start_x : Ref[Float] = { val: 0.0 }
  let pan_start_y : Ref[Float] = { val: 0.0 }
  let pan_start_target_x : Ref[Float] = { val: 0.0 }
  let pan_start_target_y : Ref[Float] = { val: 0.0 }

  // ---- Helper closures ----

  fn calculate_layout() -> Unit {
    let avail_w = Float::from_int(screen_width.val)
    let avail_h = Float::from_int(screen_height.val) - header_height.val
    let cell_w = avail_w / Float::from_int(cols.val)
    let cell_h = avail_h / Float::from_int(rows.val)
    cell_size.val = if cell_w < cell_h { cell_w } else { cell_h }
    let board_w = cell_size.val * Float::from_int(cols.val)
    let board_h = cell_size.val * Float::from_int(rows.val)
    offset_x.val = (avail_w - board_w) / 2.0
    offset_y.val = header_height.val + (avail_h - board_h) / 2.0
  }

  fn init_camera() -> Unit {
    let avail_h = Float::from_int(screen_height.val) - header_height.val
    cam_offset_x.val = Float::from_int(screen_width.val) / 2.0
    cam_offset_y.val = header_height.val + avail_h / 2.0
    cam_target_x.val = offset_x.val + Float::from_int(cols.val) * cell_size.val / 2.0
    cam_target_y.val = offset_y.val + Float::from_int(rows.val) * cell_size.val / 2.0
    cam_zoom.val = 1.0
    min_zoom.val = 1.0
    max_zoom.val = float_max(90.0 / cell_size.val, min_zoom.val)
    active_gesture.val = touch_none
    gesture_decided.val = false
    long_press_triggered.val = false
    gesture_move_dist.val = 0.0
  }

  fn clamp_camera() -> Unit {
    let board_w = Float::from_int(cols.val) * cell_size.val
    let board_h = Float::from_int(rows.val) * cell_size.val
    let board_cx = offset_x.val + board_w / 2.0
    let board_cy = offset_y.val + board_h / 2.0
    let avail_h = Float::from_int(screen_height.val) - header_height.val
    let vis_w = Float::from_int(screen_width.val) / cam_zoom.val
    let vis_h = avail_h / cam_zoom.val
    if board_w > vis_w {
      let mn = offset_x.val + vis_w / 2.0
      let mx = offset_x.val + board_w - vis_w / 2.0
      cam_target_x.val = clamp(cam_target_x.val, mn, mx)
    } else {
      cam_target_x.val = board_cx
    }
    if board_h > vis_h {
      let mn = offset_y.val + vis_h / 2.0
      let mx = offset_y.val + board_h - vis_h / 2.0
      cam_target_y.val = clamp(cam_target_y.val, mn, mx)
    } else {
      cam_target_y.val = board_cy
    }
  }

  fn init_board(r : Int, c : Int, mines : Int) -> Unit {
    rows.val = r
    cols.val = c
    total_mines.val = mines
    revealed_count.val = 0
    flag_count.val = 0
    first_click.val = true
    timer.val = 0.0
    game_state.val = state_playing
    let total = r * c
    let new_board = Array::make(total, Cell::new())
    for i = 0; i < total; i = i + 1 {
      new_board[i] = Cell::new()
    }
    board.val = new_board
    calculate_layout()
    init_camera()
  }

  fn make_camera() -> @raylib.Camera2D {
    @raylib.Camera2D::new(
      @raylib.Vector2::new(cam_offset_x.val, cam_offset_y.val),
      @raylib.Vector2::new(cam_target_x.val, cam_target_y.val),
      0.0,
      cam_zoom.val,
    )
  }

  fn screen_to_board(sx : Float, sy : Float) -> (Float, Float) {
    let cam = make_camera()
    let world = @raylib.get_screen_to_world_2d(
      @raylib.Vector2::new(sx, sy),
      cam,
    )
    (world.x, world.y)
  }

  fn get_cell_row(y : Float) -> Int {
    ((y - offset_y.val) / cell_size.val).to_int()
  }

  fn get_cell_col(x : Float) -> Int {
    ((x - offset_x.val) / cell_size.val).to_int()
  }

  fn check_win() -> Bool {
    revealed_count.val == rows.val * cols.val - total_mines.val
  }

  // ---- Main loop ----

  while not(@raylib.window_should_close()) {
    // Screen resize detection
    let new_w = @raylib.get_screen_width()
    let new_h = @raylib.get_screen_height()
    if new_w != screen_width.val || new_h != screen_height.val {
      screen_width.val = new_w
      screen_height.val = new_h
      header_height.val = Float::from_int(new_h) * 0.08
      if game_state.val == state_playing || game_state.val == state_won || game_state.val == state_lost {
        calculate_layout()
        init_camera()
      }
    }

    // ---- UPDATE ----
    let sw = Float::from_int(screen_width.val)
    let sh = Float::from_int(screen_height.val)
    let hh = header_height.val

    if game_state.val == state_menu {
      @raylib.set_gestures_enabled(@raylib.GestureTap)
      // Handle menu input
      if @raylib.is_gesture_detected(@raylib.GestureTap) {
        let pos = @raylib.get_touch_position(0)
        let btn_w = sw * 0.6
        let btn_h = sh * 0.07
        let btn_x = (sw - btn_w) / 2.0
        let start_y = sh * 0.35
        let spacing = btn_h * 1.5
        // Easy
        if pos.x >= btn_x && pos.x <= btn_x + btn_w && pos.y >= start_y && pos.y <= start_y + btn_h {
          init_board(12, 8, 10)
        }
        // Medium
        let med_y = start_y + spacing
        if pos.x >= btn_x && pos.x <= btn_x + btn_w && pos.y >= med_y && pos.y <= med_y + btn_h {
          init_board(20, 12, 40)
        }
        // Hard
        let hard_y = start_y + spacing * 2.0
        if pos.x >= btn_x && pos.x <= btn_x + btn_w && pos.y >= hard_y && pos.y <= hard_y + btn_h {
          init_board(30, 16, 99)
        }
        // About
        let about_w = sw * 0.4
        let about_h = sh * 0.055
        let about_x = (sw - about_w) / 2.0
        let about_y = start_y + spacing * 3.0 + btn_h * 0.3
        if pos.x >= about_x && pos.x <= about_x + about_w && pos.y >= about_y && pos.y <= about_y + about_h {
          game_state.val = state_about
        }
      }
    } else if game_state.val == state_about {
      @raylib.set_gestures_enabled(@raylib.GestureTap)
      if @raylib.is_gesture_detected(@raylib.GestureTap) {
        game_state.val = state_menu
      }
    } else if game_state.val == state_playing {
      @raylib.set_gestures_enabled(0)
      timer.val = timer.val + @raylib.get_frame_time()

      let touch_count = @raylib.get_touch_point_count()

      // Touch start
      if touch_count > 0 && active_gesture.val == touch_none {
        let ts = @raylib.get_touch_position(0)
        touch_start_x.val = ts.x
        touch_start_y.val = ts.y
        touch_timer.val = 0.0
        long_press_triggered.val = false
        gesture_decided.val = false
        gesture_move_dist.val = 0.0
        active_gesture.val = tap_or_hold
        if touch_count >= 2 {
          active_gesture.val = gesture_pinch
          gesture_decided.val = true
          let t0 = @raylib.get_touch_position(0)
          let t1 = @raylib.get_touch_position(1)
          pinch_start_dist.val = vector2_distance(t0, t1)
          pinch_start_zoom.val = cam_zoom.val
        }
      }

      // Touch held
      if touch_count > 0 && active_gesture.val != touch_none {
        touch_timer.val = touch_timer.val + @raylib.get_frame_time()
        let pos = @raylib.get_touch_position(0)
        let ts = @raylib.Vector2::new(touch_start_x.val, touch_start_y.val)
        gesture_move_dist.val = vector2_distance(pos, ts)

        // Transition to pinch
        if active_gesture.val != gesture_pinch && touch_count >= 2 {
          active_gesture.val = gesture_pinch
          gesture_decided.val = true
          let t0 = @raylib.get_touch_position(0)
          let t1 = @raylib.get_touch_position(1)
          pinch_start_dist.val = vector2_distance(t0, t1)
          pinch_start_zoom.val = cam_zoom.val
        }

        // Transition to pan
        if not(gesture_decided.val) && touch_count == 1 && gesture_move_dist.val > 12.0 && cam_zoom.val > min_zoom.val + 0.01 {
          active_gesture.val = gesture_pan
          gesture_decided.val = true
          pan_start_x.val = pos.x
          pan_start_y.val = pos.y
          pan_start_target_x.val = cam_target_x.val
          pan_start_target_y.val = cam_target_y.val
        }

        // Handle camera input
        if active_gesture.val == gesture_pinch {
          if touch_count >= 2 {
            let t0 = @raylib.get_touch_position(0)
            let t1 = @raylib.get_touch_position(1)
            let current_dist = vector2_distance(t0, t1)
            if pinch_start_dist.val > 1.0 {
              let mid = @raylib.Vector2::new(
                (t0.x + t1.x) / 2.0,
                (t0.y + t1.y) / 2.0,
              )
              // World position before zoom
              let cam_before = make_camera()
              let world_before = @raylib.get_screen_to_world_2d(mid, cam_before)
              // Apply new zoom
              let new_zoom = pinch_start_zoom.val * (current_dist / pinch_start_dist.val)
              cam_zoom.val = clamp(new_zoom, min_zoom.val, max_zoom.val)
              // World position after zoom
              let cam_after = make_camera()
              let world_after = @raylib.get_screen_to_world_2d(mid, cam_after)
              // Stabilize midpoint
              cam_target_x.val = cam_target_x.val + world_before.x - world_after.x
              cam_target_y.val = cam_target_y.val + world_before.y - world_after.y
            }
          }
          clamp_camera()
        }

        if active_gesture.val == gesture_pan {
          cam_target_x.val = pan_start_target_x.val - (pos.x - pan_start_x.val) / cam_zoom.val
          cam_target_y.val = pan_start_target_y.val - (pos.y - pan_start_y.val) / cam_zoom.val
          clamp_camera()
        }

        // Long press detection
        if active_gesture.val == tap_or_hold && not(long_press_triggered.val) && touch_timer.val >= 0.5 && gesture_move_dist.val < 15.0 {
          long_press_triggered.val = true
          gesture_decided.val = true
          let (wx, wy) = screen_to_board(touch_start_x.val, touch_start_y.val)
          let row = get_cell_row(wy)
          let col = get_cell_col(wx)
          if is_valid_cell(row, col, rows.val, cols.val) {
            toggle_flag(board.val, rows.val, cols.val, row, col, flag_count)
          }
        }
      }

      // Touch released
      if touch_count == 0 && active_gesture.val != touch_none {
        if active_gesture.val == tap_or_hold && not(long_press_triggered.val) && gesture_move_dist.val < 12.0 {
          // Tap detected — check restart button first
          let btn_size = hh * 0.7
          let btn_x = (sw - btn_size) / 2.0
          let btn_y = (hh - btn_size) / 2.0
          if touch_start_x.val >= btn_x && touch_start_x.val <= btn_x + btn_size && touch_start_y.val >= btn_y && touch_start_y.val <= btn_y + btn_size {
            game_state.val = state_menu
          } else {
            // Reveal cell
            let (wx, wy) = screen_to_board(touch_start_x.val, touch_start_y.val)
            let row = get_cell_row(wy)
            let col = get_cell_col(wx)
            if is_valid_cell(row, col, rows.val, cols.val) {
              if first_click.val {
                first_click.val = false
                place_mines(board.val, rows.val, cols.val, total_mines.val, row, col)
              }
              let hit_mine = reveal_cell(board.val, rows.val, cols.val, row, col, revealed_count)
              if hit_mine {
                game_state.val = state_lost
              } else if check_win() {
                game_state.val = state_won
              }
            }
          }
        }
        active_gesture.val = touch_none
        gesture_decided.val = false
        long_press_triggered.val = false
      }
    } else {
      // WON or LOST
      @raylib.set_gestures_enabled(@raylib.GestureTap)
      if @raylib.is_gesture_detected(@raylib.GestureTap) {
        game_state.val = state_menu
      }
    }

    // ---- DRAW ----
    @raylib.begin_drawing()
    @raylib.clear_background(@raylib.raywhite)

    if game_state.val == state_menu {
      // Draw menu
      let title = "MINESWEEPER"
      let mut title_size = (sh / 12.0).to_int()
      let mut title_width = @raylib.measure_text(title, title_size)
      let max_title_w = (sw * 0.9).to_int()
      if title_width > max_title_w {
        title_size = (Float::from_int(title_size) * (Float::from_int(max_title_w) / Float::from_int(title_width))).to_int()
        title_width = @raylib.measure_text(title, title_size)
      }
      @raylib.draw_text(
        title,
        (screen_width.val - title_width) / 2,
        (sh / 6.0).to_int(),
        title_size,
        @raylib.darkgray,
      )

      let btn_w = sw * 0.6
      let btn_h = sh * 0.07
      let btn_x = (sw - btn_w) / 2.0
      let start_y = sh * 0.35
      let spacing = btn_h * 1.5
      let font_size = (btn_h * 0.45).to_int()

      let labels = ["Easy (12x8)", "Medium (20x12)", "Hard (30x16)"]
      let btn_colors = [
        @raylib.green,
        @raylib.Color::new(255, 165, 0, 255),
        @raylib.red,
      ]

      for i = 0; i < 3; i = i + 1 {
        let y = start_y + spacing * Float::from_int(i)
        let rect = @raylib.Rectangle::new(btn_x, y, btn_w, btn_h)
        @raylib.draw_rectangle_rounded(rect, 0.3, 8, btn_colors[i])
        @raylib.draw_rectangle_rounded_lines(rect, 0.3, 8, @raylib.darkgray)
        let tw = @raylib.measure_text(labels[i], font_size)
        @raylib.draw_text(
          labels[i],
          (btn_x + (btn_w - Float::from_int(tw)) / 2.0).to_int(),
          (y + (btn_h - Float::from_int(font_size)) / 2.0).to_int(),
          font_size,
          @raylib.white,
        )
      }

      // About button
      let about_w = sw * 0.4
      let about_h = sh * 0.055
      let about_x = (sw - about_w) / 2.0
      let about_y = start_y + spacing * 3.0 + btn_h * 0.3
      let about_font = (about_h * 0.45).to_int()
      let about_rect = @raylib.Rectangle::new(about_x, about_y, about_w, about_h)
      @raylib.draw_rectangle_rounded(about_rect, 0.3, 8, @raylib.darkgray)
      @raylib.draw_rectangle_rounded_lines(about_rect, 0.3, 8, @raylib.darkgray)
      let about_label = "About"
      let about_tw = @raylib.measure_text(about_label, about_font)
      @raylib.draw_text(
        about_label,
        (about_x + (about_w - Float::from_int(about_tw)) / 2.0).to_int(),
        (about_y + (about_h - Float::from_int(about_font)) / 2.0).to_int(),
        about_font,
        @raylib.white,
      )
    } else if game_state.val == state_about {
      // About page
      let max_tw = (sw * 0.9).to_int()

      let title_text = "ABOUT"
      let mut title_size = (sh / 14.0).to_int()
      let mut title_tw = @raylib.measure_text(title_text, title_size)
      if title_tw > max_tw {
        title_size = (Float::from_int(title_size) * (Float::from_int(max_tw) / Float::from_int(title_tw))).to_int()
        title_tw = @raylib.measure_text(title_text, title_size)
      }
      @raylib.draw_text(
        title_text,
        (screen_width.val - title_tw) / 2,
        (sh * 0.12).to_int(),
        title_size,
        @raylib.darkgray,
      )

      let name_text = "Minesweeper"
      let mut name_size = (sh / 16.0).to_int()
      let mut name_tw = @raylib.measure_text(name_text, name_size)
      if name_tw > max_tw {
        name_size = (Float::from_int(name_size) * (Float::from_int(max_tw) / Float::from_int(name_tw))).to_int()
        name_tw = @raylib.measure_text(name_text, name_size)
      }
      @raylib.draw_text(
        name_text,
        (screen_width.val - name_tw) / 2,
        (sh * 0.30).to_int(),
        name_size,
        @raylib.black,
      )

      let ver_text = "Version 1.0"
      let mut info_size = (sh / 28.0).to_int()
      let mut ver_tw = @raylib.measure_text(ver_text, info_size)
      if ver_tw > max_tw {
        info_size = (Float::from_int(info_size) * (Float::from_int(max_tw) / Float::from_int(ver_tw))).to_int()
        ver_tw = @raylib.measure_text(ver_text, info_size)
      }
      @raylib.draw_text(
        ver_text,
        (screen_width.val - ver_tw) / 2,
        (sh * 0.40).to_int(),
        info_size,
        @raylib.gray,
      )

      let tech_text = "Built with MoonBit + Raylib"
      let mut tech_size = info_size
      let mut tech_tw = @raylib.measure_text(tech_text, tech_size)
      if tech_tw > max_tw {
        tech_size = (Float::from_int(tech_size) * (Float::from_int(max_tw) / Float::from_int(tech_tw))).to_int()
        tech_tw = @raylib.measure_text(tech_text, tech_size)
      }
      @raylib.draw_text(
        tech_text,
        (screen_width.val - tech_tw) / 2,
        (sh * 0.48).to_int(),
        tech_size,
        @raylib.gray,
      )

      // Back button
      let back_w = sw * 0.4
      let back_h = sh * 0.06
      let back_x = (sw - back_w) / 2.0
      let back_y = sh * 0.75
      let back_font = (back_h * 0.45).to_int()
      let back_rect = @raylib.Rectangle::new(back_x, back_y, back_w, back_h)
      @raylib.draw_rectangle_rounded(back_rect, 0.3, 8, @raylib.darkgray)
      @raylib.draw_rectangle_rounded_lines(back_rect, 0.3, 8, @raylib.darkgray)
      let back_label = "Back"
      let back_tw = @raylib.measure_text(back_label, back_font)
      @raylib.draw_text(
        back_label,
        (back_x + (back_w - Float::from_int(back_tw)) / 2.0).to_int(),
        (back_y + (back_h - Float::from_int(back_font)) / 2.0).to_int(),
        back_font,
        @raylib.white,
      )
    } else {
      // Draw board with camera
      let cam = make_camera()
      @raylib.begin_mode_2d(cam)

      for r = 0; r < rows.val; r = r + 1 {
        for c = 0; c < cols.val; c = c + 1 {
          let x = offset_x.val + Float::from_int(c) * cell_size.val
          let y = offset_y.val + Float::from_int(r) * cell_size.val
          let pad : Float = 1.0
          let rect = @raylib.Rectangle::new(
            x + pad,
            y + pad,
            cell_size.val - pad * 2.0,
            cell_size.val - pad * 2.0,
          )
          let idx = cell_index(r, c, cols.val)
          let cell = board.val[idx]

          if not(cell.is_revealed) {
            // Unrevealed — raised 3D look
            @raylib.draw_rectangle_rec(rect, @raylib.lightgray)
            // Top and left highlight
            @raylib.draw_line_ex(
              @raylib.Vector2::new(x + pad, y + pad),
              @raylib.Vector2::new(x + cell_size.val - pad, y + pad),
              2.0,
              @raylib.white,
            )
            @raylib.draw_line_ex(
              @raylib.Vector2::new(x + pad, y + pad),
              @raylib.Vector2::new(x + pad, y + cell_size.val - pad),
              2.0,
              @raylib.white,
            )
            // Bottom and right shadow
            @raylib.draw_line_ex(
              @raylib.Vector2::new(x + pad, y + cell_size.val - pad),
              @raylib.Vector2::new(x + cell_size.val - pad, y + cell_size.val - pad),
              2.0,
              @raylib.darkgray,
            )
            @raylib.draw_line_ex(
              @raylib.Vector2::new(x + cell_size.val - pad, y + pad),
              @raylib.Vector2::new(x + cell_size.val - pad, y + cell_size.val - pad),
              2.0,
              @raylib.darkgray,
            )

            if cell.is_flagged {
              // Red flag triangle
              let cx = x + cell_size.val / 2.0
              let cy = y + cell_size.val / 2.0
              let fs = cell_size.val * 0.3
              @raylib.draw_triangle(
                @raylib.Vector2::new(cx, cy - fs),
                @raylib.Vector2::new(cx - fs, cy),
                @raylib.Vector2::new(cx + fs, cy),
                @raylib.red,
              )
              // Flag pole
              @raylib.draw_line_ex(
                @raylib.Vector2::new(cx, cy - fs),
                @raylib.Vector2::new(cx, cy + fs),
                2.0,
                @raylib.black,
              )
            }
          } else if cell.has_mine {
            // Mine cell
            @raylib.draw_rectangle_rec(rect, @raylib.red)
            let cx = x + cell_size.val / 2.0
            let cy = y + cell_size.val / 2.0
            @raylib.draw_circle_v(
              @raylib.Vector2::new(cx, cy),
              cell_size.val * 0.25,
              @raylib.black,
            )
            // Spikes
            let sp = cell_size.val * 0.3
            @raylib.draw_line_ex(
              @raylib.Vector2::new(cx - sp, cy),
              @raylib.Vector2::new(cx + sp, cy),
              2.0,
              @raylib.black,
            )
            @raylib.draw_line_ex(
              @raylib.Vector2::new(cx, cy - sp),
              @raylib.Vector2::new(cx, cy + sp),
              2.0,
              @raylib.black,
            )
          } else {
            // Revealed safe cell
            @raylib.draw_rectangle_rec(rect, @raylib.Color::new(192, 192, 192, 255))
            @raylib.draw_rectangle_lines_ex(rect, 1.0, @raylib.Color::new(160, 160, 160, 255))

            if cell.neighbor_mines > 0 {
              let font_size = (cell_size.val * 0.6).to_int()
              let num_text = cell.neighbor_mines.to_string()
              let tw = @raylib.measure_text(num_text, font_size)
              @raylib.draw_text(
                num_text,
                (x + (cell_size.val - Float::from_int(tw)) / 2.0).to_int(),
                (y + (cell_size.val - Float::from_int(font_size)) / 2.0).to_int(),
                font_size,
                number_colors[cell.neighbor_mines],
              )
            }
          }
        }
      }

      @raylib.end_mode_2d()

      // Draw header
      @raylib.draw_rectangle(0, 0, screen_width.val, hh.to_int(), @raylib.lightgray)
      @raylib.draw_line(0, hh.to_int(), screen_width.val, hh.to_int(), @raylib.darkgray)

      let h_font_size = (hh * 0.45).to_int()

      // Mine counter (left)
      let mine_text = "\{total_mines.val - flag_count.val}"
      @raylib.draw_text(
        mine_text,
        (sw * 0.05).to_int(),
        ((hh - Float::from_int(h_font_size)) / 2.0).to_int(),
        h_font_size,
        @raylib.red,
      )

      // Restart button (center)
      let btn_size = hh * 0.7
      let btn_x = (sw - btn_size) / 2.0
      let btn_y = (hh - btn_size) / 2.0
      let btn_rect = @raylib.Rectangle::new(btn_x, btn_y, btn_size, btn_size)
      @raylib.draw_rectangle_rounded(btn_rect, 0.3, 8, @raylib.yellow)
      @raylib.draw_rectangle_rounded_lines(btn_rect, 0.3, 8, @raylib.darkgray)

      // Smiley face
      let cx = btn_x + btn_size / 2.0
      let cy = btn_y + btn_size / 2.0
      let face_r = btn_size * 0.3
      @raylib.draw_circle_v(
        @raylib.Vector2::new(cx, cy),
        face_r,
        @raylib.yellow,
      )
      // Eyes
      @raylib.draw_circle_v(
        @raylib.Vector2::new(cx - face_r * 0.35, cy - face_r * 0.2),
        face_r * 0.12,
        @raylib.black,
      )
      @raylib.draw_circle_v(
        @raylib.Vector2::new(cx + face_r * 0.35, cy - face_r * 0.2),
        face_r * 0.12,
        @raylib.black,
      )
      // Mouth
      if game_state.val == state_lost {
        @raylib.draw_line_ex(
          @raylib.Vector2::new(cx - face_r * 0.3, cy + face_r * 0.3),
          @raylib.Vector2::new(cx + face_r * 0.3, cy + face_r * 0.3),
          2.0,
          @raylib.black,
        )
      } else {
        @raylib.draw_circle_sector(
          @raylib.Vector2::new(cx, cy + face_r * 0.1),
          face_r * 0.35,
          0.0,
          180.0,
          16,
          @raylib.black,
        )
      }

      // Timer (right)
      let timer_text = "\{timer.val.to_int()}"
      let tw = @raylib.measure_text(timer_text, h_font_size)
      @raylib.draw_text(
        timer_text,
        (sw * 0.95 - Float::from_int(tw)).to_int(),
        ((hh - Float::from_int(h_font_size)) / 2.0).to_int(),
        h_font_size,
        @raylib.darkgray,
      )

      // Game over overlay
      if game_state.val != state_playing {
        @raylib.draw_rectangle(
          0,
          0,
          screen_width.val,
          screen_height.val,
          @raylib.Color::new(0, 0, 0, 128),
        )
        let msg = if game_state.val == state_won { "YOU WIN!" } else { "GAME OVER" }
        let msg_color = if game_state.val == state_won {
          @raylib.green
        } else {
          @raylib.red
        }
        let max_w = screen_width.val * 9 / 10
        let mut msg_size = (sh / 10.0).to_int()
        let mut msg_w = @raylib.measure_text(msg, msg_size)
        if msg_w > max_w {
          msg_size = (msg_size.to_double() * max_w.to_double() / msg_w.to_double()).to_int()
          msg_w = @raylib.measure_text(msg, msg_size)
        }
        @raylib.draw_text(
          msg,
          (screen_width.val - msg_w) / 2,
          (sh / 3.0).to_int(),
          msg_size,
          msg_color,
        )
        let sub_size = (sh / 20.0).to_int()
        let sub = "Tap to continue"
        let sub_w = @raylib.measure_text(sub, sub_size)
        @raylib.draw_text(
          sub,
          (screen_width.val - sub_w) / 2,
          (sh / 3.0).to_int() + msg_size + sub_size,
          sub_size,
          @raylib.white,
        )
      }
    }

    @raylib.end_drawing()
  }

  @raylib.close_window()
}
