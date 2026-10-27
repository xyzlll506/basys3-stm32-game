#include "game_protocol.h"
#include <string.h>

static void EncodeReply(GameProtocol *protocol, uint8_t sequence)
{
    GameSnapshot snapshot;
    unsigned i;
    uint8_t checksum = 0U;
    GameEngine_Snapshot(&protocol->engine, &snapshot);
    protocol->reply[0] = 0x5AU;
    protocol->reply[1] = sequence;
    protocol->reply[2] = (uint8_t)snapshot.x;
    protocol->reply[3] = (uint8_t)(snapshot.x >> 8);
    protocol->reply[4] = (uint8_t)snapshot.y;
    protocol->reply[5] = (uint8_t)(snapshot.y >> 8);
    protocol->reply[6] = snapshot.flags;
    protocol->reply[7] = (uint8_t)snapshot.deaths;
    protocol->reply[8] = (uint8_t)(snapshot.deaths >> 8);
    protocol->reply[9] = 0U;
    protocol->reply[10] = 0U;
    for (i = 0; i < GAME_REPLY_SIZE - 1U; ++i) checksum ^= protocol->reply[i];
    protocol->reply[11] = checksum;
}

void GameProtocol_Init(GameProtocol *protocol)
{
    (void)memset(protocol, 0, sizeof *protocol);
    GameEngine_Init(&protocol->engine);
}

void GameProtocol_ResetReceiver(GameProtocol *protocol)
{
    protocol->received = 0U;
}

uint8_t GameProtocol_ReceiveByte(GameProtocol *protocol, uint8_t byte, uint32_t now_ms)
{
    uint8_t sequence;
    uint8_t buttons;
    if (protocol->received != 0U &&
        (uint32_t)(now_ms - protocol->last_byte_ms) >= GAME_INTERBYTE_TIMEOUT_MS)
        protocol->received = 0U;
    protocol->last_byte_ms = now_ms;
    if (protocol->received == 0U)
    {
        if (byte == 0xA5U)
        {
            protocol->request[0] = byte;
            protocol->received = 1U;
        }
        return 0U;
    }
    protocol->request[protocol->received++] = byte;
    if (protocol->received != 4U) return 0U;
    protocol->received = 0U;
    sequence = protocol->request[1];
    buttons = protocol->request[2];
    if (byte != (uint8_t)(0xA5U ^ sequence ^ buttons) || (buttons & 0xF0U) != 0U)
    {
        ++protocol->bad_requests;
        if (byte == 0xA5U)
        {
            protocol->request[0] = byte;
            protocol->received = 1U;
        }
        return 0U;
    }
    if (protocol->have_reply != 0U && sequence == protocol->last_sequence)
    {
        /* Same sequence with different data is malformed, not another physics tick. */
        if (buttons != protocol->last_buttons)
        {
            ++protocol->bad_requests;
            return 0U;
        }
    }
    else
    {
        GameEngine_Step(&protocol->engine, buttons);
        EncodeReply(protocol, sequence);
        protocol->last_sequence = sequence;
        protocol->last_buttons = buttons;
        protocol->have_reply = 1U;
    }
    ++protocol->valid_requests;
    return 1U;
}
