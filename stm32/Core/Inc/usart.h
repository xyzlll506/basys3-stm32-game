#ifndef USART_H
#define USART_H
#include "main.h"
extern UART_HandleTypeDef huart3;
extern UART_HandleTypeDef huart6;
void MX_USART3_UART_Init(void);
void MX_USART6_UART_Init(void);
#endif
