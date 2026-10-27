#include "game_engine.h"
#include "game_protocol.h"
#include "level.h"
#include <stdio.h>
#include <string.h>

#define Q8 256L
static unsigned failures;
#define CHECK(condition) do { if (!(condition)) { \
    (void)fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #condition); ++failures; \
} } while (0)

static void Tick(GameEngine *game, uint8_t buttons, unsigned frames)
{
    unsigned i;
    for (i = 0; i < frames; ++i) GameEngine_Step(game, buttons);
}

static void TestPhysics(void)
{
    GameEngine game;
    GameEngine control;
    GameSnapshot snapshot;
    int32_t x_before;
    unsigned i;
    GameEngine_Init(&game);
    GameEngine_Snapshot(&game, &snapshot);
    CHECK(snapshot.x == LEVEL_SPAWN_X && snapshot.y == LEVEL_SPAWN_Y);
    CHECK(snapshot.flags == GAME_FLAG_GROUNDED && snapshot.deaths == 0U);
    Tick(&game, GAME_BUTTON_RIGHT, 10);
    CHECK(game.x_q8 == (LEVEL_SPAWN_X + 30L) * Q8);
    x_before = game.x_q8;
    Tick(&game, GAME_BUTTON_LEFT | GAME_BUTTON_RIGHT, 10);
    CHECK(game.x_q8 == x_before);

    GameEngine_Init(&game);
    Tick(&game, GAME_BUTTON_JUMP, 120);
    CHECK(game.grounded && game.y_q8 == LEVEL_SPAWN_Y * Q8);
    GameEngine_Step(&game, GAME_BUTTON_JUMP);
    CHECK(game.grounded); /* Holding jump does not auto-bounce. */
    GameEngine_Step(&game, 0);
    GameEngine_Step(&game, GAME_BUTTON_JUMP);
    CHECK(!game.grounded && game.vy_q8 < 0);
    control = game;
    GameEngine_Step(&game, 0);
    GameEngine_Step(&control, 0);
    GameEngine_Step(&game, GAME_BUTTON_JUMP);
    GameEngine_Step(&control, 0);
    CHECK(game.y_q8 == control.y_q8 && game.vy_q8 == control.vy_q8);

    GameEngine_Init(&game);
    Tick(&game, GAME_BUTTON_LEFT, 100);
    CHECK(game.x_q8 == 0);
    game.x_q8 = (LEVEL_WORLD_W - LEVEL_PLAYER_W - 1L) * Q8;
    GameEngine_Step(&game, GAME_BUTTON_RIGHT);
    CHECK(game.x_q8 == (LEVEL_WORLD_W - LEVEL_PLAYER_W) * Q8);

    GameEngine_Init(&game);
    game.x_q8 = 130L * Q8;
    game.y_q8 = 300L * Q8;
    game.vy_q8 = 3L * Q8;
    game.grounded = 0;
    for (i = 0; i < 40 && !game.grounded; ++i) GameEngine_Step(&game, 0);
    CHECK(game.grounded && game.y_q8 == (365L - LEVEL_PLAYER_H) * Q8);

    game.x_q8 = 130L * Q8;
    game.y_q8 = 390L * Q8;
    game.vy_q8 = -10L * Q8;
    game.grounded = 0;
    GameEngine_Step(&game, 0);
    CHECK(game.y_q8 == 381L * Q8 && game.vy_q8 == 0 && !game.grounded);

    game.x_q8 = 80L * Q8;
    game.y_q8 = 350L * Q8;
    game.vy_q8 = 0;
    Tick(&game, GAME_BUTTON_RIGHT, 3);
    CHECK(game.x_q8 == (100L - LEVEL_PLAYER_W) * Q8);

    GameEngine_Init(&game);
    game.x_q8 = 225L * Q8;
    GameEngine_Step(&game, GAME_BUTTON_RIGHT);
    CHECK(game.deaths == 1 && game.respawned);
    CHECK(game.x_q8 == LEVEL_SPAWN_X * Q8 && game.y_q8 == LEVEL_SPAWN_Y * Q8);
    GameEngine_Step(&game, 0);
    CHECK(!game.respawned && game.deaths == 1);
    game.x_q8 = 225L * Q8;
    game.deaths = 65535U;
    GameEngine_Step(&game, GAME_BUTTON_RIGHT);
    CHECK(game.deaths == 65535U);
    GameEngine_Step(&game, GAME_BUTTON_RESTART);
    CHECK(game.deaths == 0 && game.x_q8 == LEVEL_SPAWN_X * Q8);

    game.x_q8 = 580L * Q8;
    game.y_q8 = 121L * Q8;
    game.grounded = 1;
    GameEngine_Step(&game, 0);
    CHECK(game.won);
    x_before = game.x_q8;
    Tick(&game, GAME_BUTTON_RIGHT | GAME_BUTTON_JUMP, 10);
    CHECK(game.x_q8 == x_before && game.won);
    GameEngine_Step(&game, GAME_BUTTON_RESTART);
    CHECK(!game.won && game.deaths == 0 && game.grounded);

    game.y_q8 = LEVEL_WORLD_H * Q8;
    GameEngine_Step(&game, 0);
    CHECK(game.respawned && game.deaths == 1);
    game.y_q8 = Q8;
    game.vy_q8 = -10L * Q8;
    GameEngine_Step(&game, 0);
    CHECK(game.y_q8 == 0 && game.vy_q8 == 0);
    (void)puts("Checked: movement, jump edges, no double jump, bounds, solid collisions, death/restart/win");
}

static unsigned route_frames;
static void RouteTick(GameEngine *game, uint8_t buttons)
{
    GameEngine_Step(game, buttons);
    ++route_frames;
    CHECK(game->deaths == 0);
}

static void WalkTo(GameEngine *game, unsigned x)
{
    unsigned i;
    for (i = 0; i < 220 && game->x_q8 < (int32_t)x * Q8 && !game->won; ++i)
        RouteTick(game, GAME_BUTTON_RIGHT);
    CHECK(game->won || game->x_q8 >= (int32_t)x * Q8);
}

static void JumpToPlatform(GameEngine *game, unsigned stop_x, unsigned expected_y)
{
    unsigned i;
    RouteTick(game, GAME_BUTTON_RIGHT | GAME_BUTTON_JUMP);
    CHECK(!game->grounded);
    for (i = 0; i < 100 && !game->grounded && !game->won; ++i)
        RouteTick(game, game->x_q8 < (int32_t)stop_x * Q8 ? GAME_BUTTON_RIGHT : 0U);
    CHECK(game->grounded && game->y_q8 == (int32_t)expected_y * Q8);
    RouteTick(game, 0); /* Release jump before the next rising edge. */
}

static void TestPlayableRoute(void)
{
    GameEngine game;
    GameEngine_Init(&game);
    route_frames = 0;
    /* This entire route starts from Init and changes only input buttons.
       Jump before entering the overhang to avoid hitting solid undersides. */
    JumpToPlatform(&game, 130, 365U - LEVEL_PLAYER_H);
    WalkTo(&game, 190);
    JumpToPlatform(&game, 290, 290U - LEVEL_PLAYER_H);
    WalkTo(&game, 350);
    JumpToPlatform(&game, 450, 215U - LEVEL_PLAYER_H);
    WalkTo(&game, 460);
    JumpToPlatform(&game, 560, 145U - LEVEL_PLAYER_H);
    WalkTo(&game, 585);
    CHECK(game.won && game.deaths == 0);
    (void)printf("Checked: complete input-only level route, %u frames, zero deaths\n", route_frames);
}

static uint8_t Request(GameProtocol *protocol, uint8_t sequence, uint8_t buttons, uint32_t now)
{
    uint8_t reply;
    CHECK(!GameProtocol_ReceiveByte(protocol, 0xA5U, now));
    CHECK(!GameProtocol_ReceiveByte(protocol, sequence, now));
    CHECK(!GameProtocol_ReceiveByte(protocol, buttons, now));
    reply = GameProtocol_ReceiveByte(protocol, (uint8_t)(0xA5U ^ sequence ^ buttons), now);
    return reply;
}

static void CheckReply(const GameProtocol *protocol, uint8_t sequence)
{
    unsigned i;
    uint8_t checksum = 0;
    for (i = 0; i < GAME_REPLY_SIZE; ++i) checksum ^= protocol->reply[i];
    CHECK(protocol->reply[0] == 0x5AU && protocol->reply[1] == sequence);
    CHECK(protocol->reply[9] == 0 && protocol->reply[10] == 0 && checksum == 0);
    CHECK(((unsigned)protocol->reply[2] | ((unsigned)protocol->reply[3] << 8)) ==
          (unsigned)(protocol->engine.x_q8 / Q8));
}

static void TestProtocol(void)
{
    GameProtocol protocol;
    uint8_t cached[GAME_REPLY_SIZE];
    int32_t old_x;
    uint32_t count;
    unsigned i;
    GameProtocol_Init(&protocol);
    CHECK(Request(&protocol, 0xA5U, GAME_BUTTON_RIGHT, 1));
    CheckReply(&protocol, 0xA5U);
    old_x = protocol.engine.x_q8;
    (void)memcpy(cached, protocol.reply, sizeof cached);
    CHECK(Request(&protocol, 0xA5U, GAME_BUTTON_RIGHT, 17));
    CHECK(protocol.engine.x_q8 == old_x && memcmp(cached, protocol.reply, sizeof cached) == 0);
    CHECK(!Request(&protocol, 0xA5U, GAME_BUTTON_LEFT, 34));
    CHECK(protocol.engine.x_q8 == old_x);
    CHECK(Request(&protocol, 0x5AU, GAME_BUTTON_LEFT, 50));
    CheckReply(&protocol, 0x5AU);
    CHECK(protocol.engine.x_q8 == old_x - 3L * Q8);

    old_x = protocol.engine.x_q8;
    CHECK(!Request(&protocol, 0x10U, 0x80U, 66)); /* Reserved button bits. */
    CHECK(protocol.engine.x_q8 == old_x);
    CHECK(!GameProtocol_ReceiveByte(&protocol, 0xA5U, 80));
    CHECK(!GameProtocol_ReceiveByte(&protocol, 0x11U, 80));
    CHECK(!GameProtocol_ReceiveByte(&protocol, GAME_BUTTON_RIGHT, 80));
    CHECK(!GameProtocol_ReceiveByte(&protocol, 0U, 80)); /* Bad XOR. */
    CHECK(protocol.engine.x_q8 == old_x);
    CHECK(Request(&protocol, 0x12U, GAME_BUTTON_RIGHT, 97));

    CHECK(!GameProtocol_ReceiveByte(&protocol, 0xA5U, 100));
    CHECK(!GameProtocol_ReceiveByte(&protocol, 0x13U, 100));
    CHECK(Request(&protocol, 0x14U, 0U, 121)); /* New header after partial timeout. */
    CHECK(!GameProtocol_ReceiveByte(&protocol, 0xA5U, 0xFFFFFFF8UL));
    CHECK(!GameProtocol_ReceiveByte(&protocol, 0x20U, 0xFFFFFFF9UL));
    CHECK(Request(&protocol, 0x21U, 0U, 20)); /* Tick wrap must not prevent timeout. */
    CHECK(Request(&protocol, 0U, 0U, 40)); /* FPGA reset sequence. */
    CHECK(Request(&protocol, 1U, GAME_BUTTON_RIGHT, 57));
    for (i = 2; i < 260; ++i) CHECK(Request(&protocol, (uint8_t)i, 0U, 60U + i));
    CheckReply(&protocol, 3U);
    count = protocol.valid_requests;
    old_x = protocol.engine.x_q8;
    GameProtocol_ResetReceiver(&protocol);
    CHECK(!GameProtocol_ReceiveByte(&protocol, 0x12U, 1000));
    CHECK(protocol.valid_requests == count && protocol.engine.x_q8 == old_x);
    CHECK(protocol.bad_requests == 3U);
    (void)puts("Checked: wire encoding, A5/5A sequences, XOR/bit validation, duplicate suppression, timeout, wrap/reset recovery");
}

int main(void)
{
    TestPhysics();
    TestPlayableRoute();
    TestProtocol();
    if (failures != 0U)
    {
        (void)fprintf(stderr, "%u game test checks failed\n", failures);
        return 1;
    }
    (void)puts("PASS: game engine, playable route and game protocol");
    return 0;
}
