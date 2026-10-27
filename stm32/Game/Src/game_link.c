#include "game_link.h"
#include "game_protocol.h"
#include "main.h"
#include "usart.h"
#include <stdio.h>
#include <string.h>

static GameProtocol protocol;
static uint32_t last_request_ms;
static uint32_t last_heartbeat_ms;
static uint32_t last_log_ms;
static uint8_t have_request;

static void LogText(const char *text)
{
    (void)HAL_UART_Transmit(&huart3, (uint8_t *)text, (uint16_t)strlen(text), 20U);
}

void GameLink_Init(void)
{
    GameProtocol_Init(&protocol);
    last_request_ms = HAL_GetTick();
    last_heartbeat_ms = last_request_ms;
    last_log_ms = last_request_ms;
    have_request = 0U;
    HAL_GPIO_WritePin(GPIOB, GPIO_PIN_14, GPIO_PIN_SET);
    LogText("\r\nNUCLEO-F413ZH VGA game; USART6=115200 8N1\r\n");
    LogText("Use matching game BIT; waiting for FPGA input frames.\r\n");
}

void GameLink_Task(void)
{
    uint8_t byte;
    uint32_t now = HAL_GetTick();
    HAL_StatusTypeDef status;
    if ((uint32_t)(now - last_heartbeat_ms) >= 500U)
    {
        last_heartbeat_ms = now;
        HAL_GPIO_TogglePin(GPIOB, GPIO_PIN_7);
    }
    /* Clear receive errors explicitly; never interpret an errored partial frame. */
    if (__HAL_UART_GET_FLAG(&huart6, UART_FLAG_ORE) != RESET ||
        __HAL_UART_GET_FLAG(&huart6, UART_FLAG_FE) != RESET ||
        __HAL_UART_GET_FLAG(&huart6, UART_FLAG_NE) != RESET)
    {
        __HAL_UART_CLEAR_OREFLAG(&huart6);
        GameProtocol_ResetReceiver(&protocol);
        HAL_GPIO_WritePin(GPIOB, GPIO_PIN_14, GPIO_PIN_SET);
    }
    status = HAL_UART_Receive(&huart6, &byte, 1U, 0U);
    if (status == HAL_OK && GameProtocol_ReceiveByte(&protocol, byte, now) != 0U)
    {
        status = HAL_UART_Transmit(&huart6, protocol.reply, GAME_REPLY_SIZE, 5U);
        last_request_ms = now;
        have_request = 1U;
        HAL_GPIO_WritePin(GPIOB, GPIO_PIN_0, GPIO_PIN_SET);
        HAL_GPIO_WritePin(GPIOB, GPIO_PIN_14,
                         status == HAL_OK ? GPIO_PIN_RESET : GPIO_PIN_SET);
        /* Log only just after a reply, at most once per second. The next input
           frame is ~16.7 ms away; this short message takes <6 ms at 115200. */
        if ((uint32_t)(now - last_log_ms) >= 1000U)
        {
            GameSnapshot snapshot;
            char message[80];
            GameEngine_Snapshot(&protocol.engine, &snapshot);
            last_log_ms = now;
            (void)snprintf(message, sizeof message,
                "GAME seq=%u x=%u y=%u flags=%u deaths=%u tx=%u\r\n",
                (unsigned)protocol.last_sequence, (unsigned)snapshot.x,
                (unsigned)snapshot.y, (unsigned)snapshot.flags,
                (unsigned)snapshot.deaths, (unsigned)status);
            LogText(message);
        }
    }
    if (have_request == 0U || (uint32_t)(now - last_request_ms) >= 1000U)
    {
        HAL_GPIO_WritePin(GPIOB, GPIO_PIN_0, GPIO_PIN_RESET);
        HAL_GPIO_WritePin(GPIOB, GPIO_PIN_14, GPIO_PIN_SET);
    }
}
