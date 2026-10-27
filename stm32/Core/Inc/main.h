#ifndef MAIN_H
#define MAIN_H
#include "stm32f4xx_hal.h"
#define LED_GREEN_Pin GPIO_PIN_0
#define LED_BLUE_Pin  GPIO_PIN_7
#define LED_RED_Pin   GPIO_PIN_14
#define LED_GPIO_Port GPIOB
void SystemClock_Config(void);
void Error_Handler(void);
#endif
