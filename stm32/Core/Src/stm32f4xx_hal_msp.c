#include "main.h"
void HAL_MspInit(void)
{
    __HAL_RCC_SYSCFG_CLK_ENABLE();
    __HAL_RCC_PWR_CLK_ENABLE();
    HAL_NVIC_SetPriorityGrouping(NVIC_PRIORITYGROUP_4);
}
void HAL_UART_MspInit(UART_HandleTypeDef *uart)
{
    GPIO_InitTypeDef gpio = {0};
    gpio.Mode = GPIO_MODE_AF_PP;
    gpio.Pull = GPIO_PULLUP;
    gpio.Speed = GPIO_SPEED_FREQ_VERY_HIGH;
    if (uart->Instance == USART3)
    {
        __HAL_RCC_USART3_CLK_ENABLE();
        __HAL_RCC_GPIOD_CLK_ENABLE();
        gpio.Pin = GPIO_PIN_8 | GPIO_PIN_9;
        gpio.Alternate = GPIO_AF7_USART3;
        HAL_GPIO_Init(GPIOD, &gpio);
    }
    else if (uart->Instance == USART6)
    {
        __HAL_RCC_USART6_CLK_ENABLE();
        __HAL_RCC_GPIOG_CLK_ENABLE();
        gpio.Pin = GPIO_PIN_14 | GPIO_PIN_9;
        gpio.Alternate = GPIO_AF8_USART6;
        HAL_GPIO_Init(GPIOG, &gpio);
    }
}
