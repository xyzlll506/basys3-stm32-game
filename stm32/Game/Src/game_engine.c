#include "game_engine.h"
#include "level.h"

#define Q8 256L
#define PLAYER_WIDTH_Q8  ((int32_t)LEVEL_PLAYER_W * Q8)
#define PLAYER_HEIGHT_Q8 ((int32_t)LEVEL_PLAYER_H * Q8)
#define WALK_SPEED_Q8    (3L * Q8)
#define JUMP_SPEED_Q8    (-10L * Q8)
#define GRAVITY_Q8       (Q8 / 2L)
#define MAX_FALL_Q8      (12L * Q8)

typedef struct { int16_t x, y, w, h; } GameRect;
static const GameRect platforms[LEVEL_PLATFORM_COUNT] = LEVEL_PLATFORMS;
static const GameRect hazards[LEVEL_HAZARD_COUNT] = LEVEL_HAZARDS;

static uint8_t Overlaps(const GameEngine *game, const GameRect *rect)
{
    return (uint8_t)(game->x_q8 < ((int32_t)rect->x + rect->w) * Q8 &&
        game->x_q8 + PLAYER_WIDTH_Q8 > (int32_t)rect->x * Q8 &&
        game->y_q8 < ((int32_t)rect->y + rect->h) * Q8 &&
        game->y_q8 + PLAYER_HEIGHT_Q8 > (int32_t)rect->y * Q8);
}

static uint8_t OnSupport(const GameEngine *game)
{
    unsigned i;
    for (i = 0; i < LEVEL_PLATFORM_COUNT; ++i)
    {
        const GameRect *rect = &platforms[i];
        if (game->y_q8 + PLAYER_HEIGHT_Q8 == (int32_t)rect->y * Q8 &&
            game->x_q8 < ((int32_t)rect->x + rect->w) * Q8 &&
            game->x_q8 + PLAYER_WIDTH_Q8 > (int32_t)rect->x * Q8)
            return 1U;
    }
    return 0U;
}

static void Spawn(GameEngine *game)
{
    game->x_q8 = (int32_t)LEVEL_SPAWN_X * Q8;
    game->y_q8 = (int32_t)LEVEL_SPAWN_Y * Q8;
    game->vy_q8 = 0;
    game->grounded = OnSupport(game);
    game->won = 0U;
}

void GameEngine_Init(GameEngine *game)
{
    game->deaths = 0U;
    game->respawned = 0U;
    game->previous_buttons = 0U;
    Spawn(game);
}

static void MoveHorizontal(GameEngine *game, int32_t movement)
{
    int32_t old_x = game->x_q8;
    int32_t new_x = old_x + movement;
    unsigned i;
    for (i = 0; i < LEVEL_PLATFORM_COUNT; ++i)
    {
        const GameRect *rect = &platforms[i];
        int32_t left = (int32_t)rect->x * Q8;
        int32_t right = ((int32_t)rect->x + rect->w) * Q8;
        if (game->y_q8 >= ((int32_t)rect->y + rect->h) * Q8 ||
            game->y_q8 + PLAYER_HEIGHT_Q8 <= (int32_t)rect->y * Q8)
            continue;
        if (movement > 0 && old_x + PLAYER_WIDTH_Q8 <= left &&
            new_x + PLAYER_WIDTH_Q8 > left)
            new_x = left - PLAYER_WIDTH_Q8;
        else if (movement < 0 && old_x >= right && new_x < right)
            new_x = right;
    }
    if (new_x < 0) new_x = 0;
    if (new_x > ((int32_t)LEVEL_WORLD_W - LEVEL_PLAYER_W) * Q8)
        new_x = ((int32_t)LEVEL_WORLD_W - LEVEL_PLAYER_W) * Q8;
    game->x_q8 = new_x;
}

static void MoveVertical(GameEngine *game)
{
    int32_t old_y = game->y_q8;
    int32_t new_y;
    int32_t movement;
    unsigned i;
    game->vy_q8 += GRAVITY_Q8;
    if (game->vy_q8 > MAX_FALL_Q8) game->vy_q8 = MAX_FALL_Q8;
    movement = game->vy_q8;
    new_y = old_y + movement;
    game->grounded = 0U;
    for (i = 0; i < LEVEL_PLATFORM_COUNT; ++i)
    {
        const GameRect *rect = &platforms[i];
        int32_t top = (int32_t)rect->y * Q8;
        int32_t bottom = ((int32_t)rect->y + rect->h) * Q8;
        if (game->x_q8 >= ((int32_t)rect->x + rect->w) * Q8 ||
            game->x_q8 + PLAYER_WIDTH_Q8 <= (int32_t)rect->x * Q8)
            continue;
        if (movement >= 0 && old_y + PLAYER_HEIGHT_Q8 <= top &&
            new_y + PLAYER_HEIGHT_Q8 >= top)
        {
            new_y = top - PLAYER_HEIGHT_Q8;
            game->vy_q8 = 0;
            game->grounded = 1U;
        }
        else if (movement < 0 && old_y >= bottom && new_y <= bottom)
        {
            new_y = bottom;
            game->vy_q8 = 0;
        }
    }
    if (new_y < 0)
    {
        new_y = 0;
        game->vy_q8 = 0;
    }
    game->y_q8 = new_y;
}

void GameEngine_Step(GameEngine *game, uint8_t buttons)
{
    uint8_t pressed = (uint8_t)(buttons & (uint8_t)~game->previous_buttons);
    int32_t movement = 0;
    unsigned i;
    const GameRect goal = { LEVEL_GOAL_X, LEVEL_GOAL_Y, LEVEL_GOAL_W, LEVEL_GOAL_H };
    buttons &= 0x0FU;
    game->previous_buttons = buttons;
    game->respawned = 0U;
    if ((pressed & GAME_BUTTON_RESTART) != 0U)
    {
        GameEngine_Init(game);
        game->previous_buttons = buttons;
        return;
    }
    if (game->won != 0U) return;
    if ((buttons & (GAME_BUTTON_LEFT | GAME_BUTTON_RIGHT)) == GAME_BUTTON_LEFT)
        movement = -WALK_SPEED_Q8;
    else if ((buttons & (GAME_BUTTON_LEFT | GAME_BUTTON_RIGHT)) == GAME_BUTTON_RIGHT)
        movement = WALK_SPEED_Q8;
    if ((pressed & GAME_BUTTON_JUMP) != 0U && game->grounded != 0U)
    {
        game->vy_q8 = JUMP_SPEED_Q8;
        game->grounded = 0U;
    }
    MoveHorizontal(game, movement);
    MoveVertical(game);
    for (i = 0; i < LEVEL_HAZARD_COUNT; ++i)
    {
        if (Overlaps(game, &hazards[i]) != 0U)
        {
            if (game->deaths != 0xFFFFU) ++game->deaths;
            Spawn(game);
            game->respawned = 1U;
            return;
        }
    }
    if (game->y_q8 >= (int32_t)LEVEL_WORLD_H * Q8)
    {
        if (game->deaths != 0xFFFFU) ++game->deaths;
        Spawn(game);
        game->respawned = 1U;
        return;
    }
    if (Overlaps(game, &goal) != 0U)
    {
        game->won = 1U;
        game->vy_q8 = 0;
    }
}

void GameEngine_Snapshot(const GameEngine *game, GameSnapshot *snapshot)
{
    snapshot->x = (uint16_t)(game->x_q8 / Q8);
    snapshot->y = (uint16_t)(game->y_q8 / Q8);
    snapshot->deaths = game->deaths;
    snapshot->flags = (uint8_t)((game->grounded ? GAME_FLAG_GROUNDED : 0U) |
        (game->won ? GAME_FLAG_WON : 0U) |
        (game->respawned ? GAME_FLAG_RESPAWNED : 0U));
}
