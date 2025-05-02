import { Controller } from "@hotwired/stimulus"
import Chart from 'chart.js/auto'

export default class extends Controller {
  static values = { data: Object }

  connect() {
    this.initChart()
  }

  initChart() {
    if (!this.dataValue || !this.element) return
    
    const data = this.dataValue
    
    // Данные для исторических значений и прогнозов
    let historicalData = []
    let forecastData = []
    
    // Если есть текущие данные для исторических значений
    if (data.current_data && data.current_data.timestamps && data.current_data.values) {
      data.current_data.timestamps.forEach((timestamp, i) => {
        historicalData.push({
          x: new Date(timestamp * 1000),
          y: data.current_data.values[i]
        })
      })
    }
    
    // Если есть данные событий (прогнозов)
    if (data.events && data.events.length > 0) {
      data.events.forEach((event) => {
        if (event.type === 'prediction') {
          forecastData.push({
            x: new Date(event.timestamp * 1000),
            y: event.value
          })
        }
      })
    }
    
    // Создаем график
    new Chart(this.element, {
      type: 'line',
      data: {
        datasets: [
          {
            label: 'Исторические значения',
            data: historicalData,
            fill: false,
            borderColor: 'rgba(54, 162, 235, 1)',
            tension: 0.1,
            pointRadius: 2
          },
          {
            label: 'Прогноз',
            data: forecastData,
            fill: false,
            borderColor: 'rgba(255, 159, 64, 1)',
            borderDash: [5, 5],
            tension: 0.1,
            pointRadius: 2
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          title: {
            display: true,
            text: 'Прогнозирование трендов'
          },
          tooltip: {
            callbacks: {
              title: function(context) {
                const date = new Date(context[0].parsed.x)
                return new Intl.DateTimeFormat('ru-RU', {
                  day: '2-digit',
                  month: '2-digit',
                  year: 'numeric',
                  hour: '2-digit',
                  minute: '2-digit'
                }).format(date)
              }
            }
          }
        },
        scales: {
          x: {
            type: 'time',
            time: {
              unit: 'hour',
              displayFormats: {
                hour: 'dd.MM HH:mm'
              }
            },
            title: {
              display: true,
              text: 'Дата и время'
            }
          },
          y: {
            title: {
              display: true,
              text: 'Значение'
            },
            beginAtZero: false
          }
        }
      }
    })
  }
  
  disconnect() {
    // Очистка ресурсов при отключении контроллера
  }
}