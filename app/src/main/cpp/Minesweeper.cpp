#include "Minesweeper.h"
#include <cstdlib>
#include <ctime>
#include <cmath>
#include <queue>

static const Color NUMBER_COLORS[] = {
    BLANK,                          // 0 - not used
    BLUE,                           // 1
    DARKGREEN,                      // 2
    RED,                            // 3
    DARKBLUE,                       // 4
    MAROON,                         // 5
    {0, 128, 128, 255},             // 6 - Teal
    BLACK,                          // 7
    GRAY,                           // 8
};

Minesweeper::Minesweeper() {
    srand((unsigned int)time(nullptr));
    screenWidth = GetScreenWidth();
    screenHeight = GetScreenHeight();
    headerHeight = screenHeight * 0.08f;
    state = MENU;
}

void Minesweeper::Update() {
    int newWidth = GetScreenWidth();
    int newHeight = GetScreenHeight();
    if (newWidth != screenWidth || newHeight != screenHeight) {
        screenWidth = newWidth;
        screenHeight = newHeight;
        headerHeight = screenHeight * 0.08f;
        if (state == PLAYING || state == WON || state == LOST) {
            CalculateLayout();
            InitCamera();
        }
    }

    switch (state) {
        case MENU:
            SetGesturesEnabled(GESTURE_TAP);
            HandleMenuInput();
            break;
        case PLAYING:
            SetGesturesEnabled(0);
            timer += GetFrameTime();
            HandlePlayingInput();
            break;
        case WON:
        case LOST:
            SetGesturesEnabled(GESTURE_TAP);
            HandleGameOverInput();
            break;
    }
}

void Minesweeper::Draw() {
    BeginDrawing();
    ClearBackground(RAYWHITE);

    switch (state) {
        case MENU:
            DrawMenu();
            break;
        case PLAYING:
        case WON:
        case LOST:
            BeginMode2D(camera);
            DrawBoard();
            EndMode2D();
            DrawHeader();
            if (state != PLAYING) DrawGameOverOverlay();
            break;
    }

    EndDrawing();
}

// ---- Game Logic ----

void Minesweeper::InitBoard(int r, int c, int mines) {
    rows = r;
    cols = c;
    totalMines = mines;
    revealedCount = 0;
    flagCount = 0;
    firstClick = true;
    timer = 0.0f;
    state = PLAYING;

    board.assign(rows, std::vector<Cell>(cols));
    CalculateLayout();
    InitCamera();
}

void Minesweeper::PlaceMines(int safeRow, int safeCol) {
    int placed = 0;
    while (placed < totalMines) {
        int r = rand() % rows;
        int c = rand() % cols;
        // Exclude 3x3 area around first click
        if (abs(r - safeRow) <= 1 && abs(c - safeCol) <= 1) continue;
        if (board[r][c].hasMine) continue;
        board[r][c].hasMine = true;
        placed++;
    }
    CountNeighborMines();
}

void Minesweeper::CountNeighborMines() {
    for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
            if (board[r][c].hasMine) continue;
            int count = 0;
            for (int dr = -1; dr <= 1; dr++) {
                for (int dc = -1; dc <= 1; dc++) {
                    int nr = r + dr, nc = c + dc;
                    if (IsValidCell(nr, nc) && board[nr][nc].hasMine) count++;
                }
            }
            board[r][c].neighborMines = count;
        }
    }
}

void Minesweeper::RevealCell(int row, int col) {
    if (!IsValidCell(row, col)) return;
    Cell &cell = board[row][col];
    if (cell.isRevealed || cell.isFlagged) return;

    cell.isRevealed = true;
    revealedCount++;

    if (cell.hasMine) {
        RevealAllMines();
        state = LOST;
        return;
    }

    // BFS flood fill for zero-neighbor cells
    if (cell.neighborMines == 0) {
        std::queue<std::pair<int, int>> q;
        q.push({row, col});
        while (!q.empty()) {
            auto [cr, cc] = q.front();
            q.pop();
            for (int dr = -1; dr <= 1; dr++) {
                for (int dc = -1; dc <= 1; dc++) {
                    int nr = cr + dr, nc = cc + dc;
                    if (!IsValidCell(nr, nc)) continue;
                    Cell &neighbor = board[nr][nc];
                    if (neighbor.isRevealed || neighbor.isFlagged || neighbor.hasMine) continue;
                    neighbor.isRevealed = true;
                    revealedCount++;
                    if (neighbor.neighborMines == 0) {
                        q.push({nr, nc});
                    }
                }
            }
        }
    }

    if (CheckWinCondition()) {
        state = WON;
    }
}

void Minesweeper::ToggleFlag(int row, int col) {
    if (!IsValidCell(row, col)) return;
    Cell &cell = board[row][col];
    if (cell.isRevealed) return;

    cell.isFlagged = !cell.isFlagged;
    flagCount += cell.isFlagged ? 1 : -1;
}

bool Minesweeper::CheckWinCondition() {
    return revealedCount == (rows * cols - totalMines);
}

void Minesweeper::RevealAllMines() {
    for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
            if (board[r][c].hasMine) {
                board[r][c].isRevealed = true;
            }
        }
    }
}

// ---- Layout ----

void Minesweeper::CalculateLayout() {
    float availableWidth = (float)screenWidth;
    float availableHeight = (float)screenHeight - headerHeight;

    float cellW = availableWidth / cols;
    float cellH = availableHeight / rows;
    cellSize = (cellW < cellH) ? cellW : cellH;

    float boardWidth = cellSize * cols;
    float boardHeight = cellSize * rows;
    offsetX = (availableWidth - boardWidth) / 2.0f;
    offsetY = headerHeight + (availableHeight - boardHeight) / 2.0f;
}

void Minesweeper::InitCamera() {
    float availH = (float)screenHeight - headerHeight;
    camera.offset = { (float)screenWidth / 2.0f, headerHeight + availH / 2.0f };
    camera.target = { offsetX + cols * cellSize / 2.0f, offsetY + rows * cellSize / 2.0f };
    camera.rotation = 0.0f;
    camera.zoom = 1.0f;

    minZoom = 1.0f;
    maxZoom = fmaxf(90.0f / cellSize, minZoom);

    // Reset gesture state
    activeGesture = TOUCH_NONE;
    gestureDecided = false;
    longPressTriggered = false;
    gestureMoveDist = 0.0f;
}

void Minesweeper::ClampCamera() {
    float boardW = cols * cellSize;
    float boardH = rows * cellSize;
    float boardCenterX = offsetX + boardW / 2.0f;
    float boardCenterY = offsetY + boardH / 2.0f;

    float availH = (float)screenHeight - headerHeight;
    float visibleW = (float)screenWidth / camera.zoom;
    float visibleH = availH / camera.zoom;

    if (boardW > visibleW) {
        float minX = offsetX + visibleW / 2.0f;
        float maxX = offsetX + boardW - visibleW / 2.0f;
        camera.target.x = Clamp(camera.target.x, minX, maxX);
    } else {
        camera.target.x = boardCenterX;
    }

    if (boardH > visibleH) {
        float minY = offsetY + visibleH / 2.0f;
        float maxY = offsetY + boardH - visibleH / 2.0f;
        camera.target.y = Clamp(camera.target.y, minY, maxY);
    } else {
        camera.target.y = boardCenterY;
    }
}

// ---- Input ----

void Minesweeper::HandleMenuInput() {
    if (IsGestureDetected(GESTURE_TAP)) {
        Vector2 pos = GetTouchPosition(0);

        float btnWidth = screenWidth * 0.6f;
        float btnHeight = screenHeight * 0.07f;
        float btnX = (screenWidth - btnWidth) / 2.0f;
        float startY = screenHeight * 0.35f;
        float spacing = btnHeight * 1.5f;

        // Easy
        if (pos.x >= btnX && pos.x <= btnX + btnWidth &&
            pos.y >= startY && pos.y <= startY + btnHeight) {
            InitBoard(9, 9, 10);
        }
        // Medium
        float medY = startY + spacing;
        if (pos.x >= btnX && pos.x <= btnX + btnWidth &&
            pos.y >= medY && pos.y <= medY + btnHeight) {
            InitBoard(16, 16, 40);
        }
        // Hard
        float hardY = startY + spacing * 2;
        if (pos.x >= btnX && pos.x <= btnX + btnWidth &&
            pos.y >= hardY && pos.y <= hardY + btnHeight) {
            InitBoard(16, 30, 99);
        }
    }
}

void Minesweeper::HandlePlayingInput() {
    int touchCount = GetTouchPointCount();

    // Touch start
    if (touchCount > 0 && activeGesture == TOUCH_NONE) {
        touchStart = GetTouchPosition(0);
        touchTimer = 0.0f;
        longPressTriggered = false;
        gestureDecided = false;
        gestureMoveDist = 0.0f;
        activeGesture = TAP_OR_HOLD;

        if (touchCount >= 2) {
            activeGesture = GESTURE_PINCH;
            gestureDecided = true;
            pinchStartDist = Vector2Distance(GetTouchPosition(0), GetTouchPosition(1));
            pinchStartZoom = camera.zoom;
        }
    }

    // Touch held
    if (touchCount > 0 && activeGesture != TOUCH_NONE) {
        touchTimer += GetFrameTime();
        Vector2 pos = GetTouchPosition(0);
        gestureMoveDist = Vector2Distance(pos, touchStart);

        // Transition to pinch if second finger appears
        if (activeGesture != GESTURE_PINCH && touchCount >= 2) {
            activeGesture = GESTURE_PINCH;
            gestureDecided = true;
            pinchStartDist = Vector2Distance(GetTouchPosition(0), GetTouchPosition(1));
            pinchStartZoom = camera.zoom;
        }

        // Transition to pan if finger moved enough while zoomed in
        if (!gestureDecided && touchCount == 1 && gestureMoveDist > 12.0f
            && camera.zoom > minZoom + 0.01f) {
            activeGesture = GESTURE_PAN;
            gestureDecided = true;
            panStartPos = pos;
            panStartTarget = camera.target;
        }

        // Process camera gestures
        HandleCameraInput();

        // Long press detection
        if (activeGesture == TAP_OR_HOLD && !longPressTriggered
            && touchTimer >= 0.5f && gestureMoveDist < 15.0f) {
            longPressTriggered = true;
            gestureDecided = true;
            Vector2 worldPos = ScreenToBoard(touchStart);
            int row = GetCellRow(worldPos.y);
            int col = GetCellCol(worldPos.x);
            if (IsValidCell(row, col)) {
                ToggleFlag(row, col);
            }
        }
    }

    // Touch released
    if (touchCount == 0 && activeGesture != TOUCH_NONE) {
        if (activeGesture == TAP_OR_HOLD && !longPressTriggered && gestureMoveDist < 12.0f) {
            // Tap detected — check restart button first (screen coordinates)
            float btnSize = headerHeight * 0.7f;
            float btnX = ((float)screenWidth - btnSize) / 2.0f;
            float btnY = (headerHeight - btnSize) / 2.0f;
            if (touchStart.x >= btnX && touchStart.x <= btnX + btnSize
                && touchStart.y >= btnY && touchStart.y <= btnY + btnSize) {
                state = MENU;
            } else {
                // Reveal cell
                Vector2 worldPos = ScreenToBoard(touchStart);
                int row = GetCellRow(worldPos.y);
                int col = GetCellCol(worldPos.x);
                if (IsValidCell(row, col)) {
                    if (firstClick) {
                        firstClick = false;
                        PlaceMines(row, col);
                    }
                    RevealCell(row, col);
                }
            }
        }

        // Reset gesture state
        activeGesture = TOUCH_NONE;
        gestureDecided = false;
        longPressTriggered = false;
    }
}

void Minesweeper::HandleGameOverInput() {
    if (IsGestureDetected(GESTURE_TAP)) {
        state = MENU;
    }
}

void Minesweeper::HandleCameraInput() {
    if (activeGesture == GESTURE_PINCH) {
        int touchCount = GetTouchPointCount();
        if (touchCount >= 2) {
            Vector2 touch0 = GetTouchPosition(0);
            Vector2 touch1 = GetTouchPosition(1);
            float currentDist = Vector2Distance(touch0, touch1);

            if (pinchStartDist > 1.0f) {
                Vector2 midpoint = { (touch0.x + touch1.x) / 2.0f, (touch0.y + touch1.y) / 2.0f };

                // World position before zoom change
                Vector2 worldBefore = GetScreenToWorld2D(midpoint, camera);

                // Apply new zoom
                float newZoom = pinchStartZoom * (currentDist / pinchStartDist);
                camera.zoom = Clamp(newZoom, minZoom, maxZoom);

                // World position after zoom change
                Vector2 worldAfter = GetScreenToWorld2D(midpoint, camera);

                // Adjust target to keep pinch midpoint stable
                camera.target.x += worldBefore.x - worldAfter.x;
                camera.target.y += worldBefore.y - worldAfter.y;
            }
        }
        ClampCamera();
    }

    if (activeGesture == GESTURE_PAN) {
        Vector2 pos = GetTouchPosition(0);
        camera.target.x = panStartTarget.x - (pos.x - panStartPos.x) / camera.zoom;
        camera.target.y = panStartTarget.y - (pos.y - panStartPos.y) / camera.zoom;
        ClampCamera();
    }
}

// ---- Rendering ----

void Minesweeper::DrawMenu() {
    const char *title = "MINESWEEPER";
    int titleSize = screenHeight / 12;
    int titleWidth = MeasureText(title, titleSize);

    // Ensure title fits screen width with some padding
    float maxTitleWidth = screenWidth * 0.9f;
    if (titleWidth > maxTitleWidth) {
        titleSize = (int)(titleSize * (maxTitleWidth / titleWidth));
        titleWidth = MeasureText(title, titleSize);
    }

    DrawText(title, (screenWidth - titleWidth) / 2, screenHeight / 6, titleSize, DARKGRAY);

    float btnWidth = screenWidth * 0.6f;
    float btnHeight = screenHeight * 0.07f;
    float btnX = (screenWidth - btnWidth) / 2.0f;
    float startY = screenHeight * 0.35f;
    float spacing = btnHeight * 1.5f;
    int fontSize = (int)(btnHeight * 0.45f);

    struct { const char *label; } buttons[] = {
        {"Easy (9x9)"},
        {"Medium (16x16)"},
        {"Hard (16x30)"},
    };

    Color btnColors[] = {GREEN, {255, 165, 0, 255}, RED};

    for (int i = 0; i < 3; i++) {
        float y = startY + spacing * i;
        DrawRectangleRounded({btnX, y, btnWidth, btnHeight}, 0.3f, 8, btnColors[i]);
        DrawRectangleRoundedLines({btnX, y, btnWidth, btnHeight}, 0.3f, 8, DARKGRAY);
        int tw = MeasureText(buttons[i].label, fontSize);
        DrawText(buttons[i].label,
                 (int)(btnX + (btnWidth - tw) / 2),
                 (int)(y + (btnHeight - fontSize) / 2),
                 fontSize, WHITE);
    }
}

void Minesweeper::DrawHeader() {
    DrawRectangle(0, 0, screenWidth, (int)headerHeight, LIGHTGRAY);
    DrawLine(0, (int)headerHeight, screenWidth, (int)headerHeight, DARKGRAY);

    int fontSize = (int)(headerHeight * 0.45f);

    // Mine counter (left)
    const char *mineText = TextFormat("%d", totalMines - flagCount);
    DrawText(mineText, (int)(screenWidth * 0.05f),
             (int)((headerHeight - fontSize) / 2), fontSize, RED);

    // Restart button (center)
    float btnSize = headerHeight * 0.7f;
    float btnX = (screenWidth - btnSize) / 2.0f;
    float btnY = (headerHeight - btnSize) / 2.0f;
    DrawRectangleRounded({btnX, btnY, btnSize, btnSize}, 0.3f, 8, YELLOW);
    DrawRectangleRoundedLines({btnX, btnY, btnSize, btnSize}, 0.3f, 8, DARKGRAY);
    // Smiley face
    float cx = btnX + btnSize / 2;
    float cy = btnY + btnSize / 2;
    float r = btnSize * 0.3f;
    DrawCircleV({cx, cy}, r, YELLOW);
    DrawCircleV({cx - r * 0.35f, cy - r * 0.2f}, r * 0.12f, BLACK);
    DrawCircleV({cx + r * 0.35f, cy - r * 0.2f}, r * 0.12f, BLACK);
    if (state == LOST) {
        DrawLineEx({cx - r * 0.3f, cy + r * 0.3f}, {cx + r * 0.3f, cy + r * 0.3f}, 2.0f, BLACK);
    } else {
        DrawCircleSector({cx, cy + r * 0.1f}, r * 0.35f, 0, 180, 16, BLACK);
    }

    // Timer (right)
    const char *timerText = TextFormat("%d", (int)timer);
    int tw = MeasureText(timerText, fontSize);
    DrawText(timerText, (int)(screenWidth * 0.95f - tw),
             (int)((headerHeight - fontSize) / 2), fontSize, DARKGRAY);
}

void Minesweeper::DrawBoard() {
    for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
            DrawCell(r, c);
        }
    }
}

void Minesweeper::DrawCell(int row, int col) {
    float x = offsetX + col * cellSize;
    float y = offsetY + row * cellSize;
    float pad = 1.0f;
    Rectangle rect = {x + pad, y + pad, cellSize - pad * 2, cellSize - pad * 2};

    const Cell &cell = board[row][col];

    if (!cell.isRevealed) {
        // Unrevealed cell — raised 3D look
        DrawRectangleRec(rect, LIGHTGRAY);
        // Top and left highlight
        DrawLineEx({x + pad, y + pad}, {x + cellSize - pad, y + pad}, 2.0f, WHITE);
        DrawLineEx({x + pad, y + pad}, {x + pad, y + cellSize - pad}, 2.0f, WHITE);
        // Bottom and right shadow
        DrawLineEx({x + pad, y + cellSize - pad}, {x + cellSize - pad, y + cellSize - pad}, 2.0f, DARKGRAY);
        DrawLineEx({x + cellSize - pad, y + pad}, {x + cellSize - pad, y + cellSize - pad}, 2.0f, DARKGRAY);

        if (cell.isFlagged) {
            // Red flag triangle
            float cx = x + cellSize / 2;
            float cy = y + cellSize / 2;
            float fs = cellSize * 0.3f;
            DrawTriangle(
                {cx, cy - fs},
                {cx - fs, cy},
                {cx + fs, cy},
                RED
            );
            // Flag pole
            DrawLineEx({cx, cy - fs}, {cx, cy + fs}, 2.0f, BLACK);
        }
    } else if (cell.hasMine) {
        // Mine cell
        DrawRectangleRec(rect, RED);
        float cx = x + cellSize / 2;
        float cy = y + cellSize / 2;
        DrawCircleV({cx, cy}, cellSize * 0.25f, BLACK);
        // Spikes
        float sp = cellSize * 0.3f;
        DrawLineEx({cx - sp, cy}, {cx + sp, cy}, 2.0f, BLACK);
        DrawLineEx({cx, cy - sp}, {cx, cy + sp}, 2.0f, BLACK);
    } else {
        // Revealed safe cell
        DrawRectangleRec(rect, {192, 192, 192, 255});
        DrawRectangleLinesEx(rect, 1.0f, {160, 160, 160, 255});

        if (cell.neighborMines > 0) {
            int fontSize = (int)(cellSize * 0.6f);
            const char *numText = TextFormat("%d", cell.neighborMines);
            int tw = MeasureText(numText, fontSize);
            Color col = NUMBER_COLORS[cell.neighborMines];
            DrawText(numText,
                     (int)(x + (cellSize - tw) / 2),
                     (int)(y + (cellSize - fontSize) / 2),
                     fontSize, col);
        }
    }
}

void Minesweeper::DrawGameOverOverlay() {
    // Semi-transparent overlay
    DrawRectangle(0, 0, screenWidth, screenHeight, {0, 0, 0, 128});

    int fontSize = screenHeight / 10;
    const char *msg = (state == WON) ? "YOU WIN!" : "GAME OVER";
    Color msgColor = (state == WON) ? GREEN : RED;
    int tw = MeasureText(msg, fontSize);
    DrawText(msg, (screenWidth - tw) / 2, screenHeight / 3, fontSize, msgColor);

    int subSize = screenHeight / 20;
    const char *sub = "Tap to continue";
    int stw = MeasureText(sub, subSize);
    DrawText(sub, (screenWidth - stw) / 2, screenHeight / 3 + fontSize + subSize, subSize, WHITE);
}

// ---- Helpers ----

int Minesweeper::GetCellRow(float y) {
    return (int)((y - offsetY) / cellSize);
}

int Minesweeper::GetCellCol(float x) {
    return (int)((x - offsetX) / cellSize);
}

bool Minesweeper::IsValidCell(int row, int col) {
    return row >= 0 && row < rows && col >= 0 && col < cols;
}

Vector2 Minesweeper::ScreenToBoard(Vector2 screenPos) {
    return GetScreenToWorld2D(screenPos, camera);
}
