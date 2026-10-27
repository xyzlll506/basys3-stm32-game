/* NUCLEO-F413ZH: USART6 <-> Basys 3, USART3 -> ST-LINK virtual COM. */
#include "main.h"
#include "gpio.h"
#include "usart.h"
#include "board_link.h"

int main(void)
{
    HAL_Init();
    SystemClock_Config();
    MX_GPIO_Init();
    MX_USART3_UART_Init();
    MX_USART6_UART_Init();
    /* USER CODE BEGIN 2 */
    BoardLink_Init();
    /* USER CODE END 2 */
    while (1)
    {
        /* USER CODE BEGIN 3 */
        BoardLink_Task();
        /* USER CODE END 3 */
    }
}

void SystemClock_Config(void)
{
    RCC_OscInitTypeDef osc = {0};
    RCC_ClkInitTypeDef clk = {0};
    __HAL_RCC_PWR_CLK_ENABLE();
    __HAL_PWR_VOLTAGESCALING_CONFIG(PWR_REGULATOR_VOLTAGE_SCALE1);
    osc.OscillatorType = RCC_OSCILLATORTYPE_HSI;
    osc.HSIState = RCC_HSI_ON;
    osc.HSICalibrationValue = RCC_HSICALIBRATION_DEFAULT;
    osc.PLL.PLLState = RCC_PLL_NONE;
    if (HAL_RCC_OscConfig(&osc) != HAL_OK) Error_Handler();
    clk.ClockType = RCC_CLOCKTYPE_HCLK | RCC_CLOCKTYPE_SYSCLK |
                    RCC_CLOCKTYPE_PCLK1 | RCC_CLOCKTYPE_PCLK2;
    clk.SYSCLKSource = RCC_SYSCLKSOURCE_HSI;
    clk.AHBCLKDivider = RCC_SYSCLK_DIV1;
    clk.APB1CLKDivider = RCC_HCLK_DIV1;
    clk.APB2CLKDivider = RCC_HCLK_DIV1;
    if (HAL_RCC_ClockConfig(&clk, FLASH_LATENCY_0) != HAL_OK) Error_Handler();
}

void Error_Handler(void)
{
    __disable_irq();
    __HAL_RCC_GPIOB_CLK_ENABLE();
    /* This output setup also makes early initialization failures visible. */
    {
        GPIO_InitTypeDef led = {0};
        led.Pin = LED_RED_Pin;
        led.Mode = GPIO_MODE_OUTPUT_PP;
        led.Pull = GPIO_NOPULL;
        led.Speed = GPIO_SPEED_FREQ_LOW;
        HAL_GPIO_Init(LED_GPIO_Port, &led);
    }
    HAL_GPIO_WritePin(LED_GPIO_Port, LED_RED_Pin, GPIO_PIN_SET);
    while (1) { }
}
