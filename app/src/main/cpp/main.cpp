#include "raylib.h"
#include "Minesweeper.h"

extern "C" int main(void) {
    InitWindow(0, 0, "Minesweeper");
    SetTargetFPS(60);
    SetExitKey(0);

    Minesweeper game;
    while (!WindowShouldClose()) {
        game.Update();
        game.Draw();
    }
    CloseWindow();
    return 0;
}
