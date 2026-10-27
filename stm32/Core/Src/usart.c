#include "usart.h"
UART_HandleTypeDef huart3;
UART_HandleTypeDef huart6;

static void UART_Config(UART_HandleTypeDef *uart, USART_TypeDef *instance)
{
    uart->Instance = instance;
    uart->Init.BaudRate = 115200;
    uart->Init.WordLength = UART_WORDLENGTH_8B;
    uart->Init.StopBits = UART_STOPBITS_1;
    uart->Init.Parity = UART_PARITY_NONE;
    uart->Init.Mode = UART_MODE_TX_RX;
    uart->Init.HwFlowCtl = UART_HWCONTROL_NONE;
    uart->Init.OverSampling = UART_OVERSAMPLING_16;
    if (HAL_UART_Init(uart) != HAL_OK) Error_Handler();
}
void MX_USART3_UART_Init(void) { UART_Config(&huart3, USART3); }
void MX_USART6_UART_Init(void) { UART_Config(&huart6, USART6); }
