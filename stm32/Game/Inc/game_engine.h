#ifndef GAME_ENGINE_H
#define GAME_ENGINE_H

#include <stdint.h>

#define GAME_BUTTON_LEFT    0x01U
#define GAME_BUTTON_RIGHT   0x02U
#define GAME_BUTTON_JUMP    0x04U
#define GAME_BUTTON_RESTART 0x08U

#define GAME_FLAG_GROUNDED  0x01U
#define GAME_FLAG_WON       0x02U
#define GAME_FLAG_RESPAWNED 0x04U

/* All physics values use signed Q8 pixels. One Step is one accepted input frame. */
typedef struct
{
    int32_t x_q8;
    int32_t y_q8;
    int32_t vy_q8;
    uint16_t deaths;
    uint8_t grounded;
    uint8_t won;
    uint8_t respawned;
    uint8_t previous_buttons;
} GameEngine;

typedef struct
{
    uint16_t x;
    uint16_t y;
    uint16_t deaths;
    uint8_t flags;
} GameSnapshot;

void GameEngine_Init(GameEngine *game);
void GameEngine_Step(GameEngine *game, uint8_t buttons);
void GameEngine_Snapshot(const GameEngine *game, GameSnapshot *snapshot);

#endif
