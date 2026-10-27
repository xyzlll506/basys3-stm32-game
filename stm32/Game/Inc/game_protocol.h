#ifndef GAME_PROTOCOL_H
#define GAME_PROTOCOL_H

#include "game_engine.h"

#define GAME_REPLY_SIZE 12U
#define GAME_INTERBYTE_TIMEOUT_MS 20U

typedef struct
{
    GameEngine engine;
    uint8_t request[4];
    uint8_t reply[GAME_REPLY_SIZE];
    uint8_t received;
    uint8_t have_reply;
    uint8_t last_sequence;
    uint8_t last_buttons;
    uint32_t last_byte_ms;
    uint32_t valid_requests;
    uint32_t bad_requests;
} GameProtocol;

void GameProtocol_Init(GameProtocol *protocol);
void GameProtocol_ResetReceiver(GameProtocol *protocol);
/* Returns 1 only when a reply is ready, including a repeated request's cached reply. */
uint8_t GameProtocol_ReceiveByte(GameProtocol *protocol, uint8_t byte, uint32_t now_ms);

#endif
