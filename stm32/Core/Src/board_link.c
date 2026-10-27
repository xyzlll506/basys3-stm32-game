#include "board_link.h"
#include "main.h"
#include "usart.h"
#include <stdio.h>
#include <string.h>

#define REQUEST_HEADER  0xA5U
#define RESPONSE_HEADER 0x5AU
#define TEST_PERIOD_MS  500U
#define RECEIVE_TIMEOUT_MS 100U

static uint8_t sequence;
static uint32_t last_test;

static void Log_Text(const char *text)
{
    (void)HAL_UART_Transmit(&huart3, (uint8_t *)text,
                            (uint16_t)strlen(text), 100U);
}

void BoardLink_Init(void)
{
    sequence = 0;
    last_test = HAL_GetTick();
    Log_Text("\r\nNUCLEO-F413ZH <-> Basys 3 UART starter\r\n");
    Log_Text("HSI=16MHz; USART6 PG14(TX)/PG9(RX); 115200 8N1\r\n");
    Log_Text("Request=A5 seq data xor; response=5A seq data xor\r\n");
}

void BoardLink_Task(void)
{
    uint8_t tx[4];
    uint8_t rx[4] = {0};
    HAL_StatusTypeDef tx_status;
    HAL_StatusTypeDef rx_status;
    char text[112];

    if ((uint32_t)(HAL_GetTick() - last_test) < TEST_PERIOD_MS) return;
    last_test = HAL_GetTick();
    HAL_GPIO_TogglePin(GPIOB, GPIO_PIN_7);

    tx[0] = REQUEST_HEADER;
    tx[1] = sequence;
    tx[2] = sequence;
    tx[3] = tx[0] ^ tx[1] ^ tx[2];

    /* Remove a stale byte/error from a previous timed-out transaction. */
    __HAL_UART_CLEAR_OREFLAG(&huart6);
    tx_status = HAL_UART_Transmit(&huart6, tx, sizeof tx, 20U);
    if (tx_status != HAL_OK)
    {
        HAL_GPIO_WritePin(GPIOB, GPIO_PIN_14, GPIO_PIN_SET);
        (void)snprintf(text, sizeof text, "TX_ERROR seq=%u status=%u\r\n",
                       (unsigned)sequence, (unsigned)tx_status);
        Log_Text(text);
        sequence++;
        return;
    }

    rx_status = HAL_UART_Receive(&huart6, rx, sizeof rx, RECEIVE_TIMEOUT_MS);
    if (rx_status == HAL_TIMEOUT)
    {
        HAL_GPIO_WritePin(GPIOB, GPIO_PIN_14, GPIO_PIN_SET);
        (void)snprintf(text, sizeof text, "TIMEOUT seq=%u data=0x%02X\r\n",
                       (unsigned)sequence, (unsigned)tx[2]);
    }
    else if (rx_status == HAL_OK && rx[0] == RESPONSE_HEADER &&
             rx[1] == sequence && rx[2] == tx[2] &&
             rx[3] == (uint8_t)(rx[0] ^ rx[1] ^ rx[2]))
    {
        HAL_GPIO_TogglePin(GPIOB, GPIO_PIN_0);
        HAL_GPIO_WritePin(GPIOB, GPIO_PIN_14, GPIO_PIN_RESET);
        (void)snprintf(text, sizeof text, "PASS seq=%u data=0x%02X\r\n",
                       (unsigned)sequence, (unsigned)tx[2]);
    }
    else
    {
        HAL_GPIO_WritePin(GPIOB, GPIO_PIN_14, GPIO_PIN_SET);
        (void)snprintf(text, sizeof text,
                       "BAD seq=%u status=%u rx=%02X %02X %02X %02X\r\n",
                       (unsigned)sequence, (unsigned)rx_status,
                       (unsigned)rx[0], (unsigned)rx[1],
                       (unsigned)rx[2], (unsigned)rx[3]);
    }
    Log_Text(text);
    sequence++;
}
