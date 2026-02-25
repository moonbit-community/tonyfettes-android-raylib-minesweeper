#ifndef MINESWEEPER_H
#define MINESWEEPER_H

#include "raylib.h"
#include "raymath.h"
#include <vector>

struct Cell {
    bool hasMine = false;
    bool isRevealed = false;
    bool isFlagged = false;
    int neighborMines = 0;
};

enum GameState {
    MENU,
    PLAYING,
    WON,
    LOST
};

enum ActiveGesture {
    TOUCH_NONE,
    TAP_OR_HOLD,
    GESTURE_PAN,
    GESTURE_PINCH
};

class Minesweeper {
public:
    Minesweeper();
    void Update();
    void Draw();

private:
    // Board
    std::vector<std::vector<Cell>> board;
    int rows = 0;
    int cols = 0;
    int totalMines = 0;
    int revealedCount = 0;
    int flagCount = 0;

    // Game state
    GameState state = MENU;
    bool firstClick = true;
    float timer = 0.0f;

    // Layout
    float cellSize = 0.0f;
    float offsetX = 0.0f;
    float offsetY = 0.0f;
    float headerHeight = 0.0f;
    int screenWidth = 0;
    int screenHeight = 0;

    // Touch / gesture state
    Vector2 touchStart = {0, 0};
    float touchTimer = 0.0f;
    bool longPressTriggered = false;

    // Camera
    Camera2D camera = {0};
    float minZoom = 1.0f;
    float maxZoom = 1.0f;

    // Pinch state
    float pinchStartDist = 0.0f;
    float pinchStartZoom = 0.0f;

    // Pan state
    Vector2 panStartPos = {0, 0};
    Vector2 panStartTarget = {0, 0};

    // Gesture disambiguation
    bool gestureDecided = false;
    ActiveGesture activeGesture = TOUCH_NONE;
    float gestureMoveDist = 0.0f;

    // Game logic
    void InitBoard(int r, int c, int mines);
    void PlaceMines(int safeRow, int safeCol);
    void CountNeighborMines();
    void RevealCell(int row, int col);
    void ToggleFlag(int row, int col);
    bool CheckWinCondition();
    void RevealAllMines();

    // Layout
    void CalculateLayout();
    void InitCamera();
    void ClampCamera();

    // Input
    void HandleMenuInput();
    void HandlePlayingInput();
    void HandleGameOverInput();
    void HandleCameraInput();

    // Rendering
    void DrawMenu();
    void DrawHeader();
    void DrawBoard();
    void DrawCell(int row, int col);
    void DrawGameOverOverlay();

    // Helpers
    int GetCellRow(float y);
    int GetCellCol(float x);
    bool IsValidCell(int row, int col);
    Vector2 ScreenToBoard(Vector2 screenPos);
};

#endif // MINESWEEPER_H
