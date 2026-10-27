#include "gpio.h"
void MX_GPIO_Init(void)
{
    GPIO_InitTypeDef gpio = {0};
    __HAL_RCC_GPIOB_CLK_ENABLE();
    HAL_GPIO_WritePin(LED_GPIO_Port, LED_GREEN_Pin | LED_BLUE_Pin | LED_RED_Pin,
                     GPIO_PIN_RESET);
    gpio.Pin = LED_GREEN_Pin | LED_BLUE_Pin | LED_RED_Pin;
    gpio.Mode = GPIO_MODE_OUTPUT_PP;
    gpio.Pull = GPIO_NOPULL;
    gpio.Speed = GPIO_SPEED_FREQ_LOW;
    HAL_GPIO_Init(LED_GPIO_Port, &gpio);
}
